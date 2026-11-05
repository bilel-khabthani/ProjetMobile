<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Module 1 + Module 4 : telephone verifie par SMS, un numero = un compte.
        // Le CDC section 6.4.3 impose cette contrainte pour bloquer les comptes
        // multiples servant a l'auto-restitution fictive.
        Schema::table('users', function (Blueprint $table) {
            $table->unique('phone')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['phone']);
        });
    }
};
