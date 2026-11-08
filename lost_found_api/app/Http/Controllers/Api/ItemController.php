<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Services\MatchingService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Module 2 - Declaration et verification (CDC section 6.2).
 * Une declaration est un Item de type LOST ou FOUND.
 */
class ItemController extends Controller
{
    public function index(Request $request)
    {
        $items = Item::query()
            ->with('user:id,name,trust_score')
            ->where('status', 'ACTIVE')
            ->when($request->query('type'), fn ($q, $type) => $q->where('type', $type))
            ->latest()
            ->limit(100)
            ->get();

        return response()->json($items);
    }

    /** Mes declarations : une seule structure LOST/_FOUND (CDC 6.2.1). */
    public function mine(Request $request)
    {
        $items = Item::where('user_id', $request->user()->id)->latest()->get();

        return response()->json($items);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'type' => ['required', Rule::in([Item::TYPE_LOST, Item::TYPE_FOUND])],
            'category' => ['required', 'string', 'max:40'],
            'title' => ['required', 'string', 'max:120'],
            'description' => ['required', 'string'],
            'secret_detail' => ['nullable', 'string'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'place_label' => ['nullable', 'string', 'max:160'],
            'occurred_at' => ['required', 'date'],
        ]);

        $item = Item::create([
            ...$data,
            'user_id' => $request->user()->id,
            'status' => 'ACTIVE',
        ]);

        return response()->json($item, 201);
    }

    public function show(Item $item)
    {
        return response()->json($item->load('user:id,name,trust_score'));
    }

    /**
     * Declenche le moteur de matching (Module 3) pour une declaration
     * et retourne les candidats tries par score decroissant.
     */
    public function findMatches(Request $request, Item $item, MatchingService $matching)
    {
        abort_unless($item->user_id === $request->user()->id, 403);

        $results = $matching->findMatches($item);

        return response()->json(array_map(
            fn ($r) => ['match' => $r['match']->load('lostItem', 'foundItem'), 'decision' => $r['score']['decision']],
            $results
        ));
    }

    /**
     * Module 2 - Suggestions dynamiques : objets trouves a proximite de ma
     * derniere declaration perdue.
     */
    public function nearbyFound(Request $request, MatchingService $matching)
    {
        $user = $request->user();

        $lastLost = Item::where('user_id', $user->id)
            ->where('type', Item::TYPE_LOST)
            ->latest('occurred_at')
            ->first();

        if (! $lastLost) {
            return response()->json([]);
        }

        $candidates = Item::query()
            ->where('type', Item::TYPE_FOUND)
            ->where('status', 'ACTIVE')
            ->where('user_id', '!=', $user->id)
            ->get();

        $results = [];

        foreach ($candidates as $candidate) {
            $scored = $matching->score($lastLost, $candidate);

            if ($scored['decision'] === 'NO') {
                continue;
            }

            $results[] = [
                'found_item' => $candidate->load('user:id,name,trust_score'),
                'global_score' => $scored['global_score'],
                'dimensions' => $scored['dimensions'],
                'decision' => $scored['decision'],
                'distance_km' => $this->distanceKm($lastLost, $candidate),
                'time_hours' => abs($lastLost->occurred_at->diffInHours($candidate->occurred_at, false)),
            ];
        }

        usort($results, fn ($a, $b) => $b['global_score'] <=> $a['global_score']);

        return response()->json(array_slice($results, 0, 10));
    }

    private function distanceKm(Item $a, Item $b): ?float
    {
        if ($a->latitude === null || $b->latitude === null) {
            return null;
        }

        $earthRadius = 6371;
        $deltaLat = deg2rad((float) $b->latitude - (float) $a->latitude);
        $deltaLon = deg2rad((float) $b->longitude - (float) $a->longitude);

        $aVal = sin($deltaLat / 2) ** 2 + cos(deg2rad((float) $a->latitude)) * cos(deg2rad((float) $b->latitude)) * sin($deltaLon / 2) ** 2;
        $dist = 2 * $earthRadius * atan2(sqrt($aVal), sqrt(1 - $aVal));

        return round($dist, 2);
    }
}
