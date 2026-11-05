<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->string('status', 20)->default('APPROVED')->after('body');
            $table->json('moderation_categories')->nullable()->after('status');
            $table->json('moderation_scores')->nullable()->after('moderation_categories');
            $table->string('moderation_provider', 40)->nullable()->after('moderation_scores');
            $table->timestamp('read_at')->nullable()->after('moderation_provider');
            $table->softDeletes();
        });

        // Journal d'audit de la moderation. Le contenu bloque n'est pas stocke
        // dans le chat : on conserve un hash et un extrait tronque, uniquement
        // pour permettre un arbitrage humain (CDC 6.4.5).
        Schema::create('moderation_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('message_id')->nullable()->constrained('messages')->nullOnDelete();
            $table->foreignUuid('match_id')->nullable()->constrained('matches')->nullOnDelete();
            $table->string('source', 20)->default('CHAT');
            $table->string('decision', 20);
            $table->json('categories')->nullable();
            $table->json('scores')->nullable();
            $table->string('text_hash', 64);
            $table->text('excerpt')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('moderation_events');

        Schema::table('messages', function (Blueprint $table) {
            $table->dropSoftDeletes();
            $table->dropColumn([
                'status',
                'moderation_categories',
                'moderation_scores',
                'moderation_provider',
                'read_at',
            ]);
        });
    }
};
