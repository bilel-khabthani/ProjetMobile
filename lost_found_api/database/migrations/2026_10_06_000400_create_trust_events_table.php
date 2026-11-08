<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Module 4 : journal immuable des evenements de score (CDC section 8.5.4)
        // Aucun gain ni perte n'est declare directement par l'utilisateur :
        // chaque ligne provient d'un evenement verifiable (CDC section 6.4.4).
        Schema::create('trust_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 40);   // RESTITUTION_CONFIRMEE, DECLARATION_FAUSSE, ABSENCE_RDV, RECLAMATION_FONDEE, RECLAMATION_ABUSIVE, ...
            $table->integer('points');    // variation, positive ou negative
            $table->uuid('related_match_id')->nullable();
            $table->string('validated_by', 10)->default('SYSTEME'); // SYSTEME | ADMIN
            $table->string('reason')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trust_events');
    }
};
