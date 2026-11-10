<?php

namespace App\Console\Commands;

use App\Models\Claim;
use App\Services\TrustService;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use InvalidArgumentException;

#[Signature('trust:resolve-appeal {claim : Identifiant de la reclamation} {--uphold : Accepte l appel} {--reject : Rejette l appel} {--note= : Note d arbitrage} {--by=ADMIN : Auteur de l arbitrage}')]
#[Description('Accepte ou rejette un appel de sanction et corrige le score de confiance.')]
class ResolveTrustAppeal extends Command
{
    public function handle(TrustService $trust): int
    {
        $claim = Claim::query()
            ->with('relatedTrustEvent.user')
            ->find($this->argument('claim'));

        if (! $claim) {
            $this->error('Réclamation introuvable.');

            return self::FAILURE;
        }

        if ($claim->type !== Claim::TYPE_APPEL_SANCTION) {
            $this->error('Cette réclamation n\'est pas un appel de sanction.');

            return self::FAILURE;
        }

        if (in_array($claim->status, [Claim::STATUS_RESOLVED, Claim::STATUS_CLOSED], true)) {
            $this->error('Cet appel est déjà traité ('.$claim->status.').');

            return self::FAILURE;
        }

        $uphold = (bool) $this->option('uphold');
        $reject = (bool) $this->option('reject');

        if ($uphold === $reject) {
            $this->error('Utilisez exactement une option : --uphold ou --reject.');

            return self::FAILURE;
        }

        $event = $claim->relatedTrustEvent;

        if (! $event) {
            $this->error('La sanction liée à cet appel est introuvable.');

            return self::FAILURE;
        }

        if ($event->user_id !== $claim->reporter_id) {
            $this->error('La sanction ne concerne pas l\'auteur de l\'appel.');

            return self::FAILURE;
        }

        if ($event->points >= 0) {
            $this->error('La sanction liée n\'est pas une sanction négative.');

            return self::FAILURE;
        }

        $note = $this->option('note');

        if ($reject) {
            $claim->update([
                'status' => Claim::STATUS_CLOSED,
                'resolved_at' => now(),
                'response_text' => $note,
            ]);

            $this->info('Appel rejeté. Score inchangé : '.$event->user->trust_score.'/100.');

            return self::SUCCESS;
        }

        try {
            $reversal = $trust->reverseSanction(
                $event,
                $note ?: 'Appel accepté : sanction annulée après arbitrage.',
                (string) $this->option('by'),
            );
        } catch (InvalidArgumentException $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }

        $claim->update([
            'status' => Claim::STATUS_RESOLVED,
            'resolved_at' => now(),
            'response_text' => $note,
        ]);

        $this->info('Appel accepté. Correction : +'.$reversal->points.' points.');
        $this->info('Nouveau score : '.$event->user->fresh()->trust_score.'/100.');

        return self::SUCCESS;
    }
}
