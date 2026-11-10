<?php

namespace App\Services;

use App\Mail\CouponVoucherMail;
use App\Models\ItemMatch;
use App\Models\Message;
use App\Models\ModerationEvent;
use App\Models\TrustEvent;
use App\Models\User;
use App\Models\UserCoupon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use InvalidArgumentException;

/**
 * Module 4 - Score de confiance et prevention de la fraude (CDC 6.4).
 *
 * Regles appliquees :
 * - tout evenement de score est systematique, jamais declare par l'utilisateur ;
 * - un garde-fou STRICT interdit a un utilisateur d'etre a la fois
 *   le declarant d'un objet perdu et de l'objet trouve correspondant ;
 * - le chat ne s'ouvre qu'apres verification du proprietaire ;
 * - la restitution exige une double confirmation (voir ItemMatch::isFullyConfirmed).
 */
class TrustService
{
    /** Bareme des evenements verifiables (CDC 6.4.4). */
    public const POINTS = [
        'RESTITUTION_CONFIRMEE' => 15,
        'DECLARATION_FAUSSE' => -30,
        'ABSENCE_RDV' => -5,
        'RECLAMATION_FONDEE' => -10,
        'RECLAMATION_ABUSIVE' => -5,
        'MESSAGE_INAPPROPRIE' => -5,
        'BON_REPORT' => 2,
    ];

    public const MIN_SCORE_TO_CHAT = 40;

    public const MIN_SCORE_TO_COORDINATE = 30;

    public const COORDINATION_MESSAGE_LIMIT = 5;

    public const CHAT_MODE_FULL = 'FULL';

    public const CHAT_MODE_COORDINATION = 'COORDINATION';

    public const CHAT_MODE_LOCKED = 'LOCKED';

    /**
     * Garde-fou anti auto-restitution (CDC 6.4.3, exigence STRICT).
     * Retourne un message d'erreur, ou null si la correspondance est autorisee.
     */
    public function blockSelfMatch(int $lostOwnerId, int $foundOwnerId): ?string
    {
        if ($lostOwnerId === $foundOwnerId) {
            return 'Auto-restitution interdite : un utilisateur ne peut pas '
                .'declarer a la fois un objet perdu et l\'objet trouve correspondant.';
        }

        return null;
    }

    /**
     * Chat autorise si l'utilisateur est partie au match, que le proprietaire
     * a verifie la correspondance et que son score permet au moins une
     * coordination limitee.
     */
    public function canOpenChat(User $user, ItemMatch $match): bool
    {
        return $this->chatMode($user, $match) !== self::CHAT_MODE_LOCKED;
    }

    /**
     * Mode de chat effectif : complet, coordination limitee ou verrouille.
     * La coordination permet de finaliser une restitution sans ouvrir le chat
     * complet a un compte encore sous le seuil de confiance.
     */
    public function chatMode(User $user, ItemMatch $match): string
    {
        if ($this->chatBaseLockReason($user, $match) !== null) {
            return self::CHAT_MODE_LOCKED;
        }

        if ($user->trust_score < self::MIN_SCORE_TO_COORDINATE) {
            return self::CHAT_MODE_LOCKED;
        }

        return $user->trust_score >= self::MIN_SCORE_TO_CHAT
            ? self::CHAT_MODE_FULL
            : self::CHAT_MODE_COORDINATION;
    }

    /**
     * Explique pourquoi le chat est verrouille. Retourne null quand une
     * coordination ou le chat complet est accessible.
     */
    public function chatLockReason(User $user, ItemMatch $match): ?string
    {
        $baseReason = $this->chatBaseLockReason($user, $match);

        if ($baseReason !== null) {
            return $baseReason;
        }

        if ($user->trust_score < self::MIN_SCORE_TO_COORDINATE) {
            return 'Votre score de confiance doit atteindre '
                .self::MIN_SCORE_TO_COORDINATE.' points pour une coordination '
                .'limitée, et '.self::MIN_SCORE_TO_CHAT.' points pour discuter librement.';
        }

        return null;
    }

    /**
     * Nombre de messages de coordination restants pour ce match.
     * Retourne null quand le chat complet est actif.
     */
    public function coordinationMessagesRemaining(User $user, ItemMatch $match): ?int
    {
        if ($this->chatMode($user, $match) !== self::CHAT_MODE_COORDINATION) {
            return null;
        }

        $sent = $match->messages()
            ->where('sender_id', $user->id)
            ->where('status', '!=', Message::STATUS_BLOCKED)
            ->count();

        $blocked = ModerationEvent::query()
            ->where('user_id', $user->id)
            ->where('match_id', $match->id)
            ->where('source', ModerationEvent::SOURCE_CHAT)
            ->where('decision', ModerationEvent::DECISION_BLOCK)
            ->count();

        return max(0, self::COORDINATION_MESSAGE_LIMIT - $sent - $blocked);
    }

