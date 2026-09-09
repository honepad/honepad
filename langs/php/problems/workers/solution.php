<?php

class Worker
{
    public string $workerId;
    public string $position;
    public int $compensation;
    public bool $inOffice = false;
    public ?int $enteredAt = null;
    public array $finished = [];
    public ?array $pendingPromo = null;
    public array $doublePay = [];

    public function __construct(string $workerId, string $position, int $compensation)
    {
        $this->workerId = $workerId;
        $this->position = $position;
        $this->compensation = $compensation;
    }

    public function totalTime(): int
    {
        $sum = 0;
        foreach ($this->finished as [$start, $end]) {
            $sum += $end - $start;
        }
        return $sum;
    }

    public function positionTime(string $position): int
    {
        $sum = 0;
        foreach ($this->finished as [$start, $end, $_rate, $pos]) {
            if ($pos === $position) {
                $sum += $end - $start;
            }
        }
        return $sum;
    }

    public function applyPromoOnEnter(int $timestamp): void
    {
        if ($this->pendingPromo === null) {
            return;
        }
        [$newPos, $newComp, $startTs] = $this->pendingPromo;
        if ($timestamp >= $startTs) {
            $this->position = $newPos;
            $this->compensation = $newComp;
            $this->pendingPromo = null;
        }
    }
}

class Simulation
{
    private array $workers = [];

    public function addWorker(string $workerId, string $position, int $compensation): string
    {
        if (array_key_exists($workerId, $this->workers)) {
            return 'false';
        }
        $this->workers[$workerId] = new Worker($workerId, $position, $compensation);
        return 'true';
    }

    public function register(string $workerId, int $timestamp): string
    {
        if (!array_key_exists($workerId, $this->workers)) {
            return 'invalid_request';
        }
        $worker = $this->workers[$workerId];
        if ($worker->inOffice) {
            $worker->finished[] = [
                $worker->enteredAt,
                $timestamp,
                $worker->compensation,
                $worker->position,
            ];
            $worker->inOffice = false;
            $worker->enteredAt = null;
            return 'registered';
        }
        $worker->applyPromoOnEnter($timestamp);
        $worker->inOffice = true;
        $worker->enteredAt = $timestamp;
        return 'registered';
    }

    public function get(string $workerId): string
    {
        if (!array_key_exists($workerId, $this->workers)) {
            return '';
        }
        return (string) $this->workers[$workerId]->totalTime();
    }

    public function topNWorkers(int $n, string $position): string
    {
        $matched = array_values(array_filter(
            $this->workers,
            fn ($w) => $w->position === $position,
        ));
        usort($matched, function (Worker $a, Worker $b) use ($position): int {
            $d = $b->positionTime($position) <=> $a->positionTime($position);
            return $d !== 0 ? $d : ($a->workerId <=> $b->workerId);
        });
        $top = array_slice($matched, 0, $n);
        return implode(
            ', ',
            array_map(fn ($w) => $w->workerId . '(' . $w->positionTime($position) . ')', $top),
        );
    }

    public function promote(
        string $workerId,
        string $newPosition,
        int $newCompensation,
        int $startTimestamp,
    ): string {
        if (!array_key_exists($workerId, $this->workers)) {
            return 'invalid_request';
        }
        $worker = $this->workers[$workerId];
        if ($worker->pendingPromo !== null) {
            return 'invalid_request';
        }
        $worker->pendingPromo = [$newPosition, $newCompensation, $startTimestamp];
        return 'success';
    }

    public function setDoublePay(string $workerId, int $intervalBegin, int $intervalEnd): string
    {
        if (!array_key_exists($workerId, $this->workers) || $intervalEnd <= $intervalBegin) {
            return 'invalid_request';
        }
        $this->workers[$workerId]->doublePay[] = [$intervalBegin, $intervalEnd];
        return 'true';
    }

    public function calcSalary(string $workerId, int $startTimestamp, int $endTimestamp): string
    {
        if (!array_key_exists($workerId, $this->workers)) {
            return '';
        }
        $total = 0;
        $worker = $this->workers[$workerId];
        foreach ($worker->finished as [$sessionStart, $sessionEnd, $rate]) {
            $lo = max($sessionStart, $startTimestamp);
            $hi = min($sessionEnd, $endTimestamp);
            if ($hi > $lo) {
                $bonus = bonusOverlap($lo, $hi, $worker->doublePay);
                $total += ($hi - $lo - $bonus) * $rate + $bonus * $rate * 2;
            }
        }
        return (string) $total;
    }
}

function bonusOverlap(int $lo, int $hi, array $windows): int
{
    $segs = [];
    foreach ($windows as [$begin, $end]) {
        $start = max($lo, $begin);
        $stop = min($hi, $end);
        if ($stop > $start) {
            $segs[] = [$start, $stop];
        }
    }
    usort($segs, fn ($a, $b) => $a[0] <=> $b[0]);
    $merged = [];
    foreach ($segs as [$start, $stop]) {
        if ($merged === [] || $start >= $merged[array_key_last($merged)][1]) {
            $merged[] = [$start, $stop];
        } else {
            $last = array_key_last($merged);
            $merged[$last][1] = max($merged[$last][1], $stop);
        }
    }
    $sum = 0;
    foreach ($merged as [$start, $stop]) {
        $sum += $stop - $start;
    }
    return $sum;
}
