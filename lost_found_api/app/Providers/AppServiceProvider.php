<?php

namespace App\Providers;

use App\Services\Moderation\ModerationManager;
use App\Services\Moderation\ModerationService;
use App\Services\Moderation\TextNormalizer;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(ModerationService::class, fn () => new ModerationManager(
            $this->app->make(TextNormalizer::class),
        ));
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // CDC 7.2 : protection de l'authentification contre les attaques par
        // force brute. Chaque limiteur est pondere par identifiant + IP.
        RateLimiter::for('login', function (Request $request): Limit {
            $email = strtolower((string) $request->input('email'));

            return Limit::perMinute(5)->by($email.'|'.$request->ip());
        });

        RateLimiter::for('otp', function (Request $request): Limit {
            $phone = (string) $request->input('phone');

            return Limit::perMinute(5)->by($phone.'|'.$request->ip());
        });

        RateLimiter::for('register', function (Request $request): Limit {
            return Limit::perMinute(3)->by($request->ip());
        });

        RateLimiter::for('password-reset', function (Request $request): Limit {
            $email = strtolower((string) $request->input('email'));

            return Limit::perMinute(5)->by($email.'|'.$request->ip());
        });

        // Chat : limite les envois par utilisateur pour freiner le spam et les
        // tentatives de contournement de la moderation.
        RateLimiter::for('chat', function (Request $request): Limit {
            return Limit::perMinute(20)->by((string) $request->user()?->id.'|'.$request->ip());
        });
    }
}
