<?php

namespace App\Services;

use App\Models\Item;
use Illuminate\Support\Facades\DB;

/**
 * Intelligent Matching Service - AI-powered object matching
 * Uses ML-inspired scoring to match lost and found items
 * 
 * Scoring Factors:
 * - Category similarity (40 points)
 * - Temporal proximity (30 points)
 * - Geographic proximity (20 points)
 * - Description similarity (10 points)
 * - Image similarity (future: ML-based)
 */
class MatchingService
{
    const HIGH_MATCH_THRESHOLD = 75;  // 75+ = strong match
    const MEDIUM_MATCH_THRESHOLD = 60; // 60-74 = possible match
    const LOW_MATCH_THRESHOLD = 45;    // 45-59 = weak match

    /**
     * Find best matches for a lost item
     * Returns scored candidates for manual verification
     */
    public function findMatchesForLost(Item $lost): array
    {
        $found = Item::where('type', Item::TYPE_FOUND)
            ->where('status', 'ACTIVE')
            ->get();

        $matches = [];
        foreach ($found as $foundItem) {
            $score = $this->calculateScore($lost, $foundItem);

            if ($score >= self::LOW_MATCH_THRESHOLD) {
                $matches[] = [
                    'item' => $foundItem,
                    'score' => $score,
                    'confidence' => $this->getConfidenceLevel($score),
                    'reasons' => $this->getMatchReasons($lost, $foundItem),
                ];
            }
        }

        // Sort by score descending
        usort($matches, fn ($a, $b) => $b['score'] <=> $a['score']);

        return $matches;
    }

    /**
     * Find best matches for a found item
     * Returns scored candidates
     */
    public function findMatchesForFound(Item $found): array
    {
        $lost = Item::where('type', Item::TYPE_LOST)
            ->where('status', 'ACTIVE')
            ->get();

        $matches = [];
        foreach ($lost as $lostItem) {
            $score = $this->calculateScore($lostItem, $found);

            if ($score >= self::LOW_MATCH_THRESHOLD) {
                $matches[] = [
                    'item' => $lostItem,
                    'score' => $score,
                    'confidence' => $this->getConfidenceLevel($score),
                    'reasons' => $this->getMatchReasons($lostItem, $found),
                ];
            }
        }

        usort($matches, fn ($a, $b) => $b['score'] <=> $a['score']);

        return $matches;
    }

    /**
     * Calculate comprehensive match score (0-100)
     */
    public function calculateScore(Item $lost, Item $found): int
    {
        $score = 0;
        $weight = 0;

        // 1. CATEGORY MATCH (40 points max)
        $categoryScore = $this->calculateCategoryScore($lost->category, $found->category);
        $score += $categoryScore * 0.40;
        $weight += 0.40;

        // 2. TEMPORAL PROXIMITY (30 points max)
        $temporalScore = $this->calculateTemporalScore(
            $lost->occurred_at,
            $found->occurred_at
        );
        $score += $temporalScore * 0.30;
        $weight += 0.30;

        // 3. GEOGRAPHIC PROXIMITY (20 points max)
        if ($lost->location && $found->location) {
            $geoScore = $this->calculateGeoScore(
                $lost->latitude,
                $lost->longitude,
                $found->latitude,
                $found->longitude
            );
            $score += $geoScore * 0.20;
            $weight += 0.20;
        }

        // 4. DESCRIPTION SIMILARITY (10 points max)
        $descriptionScore = $this->calculateDescriptionScore(
            $lost->description,
            $found->description
        );
        $score += $descriptionScore * 0.10;
        $weight += 0.10;

        return intval($weight > 0 ? $score / $weight : 0);
    }

    /**
     * Category similarity scoring (0-100)
     */
    private function calculateCategoryScore(string $category1, string $category2): int
    {
        if ($category1 === $category2) {
            return 100; // Perfect match
        }

        // Similar categories
        $similar = [
            'phone' => ['mobile', 'telephone', 'device'],
            'keys' => ['keychain', 'keyring'],
            'wallet' => ['purse', 'bag'],
            'glasses' => ['sunglasses', 'spectacles'],
        ];

        foreach ($similar as $cat => $variants) {
            if (in_array($category1, [$cat, ...$variants]) &&
                in_array($category2, [$cat, ...$variants])) {
                return 70; // Related categories
            }
        }

        return 0; // Different categories
    }

