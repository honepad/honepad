<?php

class Simulation
{
    private array $subs = [];
    private array $inboxMap = [];
    private array $retained = [];

    public function subscribe(string $topic, string $client): string
    {
        if (!array_key_exists($topic, $this->subs)) {
            $this->subs[$topic] = [];
        }
        if (in_array($client, $this->subs[$topic], true)) {
            return 'false';
        }
        $this->subs[$topic][] = $client;
        if (array_key_exists($topic, $this->retained)) {
            if (!array_key_exists($client, $this->inboxMap)) {
                $this->inboxMap[$client] = [];
            }
            $this->inboxMap[$client][] = $topic . ':' . $this->retained[$topic];
        }
        return 'true';
    }

    public function unsubscribe(string $topic, string $client): string
    {
        if (!array_key_exists($topic, $this->subs)) {
            return 'false';
        }
        $idx = array_search($client, $this->subs[$topic], true);
        if ($idx === false) {
            return 'false';
        }
        array_splice($this->subs[$topic], (int) $idx, 1);
        if ($this->subs[$topic] === []) {
            unset($this->subs[$topic]);
        }
        return 'true';
    }

    public function publish(string $topic, string $message): string
    {
        $clients = array_key_exists($topic, $this->subs) ? $this->subs[$topic] : [];
        $payload = $topic . ':' . $message;
        foreach ($clients as $client) {
            if (!array_key_exists($client, $this->inboxMap)) {
                $this->inboxMap[$client] = [];
            }
            $this->inboxMap[$client][] = $payload;
        }
        return (string) count($clients);
    }

    public function inbox(string $client): string
    {
        $items = array_key_exists($client, $this->inboxMap) ? $this->inboxMap[$client] : [];
        return implode(', ', $items);
    }

    public function listTopics(): string
    {
        $topics = array_keys($this->subs);
        sort($topics);
        return implode(', ', $topics);
    }

    public function subscribers(string $topic): string
    {
        $clients = array_key_exists($topic, $this->subs) ? $this->subs[$topic] : [];
        $clients = $clients;
        sort($clients);
        return implode(', ', $clients);
    }

    public function peek(string $client): string
    {
        $items = array_key_exists($client, $this->inboxMap) ? $this->inboxMap[$client] : [];
        return $items === [] ? '' : $items[0];
    }

    public function ack(string $client, int $n): string
    {
        if ($n <= 0 || !array_key_exists($client, $this->inboxMap)) {
            return 'invalid_request';
        }
        $items = &$this->inboxMap[$client];
        if ($n > count($items)) {
            return 'invalid_request';
        }
        array_splice($items, 0, $n);
        return (string) count($items);
    }

    public function retain(string $topic, string $message): string
    {
        $this->retained[$topic] = $message;
        return '';
    }
}
