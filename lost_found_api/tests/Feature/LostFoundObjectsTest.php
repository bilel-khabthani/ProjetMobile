<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class LostFoundObjectsTest extends TestCase
{
    protected function authenticateUser(): User
    {
        $user = User::firstOrCreate(
            ['email' => 'testuser@example.com'],
            [
                'name' => 'Test User',
                'password' => bcrypt('password123'),
                'phone' => '+33612345678',
                'phone_verified_at' => now(),
                'trust_score' => 90,
            ]
        );
        $user->phone_verified_at = now();
        $user->save();

        $this->actingAs($user, 'sanctum');

        return $user;
    }

    public function test_can_retrieve_objects_list(): void
    {
        $this->authenticateUser();

        $response = $this->getJson('/api/objects');
        $response->assertStatus(200);
    }

    public function test_can_retrieve_statistics(): void
    {
        $this->authenticateUser();

        $response = $this->getJson('/api/objects/statistics');
        $response->assertStatus(200)
            ->assertJsonStructure([
                'total_lost',
                'total_found',
                'active_count',
                'resolved_count',
                'recent_objects',
            ]);
    }

    public function test_can_create_lost_object(): void
    {
        $user = $this->authenticateUser();
        Storage::fake('public');

        $image = UploadedFile::fake()->image('lost_phone.jpg');

        $payload = [
            'type' => 'LOST',
            'category' => 'telephone',
            'title' => 'iPhone 15 Pro Noir',
            'description' => 'Perdu sur le quai de la gare.',
            'place_label' => 'Gare de Lyon, Paris',
            'latitude' => 48.8443,
            'longitude' => 2.3735,
            'occurred_at' => now()->toIso8601String(),
            'contact_phone' => '+33611223344',
            'image' => $image,
        ];

        $response = $this->postJson('/api/objects', $payload);
        $response->assertStatus(201)
            ->assertJsonFragment(['title' => 'iPhone 15 Pro Noir'])
            ->assertJsonFragment(['type' => 'LOST']);

        $id = $response->json('id');
        $this->assertNotEmpty($id);

        $item = Item::find($id);
        $this->assertNotNull($item);
        $this->assertNotNull($item->image_path);
        Storage::disk('public')->assertExists($item->image_path);
    }

    public function test_can_retrieve_nearby_objects_with_haversine(): void
    {
        $user = $this->authenticateUser();

        // Object at Eiffel Tower
        Item::create([
            'user_id' => $user->id,
            'type' => 'FOUND',
            'category' => 'cles',
            'title' => 'Trousseau de cles Tour Eiffel',
            'description' => 'Trouve pres de la tour.',
            'place_label' => 'Tour Eiffel, Paris',
            'latitude' => 48.8584,
            'longitude' => 2.2945,
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ]);

        // Search near Champ de Mars (approx 0.5 km)
        $response = $this->getJson('/api/objects/nearby?latitude=48.8556&longitude=2.2986&radius_km=5');
        $response->assertStatus(200);

        $data = $response->json();
        $this->assertIsArray($data);
        $found = collect($data)->firstWhere('title', 'Trousseau de cles Tour Eiffel');
        $this->assertNotNull($found);
        $this->assertLessThan(2.0, $found['distance_km']);
    }

    public function test_cannot_edit_other_users_object(): void
    {
        $user1 = $this->authenticateUser();

        $item = Item::create([
            'user_id' => $user1->id,
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Sac a dos cuir',
            'description' => 'Perdu au cafe.',
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ]);

        $otherUser = User::firstOrCreate(
            ['email' => 'otheruser@example.com'],
            [
                'name' => 'Other User',
                'password' => bcrypt('password123'),
                'phone' => '+33699887766',
                'phone_verified_at' => now(),
                'trust_score' => 70,
            ]
        );
        $otherUser->phone_verified_at = now();
        $otherUser->save();

        $this->actingAs($otherUser, 'sanctum');

        $response = $this->putJson("/api/objects/{$item->id}", [
            'title' => 'Titre pirate',
        ]);

        $response->assertStatus(403);
    }

    public function test_owner_can_resolve_object(): void
    {
        $user = $this->authenticateUser();

        $item = Item::create([
            'user_id' => $user->id,
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Portefeuille retrouve',
            'description' => 'Perdu dans le metro.',
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ]);

        $response = $this->patchJson("/api/objects/{$item->id}/resolve");
        $response->assertStatus(200);

        $item->refresh();
        $this->assertEquals('RECOVERED', $item->status);
    }
}

