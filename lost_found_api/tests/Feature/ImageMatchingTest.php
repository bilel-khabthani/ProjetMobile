<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\User;
use App\Services\ImageHashService;
use App\Services\MatchingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ImageMatchingTest extends TestCase
{
    use RefreshDatabase;

    public function test_uploading_a_photo_stores_a_perceptual_hash(): void
    {
        Storage::fake('public');
        $user = $this->verifiedUser();

        $this->actingAs($user, 'sanctum')->post('/api/items', [
            'type' => 'LOST',
            'category' => 'sac',
            'title' => 'Sac noir perdu',
            'description' => 'Sac de sport noir laisse au vestiaire.',
            'place_label' => 'Vestiaire A',
            'occurred_at' => now()->toIso8601String(),
            'image' => UploadedFile::fake()->image('sac.png', 320, 240),
        ], ['Accept' => 'application/json'])->assertCreated();

        $item = Item::sole();

        $this->assertNotNull($item->image_hash);
        $this->assertSame(64, strlen($item->image_hash));
    }

    public function test_identical_photos_produce_the_same_hash(): void
    {
        $hash = app(ImageHashService::class);
        $bytes = $this->photoBytes();

        $first = $hash->hashContents($bytes);
        $second = $hash->hashContents($bytes);

        $this->assertNotNull($first);
        $this->assertSame(64, strlen($first));
        $this->assertSame($first, $second);
        $this->assertSame(100, $hash->similarity($first, $second));
    }

    public function test_identical_photos_match_even_when_descriptions_differ(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();
        $sharedHash = str_repeat('1', 64);

        $lost = $this->item($owner, [
            'type' => Item::TYPE_LOST,
            'title' => 'Sac perdu',
            'description' => 'Objet egare pres du hall.',
            'image_hash' => $sharedHash,
        ]);

        $found = $this->item($finder, [
            'type' => Item::TYPE_FOUND,
            'title' => 'Trousseau trouve',
            'description' => 'Trouve dans le batiment.',
            'image_hash' => $sharedHash,
        ]);

        $results = app(MatchingService::class)->findMatches($lost);

        $this->assertCount(1, $results);
        $this->assertSame(100, $results[0]['score']['dimensions']['image_score']);
        $this->assertGreaterThanOrEqual(80, $results[0]['score']['global_score']);
        $this->assertDatabaseHas('matches', [
            'lost_item_id' => $lost->id,
            'found_item_id' => $found->id,
        ]);
    }

    public function test_different_photos_score_zero_on_the_image_dimension(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();

        $lost = $this->item($owner, [
            'type' => Item::TYPE_LOST,
            'image_hash' => str_repeat('0', 64),
        ]);

        $found = $this->item($finder, [
            'type' => Item::TYPE_FOUND,
            'image_hash' => str_repeat('1', 64),
        ]);

        $score = app(MatchingService::class)->score($lost, $found);

        $this->assertSame(0, $score['dimensions']['image_score']);
    }

    private function verifiedUser(): User
    {
        return User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => true,
        ]);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function item(User $user, array $overrides): Item
    {
        return Item::create([
            'user_id' => $user->id,
            'type' => Item::TYPE_LOST,
            'category' => 'sac',
            'title' => 'Objet',
            'description' => 'Description suffisamment longue pour le test.',
            'place_label' => 'Hall du campus',
            'latitude' => 36.8065,
            'longitude' => 10.1815,
            'occurred_at' => now(),
            'status' => 'ACTIVE',
            ...$overrides,
        ]);
    }

    private function photoBytes(): string
    {
        $image = imagecreatetruecolor(64, 64);

        for ($x = 0; $x < 64; $x++) {
            for ($y = 0; $y < 64; $y++) {
                $color = imagecolorallocate(
                    $image,
                    ($x * 4) % 256,
                    ($y * 4) % 256,
                    (($x + $y) * 2) % 256,
                );
                imagesetpixel($image, $x, $y, $color);
            }
        }

        ob_start();
        imagepng($image);
        $bytes = (string) ob_get_clean();
        imagedestroy($image);

        return $bytes;
    }
}
