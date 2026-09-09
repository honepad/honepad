<?php

class Gpu
{
    public string $gpuId;
    public int $mem;
    public ?string $jobId = null;

    public function __construct(string $gpuId, int $mem)
    {
        $this->gpuId = $gpuId;
        $this->mem = $mem;
    }
}

class Job
{
    public string $jobId;
    public int $mem;
    public int $seq;
    public int $priority = 0;
    public string $state = 'queued';
    public ?string $gpuId = null;

    public function __construct(string $jobId, int $mem, int $seq)
    {
        $this->jobId = $jobId;
        $this->mem = $mem;
        $this->seq = $seq;
    }
}

class Simulation
{
    /** @var array<string, Gpu> */
    private array $gpus = [];
    /** @var list<string> */
    private array $gpuOrder = [];
    /** @var array<string, Job> */
    private array $jobs = [];
    private int $nextSeq = 0;

    public function addGpu(string $gpuId, int $mem): string
    {
        if ($mem <= 0) {
            return 'invalid_request';
        }
        if (array_key_exists($gpuId, $this->gpus)) {
            return 'false';
        }
        $this->gpus[$gpuId] = new Gpu($gpuId, $mem);
        $this->gpuOrder[] = $gpuId;
        return 'true';
    }

    public function submitJob(string $jobId, int $mem): string
    {
        if ($mem <= 0) {
            return 'invalid_request';
        }
        if (array_key_exists($jobId, $this->jobs)) {
            return 'false';
        }
        $this->jobs[$jobId] = new Job($jobId, $mem, $this->nextSeq);
        $this->nextSeq += 1;
        return 'true';
    }

    public function status(string $jobId): string
    {
        $job = $this->jobs[$jobId] ?? null;
        return $job === null ? '' : $job->state;
    }

    public function assign(): string
    {
        $queued = array_values(array_filter(
            $this->jobs,
            static fn (Job $job): bool => $job->state === 'queued'
        ));
        usort($queued, static function (Job $a, Job $b): int {
            return [-$a->priority, $a->seq] <=> [-$b->priority, $b->seq];
        });
        foreach ($queued as $job) {
            foreach ($this->gpuOrder as $gpuId) {
                $gpu = $this->gpus[$gpuId];
                if ($gpu->jobId === null && $gpu->mem >= $job->mem) {
                    $this->place($job, $gpu);
                    return $job->jobId;
                }
            }
        }
        return '';
    }

    public function complete(string $jobId): string
    {
        $job = $this->jobs[$jobId] ?? null;
        if ($job === null || $job->state !== 'running' || $job->gpuId === null) {
            return 'invalid_request';
        }
        $this->gpus[$job->gpuId]->jobId = null;
        $job->gpuId = null;
        $job->state = 'done';
        return 'true';
    }

    public function cancel(string $jobId): string
    {
        $job = $this->jobs[$jobId] ?? null;
        if ($job === null || $job->state === 'done') {
            return 'invalid_request';
        }
        if ($job->state === 'running' && $job->gpuId !== null) {
            $this->gpus[$job->gpuId]->jobId = null;
        }
        unset($this->jobs[$jobId]);
        if ($job->state === 'running') {
            $this->assign();
        }
        return 'true';
    }

    public function setPriority(string $jobId, int $priority): string
    {
        $job = $this->jobs[$jobId] ?? null;
        if ($job === null || $job->state !== 'queued') {
            return 'invalid_request';
        }
        $job->priority = $priority;
        return 'true';
    }

    private function place(Job $job, Gpu $gpu): void
    {
        $job->state = 'running';
        $job->gpuId = $gpu->gpuId;
        $gpu->jobId = $job->jobId;
    }
}
