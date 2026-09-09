<?php

class Item
{
    public string $sku;
    public string $name;
    public int $qty = 0;
    public int $reserved = 0;

    public function __construct(string $sku, string $name)
    {
        $this->sku = $sku;
        $this->name = $name;
    }
}

class Simulation
{
    private array $items = [];

    public function createItem(string $sku, string $name): string
    {
        if (array_key_exists($sku, $this->items)) {
            return 'false';
        }
        $this->items[$sku] = new Item($sku, $name);
        return 'true';
    }

    public function stock(string $sku, int $delta): string
    {
        if (!array_key_exists($sku, $this->items)) {
            return '';
        }
        $item = $this->items[$sku];
        $nxt = $item->qty + $delta;
        if ($nxt < $item->reserved) {
            return 'invalid_request';
        }
        $item->qty = $nxt;
        return (string) $item->qty;
    }

    public function getQty(string $sku): string
    {
        if (!array_key_exists($sku, $this->items)) {
            return '';
        }
        return (string) $this->items[$sku]->qty;
    }

    public function listLow(int $threshold): string
    {
        $matched = array_values(array_filter(
            $this->items,
            fn ($item) => $item->qty <= $threshold,
        ));
        usort($matched, function (Item $a, Item $b): int {
            $d = $a->qty <=> $b->qty;
            return $d !== 0 ? $d : ($a->sku <=> $b->sku);
        });
        return implode(
            ', ',
            array_map(fn ($item) => $item->sku . '(' . $item->qty . ')', $matched),
        );
    }

    public function reserve(string $sku, int $n): string
    {
        if (!array_key_exists($sku, $this->items)) {
            return 'invalid_request';
        }
        $item = $this->items[$sku];
        if ($n <= 0 || $item->reserved + $n > $item->qty) {
            return 'invalid_request';
        }
        $item->reserved += $n;
        return 'true';
    }

    public function release(string $sku, int $n): string
    {
        if (!array_key_exists($sku, $this->items)) {
            return 'invalid_request';
        }
        $item = $this->items[$sku];
        if ($n <= 0 || $n > $item->reserved) {
            return 'invalid_request';
        }
        $item->reserved -= $n;
        return 'true';
    }

    public function ship(string $sku, int $n): string
    {
        if (!array_key_exists($sku, $this->items)) {
            return 'invalid_request';
        }
        $item = $this->items[$sku];
        if ($n <= 0 || $n > $item->reserved) {
            return 'invalid_request';
        }
        $item->reserved -= $n;
        $item->qty -= $n;
        return 'true';
    }
}
