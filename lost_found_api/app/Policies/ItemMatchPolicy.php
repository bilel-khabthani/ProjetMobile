<?php

namespace App\Policies;

use App\Models\ItemMatch;
use App\Models\User;
use App\Services\TrustService;

class ItemMatchPolicy
{
    public function __construct(private readonly TrustService $trust) {}

    /**
     * Seules les deux parties de la correspondance peuvent consulter le match.
     */
    public function view(User $user, ItemMatch $match): bool
    {
        return $match->lostItem?->user_id === $user->id
            || $match->foundItem?->user_id === $user->id;
    }

    /**
     * Le chat exige en plus un numero verifie, un match non PENDING et un
     * score de confiance suffisant (CDC 6.4.3).
     */
    public function chat(User $user, ItemMatch $match): bool
    {
        return $this->trust->canOpenChat($user, $match);
    }

    /**
     * Une reclamation liee a un match reste reservee a ses participants.
     */
    public function report(User $user, ItemMatch $match): bool
    {
        return $this->view($user, $match);
    }
}
