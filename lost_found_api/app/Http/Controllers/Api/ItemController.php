<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Services\MatchingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Module 2 - Declaration et verification (CDC section 6.2).
 * Une declaration est un Item de type LOST ou FOUND.
 */
class ItemController extends Controller
{
    private const CATEGORIES = [
        'sac', 'telephone', 'cles', 'papiers', 'vetement', 'lunettes', 'portefeuille', 'autre',
    ];

    private const PUBLIC_STATUSES = ['ACTIVE', 'MATCHED', 'DISPUTED', 'RECOVERED', 'CLOSED'];

    public function index(Request $request)
    {
        $filters = $request->validate([
            'type' => ['nullable', Rule::in([Item::TYPE_LOST, Item::TYPE_FOUND])],
            'category' => ['nullable', Rule::in(self::CATEGORIES)],
            'status' => ['nullable', Rule::in(self::PUBLIC_STATUSES)],
            'q' => ['nullable', 'string', 'max:120'],
            'occurred_from' => ['nullable', 'date'],
            'occurred_to' => ['nullable', 'date'],
            'with_location' => ['nullable', 'boolean'],
            'sort' => ['nullable', Rule::in(['recent', 'oldest', 'title'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'page' => ['nullable', 'integer', 'min:1'],
        ]);

        $query = Item::query()->with('user:id,name,trust_score');

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        } else {
            $query->whereIn('status', ['ACTIVE', 'MATCHED', 'DISPUTED']);
        }

        $query
            ->when($filters['type'] ?? null, fn ($q, $type) => $q->where('type', $type))
            ->when($filters['category'] ?? null, fn ($q, $category) => $q->where('category', $category))
            ->when($filters['occurred_from'] ?? null, fn ($q, $from) => $q->where('occurred_at', '>=', $from))
            ->when($filters['occurred_to'] ?? null, fn ($q, $to) => $q->where('occurred_at', '<=', $to));

        if ($request->boolean('with_location')) {
            $query->whereNotNull('latitude')->whereNotNull('longitude');
        }

        $term = trim((string) ($filters['q'] ?? ''));
        if ($term !== '') {
            $like = '%'.addcslashes($term, '%_\\').'%';
            $query->where(function ($inner) use ($like) {
                $inner->where('title', 'like', $like)
                    ->orWhere('description', 'like', $like)
                    ->orWhere('place_label', 'like', $like);
            });
        }

        match ($filters['sort'] ?? 'recent') {
            'oldest' => $query->orderBy('occurred_at')->orderBy('id'),
            'title' => $query->orderBy('title')->orderBy('id'),
            default => $query->orderByDesc('occurred_at')->orderBy('id'),
        };

        $paginator = $query->paginate((int) ($filters['per_page'] ?? 50));

        return response()->json([
            'data' => $paginator->getCollection()
                ->map(fn (Item $item) => $this->payload($item, $request))
                ->values(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /** Mes declarations : une seule structure LOST/FOUND (CDC 6.2.1). */
    public function mine(Request $request)
    {
        $items = Item::query()
            ->with('user:id,name,trust_score')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return response()->json(
            $items->map(fn (Item $item) => $this->payload($item, $request))->values()
        );
    }

    public function store(Request $request, MatchingService $matching)
    {
        $data = $this->validatedItem($request);
        $imagePath = $this->storeImage($request);

        $item = Item::create([
            ...$data,
            'user_id' => $request->user()->id,
            'status' => 'ACTIVE',
            'image_path' => $imagePath,
        ]);

        // Chaque annonce declaree genere immediatement ses cartes : le moteur
        // tourne des la declaration, pas seulement a l'ouverture du deck, pour
        // que les correspondances existent deja pour les chercheurs.
        $matching->findMatches($item);

        return response()->json($this->payload($item, $request), 201);
    }

    public function show(Request $request, Item $item)
    {
        return response()->json($this->payload($item, $request));
    }

    public function update(Request $request, Item $item, MatchingService $matching)
    {
        $this->authorizeOwner($request, $item, 'Vous ne pouvez modifier que vos propres annonces.');

        $data = $this->validatedItem($request);

        if ($request->filled('status')) {
            $data['status'] = $request->validate([
                'status' => ['required', Rule::in(['ACTIVE', 'CLOSED'])],
            ])['status'];
        }

        if ($request->boolean('clear_location') && ! $request->filled('latitude')) {
            $data['latitude'] = null;
            $data['longitude'] = null;
        }

        if ($request->hasFile('image')) {
            $this->deleteImage($item);
            $data['image_path'] = $this->storeImage($request);
        } elseif ($request->boolean('remove_image')) {
            $this->deleteImage($item);
            $data['image_path'] = null;
        }

        $item->update($data);

        // Une annonce active remet ses correspondances a jour (description,
        // lieu, photo...). Une annonce fermee ne propose plus de cartes.
        if ($item->status === 'ACTIVE') {
            $matching->findMatches($item);
        }

        return response()->json($this->payload($item->refresh(), $request));
    }

    public function destroy(Request $request, Item $item)
    {
        $this->authorizeOwner($request, $item, 'Vous ne pouvez supprimer que vos propres annonces.');
        $this->deleteImage($item);
        $item->delete();

        return response()->noContent();
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
                'found_item' => $this->payload($candidate, $request),
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

    /**
     * @return array<string, mixed>
     */
    private function validatedItem(Request $request): array
    {
        $data = $request->validate([
            'type' => ['required', Rule::in([Item::TYPE_LOST, Item::TYPE_FOUND])],
            'category' => ['required', Rule::in(self::CATEGORIES)],
            'title' => ['required', 'string', 'min:3', 'max:120'],
            'description' => ['required', 'string', 'min:10', 'max:5000'],
            'secret_detail' => ['nullable', 'string', 'max:500'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:longitude'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:latitude'],
            'place_label' => ['nullable', 'string', 'min:2', 'max:160'],
            'occurred_at' => ['required', 'date'],
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'remove_image' => ['sometimes', 'boolean'],
            'clear_location' => ['sometimes', 'boolean'],
        ]);

        unset($data['image'], $data['remove_image'], $data['clear_location']);

        $hasPlace = isset($data['place_label']) && trim((string) $data['place_label']) !== '';
        $hasPoint = isset($data['latitude'], $data['longitude']);
        $clearsPoint = $request->boolean('clear_location') && ! $request->filled('latitude');

        if (! $hasPlace && (! $hasPoint || $clearsPoint)) {
            throw ValidationException::withMessages([
                'place_label' => 'Indiquez un lieu ou une position géographique.',
            ]);
        }

        return $data;
    }

    private function storeImage(Request $request): ?string
    {
        if (! $request->hasFile('image')) {
            return null;
        }

        return $request->file('image')->store('items', 'public');
    }

    private function deleteImage(Item $item): void
    {
        if ($item->image_path) {
            Storage::disk('public')->delete($item->image_path);
        }
    }

    private function authorizeOwner(Request $request, Item $item, string $message): void
    {
        abort_unless($item->user_id === $request->user()->id, 403, $message);
    }

    /**
     * @return array<string, mixed>
     */
    private function payload(Item $item, Request $request): array
    {
        $item->loadMissing('user:id,name,trust_score');
        $mine = $request->user() !== null && $request->user()->id === $item->user_id;
        $data = $item->toArray();

        if (! $mine) {
            unset($data['secret_detail']);
        }

        $data['is_mine'] = $mine;
        $data['owner_name'] = $item->user?->name;
        $data['image_url'] = $item->image_path ? '/storage/'.$item->image_path : null;

        return $data;
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
