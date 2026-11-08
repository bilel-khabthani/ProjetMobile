<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ItemCrudTest extends TestCase
{
    use RefreshDatabase;

    private function makeUser(bool $phoneVerified = true): User
    {
        return User::factory()->create([
            'phone_verified' => $phoneVerified,
        ]);
    }

    private function createItem(array $attributes = []): Item
    {
        return Item::create(array_merge([
            'user_id' => $attributes['user_id'] ?? $this->makeUser()->id,
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Titre de test',
            'description' => 'Description de test suffisamment longue',
            'place_label' => 'Campus',
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ], $attributes));
    }

    public function test_authenticated_verified_user_can_create_lost_item(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/items', [
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Sac à dos noir perdu',
            'description' => 'Sac Eastpak noir oublié en amphi B',
            'place_label' => 'Amphi B, Campus Nord',
            'occurred_at' => now()->toIso8601String(),
            'secret_detail' => 'Porte-clés pingouin dans la petite poche',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('title', 'Sac à dos noir perdu')
            ->assertJsonPath('type', 'LOST')
            ->assertJsonPath('category', 'sac')
            ->assertJsonPath('is_mine', true)
            ->assertJsonPath('secret_detail', 'Porte-clés pingouin dans la petite poche');

        $this->assertDatabaseHas('items', [
            'title' => 'Sac à dos noir perdu',
            'user_id' => $user->id,
            'status' => 'ACTIVE',
        ]);
    }

    public function test_authenticated_verified_user_can_create_found_item_with_coordinates(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/items', [
            'type' => 'FOUND',
            'category' => 'cles',
            'title' => 'Trousseau de clés trouvé',
            'description' => '3 clés avec un badge bleu trouvées sur un banc',
            'place_label' => 'Banc jardin central',
            'latitude' => 36.8065,
            'longitude' => 10.1815,
            'occurred_at' => now()->toIso8601String(),
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('title', 'Trousseau de clés trouvé')
            ->assertJsonPath('type', 'FOUND')
            ->assertJsonPath('category', 'cles')
            ->assertJsonPath('latitude', 36.8065)
            ->assertJsonPath('longitude', 10.1815);

        $this->assertDatabaseHas('items', [
            'title' => 'Trousseau de clés trouvé',
            'latitude' => 36.8065,
            'longitude' => 10.1815,
        ]);
    }

    public function test_validation_fails_when_required_fields_missing(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/items', [
            'title' => 'Ab', // too short (< 3)
            'description' => 'Court', // too short (< 10)
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['type', 'category', 'title', 'description', 'occurred_at']);
    }

    public function test_validation_fails_without_location_or_place(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/items', [
            'type' => 'LOST',
            'category' => 'telephone',
            'title' => 'iPhone 13 bleu',
            'description' => 'iPhone avec coque transparente',
            'occurred_at' => now()->toIso8601String(),
            // No place_label and no latitude/longitude
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['place_label']);
    }

    public function test_unverified_phone_user_is_forbidden_from_creating_items(): void
    {
        $user = $this->makeUser(phoneVerified: false);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/items', [
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Sac à dos',
            'description' => 'Description valide pour le test',
            'place_label' => 'Campus',
            'occurred_at' => now()->toIso8601String(),
        ]);

        $response->assertStatus(403);
    }

    public function test_unauthenticated_user_cannot_access_items(): void
    {
        $response = $this->getJson('/api/items');
        $response->assertStatus(401);
    }

    public function test_can_list_and_filter_items_by_type_and_category(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $this->createItem([
            'user_id' => $user->id,
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Sac perdu 1',
            'status' => 'ACTIVE',
        ]);

        $this->createItem([
            'user_id' => $user->id,
            'type' => 'FOUND',
            'category' => 'sac',
            'title' => 'Sac trouvé 1',
            'status' => 'ACTIVE',
        ]);

        $this->createItem([
            'user_id' => $user->id,
            'type' => 'LOST',
            'category' => 'telephone',
            'title' => 'Téléphone perdu',
            'status' => 'ACTIVE',
        ]);

        // Filter type=LOST
        $lostResp = $this->getJson('/api/items?type=LOST');
        $lostResp->assertStatus(200);
        $this->assertCount(2, $lostResp->json('data'));

        // Filter type=FOUND
        $foundResp = $this->getJson('/api/items?type=FOUND');
        $foundResp->assertStatus(200);
        $this->assertCount(1, $foundResp->json('data'));

        // Filter category=telephone
        $phoneResp = $this->getJson('/api/items?category=telephone');
        $phoneResp->assertStatus(200);
        $this->assertCount(1, $phoneResp->json('data'));
    }

    public function test_can_filter_items_with_location_only(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $this->createItem([
            'user_id' => $user->id,
            'title' => 'Item avec géolocalisation',
            'latitude' => 36.8000,
            'longitude' => 10.1800,
            'status' => 'ACTIVE',
        ]);

        $this->createItem([
            'user_id' => $user->id,
            'title' => 'Item sans coordonnées',
            'latitude' => null,
            'longitude' => null,
            'status' => 'ACTIVE',
        ]);

        $resp = $this->getJson('/api/items?with_location=1');
        $resp->assertStatus(200);
        $this->assertCount(1, $resp->json('data'));
        $this->assertEquals('Item avec géolocalisation', $resp->json('data.0.title'));
    }

    public function test_can_search_items_by_query(): void
    {
        $user = $this->makeUser();
        Sanctum::actingAs($user);

        $this->createItem([
            'user_id' => $user->id,
            'title' => 'Casque Sony WH-1000XM4',
            'description' => 'Casque noir à réduction de bruit',
            'place_label' => 'Bibliothèque',
            'status' => 'ACTIVE',
        ]);

        $this->createItem([
            'user_id' => $user->id,
            'title' => 'Parapluie rouge',
            'description' => 'Grand parapluie canne',
            'place_label' => 'Cafétéria',
            'status' => 'ACTIVE',
        ]);

        $searchResp = $this->getJson('/api/items?q=Sony');
        $searchResp->assertStatus(200);
        $this->assertCount(1, $searchResp->json('data'));
        $this->assertEquals('Casque Sony WH-1000XM4', $searchResp->json('data.0.title'));
    }

    public function test_secret_detail_is_hidden_from_non_owners(): void
    {
        $owner = $this->makeUser();
        $otherUser = $this->makeUser();

        $item = $this->createItem([
            'user_id' => $owner->id,
            'title' => 'Portefeuille en cuir',
            'secret_detail' => 'Photo de famille dans la doublure secrète',
            'status' => 'ACTIVE',
        ]);

        // When other user views the item
        Sanctum::actingAs($otherUser);
        $otherResp = $this->getJson("/api/items/{$item->id}");
        $otherResp->assertStatus(200)
            ->assertJsonPath('is_mine', false)
            ->assertJsonMissing(['secret_detail']);

        // When owner views the item
        Sanctum::actingAs($owner);
        $ownerResp = $this->getJson("/api/items/{$item->id}");
        $ownerResp->assertStatus(200)
            ->assertJsonPath('is_mine', true)
            ->assertJsonPath('secret_detail', 'Photo de famille dans la doublure secrète');
    }

    public function test_owner_can_update_item(): void
    {
        $owner = $this->makeUser();
        Sanctum::actingAs($owner);

        $item = $this->createItem([
            'user_id' => $owner->id,
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Titre original',
            'description' => 'Description originale longue',
            'place_label' => 'Lieu original',
            'latitude' => 36.80,
            'longitude' => 10.18,
            'status' => 'ACTIVE',
        ]);

        $updateResp = $this->putJson("/api/items/{$item->id}", [
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Titre modifié',
            'description' => 'Description modifiée avec détails',
            'place_label' => 'Nouveau lieu',
            'latitude' => 36.85,
            'longitude' => 10.20,
            'occurred_at' => now()->toIso8601String(),
            'status' => 'CLOSED',
        ]);

        $updateResp->assertStatus(200)
            ->assertJsonPath('title', 'Titre modifié')
            ->assertJsonPath('place_label', 'Nouveau lieu')
            ->assertJsonPath('latitude', 36.85)
            ->assertJsonPath('longitude', 10.20)
            ->assertJsonPath('status', 'CLOSED');

        $this->assertDatabaseHas('items', [
            'id' => $item->id,
            'title' => 'Titre modifié',
            'status' => 'CLOSED',
        ]);
    }

    public function test_non_owner_cannot_update_item(): void
    {
        $owner = $this->makeUser();
        $intruder = $this->makeUser();

        $item = $this->createItem([
            'user_id' => $owner->id,
            'title' => 'Objet de Alice',
            'status' => 'ACTIVE',
        ]);

        Sanctum::actingAs($intruder);

        $response = $this->putJson("/api/items/{$item->id}", [
            'type' => 'LOST',
            'category' => 'autre',
            'title' => 'Piraté par Bob',
            'description' => 'Tentative de modification non autorisée',
            'place_label' => 'Quelque part',
            'occurred_at' => now()->toIso8601String(),
        ]);

        $response->assertStatus(403);
    }

    public function test_owner_can_delete_item(): void
    {
        $owner = $this->makeUser();
        Sanctum::actingAs($owner);

        $item = $this->createItem([
            'user_id' => $owner->id,
            'status' => 'ACTIVE',
        ]);

        $response = $this->deleteJson("/api/items/{$item->id}");
        $response->assertStatus(204);

        $this->assertDatabaseMissing('items', [
            'id' => $item->id,
        ]);
    }

    public function test_non_owner_cannot_delete_item(): void
    {
        $owner = $this->makeUser();
        $intruder = $this->makeUser();

        $item = $this->createItem([
            'user_id' => $owner->id,
            'status' => 'ACTIVE',
        ]);

        Sanctum::actingAs($intruder);

        $response = $this->deleteJson("/api/items/{$item->id}");
        $response->assertStatus(403);

        $this->assertDatabaseHas('items', [
            'id' => $item->id,
        ]);
    }

    public function test_owner_can_clear_location(): void
    {
        $owner = $this->makeUser();
        Sanctum::actingAs($owner);

        $item = $this->createItem([
            'user_id' => $owner->id,
            'latitude' => 36.80,
            'longitude' => 10.18,
            'place_label' => 'Bâtiment Informatique',
            'status' => 'ACTIVE',
        ]);

        $response = $this->putJson("/api/items/{$item->id}", [
            'type' => $item->type,
            'category' => $item->category,
            'title' => $item->title,
            'description' => $item->description,
            'place_label' => 'Bâtiment Informatique',
            'occurred_at' => now()->toIso8601String(),
            'clear_location' => true,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('latitude', null)
            ->assertJsonPath('longitude', null);

        $this->assertDatabaseHas('items', [
            'id' => $item->id,
            'latitude' => null,
            'longitude' => null,
        ]);
    }
}
