<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'phone', 'phone_verified', 'google_id', 'avatar'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            // 'hashed' : Laravel hache automatiquement le mot de passe au moment
            // de l'ecriture. Le CDC section 7.2 exige un stockage hache, jamais en clair.
            'password' => 'hashed',
            'phone_verified' => 'boolean',
            'trust_score' => 'integer',
            'recovered_count' => 'integer',
        ];
    }

    public function items(): HasMany
    {
        return $this->hasMany(Item::class);
    }

    /** Journal des evenements de score (Module 4). */
    public function trustEvents(): HasMany
    {
        return $this->hasMany(TrustEvent::class);
    }

    /**
     * Module 4 - Periode de probation (CDC 6.4.3).
     * Un compte de moins de 14 jours, ou dont le telephone n'est pas verifie,
     * ne genere qu'un gain de points plafonne a 50 % du bareme.
     */
    public function isInProbation(): bool
    {
        $isYoung = $this->created_at->diffInDays(now()) < 14;

        return $isYoung || ! $this->phone_verified;
    }

    /**
     * Module 4 - Regle de garde-fou : un evenement de score n'est jamais
     * declare par l'utilisateur concerne. Il provient toujours d'un evenement
     * verifiable et la periode de probation plafonne le gain.
     */
    public function applyTrustDelta(int $points, string $type, string $reason, ?string $matchId = null): TrustEvent
    {
        $applied = $points > 0 && $this->isInProbation()
            ? (int) round($points * 0.5)
            : $points;

        $this->trust_score = max(0, min(100, $this->trust_score + $applied));
        $this->save();

        return TrustEvent::create([
            'user_id' => $this->id,
            'type' => $type,
            'points' => $applied,
            'related_match_id' => $matchId,
            'validated_by' => 'SYSTEME',
            'reason' => $reason,
        ]);
    }

    /** Deux lettres pour l'avatar, comme sur l'ecran d'accueil. */
    public function initials(): string
    {
        $parts = preg_split('/\s+/', trim($this->name)) ?: [];
        $letters = '';

        foreach (array_slice(array_filter($parts), 0, 2) as $part) {
            $letters .= mb_strtoupper(mb_substr($part, 0, 1));
        }

        return $letters === '' ? 'LF' : $letters;
    }
}
