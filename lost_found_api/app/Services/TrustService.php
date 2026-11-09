<?php

namespace App\Services;

use App\Mail\CouponVoucherMail;
use App\Models\ItemMatch;
use App\Models\User;
use App\Models\UserCoupon;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

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
     * Chat autorise seulement si l'utilisateur est partie au match, que le
     * proprietaire a verifie la correspondance et que son score est suffisant.
     * Le controle de participation est indispensable : sans lui, tout compte
     * verifie pourrait lire n'importe quelle conversation (IDOR).
     */
    public function canOpenChat(User $user, ItemMatch $match): bool
    {
        return $this->chatLockReason($user, $match) === null;
    }

    /**
     * Explique pourquoi le chat est verrouille. Retourne null quand il est
     * accessible, sinon un message affichable dans l'application.
     */
    public function chatLockReason(User $user, ItemMatch $match): ?string
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

        if ($user->trust_score < self::MIN_SCORE_TO_CHAT) {
            return 'Votre score de confiance doit atteindre '
                .self::MIN_SCORE_TO_CHAT.' points pour discuter.';
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
}
