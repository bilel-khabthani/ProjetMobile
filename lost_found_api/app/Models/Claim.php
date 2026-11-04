<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'reporter_id', 'respondent_id', 'related_match_id', 'related_item_id',
    'type', 'description', 'response_text', 'status', 'responded_at', 'resolved_at',
])]
class Claim extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    // Cycle de vie impose par le CDC (section 6.4.5) : toute reclamation
    // reste tracee jusqu'a sa cloture, aucune sanction automatique n'est appliquee.
    public const STATUS_OPEN = 'OUVERTE';

    public const STATUS_IN_PROGRESS = 'EN_COURS';

    public const STATUS_ANSWERED = 'REPONSE_APPORTEE';

    public const STATUS_ESCALATED = 'ESCALADEE';

    public const STATUS_RESOLVED = 'RESOLUE';

    public const STATUS_CLOSED = 'CLOTUREE';

    protected function casts(): array
    {
        return [
            'responded_at' => 'datetime',
            'resolved_at' => 'datetime',
        ];
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function respondent(): BelongsTo
    {
        return $this->belongsTo(User::class, 'respondent_id');
    }

    /** Une reclamation fondee debouche sur un evenement de score (CDC 6.4.4). */
    public function isFounded(): bool
    {
        return $this->type === 'FRAUDE_CONFIRMEE';
    }

    /** L'admin tranche ; le systeme ne peut pas cloturer seul (CDC 6.4.5). */
    public function requiresAdminReview(): bool
    {
        return $this->status === self::STATUS_ESCALATED;
    }
}
