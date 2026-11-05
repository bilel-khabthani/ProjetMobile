<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\User;

$users = User::select('id', 'name', 'phone', 'email')->take(3)->get();

echo "=== USERS IN DATABASE ===\n\n";
foreach ($users as $user) {
    echo "User: {$user->name}\n";
    echo "Phone: {$user->phone}\n";
    echo "Email: {$user->email}\n";
    echo "ID: {$user->id}\n";
    echo "---\n";
}
