<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Incremental objects-module tables. Does not drop or truncate existing data.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('categories')) {
            Schema::create('categories', function (Blueprint $table) {
                $table->id();
                $table->string('slug')->unique();
                $table->string('name');
                $table->string('description')->nullable();
                $table->string('icon')->nullable();
                $table->timestamps();
            });
        }

        $now = now();
        $categories = [
            ['slug' => 'electronique', 'name' => 'Électronique', 'description' => 'Appareils électroniques', 'icon' => 'devices'],
            ['slug' => 'telephone', 'name' => 'Téléphones', 'description' => 'Téléphones et smartphones', 'icon' => 'smartphone'],
            ['slug' => 'ordinateur', 'name' => 'Ordinateurs', 'description' => 'Ordinateurs et tablettes', 'icon' => 'computer'],
            ['slug' => 'papiers', 'name' => 'Documents', 'description' => 'Papiers et documents', 'icon' => 'description'],
            ['slug' => 'cles', 'name' => 'Clés', 'description' => 'Clés et badges', 'icon' => 'key'],
            ['slug' => 'sac', 'name' => 'Sacs', 'description' => 'Sacs et bagages', 'icon' => 'backpack'],
            ['slug' => 'vetement', 'name' => 'Vêtements', 'description' => 'Vêtements', 'icon' => 'checkroom'],
            ['slug' => 'accessoire', 'name' => 'Accessoires', 'description' => 'Accessoires', 'icon' => 'watch'],
            ['slug' => 'bijou', 'name' => 'Bijoux', 'description' => 'Bijoux', 'icon' => 'diamond'],
            ['slug' => 'livre', 'name' => 'Livres', 'description' => 'Livres et cahiers', 'icon' => 'menu_book'],
            ['slug' => 'animal', 'name' => 'Animaux', 'description' => 'Animaux', 'icon' => 'pets'],
            ['slug' => 'lunettes', 'name' => 'Lunettes', 'description' => 'Lunettes', 'icon' => 'visibility'],
            ['slug' => 'portefeuille', 'name' => 'Portefeuille', 'description' => 'Portefeuilles', 'icon' => 'account_balance_wallet'],
            ['slug' => 'autre', 'name' => 'Autre', 'description' => 'Autre objet', 'icon' => 'category'],
        ];

        foreach ($categories as $category) {
            $exists = DB::table('categories')->where('slug', $category['slug'])->exists();
            if (! $exists) {
                DB::table('categories')->insert($category + [
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        if (! Schema::hasTable('item_images')) {
            Schema::create('item_images', function (Blueprint $table) {
                $table->id();
                $table->uuid('item_id');
                $table->string('path');
                $table->boolean('is_primary')->default(false);
                $table->timestamps();

                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
                $table->index(['item_id', 'is_primary']);
            });
        }

        if (! Schema::hasTable('object_favorites')) {
            Schema::create('object_favorites', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
                $table->uuid('item_id');
                $table->timestamps();

                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
                $table->unique(['user_id', 'item_id']);
            });
        }

        if (! Schema::hasTable('object_reports')) {
            Schema::create('object_reports', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
                $table->uuid('item_id');
                $table->string('reason', 40);
                $table->text('details')->nullable();
                $table->string('status', 20)->default('OPEN');
                $table->timestamps();

                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
                $table->index(['item_id', 'status']);
            });
        }

        if (! Schema::hasTable('object_events')) {
            Schema::create('object_events', function (Blueprint $table) {
                $table->id();
                $table->uuid('item_id');
                $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
                $table->string('event', 40);
                $table->json('meta')->nullable();
                $table->timestamps();

                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
                $table->index(['item_id', 'created_at']);
            });
        }

        Schema::table('items', function (Blueprint $table) {
            if (! Schema::hasColumn('items', 'category_id')) {
                $table->foreignId('category_id')->nullable()->constrained('categories')->nullOnDelete();
            }
        });

        $this->addIndex('items', ['category'], 'items_category_lookup');
        $this->addIndex('items', ['occurred_at'], 'items_occurred_at_lookup');
        $this->addIndex('items', ['created_at'], 'items_created_at_lookup');
        $this->addIndex('items', ['status'], 'items_status_lookup');
    }

    public function down(): void
    {
        Schema::table('items', function (Blueprint $table) {
            if (Schema::hasColumn('items', 'category_id')) {
                $table->dropConstrainedForeignId('category_id');
            }
        });

        Schema::dropIfExists('object_events');
        Schema::dropIfExists('object_reports');
        Schema::dropIfExists('object_favorites');
        Schema::dropIfExists('item_images');
        Schema::dropIfExists('categories');
    }

    private function addIndex(string $table, array $columns, string $name): void
    {
        try {
            Schema::table($table, function (Blueprint $blueprint) use ($columns, $name) {
                $blueprint->index($columns, $name);
            });
        } catch (\Throwable $e) {
            // Index already present on this database.
        }
    }
};
