<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // User rewards (coins tracking)
        Schema::create('user_rewards', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->integer('coins')->default(0);
            $table->string('reason')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
        });

        // User badges (achievements)
        Schema::create('user_badges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('badge_name');
            $table->timestamps();

            $table->unique(['user_id', 'badge_name']);
        });

        // Item shares (social sharing tracking)
        Schema::create('item_shares', function (Blueprint $table) {
            $table->id();
            $table->uuid('item_id')->constrained('items')->onDelete('cascade');
            $table->foreignId('shared_by_user_id')->constrained('users')->onDelete('cascade');
            $table->string('share_token')->unique();
            $table->string('platform')->default('generic'); // whatsapp, facebook, twitter
            $table->integer('clicked_count')->default(0);
            $table->timestamps();

            $table->index(['item_id', 'created_at']);
        });

        // Notifications table
        if (!Schema::hasTable('notifications')) {
            Schema::create('notifications', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('title');
                $table->text('message');
                $table->string('type'); // match, message, recovery, trending
                $table->json('data')->nullable();
                $table->boolean('is_read')->default(false);
                $table->timestamps();

                $table->index(['user_id', 'is_read']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('item_shares');
        Schema::dropIfExists('user_badges');
        Schema::dropIfExists('user_rewards');
    }
};
