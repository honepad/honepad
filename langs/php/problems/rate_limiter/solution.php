<?php

class KeyState
{
    public int $limit = 3;
    public int $window = 10;
    public ?int $windowId = null;
    public int $used = 0;
}

class Simulation
{
    /** @var array<string, KeyState> */
    private array $keys = [];

    public function allow(string $key, int $timestamp): string
    {
        return $this->allowWeighted($key, 1, $timestamp);
    }

    public function configure(string $key, int $limit, int $window): string
    {
        if ($limit <= 0 || $window <= 0) {
            return 'invalid_request';
        }
        $item = $this->state($key);
        $item->limit = $limit;
        $item->window = $window;
        $item->windowId = null;
        $item->used = 0;
        return 'true';
    }

    public function remaining(string $key, int $timestamp): string
    {
        $item = $this->state($key);
        $used = $this->usedAt($item, $timestamp, false);
        return (string) ($item->limit - $used);
    }

    public function allowWeighted(string $key, int $cost, int $timestamp): string
    {
        if ($cost <= 0) {
            return 'invalid_request';
        }
        $item = $this->state($key);
        $this->usedAt($item, $timestamp, true);
        if ($item->used + $cost > $item->limit) {
            return 'false';
        }
        $item->used += $cost;
        return 'true';
    }

    private function state(string $key): KeyState
    {
        if (!array_key_exists($key, $this->keys)) {
            $this->keys[$key] = new KeyState();
        }
        return $this->keys[$key];
    }

    private function usedAt(KeyState $item, int $timestamp, bool $persist): int
    {
        $windowId = intdiv($timestamp, $item->window);
        if ($item->windowId === null || $windowId !== $item->windowId) {
            if ($persist) {
                $item->windowId = $windowId;
                $item->used = 0;
            }
            return 0;
        }
        return $item->used;
    }
}
