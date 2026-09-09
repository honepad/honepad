# GPU scheduler level 1

`add_gpu(gpu_id, mem)` registers a device. Returns `"true"` if created.
Duplicate id is `"false"`. `mem <= 0` is `"invalid_request"`.

`submit_job(job_id, mem)` queues a job. Returns `"true"` if queued.
Duplicate id is `"false"`. `mem <= 0` is `"invalid_request"`.

`status(job_id)` is `"queued"`, `"running"`, `"done"`, or `""`.

## Example

```
add_gpu("g1", 8) -> "true"
add_gpu("g1", 8) -> "false"
add_gpu("g2", 0) -> "invalid_request"
submit_job("j1", 4) -> "true"
submit_job("j1", 4) -> "false"
submit_job("j2", 0) -> "invalid_request"
status("j1") -> "queued"
status("j9") -> ""
```
