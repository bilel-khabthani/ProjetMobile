<?php

namespace Database\Seeders;

use App\Models\Item;
use App\Models\User;
use App\Services\MatchingService;
use Illuminate\Database\Seeder;

/**
 * Jeu de donnees de demonstration : un campus, trois utilisateurs verifies et
 * plusieurs declarations qui alimentent le deck Tinder Cards.
 *
 * Comptes prets a l'emploi (aucun numero reel ni SMS requis) :
 * - amina@campus.fr / campus2026 : proprietaire d'une annonce perdue, c'est
 *   elle qui voit les cartes et peut repondre "c'est a moi".
 * - karim@campus.fr / campus2026 et sami@campus.fr / campus2026 : trouveurs.
 */
class DemoSeeder extends Seeder
{
    /** Mot de passe commun aux comptes de demonstration. */
    public const DEMO_PASSWORD = 'campus2026';

    public function run(MatchingService $matching): void
    {
        $owner = $this->user(
            'amina@campus.fr',
            'Amina Benali',
            '+33601020304',
            72
        );

        $karim = $this->user(
            'karim@campus.fr',
            'Karim Mansouri',
            '+33605060708',
            88
        );

        $sami = $this->user(
            'sami@campus.fr',
            'Sami Trabelsi',
            '+33607080910',
            64
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

        $foundItems = [
            [
                'user' => $karim,
                'title' => 'Sac a dos Nike noir trouve au batiment B',
                'category' => 'sac',
                'description' => 'Sac a dos Nike noir trouve vers le batiment B, poche frontale fermee par un zip.',
                'secret_detail' => 'Etiquette bleue "CAMPUS" cousue a l\'interieur.',
                'latitude' => 48.8566,
                'longitude' => 2.3522,
                'place_label' => 'Batiment B, universite',
                'occurred_at' => now()->subDays(2),
            ],
            [
                'user' => $sami,
                'title' => 'Sac a dos noir oublie a la bibliotheque',
                'category' => 'sac',
                'description' => 'Sac noir a dos retrouve sur une table de la bibliotheque, avec une poche avant zippee.',
                'secret_detail' => 'Un badge etudiant au nom d\'Amina a l\'interieur.',
                'latitude' => 48.8572,
                'longitude' => 2.3525,
                'place_label' => 'Bibliotheque universitaire',
                'occurred_at' => now()->subDay(),
            ],
            [
                'user' => $sami,
                'title' => 'Sac de sport noir trouve au gymnase',
                'category' => 'sac',
                'description' => 'Sac de sport noir trouve pres du gymnase, contenant une gourde et un porte-cles.',
                'secret_detail' => 'Bandes reflechissantes sur les sangles.',
                'latitude' => 48.8560,
                'longitude' => 2.3530,
                'place_label' => 'Gymnase, universite',
                'occurred_at' => now()->subHours(30),
            ],
        ];

        foreach ($foundItems as $data) {
            Item::firstOrCreate(
                [
                    'title' => $data['title'],
                    'type' => Item::TYPE_FOUND,
                    'user_id' => $data['user']->id,
                ],
                [
                    'category' => $data['category'],
                    'description' => $data['description'],
                    'secret_detail' => $data['secret_detail'],
                    'latitude' => $data['latitude'],
                    'longitude' => $data['longitude'],
                    'place_label' => $data['place_label'],
                    'occurred_at' => $data['occurred_at'],
                    'status' => 'ACTIVE',
                ]
            );
        }

        // Declenche le moteur de matching pour alimenter la liste des matchs et
        // le deck Tinder Cards des le premier lancement.
        $matching->findMatches($lost->fresh());
    }

    /** Cree (ou retrouve) un compte de demonstration deja verifie. */
    private function user(string $email, string $name, string $phone, int $trustScore): User
    {
        return User::firstOrCreate(
            ['email' => $email],
            [
                'name' => $name,
                'password' => self::DEMO_PASSWORD,
                'phone' => $phone,
                // Le numero est deja verifie : la connexion ne demande aucun
                // code et le middleware verified-phone laisse passer.
                'phone_verified' => true,
                'trust_score' => $trustScore,
            ]
        );
    }
}
