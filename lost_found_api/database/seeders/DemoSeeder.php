<?php

namespace Database\Seeders;

use App\Models\Item;
use App\Models\User;
use App\Services\MatchingService;
use Illuminate\Database\Seeder;

/**
 * Jeu de donnees de demonstration : un campus, deux utilisateurs, une
 * declaration perdue et une declaration trouvee qui doivent correspondre.
 */
class DemoSeeder extends Seeder
{
    public function run(MatchingService $matching): void
    {
        $owner = User::firstOrCreate(
            ['email' => 'amina@campus.fr'],
            [
                'name' => 'Amina Benali',
                // "campus2026" : meme mot de passe que dans l'ecran de connexion Flutter.
                'password' => 'campus2026',
                'phone' => '+33601020304',
                'phone_verified' => true,
                'trust_score' => 72,
            ]
        );

        $finder = User::firstOrCreate(
            ['email' => 'karim@campus.fr'],
            [
                'name' => 'Karim Mansouri',
                'password' => 'campus2026',
                'phone' => '+33605060708',
                'phone_verified' => true,
                'trust_score' => 88,
            ]
        );

        $found = Item::firstOrCreate(
            ['title' => 'Sac a dos Nike noir', 'type' => Item::TYPE_FOUND, 'user_id' => $finder->id],
            [
                'category' => 'sac',
                'description' => 'Sac a dos Nike noir trouve vers le batiment B, poche frontale fermee par un zip.',
                // Reponse attendue a la question de verification.
                'secret_detail' => 'Etiquette bleue "CAMPUS" cousue a l\'interieur.',
                'latitude' => 48.8566,
                'longitude' => 2.3522,
                'place_label' => 'Batiment B, universite',
                'occurred_at' => now()->subDays(2),
                'status' => 'ACTIVE',
            ]
        );

        $lost = Item::firstOrCreate(
            ['title' => 'Sac Nike noir', 'type' => Item::TYPE_LOST, 'user_id' => $owner->id],
            [
                'category' => 'sac',
                'description' => 'Sac a dos Nike noir avec une poche frontale, perdu apres les cours de l\'apres-midi.',
                'secret_detail' => 'Etiquette bleue "CAMPUS" a l\'interieur du sac.',
                'latitude' => 48.8570,
                'longitude' => 2.3518,
                'place_label' => 'Batiment B, universite',
                'occurred_at' => now()->subDays(2)->subHours(3),
                'status' => 'ACTIVE',
            ]
        );

        // Declenche le moteur de matching pour alimenter la liste des matchs.
        $matching->findMatches($lost);
    }
}
