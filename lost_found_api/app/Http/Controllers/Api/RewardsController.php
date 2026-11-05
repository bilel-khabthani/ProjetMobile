<?php

namespace App\Http\Controllers\Api;

use App\Models\Item;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;

/**
 * Rewards Controller - Manages rewards and social sharing
 * Features:
 * - Coin rewards for actions (posting, helping recover, sharing)
 * - Leaderboards by rewards, success rate
 * - Social sharing of objects
 * - Badges and achievements
 * - Referral rewards
 */
class RewardsController extends Controller
{
    // Reward points for actions
    const COINS_PER_POST = 10;           // Post lost/found object
    const COINS_PER_RECOVERY = 100;      // Mark item recovered
    const COINS_PER_HELPFUL_MESSAGE = 5;  // Send helpful message
    const COINS_PER_SHARE = 2;           // Share object on social media
    const COINS_REFERRAL = 50;           // Referral reward

    /**
     * Get user's coin balance and rewards
     */
    public function balance(Request $request)
    {
        $user = $request->user();

        $coins = DB::table('user_rewards')
            ->where('user_id', $user->id)
            ->sum('coins') ?? 0;

        $badges = DB::table('user_badges')
            ->where('user_id', $user->id)
            ->pluck('badge_name')
            ->toArray();

        // Get recent activities
        $recentRewards = DB::table('user_rewards')
            ->where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->limit(10)
            ->get();

        return response()->json([
            'user_id' => $user->id,
            'total_coins' => $coins,
            'badges' => $badges,
            'recent_rewards' => $recentRewards,
        ]);
    }

