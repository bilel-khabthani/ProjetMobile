<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClaimController;
use App\Http\Controllers\Api\ItemController;
use App\Http\Controllers\Api\MatchController;
use App\Http\Controllers\Api\TrustController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API REST Lost&Found AI
|--------------------------------------------------------------------------
| Les routes publiques sont celles d'authentification et de consultation
| du catalogue. Tout ce qui touche au score de confiance, au chat ou a la
| restitution exige un jeton Sanctum : c'est la traduction applicative
| des garde-fous du CDC.
*/

Route::get('/ping', fn () => ['status' => 'ok', 'app' => config('app.name')]);

// Module 1 : gestion des utilisateurs
Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:register');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::post('/otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp');
    Route::post('/otp/verify', [AuthController::class, 'otpVerify'])->middleware('throttle:otp');
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:password-reset');
    Route::post('/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:password-reset');
});

Route::middleware('auth:sanctum')->group(function () {
    // Parcours "compte" accessible meme sans numero verifie : c'est depuis
    // /me que l'application declenche la verification, et /trust/me permet
    // de consulter son score (avec l'etait de probation le cas echeant).
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/me', [AuthController::class, 'updateMe']);
    // Le client Flutter envoie PATCH : les deux verbos sont acceptes.
    Route::patch('/auth/me', [AuthController::class, 'updateMe']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/trust/me', [TrustController::class, 'me']);

    // CDC 6.1 : les services (annonces, matching, reclamations) exigent un
    // numero de telephone verifie (anti-fraude 6.4.3).
    Route::middleware('verified-phone')->group(function () {
        // Module 2 : declarations
        Route::get('/items', [ItemController::class, 'index']);
        Route::get('/items/mine', [ItemController::class, 'mine']);
        Route::get('/items/nearby-found', [ItemController::class, 'nearbyFound']);
        Route::post('/items', [ItemController::class, 'store']);
        Route::get('/items/{item}', [ItemController::class, 'show']);
        Route::match(['put', 'patch', 'post'], '/items/{item}', [ItemController::class, 'update']);
        Route::delete('/items/{item}', [ItemController::class, 'destroy']);
        Route::get('/items/{item}/matches', [ItemController::class, 'findMatches']);

        // Module 3 : matching + verification
        Route::get('/matches', [MatchController::class, 'index']);
        Route::get('/matches/{match}', [MatchController::class, 'show']);
        Route::post('/matches/{match}/answer', [MatchController::class, 'answer']);

        // Module 5 : restitution et chat
        Route::post('/matches/{match}/confirm-restitution', [MatchController::class, 'confirmRestitution']);
        Route::get('/matches/{match}/messages', [MatchController::class, 'messages']);
        Route::post('/matches/{match}/messages', [MatchController::class, 'sendMessage'])->middleware('throttle:chat');
        Route::post('/matches/{match}/messages/read', [MatchController::class, 'markMessagesRead']);
        Route::post('/matches/{match}/messages/{message}/report', [MatchController::class, 'reportMessage']);
        Route::get('/claims', [ClaimController::class, 'index']);
        Route::post('/claims', [ClaimController::class, 'store']);
        Route::post('/claims/{claim}/respond', [ClaimController::class, 'respond']);
        Route::post('/claims/{claim}/escalate', [ClaimController::class, 'escalate']);
        Route::post('/claims/{claim}/resolve', [ClaimController::class, 'resolve']);
    });
});
