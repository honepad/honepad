<?php

class StoredFile
{
    public string $name;
    public int $size;
    public string $owner;

    public function __construct(string $name, int $size, string $owner)
    {
        $this->name = $name;
        $this->size = $size;
        $this->owner = $owner;
    }
}

class Simulation
{
    private array $files = [];
    private array $capacity = ['admin' => null];
    private array $backups = [];

    private function used(string $userId): int
    {
        $sum = 0;
        foreach ($this->files as $item) {
            if ($item->owner === $userId) {
                $sum += $item->size;
            }
        }
        return $sum;
    }

    private function remaining(string $userId): ?int
    {
        if (!array_key_exists($userId, $this->capacity)) {
            return null;
        }
        $cap = $this->capacity[$userId];
        if ($cap === null) {
            return null;
        }
        return $cap - $this->used($userId);
    }

    public function addFile(string $name, int $size): string
    {
        if (array_key_exists($name, $this->files)) {
            return 'false';
        }
        $this->files[$name] = new StoredFile($name, $size, 'admin');
        return 'true';
    }

    public function getFileSize(string $name): string
    {
        return array_key_exists($name, $this->files) ? (string) $this->files[$name]->size : '';
    }

    public function deleteFile(string $name): string
    {
        if (!array_key_exists($name, $this->files)) {
            return '';
        }
        $size = $this->files[$name]->size;
        unset($this->files[$name]);
        return (string) $size;
    }

    public function copyFile(string $source, string $dest): string
    {
        if (!array_key_exists($source, $this->files)) {
            return '';
        }
        $src = $this->files[$source];
        if ($source === $dest) {
            return (string) $src->size;
        }
        $destItem = array_key_exists($dest, $this->files) ? $this->files[$dest] : null;
        $owner = $destItem === null ? $src->owner : $destItem->owner;
        $extra = $destItem === null ? $src->size : $src->size - $destItem->size;
        $remaining = $this->remaining($owner);
        if ($remaining !== null && $extra > $remaining) {
            return '';
        }
        if ($destItem === null) {
            $this->files[$dest] = new StoredFile($dest, $src->size, $owner);
        } else {
            $destItem->size = $src->size;
        }
        return (string) $src->size;
    }

    public function getNLargest(string $prefix, int $n): string
    {
        $matched = array_values(array_filter(
            $this->files,
            fn ($item) => str_starts_with($item->name, $prefix),
        ));
        usort($matched, function (StoredFile $a, StoredFile $b): int {
            $d = $b->size <=> $a->size;
            return $d !== 0 ? $d : ($a->name <=> $b->name);
        });
        $top = array_slice($matched, 0, $n);
        return implode(', ', array_map(fn ($item) => $item->name . '(' . $item->size . ')', $top));
    }

    public function addUser(string $userId, int $capacity): string
    {
        if (array_key_exists($userId, $this->capacity)) {
            return 'false';
        }
        $this->capacity[$userId] = $capacity;
        return 'true';
    }

    public function addFileBy(string $userId, string $name, int $size): string
    {
        if (!array_key_exists($userId, $this->capacity) || array_key_exists($name, $this->files)) {
            return '';
        }
        $remaining = $this->remaining($userId);
        if ($remaining !== null && $size > $remaining) {
            return '';
        }
        $this->files[$name] = new StoredFile($name, $size, $userId);
        $left = $this->remaining($userId);
        return $left === null ? '' : (string) $left;
    }

    public function mergeUser(string $userId1, string $userId2): string
    {
        if ($userId1 === $userId2) {
            return '';
        }
        if (!array_key_exists($userId1, $this->capacity) || !array_key_exists($userId2, $this->capacity)) {
            return '';
        }
        $cap1 = $this->capacity[$userId1];
        $cap2 = $this->capacity[$userId2];
        if ($cap1 === null || $cap2 === null) {
            return '';
        }
        $this->capacity[$userId1] = $cap1 + $cap2;
        foreach ($this->files as $item) {
            if ($item->owner === $userId2) {
                $item->owner = $userId1;
            }
        }
        unset($this->capacity[$userId2]);
        unset($this->backups[$userId2]);
        $left = $this->remaining($userId1);
        return $left === null ? '' : (string) $left;
    }

    public function backupUser(string $userId): string
    {
        if (!array_key_exists($userId, $this->capacity)) {
            return '';
        }
        $snap = [];
        foreach ($this->files as $item) {
            if ($item->owner === $userId) {
                $snap[$item->name] = $item->size;
            }
        }
        $this->backups[$userId] = $snap;
        return (string) count($snap);
    }

    public function restoreUser(string $userId): string
    {
        if (!array_key_exists($userId, $this->capacity)) {
            return '';
        }
        foreach (array_keys($this->files) as $name) {
            if ($this->files[$name]->owner === $userId) {
                unset($this->files[$name]);
            }
        }
        if (!array_key_exists($userId, $this->backups)) {
            return '0';
        }
        $snap = $this->backups[$userId];
        $restored = 0;
        foreach ($snap as $name => $size) {
            if (array_key_exists($name, $this->files)) {
                continue;
            }
            $remaining = $this->remaining($userId);
            if ($remaining !== null && $size > $remaining) {
                continue;
            }
            $this->files[$name] = new StoredFile($name, $size, $userId);
            $restored += 1;
        }
        return (string) $restored;
    }
}
