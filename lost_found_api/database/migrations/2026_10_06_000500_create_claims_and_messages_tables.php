<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Module 5 : reclamation (CDC section 8.5.5)
        // Le cycle OUVERTE -> EN_COURS -> REPONSE_APPORTEE -> ESCALADEE ->
        // RESOLUE -> CLOTUREE garantit qu'une reponse est toujours apportee.
        Schema::create('claims', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('respondent_id')->nullable()->constrained('users')->nullOnDelete();
            $table->uuid('related_match_id')->nullable();
            $table->uuid('related_item_id')->nullable();
            $table->string('type', 40);   // OBJET_NON_REMIS, CONTESTATION_PROPRIETE, SUSPICION_FRAUDE, COMPORTEMENT_ABUSIF, ERREUR_CORRESPONDANCE
            $table->text('description');
            $table->text('response_text')->nullable();
            $table->string('status', 20)->default('OUVERTE');
            $table->timestamp('responded_at')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['reporter_id', 'status']);
        });

        // Chat securise : deverrouille uniquement apres verification du proprietaire (EF-08)
        Schema::create('messages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('match_id');
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->text('body');
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('match_id')->references('id')->on('matches')->cascadeOnDelete();
            $table->index('match_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('messages');
        Schema::dropIfExists('claims');
    }
};
