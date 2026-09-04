# Adding a language

A language pack is a directory. Nothing in `src/honepad/` changes.

```
langs/<id>/
  meta.json                     identity + the run recipe
  adapter.<ext>                 replays traces against the candidate class
  problems/<problem>/solution.* reference solution (must pass every trace)
  problems/<problem>/stub.*     what the candidate starts from
```

`langs/catalog.json` is the language list (constitution rule 7). `meta.json`
mirrors the catalog row and adds `run`, which is the whole toolchain contract:
`honepad.runner` executes it, so a pack with a valid `run` block is runnable and
one without it is a factory job.

## The run recipe

Two kinds cover every pack. `hook` is a third, used only by Python 3, which
imports the pack in a child interpreter instead of shelling out.

### `script` — an interpreter runs the adapter

```json
"run": {
  "kind": "script",
  "solution": "solution.rb",
  "stub": "stub.rb",
  "tool": ["ruby"],
  "argv": ["{{tool}}", "{{pack}}/adapter.rb", "{{src}}", "{{class}}"],
  "requires": ["ruby"]
}
```

The traces file is appended to `argv`, so the adapter is called as
`ruby adapter.rb <src> <class> <cases.json>`.

### `compiled` — build in a temp dir, then run what was built

```json
"run": {
  "kind": "compiled",
  "solution": "solution.hs",
  "stub": "stub.hs",
  "copy": {"Adapter.hs": "{{pack}}/Adapter.hs"},
  "src_as": "Solution.hs",
  "write": {"ctor.hs": "-- generated, may use {{class}}\n"},
  "steps": [
    {
      "tool": ["ghc"],
      "tool_error": "ghc not found",
      "argv": ["{{tool}}", "-O0", "-w", "-o", "run", "Adapter.hs"],
      "fail": "ghc compile failed"
    }
  ],
  "argv": ["{{tmp}}/run", "{{cases}}"],
  "requires": ["ghc"]
}
```

`copy` maps destination to source, `src_as` names where the candidate source
lands, `write` generates files from a template, `steps` build, and `argv` runs
the artifact. Here `argv` names `{{cases}}` itself, because its position differs
per toolchain. Never `go run` / `cargo run` / `dotnet run`: those rebuild on
every replay, and a test guards against them.

## Tokens

Substituted in `argv` entries and in `write` bodies.

| token | is |
| --- | --- |
| `{{class}}` | class the problem expects (`Simulation`, `InMemoryDatabase`) |
| `{{src}}` | absolute path of the candidate source |
| `{{src_name}}` | that source's file name |
| `{{cases}}` | absolute path of the traces file (`compiled` only) |
| `{{tmp}}` | build directory (`compiled` only) |
| `{{pack}}` | `langs/<id>` |
| `{{langs}}` | `langs`, for packs that borrow another pack's adapter |
| `{{pathsep}}` | `os.pathsep` |
| `{{tool}}` | the resolved tool, expanded in place as one or more words |

`{{tool}}` is only meaningful as a whole entry; it expands to however many words
the resolved tool needs, which is how CoffeeScript falls back to `npx`.

## Tools

`tool` is a candidate list, first hit on PATH wins. An entry may itself be a
list when the tool takes fixed leading arguments:

```json
"tool": [["coffee"], ["npx", "--yes", "-p", "coffeescript@2.7.0", "coffee"]]
```

A single bare candidate with no `tool_error` is passed straight through, so a
missing binary surfaces as the runner's `<lang>: <bin> not on PATH`. Anything
with alternatives or its own `tool_error` is looked up before the run, because
the recipe has to know which candidate won.

`argv_by_tool` lets a step vary by which candidate won, matched on the front of
the binary's name with `*` as the fallback -- `gdc` spells its output flag
differently from `dmd`.

Two toolchains cannot be found by name and use a `tool_hook` registered in
`honepad/runner.py`: `scalac`/`scala` (installed through Coursier, whose bin
directory is not always on PATH) and `clojure` (the CLI needs `-M`, the older
launcher and the bare jar do not). `env_hook` is the same escape hatch for
environment setup; only `dotnet` needs it.

## requires

`requires` is what `honepad start` checks before the clock starts, and what
`honepad langs --check` probes. Each entry is a group of interchangeable names;
a group is satisfied when any member is on PATH:

```json
"requires": [["cc", "gcc", "clang"], "gfortran"]
```

Leave out tools a hook installs on demand (Scala) or that are the host itself
(Python 3).

A missing toolchain only warns: a work file and a spec are useful before the
compiler is, and `run` fails clearly enough on its own. A pack that would rather
not start at all sets `"on_missing_tools": "block"`. Only Java does, because a
missing JDK used to surface as a confusing `javac` error.

## Done means green

Traces in `problems/*/cases/` are the contract (constitution rule 5). A pack is
done when `run(problem, lang, level, "solution")` passes every trace for every
problem and the stub fails. Add both to `tests/test_traces.py` next to the
existing per-language pairs, then `make check`.
