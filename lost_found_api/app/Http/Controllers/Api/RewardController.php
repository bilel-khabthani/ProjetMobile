<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\CouponVoucherMail;
use App\Models\Reward;
use App\Models\UserCoupon;
use App\Services\PdfService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class RewardController extends Controller
{
    /** Dernière erreur d'envoi d'e-mail, remontée au client le cas échéant. */
    protected ?string $lastMailError = null;

    /**
     * Catalogue des récompenses disponibles à l'échange.
     */
    public function index()
    {
        // Mise à niveau des tarifs vers des valeurs attractives et réalistes
        $priceMap = [
            'Cafétéria Centrale' => 100,
            'Campus Resto' => 150,
            'Glovo Express' => 200,
            'Yassir Express' => 250,
            'Jumia Food' => 350,
        ];

        foreach ($priceMap as $partner => $cost) {
            Reward::where('partner_name', $partner)
                ->where('points_cost', '<', $cost)
                ->update(['points_cost' => $cost]);
        }

        $rewards = Reward::where('is_active', true)
            ->orderBy('points_cost')
            ->get();

        return response()->json($rewards);
    }

    /**
     * Portefeuille de coupons de l'utilisateur connecté.
     */
    public function myCoupons(Request $request)
    {
        $coupons = $request->user()
            ->coupons()
            ->latest()
            ->get()
            ->map(function (UserCoupon $coupon) {
                // Actualise le statut si la date d'expiration est dépassée
                if ($coupon->status === 'ACTIVE' && $coupon->isExpired()) {
                    $coupon->update(['status' => 'EXPIRED']);
                }

                return [
                    'id' => $coupon->id,
                    'title' => $coupon->title,
                    'partner_name' => $coupon->partner_name,
                    'partner_type' => $coupon->partner_type,
                    'code' => $coupon->code,
                    'discount_text' => $coupon->discount_text,
                    'status' => $coupon->status,
                    'source' => $coupon->source,
                    'terms' => $coupon->terms,
                    'expires_at' => $coupon->expires_at->toIso8601String(),
                    'used_at' => $coupon->used_at?->toIso8601String(),
                    'created_at' => $coupon->created_at->toIso8601String(),
                    'pdf_url' => url("/api/rewards/coupons/{$coupon->id}/pdf"),
                ];
            });

        return response()->json($coupons);
    }

    /**
     * Solde de points, statut du tour gratuit et historique de l'utilisateur.
     */
    public function wallet(Request $request)
    {
        $user = $request->user();

        $history = $user->rewardTransactions()
            ->latest('created_at')
            ->limit(30)
            ->get()
            ->map(fn ($tx) => [
                'id' => $tx->id,
                'type' => $tx->type,
                'points' => $tx->points,
                'description' => $tx->description,
                'created_at' => $tx->created_at->toIso8601String(),
            ]);

        return response()->json([
            'points' => $user->reward_points ?? 0,
            'can_spin_free_today' => $user->canSpinFreeToday(),
            'spin_cost' => 0,
            'history' => $history,
        ]);
    }

    /**
     * Échange de points contre un coupon de réduction.
     */
    public function redeem(Request $request, Reward $reward)
    {
        $user = $request->user();

        if ($user->reward_points < $reward->points_cost) {
            return response()->json([
                'message' => 'Solde insuffisant : il vous faut '.$reward->points_cost.' points.',
            ], 422);
        }

        // Déduction des points
        $user->addRewardPoints(
            -$reward->points_cost,
            'COUPON_REDEEM',
            'Échange contre : '.$reward->title
        );

        // Génération d'un code promo unique
        $prefix = strtoupper(substr(preg_replace('/[^A-Za-z0-9]/', '', $reward->partner_name), 0, 5));
        $code = $prefix.'-'.strtoupper(Str::random(4)).'-'.rand(10, 99);

        $coupon = UserCoupon::create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'reward_id' => $reward->id,
            'title' => $reward->title,
            'partner_name' => $reward->partner_name,
            'partner_type' => $reward->partner_type,
            'code' => $code,
            'discount_text' => $reward->discount_text,
            'status' => 'ACTIVE',
            'source' => 'POINTS_EXCHANGE',
            'terms' => $reward->terms,
            'expires_at' => now()->addDays(30),
        ]);

        // Envoi automatique par e-mail avec PDF joint
        $emailSent = $this->safeSendCouponMail($coupon);
        $message = $emailSent
            ? 'Félicitations ! Votre coupon '.$reward->partner_name.' a été généré et envoyé par e-mail.'
            : 'Coupon '.$reward->partner_name.' généré. L\'e-mail n\'a pas pu être envoyé, vous pouvez le télécharger depuis « Mes Bons ».';

        return response()->json([
            'message' => $message,
            'email_sent' => $emailSent,
            'coupon' => $coupon,
            'new_balance' => $user->fresh()->reward_points,
        ], 201);
    }

    /**
     * Téléchargement du bon de réduction au format PDF.
     */
    public function downloadPdf(Request $request, UserCoupon $coupon, PdfService $pdfService)
    {
        if ($coupon->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $pdfBytes = $pdfService->generateCouponPdf($coupon);

        // Sauvegarder également une copie physique dans public/vouchers
        try {
            $dir = public_path('vouchers');
            if (! file_exists($dir)) {
                mkdir($dir, 0755, true);
            }
            file_put_contents($dir.'/Bon-Reduction-'.$coupon->code.'.pdf', $pdfBytes);
        } catch (\Throwable) {
        }

        return response($pdfBytes, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="Bon-Reduction-'.$coupon->code.'.pdf"',
            'Access-Control-Expose-Headers' => 'Content-Disposition',
        ]);
    }

    /**
     * Déclenchement manuel de l'envoi du coupon par e-mail (avec PDF joint).
     */
    public function sendEmail(Request $request, UserCoupon $coupon)
    {
        if ($coupon->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $targetEmail = $request->input('email', $request->user()->email);

        $sent = $this->safeSendCouponMail($coupon, $targetEmail);

        if (! $sent) {
            return response()->json([
                'status' => 'failed',
                'message' => "L'e-mail n'a pas pu être envoyé à ".$targetEmail.'. Vérifiez la configuration e-mail du serveur.',
            ], 502);
        }

        return response()->json([
            'status' => 'sent',
            'email_sent' => true,
            'message' => 'Le bon de réduction a été envoyé avec succès à '.$targetEmail.' avec le PDF en pièce jointe !',
        ]);
    }

    /**
     * Marquer un coupon comme utilisé lors du passage en caisse / livraison.
     */
    public function useCoupon(Request $request, UserCoupon $coupon)
    {
        if ($coupon->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        if ($coupon->status === 'USED') {
            return response()->json(['message' => 'Ce coupon a déjà été utilisé.'], 422);
        }

        if ($coupon->isExpired()) {
            return response()->json(['message' => 'Ce coupon a expiré.'], 422);
        }

        $coupon->update([
            'status' => 'USED',
            'used_at' => now(),
        ]);

        return response()->json([
            'message' => 'Coupon validé avec succès !',
            'coupon' => $coupon,
        ]);
    }

    /**
     * Mini-jeu : Roue de la Chance (Strictement 1 tour par jour et par utilisateur).
     * Répartition 100% Points avec probabilités inversées : plus les points montent, plus la chance diminue.
     */
    public function spinWheel(Request $request)
    {
        $user = $request->user();

        if (! $user->canSpinFreeToday()) {
            return response()->json([
                'message' => 'Vous avez déjà fait tourner la Roue aujourd\'hui ! Revenez demain pour votre prochain tour.',
            ], 422);
        }

        // Enregistrer immédiatement la date du tour du jour (1 seule fois par jour)
        $user->last_spin_at = now();
        $user->save();

        // 8 tranches de points : probabilités décroissantes quand les points augmentent
        $slices = [
            0 => [
                'index' => 0,
                'label' => '+5 Pts',
                'type' => 'POINTS',
                'points' => 5,
                'chance' => '35%',
                'color_hex' => '#10B981', // Vert émeraude
                'icon' => 'add_circle',
                'weight' => 35,
            ],
            1 => [
                'index' => 1,
                'label' => '+10 Pts',
                'type' => 'POINTS',
                'points' => 10,
                'chance' => '25%',
                'color_hex' => '#3B82F6', // Bleu
                'icon' => 'bolt',
                'weight' => 25,
            ],
            2 => [
                'index' => 2,
                'label' => '+15 Pts',
                'type' => 'POINTS',
                'points' => 15,
                'chance' => '15%',
                'color_hex' => '#8B5CF6', // Violet
                'icon' => 'stars',
                'weight' => 15,
            ],
            3 => [
                'index' => 3,
                'label' => '+20 Pts',
                'type' => 'POINTS',
                'points' => 20,
                'chance' => '10%',
                'color_hex' => '#6366F1', // Indigo
                'icon' => 'card_giftcard',
                'weight' => 10,
            ],
            4 => [
                'index' => 4,
                'label' => '+30 Pts',
                'type' => 'POINTS',
                'points' => 30,
                'chance' => '7%',
                'color_hex' => '#F59E0B', // Ambre
                'icon' => 'military_tech',
                'weight' => 7,
            ],
            5 => [
                'index' => 5,
                'label' => '+50 Pts',
                'type' => 'POINTS',
                'points' => 50,
                'chance' => '4%',
                'color_hex' => '#F97316', // Orange
                'icon' => 'diamond',
                'weight' => 4,
            ],
            6 => [
                'index' => 6,
                'label' => '+75 Pts',
                'type' => 'POINTS',
                'points' => 75,
                'chance' => '3%',
                'color_hex' => '#EC4899', // Rose
                'icon' => 'workspace_premium',
                'weight' => 3,
            ],
            7 => [
                'index' => 7,
                'label' => 'JACKPOT 100',
                'type' => 'POINTS',
                'points' => 100,
                'chance' => '1%',
                'color_hex' => '#EAB308', // Or
                'icon' => 'emoji_events',
                'weight' => 1,
            ],
        ];

        // Tirage pondéré
        $totalWeight = array_sum(array_column($slices, 'weight'));
        $random = rand(1, $totalWeight);
        $current = 0;
        $winningSlice = $slices[0]; // fallback

        foreach ($slices as $slice) {
            $current += $slice['weight'];
            if ($random <= $current) {
                $winningSlice = $slice;
                break;
            }
        }

        $pts = $winningSlice['points'];
        $user->addRewardPoints($pts, 'WHEEL_WIN', 'Gain à la Roue de la Chance ('.$winningSlice['label'].')');
        $message = 'Félicitations ! Vous avez remporté '.$pts.' points sur la Roue de la Chance (Chance : '.$winningSlice['chance'].') ! Utilisez vos points dans la boutique pour obtenir vos bons de réduction.';

        return response()->json([
            'prize_index' => $winningSlice['index'],
            'prize' => [
                'index' => $winningSlice['index'],
                'label' => $winningSlice['label'],
                'type' => 'POINTS',
                'color_hex' => $winningSlice['color_hex'],
                'icon' => $winningSlice['icon'],
                'points' => $pts,
                'chance' => $winningSlice['chance'],
            ],
            'message' => $message,
            'new_balance' => $user->fresh()->reward_points,
            'can_spin_free_today' => false,
        ]);
    }

    /**
     * Envoie l'e-mail du coupon (avec PDF joint) au destinataire ressorti du
     * coupon ou a l'adresse demandee. Toute anomalie est journalisee : un
     * echec de messagerie ne doit jamais passer inapercu.
     */
    protected function safeSendCouponMail(UserCoupon $coupon, ?string $toEmail = null): bool
    {
        $this->lastMailError = null;

        try {
            $dest = $toEmail ?: $coupon->user?->email;

            // Les comptes de démo utilisent @campus.fr (boîte inexistante).
            // On ne redirige que si MAIL_DEMO_REDIRECT est explicitement configuré.
            $demoRedirect = config('mail.demo_redirect');
            if ($demoRedirect && (! $dest || str_ends_with($dest, '@campus.fr'))) {
                $dest = $demoRedirect;
            }

            if (! $dest) {
                throw new \RuntimeException('Aucune adresse e-mail destinataire.');
            }

            Mail::to($dest)->send(new CouponVoucherMail($coupon));
            Log::info("E-mail de coupon envoye avec PDF joint a : {$dest}");

            return true;
        } catch (\Throwable $e) {
            $this->lastMailError = $e->getMessage();
            Log::error('Echec d\'envoi de l\'e-mail du coupon '.$coupon->id.' : '.$this->lastMailError);

            return false;
        }
    }
}