    /**
     * Temporal proximity scoring (0-100)
     */
    private function calculateTemporalScore($time1, $time2): int
    {
        $daysDiff = abs($time1->diffInDays($time2));

        if ($daysDiff === 0) {
            return 100;  // Same day
        } elseif ($daysDiff <= 1) {
            return 90;   // Within 1 day
        } elseif ($daysDiff <= 3) {
            return 70;   // Within 3 days
        } elseif ($daysDiff <= 7) {
            return 50;   // Within 1 week
        } elseif ($daysDiff <= 30) {
            return 25;   // Within 1 month
        }

        return 0;        // Too old
    }

    /**
     * Geographic proximity scoring (0-100)
     */
    private function calculateGeoScore(
        ?float $lat1,
        ?float $lon1,
        ?float $lat2,
        ?float $lon2
    ): int {
        if (!$lat1 || !$lon1 || !$lat2 || !$lon2) {
            return 50; // Assume medium if missing data
        }

        $distanceKm = $this->haversineDistance($lat1, $lon1, $lat2, $lon2);

        if ($distanceKm <= 0.5) {
            return 100;  // Same location
        } elseif ($distanceKm <= 1) {
            return 95;   // Very close
        } elseif ($distanceKm <= 2) {
            return 80;   // Close
        } elseif ($distanceKm <= 5) {
            return 60;   // Nearby
        } elseif ($distanceKm <= 10) {
            return 40;   // Same area
        } elseif ($distanceKm <= 20) {
            return 20;   // Same district
        }

        return 0;        // Too far
    }

    /**
     * Description similarity scoring (0-100)
     * Uses word overlap and semantic similarity
     */
    private function calculateDescriptionScore(string $desc1, string $desc2): int
    {
        $words1 = $this->extractKeywords($desc1);
        $words2 = $this->extractKeywords($desc2);

        if (empty($words1) || empty($words2)) {
            return 0;
        }

        $common = count(array_intersect($words1, $words2));
        $total = max(count($words1), count($words2));

        $similarity = intval(($common / $total) * 100);

        if ($similarity >= 70) {
            return 100;  // Highly similar
        } elseif ($similarity >= 50) {
            return 75;   // Similar
        } elseif ($similarity >= 30) {
            return 50;   // Partially similar
        }

        return 25;       // Slightly similar
    }

    /**
     * Haversine distance formula
     */
    private function haversineDistance(
        float $lat1,
        float $lon1,
        float $lat2,
        float $lon2
    ): float {
        $earthRadius = 6371; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
            cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
            sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return $earthRadius * $c;
    }

    /**
     * Extract keywords from text
     */
    private function extractKeywords(string $text): array
    {
        $stopWords = ['the', 'a', 'an', 'and', 'or', 'but', 'in', 'at', 'to', 'for', 'of', 'is', 'was'];
        $words = str_word_count(strtolower($text), 1);
        return array_filter($words, fn ($w) => !in_array($w, $stopWords) && strlen($w) > 2);
    }

    /**
     * Get confidence level label
     */
    private function getConfidenceLevel(int $score): string
    {
        if ($score >= self::HIGH_MATCH_THRESHOLD) {
            return 'high';
        } elseif ($score >= self::MEDIUM_MATCH_THRESHOLD) {
            return 'medium';
        } else {
            return 'low';
        }
    }

    /**
     * Get human-readable match reasons
     */
    private function getMatchReasons(Item $lost, Item $found): array
    {
        $reasons = [];

        // Category reason
        if ($lost->category === $found->category) {
            $reasons[] = "Same category: {$lost->category}";
        }

        // Time reason
        $daysDiff = abs($lost->occurred_at->diffInDays($found->occurred_at));
        if ($daysDiff === 0) {
            $reasons[] = "Same day occurrence";
        } elseif ($daysDiff <= 3) {
            $reasons[] = "Within 3 days of each other";
        }

        // Location reason
        if ($lost->location && $found->location) {
            $distance = $this->haversineDistance(
                $lost->latitude,
                $lost->longitude,
                $found->latitude,
                $found->longitude
            );

            if ($distance <= 1) {
                $reasons[] = "Found very close by (" . round($distance, 2) . " km)";
            } elseif ($distance <= 10) {
                $reasons[] = "Found nearby (" . round($distance, 1) . " km away)";
            }
        }

        // Description reason
        $descScore = $this->calculateDescriptionScore(
            $lost->description,
            $found->description
        );
        if ($descScore >= 50) {
            $reasons[] = "Description details match";
        }

        return $reasons ?: ["Potential match based on available data"];
    }
}
