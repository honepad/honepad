import importlib.util
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _shard_mod():
    path = ROOT / "factory" / "scripts" / "ci-pytest-shard.py"
    spec = importlib.util.spec_from_file_location("ci_pytest_shard", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_SHARD = _shard_mod()


def test_next_job_stops_on_human_gate() -> None:
    state = json.loads((ROOT / "factory" / "STATE.json").read_text())
    gate = state.get("human_gate")
    assert isinstance(gate, dict)
    assert gate.get("kind")
    result = subprocess.run(
        ["bash", "factory/scripts/next-job.sh"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 2
    assert "WAIT: human_gate" in result.stdout
    assert "DONE: ok=false error=human_gate" in result.stdout
    assert "OK: picked" not in result.stdout
    job_lines = [
        line for line in result.stdout.splitlines() if line.startswith("{") and line.endswith("}")
    ]
    assert job_lines == []


def _ci_on_block(text: str) -> str:
    start = text.index("\non:")
    end = text.index("\nconcurrency:")
    return text[start:end]


def test_ci_does_not_rebuild_on_push_to_main() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    on_block = _ci_on_block(text)
    assert "pull_request:" in on_block
    assert "workflow_dispatch:" in on_block
    assert "merge_group:" in on_block
    assert "push:" not in on_block
    assert "tags:" not in on_block
    assert "name: CI" in text
    assert "needs: [stealth, lint, test]" in text


def test_dev_ruff_pin_matches_ci() -> None:
    ci = (ROOT / ".github/workflows/ci.yml").read_text()
    pyproject = (ROOT / "pyproject.toml").read_text()
    assert "ruff==0.16.5" in ci
    assert "ruff==0.16.5" in pyproject
    assert "ruff>=" not in pyproject


def test_ci_test_job_splits_apt_install() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    assert text.count("sudo apt-get update") == 1
    assert "sudo apt-get update && sudo apt-get install -y lua5.4" not in text
    wanted = {
        "lua5.4",
        "tcl",
        "r-base-core",
        "r-cran-jsonlite",
        "octave",
        "nim",
        "gdc",
        "gfortran",
        "fp-compiler",
        "ghc",
        "ocaml",
        "groovy",
        "elixir",
        "sbcl",
        "clojure",
    }
    found: set[str] = set()
    for line in text.splitlines():
        if "apt-get install -y" not in line:
            continue
        found.update(line.split("apt-get install -y", 1)[1].split())
    assert wanted <= found
    assert "Install script langs" in text
    assert "Install stats langs" in text
    assert "Install compiled langs" in text
    assert "Install GNU Smalltalk" in text
    assert "gnu-smalltalk_${ver}_amd64.deb" in text
    assert "Install PowerShell" in text
    assert "matrix.shard == 'script'" in text
    assert "matrix.shard == 'compiled'" in text
    assert "matrix.shard == 'stats'" in text
    assert "matrix.shard == 'jvm'" in text


def test_ci_test_job_keeps_short_cli_smoke() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    assert "pytest covers the matrix; these are CLI smokes" in text
    runs = [line.strip() for line in text.splitlines() if "honepad.cli run" in line]
    assert runs == [
        "run: python3 -m honepad.cli run bank_system --lang python3 --level 4",
        "run: python3 -m honepad.cli run in_memory_database --lang python3 --level 4",
        "run: python3 -m honepad.cli run file_storage --lang python3 --level 4",
        "run: python3 -m honepad.cli run workers --lang python3 --level 3",
        "run: python3 -m honepad.cli run bank_system --lang go --level 4",
        "run: python3 -m honepad.cli run bank_system --lang perl --level 4",
    ]
    assert "factory/scripts/ci-pytest-shard.py --run" in text
    assert "shard: [unit, script, compiled, jvm, stats]" in text
    assert "name: Stealth" in text
    assert "name: Lint" in text
    assert "name: Next job respects human_gate" in text
    assert 'if state.get("human_gate"):' in text
    assert "- run: bash factory/scripts/next-job.sh\n" not in text


def test_ci_pytest_shard_tokens_do_not_collide() -> None:
    assert _SHARD.langs_in("test_javascript_bank_and_db") == ["javascript"]
    assert _SHARD.langs_in("test_java_all_problems") == ["java"]
    assert _SHARD.langs_in("test_csharp_all_problems") == ["csharp"]
    assert _SHARD.langs_in("test_c_all_problems") == ["c"]
    assert _SHARD.langs_in("test_clojure_all_problems") == ["clojure"]
    assert _SHARD.langs_in("test_d_all_problems") == ["d"]
    assert _SHARD.langs_in("test_db_solution_all_levels") == []
    assert _SHARD.langs_in("test_r_all_problems") == ["r"]
    assert _SHARD.langs_in("test_report_from_proc_rejects_non_object_json") == []
    traces = "tests/test_traces.py"
    session = "tests/test_session.py"
    assert _SHARD.assign_shard(f"{traces}::test_java_all_problems") == "jvm"
    assert _SHARD.assign_shard(f"{traces}::test_javascript_bank_and_db") == "script"
    assert _SHARD.assign_shard(f"{traces}::test_c_all_problems") == "compiled"
    assert _SHARD.assign_shard(f"{traces}::test_csharp_all_problems") == "compiled"
    assert _SHARD.assign_shard(f"{traces}::test_clojure_all_problems") == "script"
    assert _SHARD.assign_shard(f"{session}::test_java_method_includes_leading_javadoc") == "unit"
    assert (
        _SHARD.assign_shard(f"{session}::test_submit_rejects_lua_exact_count_fake_json_exit")
        == "script"
    )
    assert (
        _SHARD.assign_shard(f"{session}::test_submit_rejects_tcl_exact_count_fake_json_exit")
        == "script"
    )
    assert (
        _SHARD.assign_shard(f"{session}::test_submit_rejects_r_exact_count_fake_json_exit")
        == "stats"
    )
    assert (
        _SHARD.assign_shard(f"{session}::test_submit_rejects_octave_exact_count_fake_json_exit")
        == "stats"
    )
    assert (
        _SHARD.assign_shard(f"{session}::test_work_compile_error_prints_c_work_path") == "compiled"
    )
    assert _SHARD.assign_shard("tests/test_console.py::test_java_junit_project_compiles") == "unit"


def test_ci_pytest_shard_covers_collected_tests() -> None:
    buckets = _SHARD.check_partition(_SHARD.collect_nodeids())
    assert tuple(buckets) == _SHARD.SHARDS
    for name, rows in buckets.items():
        assert rows, name
        assert all(_SHARD.assign_shard(nodeid) == name for nodeid in rows)


def test_ensure_scala_script_is_executable() -> None:
    path = ROOT / "factory" / "scripts" / "ensure-scala.sh"
    assert path.is_file()
    assert os.access(path, os.X_OK)


def test_makefile_check_accepts_parked_human_gate() -> None:
    text = (ROOT / "Makefile").read_text()
    assert "factory/scripts/write-ledger.sh --self-test" in text
    assert "factory/scripts/ensure-scala.sh" in text
    assert "factory/scripts/next-job.sh" in text
    assert "\tbash factory/scripts/next-job.sh\n" not in text
    assert "human_gate" in text
    assert "returncode == 2" in text
    wrappers = [
        line.strip()
        for line in text.splitlines()
        if line.strip().startswith("python3 -c ") and "human_gate" in line
    ]
    assert len(wrappers) == 1
    next_job = subprocess.run(
        ["bash", "factory/scripts/next-job.sh"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert next_job.returncode == 2
    result = subprocess.run(
        wrappers[0],
        cwd=ROOT,
        shell=True,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
