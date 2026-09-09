# GPU scheduler level 2

`assign()` starts one queued job on the first free GPU (add order)
with `mem >= job mem`. Returns that job id, or `""`.

`complete(job_id)` marks a running job `"done"` and frees its GPU.
Returns `"true"`. Not running is `"invalid_request"`.

## Example

```
add_gpu("g1", 8) -> "true"
submit_job("j1", 4) -> "true"
assign() -> "j1"
status("j1") -> "running"
assign() -> ""
submit_job("j2", 4) -> "true"
complete("j1") -> "true"
status("j1") -> "done"
assign() -> "j2"
complete("j9") -> "invalid_request"
```
