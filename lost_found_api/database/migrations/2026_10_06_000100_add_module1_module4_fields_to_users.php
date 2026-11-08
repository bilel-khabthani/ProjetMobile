<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Module 1 : verification du telephone (un numero = un compte)
            $table->string('phone')->nullable()->after('email');
            $table->boolean('phone_verified')->default(false)->after('phone');

            // Module 4 : score de confiance, socle neutre de 50 (section 6.4 du CDC)
            $table->integer('trust_score')->default(50)->after('phone_verified');
            $table->integer('recovered_count')->default(0)->after('trust_score');
            // created_at / updated_at existent deja dans la table users de Laravel.
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'phone_verified', 'trust_score', 'recovered_count']);
        });
    }
};
