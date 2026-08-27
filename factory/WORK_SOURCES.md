# Work sources

`next_work_source` in `STATE.json` is authoritative.

Priority (first match wins):

1. `human_gate` set: stop.
2. `ci`: red or missing main run.
3. `issues`: accepted `ready` issues.
4. `contract` / `implement`: next slice from `pr_plan_cursor`.
5. `prove`: `honepad run` on python3 then another CI language.
6. `improve`: one MPI perspective per cycle.
7. `adversary`: after a land.
8. `expand`: next language adapter / reference solution.

## PR plan cursor

- `pr-2` ICA language adapters that replay the same traces
- `pr-3` file_storage traces
- `pr-4` workers traces
- `pr-5` timer unlock of levels
- `pr-6` remaining GCA runners that Ubuntu can execute
- `pr-7` rust ICA runner for the same traces
- `pr-8` ruby ICA runner for the same traces
- `pr-9` php ICA runner for the same traces
- `pr-10` java ICA runner for the same traces
- `pr-11` typescript ICA runner for the same traces
- `pr-12` csharp ICA runner for the same traces
- `pr-13` kotlin ICA runner for the same traces
- `pr-14` cpp ICA runner for the same traces
- `pr-15` swift ICA runner for the same traces
- `pr-16` prove python3+go on all problems
- `pr-17` auto-approve on ready_for_review
- `pr-18` first MPI pass on the runner
- `pr-19` next MPI (QA: stub fails for every script lang)
- `pr-20` next MPI (timer remaining_s after mocked clock)
- `pr-21` next MPI (unlock does not skip a level)
- `pr-22` next MPI (start --reset clears unlock)
- `pr-23` next MPI (start different problem replaces session)
- `pr-24` next MPI (start same problem keeps unlock)
- `pr-25` next MPI (expired timer remaining_s is 0)
- `pr-26` next MPI (CLI run --kind stub does not unlock)
- `pr-27` next MPI (start --level 1 after unlock still prints L1 spec)
- `pr-28` next MPI (start without --level after unlock prints current spec)
- `pr-29` next MPI (explicit --level 4 run still works with a session)
- `pr-30` next MPI (run without session defaults to python3 level 4)
- `pr-31` share temp-dir compile for go rust java csharp kotlin cpp swift
- `pr-32` next MPI (QA: go stub fails bank traces)
- `pr-33` next MPI (QA: rust stub fails bank traces)
- `pr-34` next MPI (QA: java stub fails bank traces)
- `pr-35` next MPI (QA: csharp stub fails bank traces)
- `pr-36` next MPI (QA: kotlin stub fails bank traces)
- `pr-37` next MPI (QA: cpp stub fails bank traces)
- `pr-38` next MPI (QA: swift stub fails bank traces)
- `pr-39` next MPI (first remaining GCA language Ubuntu can run: perl)
- `pr-40` lua GCA runner for the same traces
- `pr-41` switch factory source to improve after perl and lua
- `pr-42` first improve MPI (Developer: runner dispatch table)
- `pr-43` next improve MPI (QA: unknown lang error mentions adapter)
- `pr-44` next improve MPI (Maintainer: next-job.sh after improve still prints one job)
- `pr-45` next improve MPI (adversary: honepad run unknown lang exits 2 or 1 via CLI if applicable; else skip to expand)
- `pr-46` next improve MPI (End User: honepad start with an unimplemented catalog lang prints FAIL and exits 1)
- `pr-47` next improve MPI (Architecture: honepad langs marks catalog ids that have no runner)
- `pr-48` next improve MPI (expand: next catalog language Ubuntu CI can run that still has no runner)
- `pr-49` next improve MPI (expand: next cheap GCA language Ubuntu can run after C: tcl)
- `pr-50` next improve MPI (expand: next cheap GCA language after tcl: r)
- `pr-51` next improve MPI (expand: next cheap GCA language after r: octave)
- `pr-52` next improve MPI (expand: next cheap GCA language after octave: nim)
- `pr-53` next improve MPI (expand: next cheap GCA language after nim: groovy)
- `pr-54` next improve MPI (expand: next cheap GCA language after groovy: dart)
- `pr-55` next improve MPI (expand: next cheap GCA language after dart: elixir)
- `pr-56` next improve MPI (expand: next cheap GCA language after elixir: erlang)
- `pr-57` next improve MPI (expand: next cheap GCA language after erlang: haskell)
- `pr-58` next improve MPI (expand: next cheap GCA language after haskell: ocaml)
- `pr-59` next improve MPI (expand: next cheap GCA language after ocaml: scala)
- `pr-60` next improve MPI (expand: next cheap GCA language after scala: d)
- `pr-61` next improve MPI (expand: next cheap GCA language after d: julia)
- `pr-62` next improve MPI (expand: next cheap GCA language after julia: coffeescript)
- `pr-63` next improve MPI (expand: next cheap GCA language after coffeescript: bash)
- `pr-64` next improve MPI (expand: next cheap GCA language after bash: common-lisp)
- `pr-65` next improve MPI (expand: next cheap GCA language after common-lisp: fortran)
- `pr-66` next improve MPI (expand: next cheap GCA language after fortran: fsharp)
- `pr-67` next improve MPI (expand: next cheap GCA language after fsharp: smalltalk)
- `pr-68` next improve MPI (expand: next cheap GCA language after smalltalk: freepascal)
- `pr-69` next improve MPI (Maintainer: CI Test apt/deb install is too long; split or cache)
- `pr-70` next improve MPI (expand: next remaining catalog lang Ubuntu can run, or skip to expand_cursor if none cheap)
- `pr-71` next improve MPI (expand: powershell extra via pwsh if cheap on Ubuntu, else skip frontend/sql)
- `pr-72` next improve MPI (QA: shell extra should share the bash runner or get its own wrapper)
- `pr-73` next improve MPI (QA: unknown-lang CLI tests still use an unimplemented id after the latest expand)
- `pr-74` next improve MPI (expand: skip frontend/sql/objc/vb unless cheap; next is QA on langs column vs _RUNNERS)
- `pr-75` next improve MPI (Developer: _RUNNERS keys vs langs/*/meta.json adapter=stub rows)
- `pr-76` next improve MPI (Maintainer: Test job wall clock; drop unused prove lines or cache apt)
- `pr-77` next improve MPI (QA: honepad langs --help or start --help mentions FAIL for unimplemented langs)
- `pr-78` next improve MPI (End User: honepad langs header line includes runner count)
- `pr-79` next improve MPI (Observability: FAIL start/run includes adapter= for unimplemented catalog langs)

`--concurrency 1`. One ready PR.
