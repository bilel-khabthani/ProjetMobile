<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Item;
use App\Models\ItemImage;
use App\Models\ObjectEvent;
use App\Models\ObjectFavorite;
use App\Services\MatchingService;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

/**
 * Module 2 - Gestion des Objets Perdus et Trouves (Lost & Found Management Module).
 * Gere le cycle de vie complet des annonces d'objets perdus et trouves,
 * la recherche geographique par formule de Haversine, le filtrage avance et les statistiques.
 */
class ItemController extends Controller
{
    /**
     * Liste des objets avec filtres avances et pagination.
     */
    public function index(Request $request)
    {
        $query = Item::query()->with(['user:id,name,trust_score', 'images', 'categoryRef:id,slug,name,icon']);

        // Filtre par statut (par defaut ACTIVE si non specifie, ou 'all' pour tout)
        $status = $request->query('status');
        if ($status && strtolower($status) !== 'all') {
            $query->where('status', strtoupper($status));
        } elseif (!$status) {
            $query->where('status', 'ACTIVE');
        }

        // Filtre par type (LOST ou FOUND)
        if ($type = $request->query('type')) {
            $query->where('type', strtoupper($type));
        }

        // Filtre par categorie
        if ($category = $request->query('category')) {
            $query->where('category', strtolower($category));
        }

        // Recherche textuelle (titre, description, lieu)
        if ($search = $request->query('search') ?: $request->query('q')) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%")
                  ->orWhere('place_label', 'like', "%{$search}%");
            });
        }

        // Filtre par date (aliases start_date / end_date acceptes par le client Flutter)
        $fromDate = $request->query('date_from') ?: $request->query('start_date');
        $toDate = $request->query('date_to') ?: $request->query('end_date');
        if ($fromDate) {
            $query->where('occurred_at', '>=', $fromDate);
        }
        if ($toDate) {
            $query->where('occurred_at', '<=', $toDate);
        }

        $sort = $request->query('sort');
        $sortBy = $request->query('sort_by', 'created_at');
        $sortOrder = strtolower((string) $request->query('sort_order', 'desc')) === 'asc' ? 'asc' : 'desc';
        if ($sort === 'oldest') {
            $query->orderBy('created_at', 'asc');
        } elseif ($sort === 'newest') {
            $query->orderBy('created_at', 'desc');
        } elseif (in_array($sortBy, ['created_at', 'occurred_at', 'title'], true)) {
            $query->orderBy($sortBy, $sortOrder);
        } else {
            $query->latest();
        }

        // Pagination
        $limit = min((int) ($request->query('limit', 50)), 100);
        $offset = max((int) ($request->query('offset', 0)), 0);

        $latitude = $request->query('latitude');
        $longitude = $request->query('longitude');
        $radiusKm = $request->query('radius_km');
        if ($latitude !== null && $longitude !== null && $radiusKm !== null) {
            $originLat = (float) $latitude;
            $originLng = (float) $longitude;
            $radius = (float) $radiusKm;
            $items = $query
                ->whereNotNull('latitude')
                ->whereNotNull('longitude')
                ->limit(500)
                ->get()
                ->map(function (Item $item) use ($originLat, $originLng) {
                    $item->distance_km = round($this->calculateHaversineDistance(
                        $originLat,
                        $originLng,
                        (float) $item->latitude,
                        (float) $item->longitude
                    ), 2);

                    return $item;
                })
                ->filter(fn (Item $item) => $item->distance_km <= $radius)
                ->sortBy($request->query('sort') === 'distance' ? 'distance_km' : 'created_at')
                ->values();

            if ($request->query('sort') !== 'distance' && $request->query('sort') === 'oldest') {
                $items = $items->sortBy('created_at')->values();
            }

            $total = $items->count();
            $items = $items->slice($offset, $limit)->values();
            $this->attachFavoriteFlag($items, $request);

            if ($request->header('Accept-Format') === 'paginated' || $request->has('page')) {
                return response()->json([
                    'data' => $items,
                    'total' => $total,
                    'limit' => $limit,
                    'offset' => $offset,
                ]);
            }

            return response()->json($items);
        }

        $total = (clone $query)->count();
        $items = $query->skip($offset)->take($limit)->get();
        $this->attachFavoriteFlag($items, $request);

        // Supporte a la fois reponse directe (tableau) pour compatibilite client ou structure paginee
        if ($request->header('Accept-Format') === 'paginated' || $request->has('page')) {
            return response()->json([
                'data' => $items,
                'total' => $total,
                'limit' => $limit,
                'offset' => $offset,
            ]);
        }

        return response()->json($items);
    }

    /**
     * Statistiques globales pour le tableau de bord.
     */
    public function statistics()
    {
        $totalLost = Item::where('type', Item::TYPE_LOST)->count();
        $totalFound = Item::where('type', Item::TYPE_FOUND)->count();
        $activeCount = Item::where('status', 'ACTIVE')->count();
        $resolvedCount = Item::whereIn('status', ['RECOVERED', 'RESOLVED', 'CLOSED'])->count();
        $recent = Item::with(['user:id,name,trust_score', 'images'])
            ->where('status', 'ACTIVE')
            ->latest()
            ->limit(5)
            ->get();

        return response()->json([
            'total_objects' => $totalLost + $totalFound,
            'total_lost' => $totalLost,
            'total_found' => $totalFound,
            'active_count' => $activeCount,
            'resolved_count' => $resolvedCount,
            'with_location' => Item::where('status', 'ACTIVE')->whereNotNull('latitude')->whereNotNull('longitude')->count(),
            'recent_objects' => $recent,
        ]);
    }

    /**
     * Mes declarations (objets crees par l'utilisateur connecte).
     */
    public function mine(Request $request)
    {
        $query = Item::where('user_id', $request->user()->id);

        if ($type = $request->query('type')) {
            $query->where('type', strtoupper($type));
        }

        if ($status = $request->query('status')) {
            if (strtolower($status) !== 'all') {
                $query->where('status', strtoupper($status));
            }
        }

        $items = $query->latest()->get();

        return response()->json($items);
    }

    /**
     * Details complets d'un objet.
     */
    public function show(Request $request, Item $item)
    {
        $item->load(['user:id,name,trust_score', 'images', 'categoryRef:id,slug,name,icon', 'events']);
        $item->setAttribute('is_favorite', ObjectFavorite::query()
            ->where('user_id', $request->user()->id)
            ->where('item_id', $item->id)
            ->exists());

        if ($item->user_id === $request->user()->id) {
            $item->makeVisible('secret_detail');
        }

        return response()->json($item);
    }

    /**
     * Publication d'un objet perdu ou trouve.
     */
    public function store(Request $request, MatchingService $matching)
    {
        $data = $request->validate([
            'type' => ['required', Rule::in([Item::TYPE_LOST, Item::TYPE_FOUND, 'lost', 'found'])],
            'category' => ['required', 'string', 'max:40', Rule::exists('categories', 'slug')],
            'title' => ['required', 'string', 'max:120'],
            'description' => ['required', 'string'],
            'secret_detail' => ['nullable', 'string'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'place_label' => ['nullable', 'string', 'max:160'],
            'occurred_at' => ['required', 'date'],
            'contact_phone' => ['nullable', 'string', 'max:30'],
            'image' => ['nullable', 'image', 'max:5120'],
            'images' => ['nullable', 'array', 'max:5'],
            'images.*' => ['image', 'max:5120'],
        ]);

        $type = strtoupper($data['type']);
        $category = Category::where('slug', strtolower($data['category']))->first();

        $imagePath = null;
        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('items', 'public');
        }

        $item = Item::create([
            'user_id' => $request->user()->id,
            'category_id' => $category?->id,
            'type' => $type,
            'category' => strtolower($data['category']),
            'title' => $data['title'],
            'description' => $data['description'],
            'secret_detail' => $data['secret_detail'] ?? null,
            'latitude' => isset($data['latitude']) ? (float) $data['latitude'] : null,
            'longitude' => isset($data['longitude']) ? (float) $data['longitude'] : null,
            'place_label' => $data['place_label'] ?? null,
            'occurred_at' => $data['occurred_at'],
            'contact_phone' => $data['contact_phone'] ?? null,
            'image_path' => $imagePath,
            'status' => 'ACTIVE',
        ]);

        if ($imagePath) {
            ItemImage::create([
                'item_id' => $item->id,
                'path' => $imagePath,
                'is_primary' => true,
            ]);
        }

        foreach ($request->file('images', []) as $index => $file) {
            $path = $file->store('items', 'public');
            $isPrimary = $imagePath === null && $index === 0;
            ItemImage::create([
                'item_id' => $item->id,
                'path' => $path,
                'is_primary' => $isPrimary,
            ]);
            if ($isPrimary) {
                $item->update(['image_path' => $path]);
            }
        }

        $this->syncGeography($item);
        $this->recordEvent($item, $request->user()->id, 'created');
        $this->notifyCredibleMatches($item, $matching);

        return response()->json($item->load(['user:id,name,trust_score', 'images', 'categoryRef']), 201);
    }

    /**
     * Mise a jour d'un objet. Seul le proprietaire peut le modifier.
     */
    public function update(Request $request, Item $item)
    {
        abort_unless($item->user_id === $request->user()->id, 403, 'Action non autorisee sur cet objet.');

        $data = $request->validate([
            'type' => ['sometimes', Rule::in([Item::TYPE_LOST, Item::TYPE_FOUND, 'lost', 'found'])],
            'category' => ['sometimes', 'string', 'max:40', Rule::exists('categories', 'slug')],
            'title' => ['sometimes', 'string', 'max:120'],
            'description' => ['sometimes', 'string'],
            'secret_detail' => ['nullable', 'string'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'place_label' => ['nullable', 'string', 'max:160'],
            'occurred_at' => ['sometimes', 'date'],
            'contact_phone' => ['nullable', 'string', 'max:30'],
            'status' => ['sometimes', Rule::in(['ACTIVE', 'RECOVERED', 'RESOLVED', 'CLOSED'])],
            'image' => ['nullable', 'image', 'max:5120'],
            'images' => ['nullable', 'array', 'max:5'],
            'images.*' => ['image', 'max:5120'],
        ]);

        if (isset($data['type'])) {
            $data['type'] = strtoupper($data['type']);
        }
        if (isset($data['category'])) {
            $data['category'] = strtolower($data['category']);
        }

        // Remplacement de l'image
        if ($request->hasFile('image')) {
            if ($item->image_path && Storage::disk('public')->exists($item->image_path)) {
                Storage::disk('public')->delete($item->image_path);
            }
            $data['image_path'] = $request->file('image')->store('items', 'public');
        }

        $item->update($data);

        return response()->json($item->fresh()->load('user:id,name,trust_score'));
    }

    /**
     * Suppression d'un objet. Seul le proprietaire peut le supprimer.
     */
    public function destroy(Request $request, Item $item)
    {
        abort_unless($item->user_id === $request->user()->id, 403, 'Action non autorisee sur cet objet.');

        // Suppression de l'image associee
        if ($item->image_path && Storage::disk('public')->exists($item->image_path)) {
            Storage::disk('public')->delete($item->image_path);
        }

        $item->delete();

        return response()->json(['message' => 'Objet supprime avec succes.']);
    }

    /**
     * Marquer un objet comme resolu / recupere.
     */
    public function resolve(Request $request, Item $item)
    {
        abort_unless($item->user_id === $request->user()->id, 403, 'Action non autorisee sur cet objet.');

        $item->update(['status' => 'RECOVERED']);

        return response()->json([
            'message' => 'Objet marque comme recupere.',
            'item' => $item->fresh()->load('user:id,name,trust_score'),
        ]);
    }

    /**
     * Recherche geographique d'objets a proximite via la formule de Haversine.
     */
    public function nearby(Request $request)
    {
        $validated = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'min:0.1', 'max:500'],
            'type' => ['nullable', Rule::in([Item::TYPE_LOST, Item::TYPE_FOUND, 'lost', 'found'])],
            'category' => ['nullable', 'string'],
        ]);

        $latitude = (float) $validated['latitude'];
        $longitude = (float) $validated['longitude'];
        $radiusKm = (float) ($validated['radius_km'] ?? 10);
        $type = !empty($validated['type']) ? strtoupper($validated['type']) : null;
        $category = !empty($validated['category']) ? strtolower($validated['category']) : null;

        $items = Item::query()
            ->with('user:id,name,trust_score')
            ->where('status', 'ACTIVE')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->when($type, fn ($q) => $q->where('type', $type))
            ->when($category, fn ($q) => $q->where('category', $category))
            ->get()
            ->map(function ($item) use ($latitude, $longitude) {
                $distance = $this->calculateHaversineDistance(
                    $latitude,
                    $longitude,
                    (float) $item->latitude,
                    (float) $item->longitude
                );
                $item->distance_km = round($distance, 2);
                return $item;
            })
            ->filter(fn ($item) => $item->distance_km <= $radiusKm)
            ->sortBy('distance_km')
            ->values();

        return response()->json($items);
    }

    /**
     * Calcul de la distance geodesique (en km) par formule de Haversine.
     */
    public function calculateHaversineDistance(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
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
     * Distance en km entre deux Item.
     */
    public function distanceKm(Item $a, Item $b): float
    {
        if ($a->latitude === null || $a->longitude === null || $b->latitude === null || $b->longitude === null) {
            return 0.0;
        }

        return round($this->calculateHaversineDistance(
            (float) $a->latitude,
            (float) $a->longitude,
            (float) $b->latitude,
            (float) $b->longitude
        ), 2);
    }

    /**
     * Complete les coordonnees geographiques de l'objet.
     *
     * Les colonnes dediees (geohash, ville) ne sont pas encore presentes :
     * latitude et longitude sont deja stockees directement sur l'objet.
     */
    private function syncGeography(Item $item): void
    {
        // Rien a synchroniser pour le moment.
    }

    /**
     * Trace une action dans le journal des objets.
     */
    private function recordEvent(Item $item, int $userId, string $event): void
    {
        if (!Schema::hasTable('object_events')) {
            return;
        }

        ObjectEvent::create([
            'item_id' => $item->id,
            'user_id' => $userId,
            'event' => $event,
        ]);
    }

    /**
     * Ajoute le drapeau "favori" aux objets d'une liste.
     */
    private function attachFavoriteFlag($items, Request $request): void
    {
        $user = $request->user();
        if (!$user) {
            return;
        }

        $favoriteIds = ObjectFavorite::where('user_id', $user->id)
            ->pluck('item_id')
            ->all();

        foreach ($items as $item) {
            $item->setAttribute('is_favorite', in_array($item->id, $favoriteIds, true));
        }
    }

    /**
     * Notifie le proprietaire des correspondances les plus credibles.
     */
    private function notifyCredibleMatches(Item $item, MatchingService $matching): void
    {
        $matches = $item->type === Item::TYPE_LOST
            ? $matching->findMatchesForLost($item)
            : $matching->findMatchesForFound($item);

        foreach ($matches as $match) {
            if ($match['score'] < MatchingService::MEDIUM_MATCH_THRESHOLD) {
                continue;
            }

            NotificationService::notifyPotentialMatch(
                $item->user_id,
                $match['item'],
                $match['score']
            );
        }
    }

    /**
     * Declenche le moteur de matching (Module 3).
     */
    public function findMatches(Request $request, Item $item, MatchingService $matching)
    {
        abort_unless($item->user_id === $request->user()->id, 403);

        $results = $item->type === Item::TYPE_LOST
            ? $matching->findMatchesForLost($item)
            : $matching->findMatchesForFound($item);

        return response()->json($results);
    }

    /**
     * Suggestions d'objets trouves a proximite de la derniere declaration perdue.
     */
    public function nearbyFound(Request $request, MatchingService $matching)
    {
        $user = $request->user();

        $lastLost = Item::where('user_id', $user->id)
            ->where('type', Item::TYPE_LOST)
            ->latest('occurred_at')
            ->first();

        if (!$lastLost) {
            return response()->json([]);
        }

        $candidates = Item::query()
            ->where('type', Item::TYPE_FOUND)
            ->where('status', 'ACTIVE')
            ->where('user_id', '!=', $user->id)
            ->get();

        $results = [];

        foreach ($candidates as $candidate) {
            $score = $matching->calculateScore($lastLost, $candidate);

            if ($score < MatchingService::LOW_MATCH_THRESHOLD) {
                continue;
            }

            $decision = $score >= MatchingService::HIGH_MATCH_THRESHOLD
                ? 'YES'
                : ($score >= MatchingService::MEDIUM_MATCH_THRESHOLD ? 'UNSURE' : 'NO');

            $results[] = [
                'found_item' => $candidate->load('user:id,name,trust_score'),
                'global_score' => $score,
                'dimensions' => [],
                'decision' => $decision,
                'distance_km' => $this->distanceKm($lastLost, $candidate),
                'time_hours' => abs($lastLost->occurred_at->diffInHours($candidate->occurred_at, false)),
            ];
        }

        usort($results, fn ($a, $b) => $b['global_score'] <=> $a['global_score']);

        return response()->json(array_slice($results, 0, 10));
    }
}
