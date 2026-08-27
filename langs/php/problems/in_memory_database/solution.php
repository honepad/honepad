<?php

class InMemoryDatabase
{
    private array $database = [];
    private array $backupTimestamps = [];
    private array $backupStates = [];

    private function setInternal(string $key, string $field, string $value, ?int $expiry): string
    {
        if (!array_key_exists($key, $this->database)) {
            $this->database[$key] = [];
        }
        $this->database[$key][$field] = [$value, $expiry];
        return '';
    }

    private function isAlive(string $key, string $field, int $timestamp): bool
    {
        if (!array_key_exists($key, $this->database) || !array_key_exists($field, $this->database[$key])) {
            return false;
        }
        $expiry = $this->database[$key][$field][1];
        if ($expiry === null) {
            return true;
        }
        return $timestamp < $expiry;
    }

    public function set(string $key, string $field, string $value): string
    {
        return $this->setInternal($key, $field, $value, null);
    }

    public function get(string $key, string $field): string
    {
        if (!array_key_exists($key, $this->database) || !array_key_exists($field, $this->database[$key])) {
            return '';
        }
        return $this->database[$key][$field][0];
    }

    public function delete(string $key, string $field): string
    {
        if (!array_key_exists($key, $this->database) || !array_key_exists($field, $this->database[$key])) {
            return 'false';
        }
        unset($this->database[$key][$field]);
        return 'true';
    }

    public function scan(string $key): string
    {
        if (!array_key_exists($key, $this->database)) {
            return '';
        }
        $fields = array_keys($this->database[$key]);
        sort($fields);
        $parts = [];
        foreach ($fields as $field) {
            $parts[] = $field . '(' . $this->database[$key][$field][0] . ')';
        }
        return implode(', ', $parts);
    }

    public function scanByPrefix(string $key, string $prefix): string
    {
        if (!array_key_exists($key, $this->database)) {
            return '';
        }
        $fields = array_keys($this->database[$key]);
        $fields = array_values(array_filter($fields, fn ($field) => str_starts_with($field, $prefix)));
        sort($fields);
        $parts = [];
        foreach ($fields as $field) {
            $parts[] = $field . '(' . $this->database[$key][$field][0] . ')';
        }
        return implode(', ', $parts);
    }

    public function setAt(string $key, string $field, string $value, int $timestamp): string
    {
        unset($timestamp);
        return $this->setInternal($key, $field, $value, null);
    }

    public function setAtWithTtl(string $key, string $field, string $value, int $timestamp, int $ttl): string
    {
        return $this->setInternal($key, $field, $value, $timestamp + $ttl);
    }

    public function deleteAt(string $key, string $field, int $timestamp): string
    {
        if (!$this->isAlive($key, $field, $timestamp)) {
            return 'false';
        }
        unset($this->database[$key][$field]);
        return 'true';
    }

    public function getAt(string $key, string $field, int $timestamp): string
    {
        if (!$this->isAlive($key, $field, $timestamp)) {
            return '';
        }
        return $this->database[$key][$field][0];
    }

    public function scanAt(string $key, int $timestamp): string
    {
        if (!array_key_exists($key, $this->database)) {
            return '';
        }
        $fields = array_keys($this->database[$key]);
        $fields = array_values(array_filter(
            $fields,
            fn ($field) => $this->isAlive($key, $field, $timestamp),
        ));
        sort($fields);
        $parts = [];
        foreach ($fields as $field) {
            $parts[] = $field . '(' . $this->database[$key][$field][0] . ')';
        }
        return implode(', ', $parts);
    }

    public function scanByPrefixAt(string $key, string $prefix, int $timestamp): string
    {
        if (!array_key_exists($key, $this->database)) {
            return '';
        }
        $fields = array_keys($this->database[$key]);
        $fields = array_values(array_filter(
            $fields,
            fn ($field) => str_starts_with($field, $prefix) && $this->isAlive($key, $field, $timestamp),
        ));
        sort($fields);
        $parts = [];
        foreach ($fields as $field) {
            $parts[] = $field . '(' . $this->database[$key][$field][0] . ')';
        }
        return implode(', ', $parts);
    }

    public function backup(int $timestamp): string
    {
        $state = [];
        foreach ($this->database as $key => $fields) {
            foreach ($fields as $field => $pair) {
                if ($this->isAlive($key, $field, $timestamp)) {
                    [$value, $expiry] = $pair;
                    $remaining = $expiry === null ? null : $expiry - $timestamp;
                    if (!array_key_exists($key, $state)) {
                        $state[$key] = [];
                    }
                    $state[$key][$field] = [$value, $remaining];
                }
            }
        }
        $this->backupTimestamps[] = $timestamp;
        $this->backupStates[] = $state;
        return (string) count($state);
    }

    public function restore(int $timestamp, int $timestampToRestore): string
    {
        $idx = -1;
        foreach ($this->backupTimestamps as $i => $ts) {
            if ($ts <= $timestampToRestore) {
                $idx = $i;
            }
        }
        $backup = $this->backupStates[$idx];
        $this->database = [];
        foreach ($backup as $key => $fields) {
            foreach ($fields as $field => $pair) {
                [$value, $remaining] = $pair;
                $expiry = $remaining === null ? null : $timestamp + $remaining;
                $this->setInternal($key, $field, $value, $expiry);
            }
        }
        return '';
    }
}
