<?php

namespace App\Services;

use App\Models\ItemMatch;
use App\Models\User;

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
     * Chat autorise seulement si le proprietaire a verifie le match et si
     * son score de confiance est suffisant (CDC 6.4.3).
     */
    public function canOpenChat(User $user, ItemMatch $match): bool
    {
        return $match->status !== ItemMatch::STATUS_PENDING
            && $user->trust_score >= self::MIN_SCORE_TO_CHAT;
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

        if (! $match->trustEvents()->where('user_id', $owner->id)->exists()) {
            $owner->applyTrustDelta(
                self::POINTS['RESTITUTION_CONFIRMEE'],
                'RESTITUTION_CONFIRMEE',
                'Restitution confirmee par les deux parties.',
                $match->id
            );
            $owner->increment('recovered_count');
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
