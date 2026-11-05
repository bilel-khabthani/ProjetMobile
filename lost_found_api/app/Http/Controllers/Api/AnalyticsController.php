<?php

namespace App\Http\Controllers\Api;

use App\Models\Item;
use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;

/**
 * Analytics Controller - Provides user and system statistics
 * Tracks:
 * - Personal stats (posted, recovered, success rate)
 * - Activity metrics (messages, matches)
 * - Platform statistics
 * - Trending categories
 * - Success stories
 */
class AnalyticsController extends Controller
{
    /**
     * Get personal user analytics
     */
    public function userStats(Request $request)
    {
        $user = $request->user();

        // Count items by status
        $totalPosted = Item::where('user_id', $user->id)->count();
        $recovered = Item::where('user_id', $user->id)
            ->where('status', 'RECOVERED')
            ->count();
        $active = Item::where('user_id', $user->id)
            ->where('status', 'ACTIVE')
            ->count();

        // Count messages
        $messagesSent = Message::where('from_user_id', $user->id)->count();
        $messagesReceived = Message::where('to_user_id', $user->id)->count();
        $unreadMessages = Message::where('to_user_id', $user->id)
            ->where('is_read', false)
            ->count();

        // Success rate
        $successRate = $totalPosted > 0 ? ($recovered / $totalPosted) * 100 : 0;

        // Items by type
        $itemsByType = Item::where('user_id', $user->id)
            ->selectRaw('type, COUNT(*) as count')
            ->groupBy('type')
            ->pluck('count', 'type')
            ->toArray();

        // Items by category
        $itemsByCategory = Item::where('user_id', $user->id)
            ->selectRaw('category, COUNT(*) as count')
            ->groupBy('category')
            ->orderByRaw('count DESC')
            ->limit(5)
            ->pluck('count', 'category')
            ->toArray();

        // First item and joined date
        $firstItem = Item::where('user_id', $user->id)
            ->orderBy('created_at')
            ->first();

        // Calculate activity streak (consecutive days with posts)
        $streak = $this->calculateActivityStreak($user->id);

        return response()->json([
            'user_id' => $user->id,
            'joined' => $user->created_at,
            'total_posted' => $totalPosted,
            'recovered' => $recovered,
            'active' => $active,
            'success_rate' => round($successRate, 1),
            'trust_score' => $user->trust_score ?? 0,
            'messages' => [
                'sent' => $messagesSent,
                'received' => $messagesReceived,
                'unread' => $unreadMessages,
            ],
            'items_by_type' => $itemsByType,
            'top_categories' => $itemsByCategory,
            'activity_streak' => $streak,
            'first_post' => $firstItem?->created_at,
        ]);
    }

    /**
     * Get platform-wide statistics
     */
    public function platformStats(Request $request)
    {
        // Total items
        $totalItems = Item::count();
        $lostItems = Item::where('type', Item::TYPE_LOST)->count();
        $foundItems = Item::where('type', Item::TYPE_FOUND)->count();
        $recoveredItems = Item::where('status', 'RECOVERED')->count();

        // Active users
        $activeUsers = DB::table('items')
            ->distinct('user_id')
            ->count('user_id');

        // Total messages
        $totalMessages = Message::count();

        // Most recovered categories
        $topCategories = Item::where('status', 'RECOVERED')
            ->selectRaw('category, COUNT(*) as count')
            ->groupBy('category')
            ->orderByRaw('count DESC')
            ->limit(5)
            ->pluck('count', 'category')
            ->toArray();

        // Recovery rate
        $recoveryRate = $totalItems > 0 ? ($recoveredItems / $totalItems) * 100 : 0;

        // Average time to recovery (in days)
        $avgRecoveryTime = DB::table('items')
            ->where('status', 'RECOVERED')
            ->selectRaw('AVG(EXTRACT(DAY FROM updated_at - created_at)) as avg_days')
            ->first()
            ?->avg_days ?? 0;

        // Growth trend (items posted last 30 days)
        $itemsLast30Days = Item::where('created_at', '>=', now()->subDays(30))->count();

        return response()->json([
            'total_items' => $totalItems,
            'lost_items' => $lostItems,
            'found_items' => $foundItems,
            'recovered_items' => $recoveredItems,
            'recovery_rate' => round($recoveryRate, 1),
            'active_users' => $activeUsers,
            'total_messages' => $totalMessages,
            'avg_recovery_time_days' => round($avgRecoveryTime, 1),
            'items_last_30_days' => $itemsLast30Days,
            'top_recovered_categories' => $topCategories,
        ]);
    }

