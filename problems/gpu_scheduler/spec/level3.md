# GPU scheduler level 3

`cancel(job_id)` removes a queued or running job. Returns `"true"`.
A running cancel frees the GPU and then `assign()`s the next job.
Missing or already done is `"invalid_request"`. Cancelled status is
`""`.

## Example

```
add_gpu("g1", 8) -> "true"
submit_job("j1", 4) -> "true"
submit_job("j2", 4) -> "true"
assign() -> "j1"
cancel("j1") -> "true"
status("j1") -> ""
status("j2") -> "running"
cancel("j9") -> "invalid_request"
cancel("j2") -> "true"
```
