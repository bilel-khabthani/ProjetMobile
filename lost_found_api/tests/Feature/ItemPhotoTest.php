<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ItemPhotoTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_publish_an_item_with_a_photo(): void
    {
        Storage::fake('public');
        $user = $this->verifiedUser();

        $response = $this->actingAs($user, 'sanctum')->post('/api/items', [
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Sac Nike noir',
            'description' => 'Sac de sport noir avec une bande rouge.',
            'place_label' => 'Vestiaire A',
            'occurred_at' => now()->toIso8601String(),
            'contact_phone' => '+21620123456',
            'image' => UploadedFile::fake()->image('sac.jpg', 640, 480),
        ], ['Accept' => 'application/json']);

        $response->assertCreated()
            ->assertJsonPath('title', 'Sac Nike noir')
            ->assertJsonPath('contact_phone', '+21620123456');

        $item = Item::sole();
        $this->assertNotNull($item->image_path);
        Storage::disk('public')->assertExists($item->image_path);
        $this->assertSame('/storage/'.$item->image_path, $response->json('image_url'));
    }

    public function test_owner_can_remove_the_photo_from_an_item(): void
    {
        Storage::fake('public');
        $user = $this->verifiedUser();

        $created = $this->actingAs($user, 'sanctum')->post('/api/items', [
            'type' => 'FOUND',
            'category' => 'cles',
            'title' => 'Trousseau de cles',
            'description' => 'Trois cles avec un porte-cles rouge.',
            'place_label' => 'Bibliotheque',
            'occurred_at' => now()->toIso8601String(),
            'image' => UploadedFile::fake()->image('cles.png', 320, 320),
        ], ['Accept' => 'application/json'])->assertCreated()->json();

        $item = Item::findOrFail($created['id']);
        Storage::disk('public')->assertExists($item->image_path);

        $this->actingAs($user, 'sanctum')
            ->patchJson("/api/items/{$item->id}", ['remove_image' => true])
            ->assertOk()
            ->assertJsonPath('image_url', null);

        $this->assertNull($item->fresh()->image_path);
        Storage::disk('public')->assertMissing($item->image_path);
    }

    public function test_photo_is_replaced_and_the_old_file_is_deleted(): void
    {
        Storage::fake('public');
        $user = $this->verifiedUser();

        $created = $this->actingAs($user, 'sanctum')->post('/api/items', [
            'type' => 'LOST',
            'category' => 'telephone',
            'title' => 'Telephone noir',
            'description' => 'Telephone noir avec une coque transparente.',
            'place_label' => 'Amphitheatre B',
            'occurred_at' => now()->toIso8601String(),
            'image' => UploadedFile::fake()->image('avant.jpg', 400, 400),
        ], ['Accept' => 'application/json'])->assertCreated()->json();

        $item = Item::findOrFail($created['id']);
        $oldPath = $item->image_path;
        Storage::disk('public')->assertExists($oldPath);

        $this->actingAs($user, 'sanctum')->post("/api/items/{$item->id}", [
            '_method' => 'PUT',
            'image' => UploadedFile::fake()->image('apres.jpg', 400, 400),
        ], ['Accept' => 'application/json'])->assertOk();

        $newPath = $item->fresh()->image_path;
        $this->assertNotSame($oldPath, $newPath);
        Storage::disk('public')->assertMissing($oldPath);
        Storage::disk('public')->assertExists($newPath);
    }

    private function verifiedUser(): User
    {
        return User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => true,
        ]);
    }
}
