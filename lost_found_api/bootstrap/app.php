<?php

use App\Http\Middleware\EnsurePhoneVerified;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['middleware' => ['auth:sanctum']],
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Pas de route web "login" : les clients non-JSON sont rediriges vers
        // la page d'accueil au lieu de lever une RouteNotFoundException (500).
        $middleware->redirectGuestsTo(fn () => url('/'));

        // CDC 6.1 : acces aux services conditionne par un numero verifie.
        $middleware->alias([
            'verified-phone' => EnsurePhoneVerified::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
