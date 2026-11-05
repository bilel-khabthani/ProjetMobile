<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\Item;
use App\Models\User;

echo "=== SEEDING TEST DATA ===\n\n";

// Get first user
$user = User::first();
if (!$user) {
    echo "❌ No users found. Please create a user first.\n";
    exit(1);
}

echo "Using user: {$user->name} (ID: {$user->id})\n\n";

// Paris coordinates (various locations)
$locations = [
    ['name' => 'Tour Eiffel', 'lat' => 48.8584, 'lon' => 2.2945],
    ['name' => 'Louvre', 'lat' => 48.8606, 'lon' => 2.3376],
    ['name' => 'Notre-Dame', 'lat' => 48.8530, 'lon' => 2.3499],
    ['name' => 'Arc de Triomphe', 'lat' => 48.8738, 'lon' => 2.2950],
    ['name' => 'Sacré-Cœur', 'lat' => 48.8867, 'lon' => 2.3431],
];

$categories = ['telephone', 'sac', 'cles', 'portefeuille', 'lunettes'];

// Create 5 LOST items
echo "Creating LOST items:\n";
for ($i = 0; $i < 5; $i++) {
    $loc = $locations[$i % count($locations)];
    $cat = $categories[$i % count($categories)];
    
    $item = Item::create([
        'user_id' => $user->id,
        'type' => 'LOST',
        'category' => $cat,
        'title' => "Perdu: " . ucfirst($cat) . " #" . ($i + 1),
        'description' => "J'ai perdu mon/ma $cat près de {$loc['name']}. C'est très important pour moi, merci de me contacter si vous l'avez trouvé.",
        'secret_detail' => "Détail secret pour vérification",
        'latitude' => $loc['lat'],
        'longitude' => $loc['lon'],
        'place_label' => $loc['name'] . ", Paris",
        'occurred_at' => now()->subDays(rand(1, 7)),
        'status' => 'ACTIVE',
        'contact_phone' => '+336' . str_pad(rand(10000000, 99999999), 8, '0', STR_PAD_LEFT),
    ]);
    
    echo "  ✅ Created LOST {$cat} at {$loc['name']}\n";
}

// Create 5 FOUND items
echo "\nCreating FOUND items:\n";
for ($i = 0; $i < 5; $i++) {
    $loc = $locations[$i % count($locations)];
    $cat = $categories[$i % count($categories)];
    
    $item = Item::create([
        'user_id' => $user->id,
        'type' => 'FOUND',
        'category' => $cat,
        'title' => "Trouvé: " . ucfirst($cat) . " #" . ($i + 1),
        'description' => "J'ai trouvé ce/cette $cat près de {$loc['name']}. Si c'est le vôtre, contactez-moi avec une description précise.",
        'secret_detail' => null,
        'latitude' => $loc['lat'] + (rand(-50, 50) / 10000), // Slight variation
        'longitude' => $loc['lon'] + (rand(-50, 50) / 10000),
        'place_label' => $loc['name'] . ", Paris",
        'occurred_at' => now()->subDays(rand(1, 7)),
        'status' => 'ACTIVE',
        'contact_phone' => '+336' . str_pad(rand(10000000, 99999999), 8, '0', STR_PAD_LEFT),
    ]);
    
    echo "  ✅ Created FOUND {$cat} at {$loc['name']}\n";
}

echo "\n=== SUMMARY ===\n";
echo "Total LOST: " . Item::where('type', 'LOST')->count() . "\n";
echo "Total FOUND: " . Item::where('type', 'FOUND')->count() . "\n";
echo "Total with coordinates: " . Item::whereNotNull('latitude')->count() . "\n";
echo "\n✅ Test data seeded successfully!\n";