    /**
     * Generate shareable link for an object
     */
    public function generateShareLink(Request $request, string $itemId)
    {
        $item = Item::findOrFail($itemId);
        $user = $request->user();

        // Only owner or admins can generate share links
        if ($item->user_id !== $user->id && !$user->is_admin) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        // Create unique share token
        $shareToken = bin2hex(random_bytes(16));

        DB::table('item_shares')->insert([
            'item_id' => $itemId,
            'shared_by_user_id' => $user->id,
            'share_token' => $shareToken,
            'platform' => $request->input('platform', 'generic'), // whatsapp, facebook, twitter
            'clicked_count' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Award sharing coins
        $this->awardCoins($user->id, self::COINS_PER_SHARE, "Shared {$item->type} item on {$request->input('platform', 'social media')}");

        $shareUrl = config('app.url') . "/share/{$shareToken}";

        return response()->json([
            'share_url' => $shareUrl,
            'share_token' => $shareToken,
            'coins_earned' => self::COINS_PER_SHARE,
        ]);
    }

    /**
     * Track share link click
     */
    public function trackShareClick(string $shareToken)
    {
        $share = DB::table('item_shares')
            ->where('share_token', $shareToken)
            ->first();

        if (!$share) {
            return response()->json(['error' => 'Invalid share link'], 404);
        }

        // Increment click count
        DB::table('item_shares')
            ->where('share_token', $shareToken)
            ->increment('clicked_count');

        // Get shared item
        $item = Item::find($share->item_id)->load('user');

        return response()->json([
            'item' => $item,
            'shared_by' => $share->shared_by_user_id,
        ]);
    }

    /**
     * Get leaderboards
     */
    public function leaderboards(Request $request)
    {
        $type = $request->input('type', 'coins'); // coins, success_rate, recoveries
        $limit = $request->input('limit', 10);

        if ($type === 'coins') {
            return response()->json($this->coinLeaderboard($limit));
        } elseif ($type === 'success_rate') {
            return response()->json($this->successRateLeaderboard($limit));
        } elseif ($type === 'recoveries') {
            return response()->json($this->recoveriesLeaderboard($limit));
        }

        return response()->json(['error' => 'Invalid leaderboard type'], 422);
    }

    /**
     * Get coin leaderboard
     */
    private function coinLeaderboard(int $limit): array
    {
        return DB::select("
            SELECT 
                u.id,
                u.name,
                u.avatar_path,
                COALESCE(SUM(ur.coins), 0) as total_coins,
                ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(ur.coins), 0) DESC) as rank
            FROM users u
            LEFT JOIN user_rewards ur ON u.id = ur.user_id
            GROUP BY u.id, u.name, u.avatar_path
            ORDER BY total_coins DESC
            LIMIT ?
        ", [$limit]);
    }

    /**
     * Get success rate leaderboard
     */
    private function successRateLeaderboard(int $limit): array
    {
        return DB::select("
            SELECT 
                u.id,
                u.name,
                u.avatar_path,
                COUNT(DISTINCT i.id) as total_posted,
                COUNT(DISTINCT CASE WHEN i.status = 'RECOVERED' THEN i.id END) as recovered,
                ROUND(COUNT(DISTINCT CASE WHEN i.status = 'RECOVERED' THEN i.id END) * 100.0 / 
                      NULLIF(COUNT(DISTINCT i.id), 0), 1) as success_rate,
                ROW_NUMBER() OVER (ORDER BY success_rate DESC) as rank
            FROM users u
            LEFT JOIN items i ON u.id = i.user_id
            GROUP BY u.id, u.name, u.avatar_path
            HAVING COUNT(DISTINCT i.id) >= 5
            ORDER BY success_rate DESC
            LIMIT ?
        ", [$limit]);
    }

    /**
     * Get recoveries leaderboard
     */
    private function recoveriesLeaderboard(int $limit): array
    {
        return DB::select("
            SELECT 
                u.id,
                u.name,
                u.avatar_path,
                COUNT(DISTINCT i.id) as recoveries,
                ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT i.id) DESC) as rank
            FROM users u
            LEFT JOIN items i ON u.id = i.user_id AND i.status = 'RECOVERED'
            GROUP BY u.id, u.name, u.avatar_path
            ORDER BY recoveries DESC
            LIMIT ?
        ", [$limit]);
    }

    /**
     * Get user's badges and achievements
     */
    public function badges(Request $request)
    {
        $user = $request->user();

        $badges = [
            ['name' => 'First Post', 'description' => 'Posted first item', 'coins' => 0],
            ['name' => 'Helper', 'description' => 'Sent 10 helpful messages', 'coins' => 10],
            ['name' => 'Finder', 'description' => 'Helped recover 5 items', 'coins' => 50],
            ['name' => 'Trusted', 'description' => 'Trust score above 90', 'coins' => 100],
            ['name' => 'Streak', 'description' => '7-day posting streak', 'coins' => 25],
            ['name' => 'Popular', 'description' => 'Item shared 100+ times', 'coins' => 50],
        ];

        $earned = DB::table('user_badges')
            ->where('user_id', $user->id)
            ->pluck('badge_name')
            ->toArray();

        $badges = array_map(function ($badge) use ($earned) {
            return array_merge($badge, ['earned' => in_array($badge['name'], $earned)]);
        }, $badges);

        return response()->json(['badges' => $badges]);
    }

    /**
     * Award coins to user
     */
    public function awardCoins(int $userId, int $coins, string $reason): void
    {
        DB::table('user_rewards')->insert([
            'user_id' => $userId,
            'coins' => $coins,
            'reason' => $reason,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Check for badge unlocks
        $this->checkBadges($userId);
    }

    /**
     * Redeem coins for rewards
     */
    public function redeemCoins(Request $request)
    {
        $validated = $request->validate([
            'reward_type' => ['required', 'in:charity_donation,premium_features,discount_voucher'],
            'coins' => ['required', 'integer', 'min:10'],
        ]);

        $user = $request->user();
        $totalCoins = DB::table('user_rewards')
            ->where('user_id', $user->id)
            ->sum('coins') ?? 0;

        if ($totalCoins < $validated['coins']) {
            return response()->json(['error' => 'Insufficient coins'], 422);
        }

        // Deduct coins
        DB::table('user_rewards')->insert([
            'user_id' => $user->id,
            'coins' => -$validated['coins'],
            'reason' => 'Redeemed for ' . $validated['reward_type'],
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'reward_type' => $validated['reward_type'],
            'coins_spent' => $validated['coins'],
            'remaining_coins' => $totalCoins - $validated['coins'],
        ]);
    }

    /**
     * Check if user has earned new badges
     */
    private function checkBadges(int $userId): void
    {
        $user = User::find($userId);

        // Badge: First Post
        if (Item::where('user_id', $userId)->count() === 1) {
            $this->awardBadge($userId, 'First Post');
        }

        // Badge: Helper
        if (\App\Models\Message::where('from_user_id', $userId)->count() >= 10) {
            $this->awardBadge($userId, 'Helper');
        }

        // Badge: Finder
        if (Item::where('user_id', $userId)->where('status', 'RECOVERED')->count() >= 5) {
            $this->awardBadge($userId, 'Finder');
        }

        // Badge: Trusted
        if ($user->trust_score >= 90) {
            $this->awardBadge($userId, 'Trusted');
        }
    }

    /**
     * Award badge to user
     */
    private function awardBadge(int $userId, string $badgeName): void
    {
        $exists = DB::table('user_badges')
            ->where('user_id', $userId)
            ->where('badge_name', $badgeName)
            ->exists();

        if (!$exists) {
            DB::table('user_badges')->insert([
                'user_id' => $userId,
                'badge_name' => $badgeName,
                'created_at' => now(),
            ]);
        }
    }
}
