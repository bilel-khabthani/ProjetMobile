<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClaimController;
use App\Http\Controllers\Api\ItemController;
use App\Http\Controllers\Api\MatchController;
use App\Http\Controllers\Api\TrustController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\RewardsController;
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
        // Module 2 : declarations & gestion des objets perdus et trouves (Lost & Found)
        Route::get('/items', [ItemController::class, 'index']);
        Route::get('/objects', [ItemController::class, 'index']);
        Route::get('/items/statistics', [ItemController::class, 'statistics']);
        Route::get('/objects/statistics', [ItemController::class, 'statistics']);
        Route::get('/items/mine', [ItemController::class, 'mine']);
        Route::get('/objects/my-objects', [ItemController::class, 'mine']);
        Route::get('/items/nearby', [ItemController::class, 'nearby']);
        Route::get('/objects/nearby', [ItemController::class, 'nearby']);
        Route::get('/items/nearby-found', [ItemController::class, 'nearbyFound']);
        Route::post('/items', [ItemController::class, 'store']);
        Route::post('/objects', [ItemController::class, 'store']);
        Route::get('/items/{item}', [ItemController::class, 'show']);
        Route::get('/objects/{item}', [ItemController::class, 'show']);
        Route::put('/items/{item}', [ItemController::class, 'update']);
        Route::put('/objects/{item}', [ItemController::class, 'update']);
        Route::delete('/items/{item}', [ItemController::class, 'destroy']);
        Route::delete('/objects/{item}', [ItemController::class, 'destroy']);
        Route::patch('/items/{item}/resolve', [ItemController::class, 'resolve']);
        Route::patch('/objects/{item}/resolve', [ItemController::class, 'resolve']);
        Route::get('/items/{item}/matches', [ItemController::class, 'findMatches']);
        Route::get('/objects/{item}/matches', [ItemController::class, 'findMatches']);

        // Module 3 : matching + verification
        Route::get('/matches', [MatchController::class, 'index']);
        Route::get('/matches/{match}', [MatchController::class, 'show']);
        Route::post('/matches/{match}/answer', [MatchController::class, 'answer']);

        // Module 5 : restitution et chat
        Route::post('/matches/{match}/confirm-restitution', [MatchController::class, 'confirmRestitution']);
        Route::get('/matches/{match}/messages', [MatchController::class, 'messages']);
        Route::post('/matches/{match}/messages', [MatchController::class, 'sendMessage']);
        Route::get('/claims', [ClaimController::class, 'index']);
        Route::post('/claims', [ClaimController::class, 'store']);
        Route::post('/claims/{claim}/respond', [ClaimController::class, 'respond']);
        Route::post('/claims/{claim}/escalate', [ClaimController::class, 'escalate']);
        Route::post('/claims/{claim}/resolve', [ClaimController::class, 'resolve']);

        // ========== NEW PREMIUM FEATURES ==========

        // Feature #1: Messaging between users
        Route::prefix('messages')->group(function () {
            Route::get('/conversations', [MessageController::class, 'conversations']);
            Route::get('/with/{userId}', [MessageController::class, 'getMessages']);
            Route::post('/send', [MessageController::class, 'sendMessage']);
            Route::patch('/{messageId}/read', [MessageController::class, 'markAsRead']);
            Route::get('/unread-count', [MessageController::class, 'unreadCount']);
        });

        // Feature #2 & #3: Analytics and Intelligent Matching
        Route::prefix('analytics')->group(function () {
            Route::get('/user-stats', [AnalyticsController::class, 'userStats']);
            Route::get('/platform-stats', [AnalyticsController::class, 'platformStats']);
            Route::get('/time-series', [AnalyticsController::class, 'timeSeriesStats']);
            Route::get('/trending-categories', [AnalyticsController::class, 'trendingCategories']);
            Route::get('/top-users', [AnalyticsController::class, 'topUsers']);
            Route::get('/success-stories', [AnalyticsController::class, 'successStories']);
        });

        // Feature #4 & #5: Rewards and Social Sharing
        Route::prefix('rewards')->group(function () {
            Route::get('/balance', [RewardsController::class, 'balance']);
            Route::post('/share/{itemId}', [RewardsController::class, 'generateShareLink']);
            Route::get('/leaderboards', [RewardsController::class, 'leaderboards']);
            Route::get('/badges', [RewardsController::class, 'badges']);
            Route::post('/redeem', [RewardsController::class, 'redeemCoins']);
        });

        // Public share tracking (no auth required - routes below)
    });
});

// Public routes (no authentication required)
Route::get('/share/{shareToken}', [RewardsController::class, 'trackShareClick']);

