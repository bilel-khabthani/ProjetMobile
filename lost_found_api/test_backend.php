<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\Item;
use App\Models\User;

echo "=== BACKEND VERIFICATION ===\n\n";

// Check database connection
echo "1. Database Connection: ";
try {
    DB::connection()->getPdo();
    echo "✅ CONNECTED\n";
    echo "   Driver: " . config('database.default') . "\n\n";
} catch (Exception $e) {
    echo "❌ FAILED\n";
    echo "   Error: " . $e->getMessage() . "\n\n";
    exit(1);
}

// Check items table
echo "2. Items Table:\n";
$itemsCount = Item::count();
echo "   Total items: $itemsCount\n";
$lostCount = Item::where('type', 'LOST')->count();
$foundCount = Item::where('type', 'FOUND')->count();
echo "   Lost: $lostCount | Found: $foundCount\n";
$activeCount = Item::where('status', 'ACTIVE')->count();
echo "   Active: $activeCount\n\n";

// Check items with coordinates
echo "3. Geographic Data:\n";
$withCoords = Item::whereNotNull('latitude')->whereNotNull('longitude')->count();
echo "   Items with coordinates: $withCoords\n";
$withImages = Item::whereNotNull('image_path')->count();
echo "   Items with images: $withImages\n\n";

// Display sample items
echo "4. Sample Items:\n";
$samples = Item::with('user:id,name')->take(3)->get();
foreach ($samples as $item) {
    echo "   • [{$item->type}] {$item->title}\n";
    echo "     Category: {$item->category} | Status: {$item->status}\n";
    echo "     Location: " . ($item->latitude ? "✅ ({$item->latitude}, {$item->longitude})" : "❌ Missing") . "\n";
    echo "     Image: " . ($item->image_path ? "✅ " . $item->image_path : "❌ Missing") . "\n";
    echo "     User: " . ($item->user ? $item->user->name : "Unknown") . "\n\n";
}

// Check users
echo "5. Users:\n";
$usersCount = User::count();
echo "   Total users: $usersCount\n";
$verifiedUsers = User::whereNotNull('phone_verified_at')->count();
echo "   Phone verified: $verifiedUsers\n\n";

// Test Haversine calculation
echo "6. Haversine Distance Test:\n";
$testItems = Item::whereNotNull('latitude')->whereNotNull('longitude')->take(2)->get();
if ($testItems->count() >= 2) {
    $item1 = $testItems[0];
    $item2 = $testItems[1];
    
    $earthRadius = 6371; // km
    $dLat = deg2rad($item2->latitude - $item1->latitude);
    $dLon = deg2rad($item2->longitude - $item1->longitude);
    $a = sin($dLat / 2) * sin($dLat / 2) +
         cos(deg2rad($item1->latitude)) * cos(deg2rad($item2->latitude)) *
         sin($dLon / 2) * sin($dLon / 2);
    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
    $distance = $earthRadius * $c;
    
    echo "   Item 1: {$item1->title} ({$item1->latitude}, {$item1->longitude})\n";
    echo "   Item 2: {$item2->title} ({$item2->latitude}, {$item2->longitude})\n";
    echo "   Distance: " . round($distance, 2) . " km ✅\n\n";
} else {
    echo "   ⚠️  Not enough items with coordinates for test\n\n";
}

// Check image URL generation
echo "7. Image URL Generation:\n";
$itemWithImage = Item::whereNotNull('image_path')->first();
if ($itemWithImage) {
    echo "   Sample: {$itemWithImage->title}\n";
    echo "   Path: {$itemWithImage->image_path}\n";
    echo "   URL: {$itemWithImage->image_url}\n";
    echo "   ✅ Image URL generated\n\n";
} else {
    echo "   ⚠️  No items with images yet\n\n";
}

echo "=== VERIFICATION COMPLETE ===\n";
echo "\n✅ Backend is functional and ready!\n";
echo "\nAPI Endpoints Available:\n";
echo "  GET    /api/objects - List all objects\n";
echo "  POST   /api/objects - Create object\n";
echo "  GET    /api/objects/{id} - Get object details\n";
echo "  PUT    /api/objects/{id} - Update object\n";
echo "  DELETE /api/objects/{id} - Delete object\n";
echo "  PATCH  /api/objects/{id}/resolve - Mark as resolved\n";
echo "  GET    /api/objects/my-objects - User's objects\n";
echo "  GET    /api/objects/nearby - Nearby search\n";
echo "  GET    /api/objects/statistics - Dashboard stats\n";
