<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('claims', function (Blueprint $table) {
            $table->uuid('related_trust_event_id')->nullable()->index();
        });

        Schema::table('trust_events', function (Blueprint $table) {
            $table->uuid('reversal_of_id')->nullable()->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('trust_events', function (Blueprint $table) {
            $table->dropColumn('reversal_of_id');
        });

        Schema::table('claims', function (Blueprint $table) {
            $table->dropColumn('related_trust_event_id');
        });
    }
};
