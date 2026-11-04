<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Enrichissement du profil utilisateur pour la gamification & récompenses
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'reward_points')) {
                $table->integer('reward_points')->default(150)->after('trust_score');
            }
            if (! Schema::hasColumn('users', 'last_spin_at')) {
                $table->timestamp('last_spin_at')->nullable()->after('reward_points');
            }
        });

        // 2. Catalogue des récompenses et coupons partenaires (Glovo, Yassir, Restos, etc.)
        Schema::create('rewards', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('partner_name');
            $table->string('partner_type', 30)->default('DELIVERY'); // DELIVERY, RESTAURANT, CAFE, SHOPPING
            $table->text('description');
            $table->integer('points_cost')->default(50);
            $table->string('discount_text');
            $table->string('icon_name', 50)->default('redeem');
            $table->string('color_hex', 20)->default('#FFC244');
            $table->text('terms')->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('stock')->default(100);
            $table->timestamps();
        });

        // 3. Portefeuille des coupons attribués aux utilisateurs
        Schema::create('user_coupons', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reward_id')->nullable()->constrained('rewards')->nullOnDelete();
            $table->string('title');
            $table->string('partner_name');
            $table->string('partner_type', 30)->default('DELIVERY');
            $table->string('code')->unique();
            $table->string('discount_text');
            $table->string('status', 20)->default('ACTIVE'); // ACTIVE, USED, EXPIRED
            $table->string('source', 30)->default('RESTITUTION'); // RESTITUTION, WHEEL_SPIN, POINTS_EXCHANGE
            $table->text('terms')->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
        });

        // 4. Historique transparent des transactions de points
        Schema::create('reward_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 40); // RESTITUTION_BONUS, WHEEL_WIN, WHEEL_SPIN_COST, COUPON_REDEEM, WELCOME_BONUS
            $table->integer('points'); // variation positive ou négative
            $table->string('description');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reward_transactions');
        Schema::dropIfExists('user_coupons');
        Schema::dropIfExists('rewards');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['reward_points', 'last_spin_at']);
        });
    }
};

