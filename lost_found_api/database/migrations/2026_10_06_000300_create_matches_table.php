<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Module 3 : resultats du moteur de matching (CDC section 8.5.3)
        // Les 4 dimensions (image, localisation, temps, texte) plus le score
        // global pondere. Les deux confirmations de restitution sont datees
        // separement : la double confirmation est une exigence Must (EF-09).
        Schema::create('matches', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('lost_item_id');
            $table->uuid('found_item_id');
            $table->integer('image_score')->default(0);
            $table->integer('location_score')->default(0);
            $table->integer('time_score')->default(0);
            $table->integer('text_score')->default(0);
            $table->integer('global_score')->default(0);
            $table->string('status', 20)->default('PENDING'); // PENDING, VERIFIED, CONTACTED, RECOVERED, REJECTED
            $table->json('decision')->nullable();               // apercu non engageant : YES, UNSURE, NO (EF-06)
            $table->integer('verification_attempts')->default(0);
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('owner_confirmed_at')->nullable();
            $table->timestamp('finder_confirmed_at')->nullable();
            $table->timestamps();

            $table->foreign('lost_item_id')->references('id')->on('items')->cascadeOnDelete();
            $table->foreign('found_item_id')->references('id')->on('items')->cascadeOnDelete();
            $table->index('global_score');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('matches');
    }
};