    private function chatBaseLockReason(User $user, ItemMatch $match): ?string
    {
        $isParticipant = $match->lostItem?->user_id === $user->id
            || $match->foundItem?->user_id === $user->id;

        if (! $isParticipant) {
            return 'Vous ne participez pas à cette correspondance.';
        }

        if (! $user->phone_verified) {
            return 'Vérifiez votre numéro de téléphone pour discuter.';
        }

        if (! in_array($match->status, [
            ItemMatch::STATUS_VERIFIED,
            ItemMatch::STATUS_CONTACTED,
            ItemMatch::STATUS_RECOVERED,
        ], true)) {
            return 'La correspondance doit d\'abord être vérifiée par le propriétaire.';
        }

        return null;
    }

    /**
     * Enregistre la restitution : le proprietaire et celui qui a trouve
     * l'objet doivent avoir confirme tous les deux avant de crediter le score.
     */
    public function registerRestitution(ItemMatch $match, User $actor): ?string
    {
        if (! $match->isFullyConfirmed()) {
            return 'La restitution n\'est validee qu\'apres double confirmation '
                .'(proprietaire et personne ayant trouve l\'objet).';
        }

        $owner = $match->lostItem->user;
        $finder = $match->foundItem->user;

        if (! $match->trustEvents()->where('user_id', $owner->id)->exists()) {
            $owner->applyTrustDelta(
                self::POINTS['RESTITUTION_CONFIRMEE'],
                'RESTITUTION_CONFIRMEE',
                'Restitution confirmee par les deux parties.',
                $match->id
            );
            $owner->increment('recovered_count');

            // Module 4 : Récompense automatique pour le trouveur citoyen (Points + Coupon Livraison + Mail)
            if ($finder) {
                $finder->applyTrustDelta(
                    self::POINTS['RESTITUTION_CONFIRMEE'],
                    'RESTITUTION_CONFIRMEE',
                    'Objet trouve restitue avec succes au proprietaire.',
                    $match->id
                );
                $finder->increment('recovered_count');
                $finder->addRewardPoints(100, 'RESTITUTION_BONUS', 'Récompense pour restitution de : '.$match->lostItem->title);

                $coupon = UserCoupon::create([
                    'id' => (string) Str::uuid(),
                    'user_id' => $finder->id,
                    'title' => 'Livraison Offerte Glovo — Restitution Citoyenne',
                    'partner_name' => 'Glovo Express',
                    'partner_type' => 'DELIVERY',
                    'code' => 'GLOVO-HERO-'.strtoupper(Str::random(4)),
                    'discount_text' => 'Livraison 100% Gratuite',
                    'status' => 'ACTIVE',
                    'source' => 'RESTITUTION',
                    'terms' => 'Récompense citoyenne offerte pour avoir restitué un objet perdu sur le campus.',
                    'expires_at' => now()->addDays(30),
                ]);

                try {
                    Mail::to($finder->email)->send(new CouponVoucherMail($coupon));
                } catch (\Throwable $e) {
                    Log::error('Echec d\'envoi de l\'e-mail de coupon (restitution) a '.$finder->email.' : '.$e->getMessage());
                }
            }

            $match->update(['status' => ItemMatch::STATUS_RECOVERED]);
            $match->lostItem->update(['status' => 'RECOVERED']);
            $match->foundItem->update(['status' => 'RECOVERED']);
        }

        return null;
    }

    /** Sanction appliquee apres arbitrage humain d'une reclamation fondee. */
    public function sanction(User $user, string $type): void
    {
        $user->applyTrustDelta(
            self::POINTS[$type] ?? -10,
            $type,
            'Evenement valide par un administrateur.',
        );
    }

    /**
     * Annule une sanction apres acceptation d'un appel. La correction est
     * volontairement hors probation : elle restitue exactement les points
     * retires, sinon un compte jeune ne recupererait que la moitie.
     */
    public function reverseSanction(
        TrustEvent $event,
        string $reason,
        string $validatedBy = 'ADMIN',
    ): TrustEvent {
        if ($event->points >= 0) {
            throw new InvalidArgumentException('Seule une sanction negative peut etre annulee.');
        }

        $alreadyReversed = TrustEvent::query()
            ->where('reversal_of_id', $event->id)
            ->exists();

        if ($alreadyReversed) {
            throw new InvalidArgumentException('Cette sanction a deja ete annulee.');
        }

        $user = $event->user;

        if (! $user) {
            throw new InvalidArgumentException('Utilisateur introuvable pour cet evenement.');
        }

        $user->trust_score = max(0, min(100, $user->trust_score - $event->points));
        $user->save();

        return TrustEvent::create([
            'user_id' => $user->id,
            'type' => 'SANCTION_ANNULEE',
            'points' => -$event->points,
            'related_match_id' => $event->related_match_id,
            'reversal_of_id' => $event->id,
            'validated_by' => $validatedBy,
            'reason' => $reason,
        ]);
    }
}
