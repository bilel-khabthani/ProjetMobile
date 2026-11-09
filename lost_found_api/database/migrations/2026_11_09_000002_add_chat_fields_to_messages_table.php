<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Chat securise : accuse de lecture et signalement d'un message.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            if (! Schema::hasColumn('messages', 'read_at')) {
                $table->timestamp('read_at')->nullable()->after('body');
            }

            if (! Schema::hasColumn('messages', 'reported_at')) {
                $table->timestamp('reported_at')->nullable()->after('read_at');
            }

            if (! Schema::hasColumn('messages', 'report_reason')) {
                $table->string('report_reason', 40)->nullable()->after('reported_at');
            }
        });

        try {
            Schema::table('messages', function (Blueprint $table) {
                $table->index(['match_id', 'read_at'], 'messages_match_read_lookup');
            });
        } catch (Throwable $e) {
            // Index deja present sur cette base.
        }
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            try {
                $table->dropIndex('messages_match_read_lookup');
            } catch (Throwable $e) {
                // Index absent.
            }

            foreach (['report_reason', 'reported_at', 'read_at'] as $column) {
                if (Schema::hasColumn('messages', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
