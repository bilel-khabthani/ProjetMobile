<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Photo principale d'une annonce. La colonne etait referencee par
     * ItemController mais aucune migration ne la creait : les uploads etaient
     * silencieusement ignores. Cette migration est idempotente pour les bases
     * ou la colonne existerait deja.
     */
    public function up(): void
    {
        if (Schema::hasColumn('items', 'image_path')) {
            return;
        }

        Schema::table('items', function (Blueprint $table) {
            $table->string('image_path')->nullable()->after('secret_detail');
        });
    }

    public function down(): void
    {
        if (! Schema::hasColumn('items', 'image_path')) {
            return;
        }

        Schema::table('items', function (Blueprint $table) {
            $table->dropColumn('image_path');
        });
    }
};
