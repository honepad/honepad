class Gpu {
    [string] $GpuId
    [long] $Mem
    [string] $JobId

    Gpu([string] $GpuId, [long] $Mem) {
        $this.GpuId = $GpuId
        $this.Mem = $Mem
        $this.JobId = ''
    }
}

class Job {
    [string] $JobId
    [long] $Mem
    [long] $Seq
    [long] $Priority
    [string] $State
    [string] $GpuId

    Job([string] $JobId, [long] $Mem, [long] $Seq) {
        $this.JobId = $JobId
        $this.Mem = $Mem
        $this.Seq = $Seq
        $this.Priority = 0
        $this.State = 'queued'
        $this.GpuId = ''
    }
}

class Simulation {
    [hashtable] $Gpus
    [System.Collections.Generic.List[string]] $GpuOrder
    [hashtable] $Jobs
    [long] $NextSeq

    Simulation() {
        $this.Gpus = @{}
        $this.GpuOrder = [System.Collections.Generic.List[string]]::new()
        $this.Jobs = @{}
        $this.NextSeq = 0
    }

    hidden [void] Place([Job] $Job, [Gpu] $Gpu) {
        $Job.State = 'running'
        $Job.GpuId = $Gpu.GpuId
        $Gpu.JobId = $Job.JobId
    }

    [object] addGpu([string] $GpuId, [long] $Mem) {
        if ($Mem -le 0) {
            return 'invalid_request'
        }
        if ($this.Gpus.ContainsKey($GpuId)) {
            return 'false'
        }
        $this.Gpus[$GpuId] = [Gpu]::new($GpuId, $Mem)
        $this.GpuOrder.Add($GpuId)
        return 'true'
    }

    [object] submitJob([string] $JobId, [long] $Mem) {
        if ($Mem -le 0) {
            return 'invalid_request'
        }
        if ($this.Jobs.ContainsKey($JobId)) {
            return 'false'
        }
        $this.Jobs[$JobId] = [Job]::new($JobId, $Mem, $this.NextSeq)
        $this.NextSeq += 1
        return 'true'
    }

    [object] status([string] $JobId) {
        if (-not $this.Jobs.ContainsKey($JobId)) {
            return ''
        }
        return $this.Jobs[$JobId].State
    }

    [object] assign() {
        $queued = @($this.Jobs.Values | Where-Object { $_.State -eq 'queued' })
        $queued = @($queued | Sort-Object -Property @{ Expression = { -$_.Priority } }, @{ Expression = { $_.Seq } })
        foreach ($job in $queued) {
            foreach ($gpuId in $this.GpuOrder) {
                $gpu = $this.Gpus[$gpuId]
                if ([string]::IsNullOrEmpty($gpu.JobId) -and $gpu.Mem -ge $job.Mem) {
                    $this.Place($job, $gpu)
                    return $job.JobId
                }
            }
        }
        return ''
    }

    [object] complete([string] $JobId) {
        if (-not $this.Jobs.ContainsKey($JobId)) {
            return 'invalid_request'
        }
        $job = $this.Jobs[$JobId]
        if ($job.State -ne 'running' -or [string]::IsNullOrEmpty($job.GpuId)) {
            return 'invalid_request'
        }
        $this.Gpus[$job.GpuId].JobId = ''
        $job.GpuId = ''
        $job.State = 'done'
        return 'true'
    }

    [object] cancel([string] $JobId) {
        if (-not $this.Jobs.ContainsKey($JobId)) {
            return 'invalid_request'
        }
        $job = $this.Jobs[$JobId]
        if ($job.State -eq 'done') {
            return 'invalid_request'
        }
        if ($job.State -eq 'running' -and -not [string]::IsNullOrEmpty($job.GpuId)) {
            $this.Gpus[$job.GpuId].JobId = ''
        }
        $this.Jobs.Remove($JobId)
        if ($job.State -eq 'running') {
            $this.assign()
        }
        return 'true'
    }

    [object] setPriority([string] $JobId, [long] $Priority) {
        if (-not $this.Jobs.ContainsKey($JobId)) {
            return 'invalid_request'
        }
        $job = $this.Jobs[$JobId]
        if ($job.State -ne 'queued') {
            return 'invalid_request'
        }
        $job.Priority = $Priority
        return 'true'
    }
}
