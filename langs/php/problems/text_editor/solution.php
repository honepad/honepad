<?php

class Simulation
{
    private string $buf = '';
    private int $pos = 0;
    private array $undoStack = [];
    private array $redoStack = [];
    private ?array $sel = null;
    private string $clip = '';

    private function push(): void
    {
        $this->undoStack[] = [$this->buf, $this->pos];
        $this->redoStack = [];
        $this->sel = null;
    }

    public function insert(int $pos, string $text): string
    {
        if ($pos < 0 || $pos > strlen($this->buf)) {
            return 'invalid_request';
        }
        $this->push();
        $this->buf = substr($this->buf, 0, $pos) . $text . substr($this->buf, $pos);
        return (string) strlen($this->buf);
    }

    public function erase(int $pos, int $n): string
    {
        if ($n <= 0 || $pos < 0 || $pos + $n > strlen($this->buf)) {
            return 'invalid_request';
        }
        $this->push();
        $deleted = substr($this->buf, $pos, $n);
        $this->buf = substr($this->buf, 0, $pos) . substr($this->buf, $pos + $n);
        if ($this->pos > strlen($this->buf)) {
            $this->pos = strlen($this->buf);
        }
        return $deleted;
    }

    public function getText(): string
    {
        return $this->buf;
    }

    public function length(): string
    {
        return (string) strlen($this->buf);
    }

    public function move(int $pos): string
    {
        if ($pos < 0 || $pos > strlen($this->buf)) {
            return 'invalid_request';
        }
        $this->pos = $pos;
        return 'true';
    }

    public function typeText(string $text): string
    {
        $this->push();
        $at = $this->pos;
        $this->buf = substr($this->buf, 0, $at) . $text . substr($this->buf, $at);
        $this->pos = $at + strlen($text);
        return (string) strlen($this->buf);
    }

    public function cursor(): string
    {
        return (string) $this->pos;
    }

    public function undo(): string
    {
        if ($this->undoStack === []) {
            return 'false';
        }
        $this->redoStack[] = [$this->buf, $this->pos];
        [$this->buf, $this->pos] = array_pop($this->undoStack);
        $this->sel = null;
        return 'true';
    }

    public function redo(): string
    {
        if ($this->redoStack === []) {
            return 'false';
        }
        $this->undoStack[] = [$this->buf, $this->pos];
        [$this->buf, $this->pos] = array_pop($this->redoStack);
        $this->sel = null;
        return 'true';
    }

    public function select(int $start, int $end): string
    {
        if ($start < 0 || $end < 0 || $start > $end || $end > strlen($this->buf)) {
            return 'invalid_request';
        }
        $this->sel = [$start, $end];
        return 'true';
    }

    public function cut(): string
    {
        if ($this->sel === null || $this->sel[0] === $this->sel[1]) {
            return 'invalid_request';
        }
        [$start, $end] = $this->sel;
        $text = substr($this->buf, $start, $end - $start);
        $this->buf = substr($this->buf, 0, $start) . substr($this->buf, $end);
        $this->clip = $text;
        $this->pos = $start;
        $this->sel = null;
        return $text;
    }

    public function copySel(): string
    {
        if ($this->sel === null || $this->sel[0] === $this->sel[1]) {
            return 'invalid_request';
        }
        [$start, $end] = $this->sel;
        $this->clip = substr($this->buf, $start, $end - $start);
        return $this->clip;
    }

    public function paste(): string
    {
        if ($this->clip === '') {
            return 'invalid_request';
        }
        $at = $this->pos;
        $this->buf = substr($this->buf, 0, $at) . $this->clip . substr($this->buf, $at);
        $this->pos = $at + strlen($this->clip);
        return (string) strlen($this->buf);
    }
}
