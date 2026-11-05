<?php

namespace App\Services;

use App\Models\User;
use App\Models\Item;
use Illuminate\Support\Facades\DB;

/**
 * Notification Service - Handles push notifications and alerts
 * Notifies users about:
 * - Nearby object matches
 * - New messages
 * - Objects marked as recovered
 * - Trending items in their area
 */
class NotificationService
{
    /**
     * Send notification about nearby matches
     * Called when a new LOST object is posted
     */
    public static function notifyNearbyFoundMatches(Item $lostItem): void
    {
        if (!$lostItem->location) {
            return;
        }

        // Find FOUND items within 50km
        $nearbyFound = Item::where('type', Item::TYPE_FOUND)
            ->where('status', 'ACTIVE')
            ->whereNotNull('location')
            ->whereRaw(
                "ST_DWithin(location, ST_GeographyFromText('SRID=4326;POINT(? ?)'), 50000)",
                [$lostItem->longitude, $lostItem->latitude]
            )
            ->with('user')
            ->get();

        // Notify each found object's reporter
        foreach ($nearbyFound as $foundItem) {
            $score = self::matchScore($lostItem, $foundItem);

            if ($score > 60) { // 60+ match score triggers notification
                self::createNotification(
                    $foundItem->user_id,
                    "Found Match!",
                    "A lost {$lostItem->category} matching your found item!",
                    'match',
                    ['item_id' => $lostItem->id, 'score' => $score]
                );
            }
        }
    }

    /**
     * Send notification when a new message arrives
     */
    public static function notifyNewMessage(int $userId, string $senderName, string $preview): void
    {
        self::createNotification(
            $userId,
            "New Message",
            "{$senderName}: {$preview}",
            'message',
            ['sender_id' => $userId]
        );
    }

    /**
     * In-app notification when a credible lost/found suggestion is found.
     * Push delivery is not configured (no FCM credentials in this project).
     */
    public static function notifyPotentialMatch(int $userId, Item $relatedItem, int $score): void
    {
        self::createNotification(
            $userId,
            'Correspondance possible',
            'Un objet « '.$relatedItem->title.' » pourrait correspondre à votre annonce ('.$score.'%).',
            'match',
            ['item_id' => $relatedItem->id, 'score' => $score]
        );
    }

    /**
     * Send notification when object is recovered
     */
    public static function notifyObjectRecovered(Item $item): void
    {
        self::createNotification(
            $item->user_id,
            "Recovered!",
            'Your '.($item->type === 'LOST' ? 'lost' : 'found').' '.$item->category.' has been recovered!',
            'recovery',
            ['item_id' => $item->id]
        );
    }

    /**
     * Notify users about trending items in their area
     * Called daily
     */
    public static function notifyTrendingNearby(User $user): void
    {
        if (!$user->last_location) {
            return;
        }

        // Get trending items (10+ matches) within 20km
        $trendingItems = DB::select("
            SELECT i.id, i.category, i.type, COUNT(DISTINCT im.id) as match_count
            FROM items i
            LEFT JOIN item_matches im ON (
                (i.id = im.lost_item_id OR i.id = im.found_item_id)
            )
            WHERE i.status = 'ACTIVE'
            AND i.location IS NOT NULL
            AND ST_DWithin(i.location, ST_GeographyFromText('SRID=4326;POINT(? ?)'), 20000)
            GROUP BY i.id, i.category, i.type
            HAVING COUNT(DISTINCT im.id) >= 10
            ORDER BY match_count DESC
            LIMIT 3
        ", [$user->last_location['longitude'], $user->last_location['latitude']]);

        if (count($trendingItems) > 0) {
            $categories = implode(', ', array_map(fn ($item) => $item->category, $trendingItems));
            self::createNotification(
                $user->id,
                "Trending Nearby",
                "Popular items nearby: {$categories}",
                'trending',
                ['count' => count($trendingItems)]
            );
        }
    }

    /**
     * Calculate match score between lost and found items (0-100)
     */
    private static function matchScore(Item $lost, Item $found): int
    {
        $score = 0;

        // Category match (40 points)
        if ($lost->category === $found->category) {
            $score += 40;
        }

        // Time proximity (30 points)
        $daysDiff = abs($lost->occurred_at->diffInDays($found->occurred_at));
        if ($daysDiff <= 1) {
            $score += 30;
            } elseif ($daysDiff <= 7) {
            $score += 15;
        }

        // Location proximity (20 points)
        if ($lost->location && $found->location) {
            $distanceKm = DB::selectOne(
                "SELECT ST_DistanceSphere(
                    ST_GeographyFromText('SRID=4326;POINT(? ?)'),
                    ST_GeographyFromText('SRID=4326;POINT(? ?)')
                ) / 1000.0 as distance",
                [$lost->longitude, $lost->latitude, $found->longitude, $found->latitude]
            )?->distance ?? 1000;

            if ($distanceKm <= 1) {
                $score += 20;
            } elseif ($distanceKm <= 5) {
                $score += 10;
            }
        }

        // Description similarity (10 points)
        $similarWords = 0;
        $lostWords = explode(' ', strtolower($lost->description));
        $foundWords = explode(' ', strtolower($found->description));
        $similarWords = count(array_intersect($lostWords, $foundWords));

        if ($similarWords >= 3) {
            $score += 10;
        }

        return min($score, 100);
    }

    /**
     * Create a notification record
     */
    private static function createNotification(
        int $userId,
        string $title,
        string $message,
        string $type,
        array $data = []
    ): void {
        // Store in database
        DB::table('notifications')->insert([
            'user_id' => $userId,
            'title' => $title,
            'message' => $message,
            'type' => $type,
            'data' => json_encode($data),
            'is_read' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // TODO: Send push notification via FCM/APNs
        // FirebaseCloudMessaging::send($user->fcm_token, $title, $message);
    }
}
