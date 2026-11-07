<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Module Tinder Cards : une decision par utilisateur et par match.
        // La decision fonctionnelle reste dans matches.decision.answer ; cette
        // table sert d'historique pour ne pas reproposer une carte passee.
        Schema::create('swipe_decisions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('item_match_id')->constrained('matches')->cascadeOnDelete();
            $table->string('direction', 12); // LIKE | PASS
            $table->unsignedTinyInteger('ai_confidence')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'item_match_id']);
            $table->index(['item_match_id', 'direction']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('swipe_decisions');
    }
};
