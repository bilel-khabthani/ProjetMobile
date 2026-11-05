<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('messages')) {
            Schema::create('messages', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->foreignId('from_user_id')->nullable()->constrained('users')->onDelete('cascade');
                $table->foreignId('to_user_id')->nullable()->constrained('users')->onDelete('cascade');
                $table->uuid('item_id')->nullable()->constrained('items')->onDelete('cascade');
                $table->text('content')->nullable();
                $table->boolean('is_read')->default(false);
                $table->timestamp('read_at')->nullable();
                $table->timestamps();
            });
        } else {
            Schema::table('messages', function (Blueprint $table) {
                if (!Schema::hasColumn('messages', 'from_user_id')) {
                    $table->foreignId('from_user_id')->nullable()->constrained('users')->onDelete('cascade');
                }
                if (!Schema::hasColumn('messages', 'to_user_id')) {
                    $table->foreignId('to_user_id')->nullable()->constrained('users')->onDelete('cascade');
                }
                if (!Schema::hasColumn('messages', 'item_id')) {
                    $table->uuid('item_id')->nullable();
                }
                if (!Schema::hasColumn('messages', 'content')) {
                    $table->text('content')->nullable();
                }
                if (!Schema::hasColumn('messages', 'is_read')) {
                    $table->boolean('is_read')->default(false);
                }
                if (!Schema::hasColumn('messages', 'read_at')) {
                    $table->timestamp('read_at')->nullable();
                }
                if (!Schema::hasColumn('messages', 'updated_at')) {
                    $table->timestamp('updated_at')->nullable();
                }
            });
        }
    }

    public function down(): void
    {
        // Safe rollback
    }
};
