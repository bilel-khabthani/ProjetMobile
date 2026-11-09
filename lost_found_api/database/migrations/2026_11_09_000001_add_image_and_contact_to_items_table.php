<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Photos d'objets et telephone de contact.
 *
 * Les colonnes sont ajoutees de facon defensive : certaines bases locales
 * ont deja recu une migration partielle du module Objects.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('items', function (Blueprint $table) {
            if (! Schema::hasColumn('items', 'image_path')) {
                $table->string('image_path')->nullable()->after('secret_detail');
            }

            if (! Schema::hasColumn('items', 'contact_phone')) {
                $table->string('contact_phone', 30)->nullable()->after('image_path');
            }
        });
    }

    public function down(): void
    {
        Schema::table('items', function (Blueprint $table) {
            if (Schema::hasColumn('items', 'contact_phone')) {
                $table->dropColumn('contact_phone');
            }

            if (Schema::hasColumn('items', 'image_path')) {
                $table->dropColumn('image_path');
            }
        });
    }
};
