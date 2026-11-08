<?php

namespace Database\Seeders;

use App\Models\Reward;
use App\Models\User;
use App\Models\UserCoupon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class RewardSeeder extends Seeder
{
    public function run(): void
    {
        $rewards = [
            [
                'title' => 'Livraison Offerte Glovo',
                'partner_name' => 'Glovo Express',
                'partner_type' => 'DELIVERY',
                'description' => 'Frais de livraison 100% offerts sur toute commande de repas, courses ou pharmacie via l\'application Glovo.',
                'points_cost' => 200,
                'discount_text' => 'Livraison 100% Gratuite',
                'icon_name' => 'delivery_dining',
                'color_hex' => '#FFC244',
                'terms' => 'Valable 30 jours sur l\'application Glovo sans montant minimum de commande.',
                'stock' => 150,
            ],
            [
                'title' => 'Bon Livraison Yassir Express',
                'partner_name' => 'Yassir Express',
                'partner_type' => 'DELIVERY',
                'description' => 'Une livraison express ou une course offerte sur tout le réseau Yassir dans la métropole.',
                'points_cost' => 250,
                'discount_text' => 'Livraison / Course Offerte',
                'icon_name' => 'local_shipping',
                'color_hex' => '#00A859',
                'terms' => 'Valable sur une course ou livraison de repas jusqu\'à 10 DT.',
                'stock' => 100,
            ],
            [
                'title' => 'Menu Sandwich / Burger -30%',
                'partner_name' => 'Campus Resto',
                'partner_type' => 'RESTAURANT',
                'description' => '30% de remise immédiate sur tous les menus chauds, pizzas et burgers de la cafétéria du campus.',
                'points_cost' => 150,
                'discount_text' => '-30% sur votre repas',
                'icon_name' => 'restaurant',
                'color_hex' => '#E11D48',
                'terms' => 'Valable au comptoir du restaurant universitaire sur présentation du QR code.',
                'stock' => 200,
            ],
            [
                'title' => 'Formule Pause Café Offerte',
                'partner_name' => 'Cafétéria Centrale',
                'partner_type' => 'CAFE',
                'description' => 'Un café expresso ou capuccino accompagné d\'une viennoiserie pur beurre offerte.',
                'points_cost' => 100,
                'discount_text' => 'Café + Croissant Offert',
                'icon_name' => 'coffee',
                'color_hex' => '#8B5CF6',
                'terms' => 'À retirer aux heures de pause (8h - 17h) du lundi au samedi.',
                'stock' => 300,
            ],
            [
                'title' => 'Bon d\'achat 15 DT Jumia',
                'partner_name' => 'Jumia Food',
                'partner_type' => 'SHOPPING',
                'description' => 'Bon de réduction de 15 DT applicable sur votre prochaine commande Jumia Food.',
                'points_cost' => 350,
                'discount_text' => 'Bon d\'achat 15 DT',
                'icon_name' => 'card_giftcard',
                'color_hex' => '#F97316',
                'terms' => 'Code promotionnel valable dès 30 DT d\'achats sur Jumia.',
                'stock' => 50,
            ],
        ];

        foreach ($rewards as $data) {
            Reward::firstOrCreate(
                ['partner_name' => $data['partner_name'], 'title' => $data['title']],
                $data
            );
        }

        // Pour chaque utilisateur existant (Amina, Karim, etc.), attribuer des points initiaux
        // et un coupon Glovo actif de démonstration
        $users = User::all();
        $glovoReward = Reward::where('partner_name', 'Glovo Express')->first();

        foreach ($users as $user) {
            $user->update([
                'reward_points' => max(150, $user->reward_points ?? 150),
            ]);

            // Créer un coupon de bienvenue si l'utilisateur n'en a pas
            if (! $user->coupons()->exists() && $glovoReward) {
                UserCoupon::create([
                    'id' => (string) Str::uuid(),
                    'user_id' => $user->id,
                    'reward_id' => $glovoReward->id,
                    'title' => 'Livraison Offerte Glovo — Bonus Citoyen',
                    'partner_name' => 'Glovo Express',
                    'partner_type' => 'DELIVERY',
                    'code' => 'GLOVO-CAMPUS-'.strtoupper(Str::random(4)),
                    'discount_text' => 'Livraison 100% Gratuite',
                    'status' => 'ACTIVE',
                    'source' => 'RESTITUTION',
                    'terms' => 'Offert suite à votre comportement exemplaire dans la communauté Lost&Found.',
                    'expires_at' => now()->addDays(30),
                ]);

                $user->rewardTransactions()->create([
                    'id' => (string) Str::uuid(),
                    'user_id' => $user->id,
                    'type' => 'WELCOME_BONUS',
                    'points' => 150,
                    'description' => 'Bienvenue sur Lost&Found AI — Crédit de points citoyen',
                    'created_at' => now(),
                ]);
            }
        }
    }
}

