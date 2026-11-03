<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Module 2 : entite Item (CDC section 8.5.2)
        // Une seule structure pour LOST et FOUND, ce qui simplifie l'ergonomie
        // et l'implementation (CDC section 6.2.1).
        Schema::create('items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            // users.id est un bigint dans la table users de Laravel (incrementing id),
            // donc on reference un unsignedBigInteger et non un UUID.
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 10);            // LOST | FOUND
            $table->string('category');            // sac, telephone, cles, papiers, vetement, autre
            $table->string('title');
            $table->text('description');
            $table->text('secret_detail')->nullable(); // detail distinctif pour la verification
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('place_label')->nullable();
            $table->timestamp('occurred_at');
            $table->string('status', 20)->default('ACTIVE'); // ACTIVE, MATCHED, DISPUTED, RECOVERED, CLOSED
            $table->timestamps();

            $table->index(['type', 'status']);
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('items');
    }
};
