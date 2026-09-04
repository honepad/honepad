"""The pack recipe schema: loading, tokens, tool resolution, layout."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from honepad import packspec
from honepad.catalog import languages
from honepad.runner import _RUNNERS


def _meta(tmp_path: Path, lang_id: str, run: dict | None) -> None:
    pack = tmp_path / "langs" / lang_id
    pack.mkdir(parents=True)
    body: dict = {"id": lang_id, "name": lang_id, "ext": "x", "naming": "snake"}
    if run is not None:
        body["run"] = run
    (pack / "meta.json").write_text(json.dumps(body), encoding="utf-8")


@pytest.fixture
def fake_root(tmp_path: Path, monkeypatch) -> Path:
    monkeypatch.setattr("honepad.packspec.repo_root", lambda: tmp_path)
    return tmp_path


def test_pack_without_a_run_block_has_no_recipe(fake_root: Path) -> None:
    _meta(fake_root, "zz", None)
    assert packspec.run_spec("zz") is None


def test_run_spec_rejects_an_unknown_kind(fake_root: Path) -> None:
    _meta(fake_root, "zz", {"kind": "magic", "solution": "s", "stub": "t", "argv": ["x"]})
    with pytest.raises(ValueError, match="run.kind"):
        packspec.run_spec("zz")


def test_run_spec_requires_solution_and_stub(fake_root: Path) -> None:
    _meta(fake_root, "zz", {"kind": "script", "solution": "s", "argv": ["x"]})
    with pytest.raises(ValueError, match="run.stub is required"):
        packspec.run_spec("zz")


def test_run_spec_requires_a_non_empty_argv(fake_root: Path) -> None:
    _meta(fake_root, "zz", {"kind": "script", "solution": "s", "stub": "t", "argv": []})
    with pytest.raises(ValueError, match="run.argv"):
        packspec.run_spec("zz")


def test_hook_kind_needs_a_hook_and_no_argv(fake_root: Path) -> None:
    _meta(fake_root, "zz", {"kind": "hook", "solution": "s", "stub": "t"})
    with pytest.raises(ValueError, match="run.hook"):
        packspec.run_spec("zz")
    _meta(fake_root, "yy", {"kind": "hook", "hook": "python", "solution": "s", "stub": "t"})
    spec = packspec.run_spec("yy")
    assert spec is not None
    assert spec["hook"] == "python"


def test_load_meta_reports_the_offending_file(fake_root: Path) -> None:
    pack = fake_root / "langs" / "zz"
    pack.mkdir(parents=True)
    (pack / "meta.json").write_text("{not json", encoding="utf-8")
    with pytest.raises(ValueError, match="meta.json"):
        packspec.load_meta("zz")


def test_load_meta_picks_up_an_edited_pack(fake_root: Path) -> None:
    _meta(fake_root, "zz", {"kind": "script", "solution": "a", "stub": "t", "argv": ["x"]})
    assert packspec.load_meta("zz")["run"]["solution"] == "a"
    path = fake_root / "langs" / "zz" / "meta.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    body["run"]["solution"] = "b"
    path.write_text(json.dumps(body), encoding="utf-8")
    assert packspec.load_meta("zz")["run"]["solution"] == "b"


def test_substitute_leaves_single_braces_alone() -> None:
    ctx = {"class": "Simulation"}
    body = "func NewTarget() any { return New{{class}}() }"
    assert packspec.substitute(body, ctx) == "func NewTarget() any { return NewSimulation() }"


def test_context_covers_every_token_the_docs_promise() -> None:
    ctx = packspec.context("go", class_name="Simulation", src=Path("/w/work.go"))
    assert ctx["class"] == "Simulation"
    assert ctx["src"] == "/w/work.go"
    assert ctx["src_name"] == "work.go"
    assert ctx["pack"].endswith("langs/go")
    assert ctx["langs"].endswith("langs")
    assert ctx["cases"] == ""
    assert ctx["tmp"] == ""


def test_render_argv_expands_a_multi_word_tool() -> None:
    ctx = packspec.context("x", class_name="Simulation", src=Path("/w/s.coffee"))
    argv = packspec.render_argv(["{{tool}}", "{{src}}", "{{class}}"], ctx, ["npx", "-p", "coffee"])
    assert argv == ["npx", "-p", "coffee", "/w/s.coffee", "Simulation"]


def test_resolve_tool_passes_a_lone_candidate_through() -> None:
    assert packspec.resolve_tool({"tool": ["no-such-honepad-bin"]}, "zz") == ["no-such-honepad-bin"]


def test_resolve_tool_probes_when_there_are_alternatives() -> None:
    spec = {"tool": ["no-such-honepad-bin", "no-such-honepad-bin-2"]}
    with pytest.raises(RuntimeError, match="no-such-honepad-bin not found"):
        packspec.resolve_tool(spec, "zz")


def test_resolve_tool_uses_the_packs_own_error_text() -> None:
    spec = {"tool": ["no-such-honepad-bin"], "tool_error": "a D compiler is required"}
    with pytest.raises(RuntimeError, match="a D compiler is required"):
        packspec.resolve_tool(spec, "zz")


def test_resolve_tool_keeps_a_candidates_fixed_arguments(monkeypatch) -> None:
    monkeypatch.setattr(
        "honepad.packspec.shutil.which",
        lambda name: "/bin/npx" if name == "npx" else None,
    )
    spec = {"tool": [["coffee"], ["npx", "--yes", "coffee"]], "tool_error": "coffee not found"}
    assert packspec.resolve_tool(spec, "zz") == ["/bin/npx", "--yes", "coffee"]


def test_resolve_tool_rejects_an_unknown_hook() -> None:
    with pytest.raises(ValueError, match="unknown tool_hook"):
        packspec.resolve_tool({"tool_hook": "nope"}, "zz")


def test_resolve_tool_is_empty_when_the_recipe_names_none() -> None:
    assert packspec.resolve_tool({}, "zz") == []


def test_step_argv_picks_the_variant_for_the_resolved_tool() -> None:
    step = {
        "argv_by_tool": {
            "gdc": ["{{tool}}", "-o", "run"],
            "*": ["{{tool}}", "-of=run"],
        }
    }
    ctx = packspec.context("d", class_name="Simulation", src=Path("/w/s.d"))
    assert packspec.step_argv(step, ctx, ["/usr/bin/gdc-13"]) == ["/usr/bin/gdc-13", "-o", "run"]
    assert packspec.step_argv(step, ctx, ["/usr/bin/dmd"]) == ["/usr/bin/dmd", "-of=run"]


def test_step_argv_needs_a_fallback_when_nothing_matches() -> None:
    step = {"argv_by_tool": {"gdc": ["{{tool}}"]}}
    ctx = packspec.context("d", class_name="Simulation", src=Path("/w/s.d"))
    with pytest.raises(ValueError, match="no match"):
        packspec.step_argv(step, ctx, ["/usr/bin/dmd"])


def test_lay_out_copies_writes_and_places_the_source(tmp_path: Path) -> None:
    pack = tmp_path / "pack"
    pack.mkdir()
    (pack / "adapter.go").write_text("adapter\n", encoding="utf-8")
    src = tmp_path / "stub.go"
    src.write_text("stub\n", encoding="utf-8")
    build = tmp_path / "build"
    build.mkdir()
    ctx = {"class": "Simulation", "src_name": src.name, "pack": str(pack)}
    spec = {
        "copy": {"nested/adapter.go": "{{pack}}/adapter.go"},
        "src_as": "{{src_name}}",
        "write": {"ctor.go": "func New() any { return New{{class}}() }\n"},
    }
    packspec.lay_out(spec, build, src, ctx)
    assert (build / "nested" / "adapter.go").read_text(encoding="utf-8") == "adapter\n"
    assert (build / "stub.go").read_text(encoding="utf-8") == "stub\n"
    assert "NewSimulation()" in (build / "ctor.go").read_text(encoding="utf-8")


def test_lay_out_defaults_to_the_sources_own_name(tmp_path: Path) -> None:
    src = tmp_path / "solution.rs"
    src.write_text("x\n", encoding="utf-8")
    build = tmp_path / "b"
    build.mkdir()
    packspec.lay_out({}, build, src, {"src_name": src.name})
    assert (build / "solution.rs").is_file()


def test_required_tools_groups_interchangeable_names() -> None:
    assert packspec.required_tools("c") == [["cc", "gcc", "clang"]]
    assert packspec.required_tools("java") == [["javac"], ["java"]]
    assert packspec.required_tools("python3") == []


def test_missing_tools_reports_the_group_head(monkeypatch) -> None:
    monkeypatch.setattr("honepad.packspec.shutil.which", lambda _name: None)
    assert packspec.missing_tools("c") == ["cc"]
    assert packspec.missing_tools("java") == ["javac", "java"]


def test_missing_tools_is_satisfied_by_any_group_member(monkeypatch) -> None:
    monkeypatch.setattr(
        "honepad.packspec.shutil.which",
        lambda name: "/bin/clang" if name == "clang" else None,
    )
    assert packspec.missing_tools("c") == []


def test_runnable_ids_are_the_runner_table() -> None:
    assert packspec.runnable_ids() == list(_RUNNERS)


def test_runnable_ids_follow_catalog_order() -> None:
    order = [row["id"] for row in languages()]
    ids = packspec.runnable_ids()
    assert ids == [lang_id for lang_id in order if lang_id in set(ids)]


def test_every_runnable_pack_declares_its_toolchain() -> None:
    # A pack the host cannot build is worth saying so before the clock starts.
    hosted = {"python3"}
    for lang_id in packspec.runnable_ids():
        if lang_id in hosted:
            continue
        assert packspec.required_tools(lang_id), lang_id