    /**
     * Get daily/weekly/monthly statistics
     */
    public function timeSeriesStats(Request $request)
    {
        $period = $request->input('period', 'daily'); // daily, weekly, monthly
        $days = $request->input('days', 30);

        $query = Item::selectRaw('DATE(created_at) as date, COUNT(*) as count, type')
            ->where('created_at', '>=', now()->subDays($days))
            ->groupBy(DB::raw('DATE(created_at)'), 'type')
            ->orderBy('date')
            ->get();

        $stats = [];
        foreach ($query as $row) {
            $date = $row->date;
            if (!isset($stats[$date])) {
                $stats[$date] = ['date' => $date, 'lost' => 0, 'found' => 0, 'total' => 0];
            }
            if ($row->type === Item::TYPE_LOST) {
                $stats[$date]['lost'] = $row->count;
            } else {
                $stats[$date]['found'] = $row->count;
            }
            $stats[$date]['total'] = $stats[$date]['lost'] + $stats[$date]['found'];
        }

        return response()->json(array_values($stats));
    }

    /**
     * Get top categories trending now
     */
    public function trendingCategories(Request $request)
    {
        $days = $request->input('days', 7);

        $trending = Item::where('created_at', '>=', now()->subDays($days))
            ->selectRaw('category, COUNT(*) as count, 
                ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM items WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)), 1) as percentage',
                [$days])
            ->groupBy('category')
            ->orderByRaw('count DESC')
            ->get();

        return response()->json($trending);
    }

    /**
     * Get user rankings by success rate
     */
    public function topUsers(Request $request)
    {
        $limit = $request->input('limit', 10);

        $users = DB::select("
            SELECT 
                u.id,
                u.name,
                u.trust_score,
                COUNT(DISTINCT i.id) as total_posted,
                COUNT(DISTINCT CASE WHEN i.status = 'RECOVERED' THEN i.id END) as recovered,
                ROUND(COUNT(DISTINCT CASE WHEN i.status = 'RECOVERED' THEN i.id END) * 100.0 / 
                      NULLIF(COUNT(DISTINCT i.id), 0), 1) as success_rate
            FROM users u
            LEFT JOIN items i ON u.id = i.user_id
            GROUP BY u.id, u.name, u.trust_score
            HAVING COUNT(DISTINCT i.id) >= 5
            ORDER BY success_rate DESC
            LIMIT ?
        ", [$limit]);

        return response()->json($users);
    }

    /**
     * Get success stories (recently recovered items)
     */
    public function successStories(Request $request)
    {
        $limit = $request->input('limit', 10);

        $stories = Item::where('status', 'RECOVERED')
            ->whereNotNull('image_path')
            ->with('user:id,name,trust_score')
            ->orderByDesc('updated_at')
            ->limit($limit)
            ->get()
            ->map(fn ($item) => [
                'id' => $item->id,
                'title' => $item->title,
                'category' => $item->category,
                'type' => $item->type,
                'image_path' => $item->image_path,
                'user' => $item->user,
                'recovered_at' => $item->updated_at,
                'days_to_recovery' => $item->created_at->diffInDays($item->updated_at),
            ]);

        return response()->json($stories);
    }

    /**
     * Calculate activity streak for user
     */
    private function calculateActivityStreak(int $userId): int
    {
        $dates = Item::where('user_id', $userId)
            ->selectRaw('DATE(created_at) as date')
            ->distinct()
            ->orderByDesc('date')
            ->pluck('date')
            ->toArray();

        if (empty($dates)) {
            return 0;
        }

        $streak = 1;
        $yesterday = now()->toDate();

        foreach ($dates as $date) {
            $date = \Carbon\Carbon::parse($date);
            if ($date->diffInDays($yesterday) === 1) {
                $streak++;
                $yesterday = $date;
            } else {
                break;
            }
        }

        return $streak;
    }
}
