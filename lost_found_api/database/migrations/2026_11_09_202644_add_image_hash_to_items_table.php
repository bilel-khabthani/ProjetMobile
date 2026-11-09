<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Empreinte perceptuelle (dHash) de la photo principale. Elle permet au
     * moteur de matching de comparer deux photos cote serveur, sans dependre
     * d'un service externe. La migration est idempotente pour les bases ou la
     * colonne existerait deja.
     */
    public function up(): void
    {
        if (Schema::hasColumn('items', 'image_hash')) {
            return;
        }

        Schema::table('items', function (Blueprint $table) {
            $table->string('image_hash', 64)->nullable()->after('image_path');
        });
    }

    public function down(): void
    {
        if (! Schema::hasColumn('items', 'image_hash')) {
            return;
        }

        Schema::table('items', function (Blueprint $table) {
            $table->dropColumn('image_hash');
        });
    }
};
