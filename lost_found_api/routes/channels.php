<?php

use App\Models\ItemMatch;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Canaux de diffusion
|--------------------------------------------------------------------------
| Le chat utilise un canal prive par correspondance. L'autorisation reprend
| la policy du match : seules les deux parties peuvent s'abonner.
*/

Broadcast::channel('match.{matchId}', function (User $user, string $matchId): bool {
    $match = ItemMatch::query()
        ->with(['lostItem:id,user_id', 'foundItem:id,user_id'])
        ->find($matchId);

    return $match !== null && $user->can('chat', $match);
});
