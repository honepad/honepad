# GPU scheduler level 4

`set_priority(job_id, priority)` sets a queued job's rank. Returns
`"true"`. Missing or not queued is `"invalid_request"`. Default
priority is 0. `assign` picks the highest priority job that fits a
free GPU, then the earlier submit.

## Example

```
add_gpu("g1", 4) -> "true"
add_gpu("g2", 16) -> "true"
submit_job("j1", 4) -> "true"
submit_job("j2", 4) -> "true"
submit_job("big", 16) -> "true"
set_priority("j2", 10) -> "true"
set_priority("big", 5) -> "true"
set_priority("j9", 1) -> "invalid_request"
assign() -> "j2"
assign() -> "big"
complete("j2") -> "true"
assign() -> "j1"
add_gpu("tiny", 4) -> "true"
submit_job("huge", 16) -> "true"
submit_job("fit", 4) -> "true"
set_priority("huge", 10) -> "true"
assign() -> "fit"
```
