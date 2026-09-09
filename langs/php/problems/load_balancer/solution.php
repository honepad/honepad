<?php

class Backend
{
    public string $backendId;
    public bool $health = true;
    public int $weight = 1;
    public int $inflight = 0;

    public function __construct(string $backendId)
    {
        $this->backendId = $backendId;
    }
}

class Simulation
{
    /** @var list<Backend> */
    private array $backends = [];
    /** @var array<string, Backend> */
    private array $byId = [];
    private int $cursor = 0;
    /** @var array<string, string> */
    private array $stickyMap = [];
    private bool $useLeast = false;

    public function addBackend(string $backendId): string
    {
        if (array_key_exists($backendId, $this->byId)) {
            return 'false';
        }
        $item = new Backend($backendId);
        $this->backends[] = $item;
        $this->byId[$backendId] = $item;
        return 'true';
    }

    public function setHealth(string $backendId, int $flag): string
    {
        $item = $this->byId[$backendId] ?? null;
        if ($item === null || ($flag !== 0 && $flag !== 1)) {
            return 'invalid_request';
        }
        $item->health = $flag === 1;
        $this->resetCycle();
        return 'true';
    }

    public function setWeight(string $backendId, int $weight): string
    {
        $item = $this->byId[$backendId] ?? null;
        if ($item === null || $weight <= 0) {
            return 'invalid_request';
        }
        $item->weight = $weight;
        $this->resetCycle();
        return 'true';
    }

    public function route(): string
    {
        return $this->take();
    }

    public function sticky(string $clientId): string
    {
        $bound = $this->stickyMap[$clientId] ?? null;
        $item = $bound !== null ? ($this->byId[$bound] ?? null) : null;
        if ($item !== null && $item->health) {
            $item->inflight += 1;
            return $item->backendId;
        }
        $chosen = $this->take();
        if ($chosen !== '') {
            $this->stickyMap[$clientId] = $chosen;
        }
        return $chosen;
    }

    public function done(string $backendId): string
    {
        $item = $this->byId[$backendId] ?? null;
        if ($item === null || $item->inflight <= 0) {
            return 'invalid_request';
        }
        $item->inflight -= 1;
        $this->useLeast = true;
        return 'true';
    }

    private function resetCycle(): void
    {
        $this->cursor = 0;
        $this->useLeast = false;
        foreach ($this->backends as $item) {
            $item->inflight = 0;
        }
    }

    /** @param list<Backend> $items
     *  @return list<Backend> */
    private function tickets(array $items): array
    {
        $tickets = [];
        foreach ($items as $item) {
            for ($i = 0; $i < $item->weight; $i++) {
                $tickets[] = $item;
            }
        }
        return $tickets;
    }

    private function pick(): ?Backend
    {
        $healthy = array_values(array_filter(
            $this->backends,
            static fn (Backend $item): bool => $item->health
        ));
        if ($healthy === []) {
            return null;
        }
        $pool = $healthy;
        if ($this->useLeast) {
            $least = min(array_map(static fn (Backend $item): int => $item->inflight, $healthy));
            $pool = array_values(array_filter(
                $healthy,
                static fn (Backend $item): bool => $item->inflight === $least
            ));
        }
        $tickets = $this->tickets($pool);
        if ($tickets === []) {
            return null;
        }
        $chosen = $tickets[$this->cursor % count($tickets)];
        $this->cursor += 1;
        return $chosen;
    }

    private function take(): string
    {
        $item = $this->pick();
        if ($item === null) {
            return '';
        }
        $item->inflight += 1;
        return $item->backendId;
    }
}
