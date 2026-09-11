import importlib.util
import inspect
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

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
    assert "needs: [stealth, lint, test, compat]" in text


def test_ci_compat_covers_linux_macos_windows_and_wsl() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    assert "name: Compat (${{ matrix.label }})" in text
    assert "ubuntu-latest" in text
    assert "macos-latest" in text
    assert "windows-2022" in text
    assert "Ubuntu-24.04" in text
    assert "label: wsl" in text
    assert "Vampire/setup-wsl@" in text
    assert "tests/test_os_compat.py" in text


def test_dev_ruff_pin_matches_ci() -> None:
    lint = (ROOT / "requirements-lint.txt").read_text()
    dev = (ROOT / "requirements-dev.txt").read_text()
    ci = (ROOT / ".github/workflows/ci.yml").read_text()
    pyproject = (ROOT / "pyproject.toml").read_text()
    match = re.search(r"ruff==([0-9]+\.[0-9]+\.[0-9]+)", pyproject)
    assert match is not None
    pin = f"ruff=={match.group(1)}"
    assert pin in lint
    assert pin in dev
    assert "--require-hashes" in ci
    assert "ruff>=" not in pyproject


def test_homebrew_and_scoop_wait_for_release_assets() -> None:
    brew = (ROOT / ".github/workflows/publish-homebrew.yml").read_text()
    scoop = (ROOT / ".github/workflows/publish-scoop.yml").read_text()
    assert "scripts/wait_for_release_asset.py" in brew
    assert "scripts/wait_for_release_asset.py" in scoop
    assert "honepad-${{ steps.ver.outputs.version }}.tar.gz" in brew
    assert "honepad-${{ steps.ver.outputs.version }}-py3-none-any.whl" in scoop
    assert "timeout-minutes: 15" in brew
    assert "timeout-minutes: 15" in scoop


def test_publish_uploads_only_from_a_version_tag() -> None:
    text = (ROOT / ".github/workflows/publish-pypi.yml").read_text()
    assert "github.event_name == 'workflow_call'" in text
    assert "startsWith(github.ref, 'refs/tags/')" in text
    assert "gh-action-pypi-publish" in text
    assert "attest-build-provenance" in text
    assert ".intoto.jsonl" in text


def test_ci_docs_only_skips_shards() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    assert "dorny/paths-filter@" in text
    assert "needs.changes.outputs.code == 'true'" in text
    assert "!startsWith(github.head_ref, 'release-please')" in text


def test_release_please_python_package() -> None:
    cfg = (ROOT / "release-please-config.json").read_text()
    man = (ROOT / ".release-please-manifest.json").read_text()
    wf = (ROOT / ".github/workflows/release-please.yml").read_text()
    assert '"release-type": "python"' in cfg
    assert '".": "0.1.1"' in man
    assert "googleapis/release-please-action@" in wf
    assert "uses: ./.github/workflows/publish-pypi.yml" in wf


def test_readme_embeds_vhs_demo() -> None:
    readme = (ROOT / "README.md").read_text()
    assert "demo/demo.gif" in readme
    assert (ROOT / "demo/demo.gif").is_file()
    assert (ROOT / "demo/demo.tape").is_file()
    assert (ROOT / "demo/setup.sh").is_file()


def test_dependabot_auto_merge_keeps_workflow_read() -> None:
    text = (ROOT / ".github/workflows/dependabot-auto-merge.yml").read_text()
    head = text.split("jobs:", 1)[0]
    assert "contents: read" in head
    assert "contents: write" not in head


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
    assert "factory/scripts/check-human-gate.py" in text
    assert 'if state.get("human_gate"):' not in text
    assert "python3 - <<'PY'" not in text
    assert "sys.exit(0 if result.returncode == 2 else 1)" not in text
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
    assert _SHARD.assign_shard(f"{session}::test_extra_java_work_file_is_not_run") == "unit"
    console = "tests/test_console.py"
    assert _SHARD.assign_shard(f"{console}::test_java_junit_l1_stub_fails_without_npe") == "unit"
    assert _SHARD.assign_shard(f"{console}::test_java_junit_l2_project_compiles") == "unit"
    hides = f"{session}::test_start_work_hides_later_level_methods"
    assert _SHARD.assign_shard(hides) == "unit"
    for lang in ("java", "rust", "go", "javascript", "python3", "c"):
        assert _SHARD.assign_shard(f"{hides}[{lang}]") == "unit"


def test_pytest_pythonpath_collects_without_editable_pth() -> None:
    """Collect via pyproject pythonpath, not an editable .pth.

    Official gate remains pip install -e ".[dev]". This does not claim a
    no-install clone works.
    """
    text = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    assert re.search(r'(?m)^pythonpath\s*=\s*\["src"\]\s*$', text)
    src = str((ROOT / "src").resolve())
    isolator = f"""
import runpy
import sys
from pathlib import Path

src = Path({src!r}).resolve()
sys.path[:] = [p for p in sys.path if not p or Path(p).resolve() != src]
try:
    import honepad
except ImportError:
    pass
else:
    raise SystemExit("isolation failed: honepad imported from editable path")

sys.argv = [
    "pytest",
    "--collect-only",
    "-q",
    "tests/test_packaging.py",
    "tests/test_catalog.py",
]
runpy.run_module("pytest", run_name="__main__")
"""
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)
    result = subprocess.run(
        [sys.executable, "-c", isolator],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "ModuleNotFoundError" not in result.stderr
    assert "test_packaging.py" in result.stdout


def test_ci_pytest_shard_skipif_unknown_binary_fails_closed() -> None:
    source = (
        "import pytest\n"
        "from shutil import which\n"
        "\n"
        '@pytest.mark.skipif(which("rustc") is None, reason="no rustc")\n'
        "def test_needs_rustc() -> None:\n"
        "    return None\n"
    )
    found = _SHARD.skipif_which_binaries(source)
    assert found["test_needs_rustc"] == ["rustc"]
    with pytest.raises(SystemExit) as exc:
        _SHARD.check_skipif_assignment(
            "tests/test_session.py::test_needs_rustc",
            "unit",
            found["test_needs_rustc"],
        )
    assert exc.value.code == 1


def test_ci_pytest_shard_skipif_wrong_shard_fails_closed() -> None:
    and_source = (
        "import pytest\n"
        "import shutil\n"
        "\n"
        "@pytest.mark.skipif(\n"
        '    shutil.which("cc") is None and shutil.which("gcc") is None,\n'
        '    reason="cc/gcc not found",\n'
        ")\n"
        "def test_needs_cc() -> None:\n"
        "    return None\n"
    )
    parsed = _SHARD.skipif_which_binaries(and_source)
    assert parsed["test_needs_cc"] == ["cc", "gcc"]
    with pytest.raises(SystemExit) as exc:
        _SHARD.check_skipif_assignment(
            "tests/test_session.py::test_needs_cargo",
            "unit",
            ["cargo"],
        )
    assert exc.value.code == 1
    _SHARD.check_skipif_assignment(
        "tests/test_session.py::test_extra_java_work_file_is_not_run",
        "unit",
        ["javac"],
    )
    _SHARD.check_skipif_assignment(
        "tests/test_console.py::test_java_junit_project_compiles",
        "unit",
        ["mvn"],
    )


def test_ci_pytest_shard_binary_table_covers_which_calls() -> None:
    found: set[str] = set()
    for path in (ROOT / "tests").rglob("*.py"):
        found.update(re.findall(r'which\("([^"]+)"\)', path.read_text(encoding="utf-8")))
    table = _SHARD.BINARY_TO_SHARDS
    assert "mvn" not in table
    assert "rustc" not in table
    assert found - {"mvn", "rustc"} <= set(table)
    assert table["javac"] == frozenset({"unit", "script", "jvm"})
    assert table["node"] == frozenset(_SHARD.SHARDS)
    assert table["cargo"] == frozenset({"compiled"})
    assert table["gst"] == frozenset({"script"})
    assert table["Rscript"] == frozenset({"stats"})
    assert _SHARD._MVN_UNIT_ALLOW == frozenset(
        {
            "test_java_junit_l1_stub_fails_without_npe",
            "test_java_junit_project_compiles",
            "test_java_junit_l2_project_compiles",
        }
    )


def test_ci_pytest_shard_docstring_default_unit_and_skipif() -> None:
    doc = _SHARD.__doc__ or ""
    lowered = doc.lower()
    assert "default" in lowered
    assert "unit" in lowered
    assert "skipif" in lowered
    assert "1:1" in doc
    source = inspect.getsource(_SHARD.check_partition)
    assert "skipif" in source


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


def _auto_approve_workflow() -> str:
    return (ROOT / ".github/workflows/auto-approve.yml").read_text()


def test_auto_approve_skip_regex_covers_protected_paths() -> None:
    text = _auto_approve_workflow()
    assert (
        r"^(\.github/workflows/|factory/scripts/ci-pytest-shard\.py$"
        r"|factory/CONSTITUTION\.md$|factory/scripts/assert-stealth\.sh$)"
    ) in text
    assert "Skip approve/auto-merge: protected path in diff:" in text
    assert "factory/scripts/next-job.sh" not in text
    assert "factory/scripts/write-ledger.sh" not in text


def test_auto_approve_job_if_keeps_actor_and_release_app_token() -> None:
    text = _auto_approve_workflow()
    assert "github.actor == 'SebTardif'" in text
    assert "startsWith(github.head_ref, 'release-please')" in text
    assert "create-github-app-token@" in text
    assert "github-actions[bot]" in text
    assert "steps.app-token.outputs.token || secrets.GITHUB_TOKEN" in text


def test_auto_approve_ordinary_source_prs_still_approve_and_automerge() -> None:
    text = _auto_approve_workflow()
    assert "gh pr review --approve" in text
    assert "gh pr merge --auto --squash" in text


def test_auto_approve_constitution_item_8_names_workflow_and_shard() -> None:
    text = (ROOT / "factory" / "CONSTITUTION.md").read_text()
    header = text.splitlines()[2]
    assert ".github/workflows/" in header
    assert "factory/scripts/ci-pytest-shard.py" in header
    assert "factory/CONSTITUTION.md" in header or "this file" in header
    assert "factory/scripts/assert-stealth.sh" in header
    item8 = next(line for line in text.splitlines() if line.startswith("8."))
    assert "No auto-merge" in item8
    assert ".github/workflows/" in item8
    assert "factory/scripts/ci-pytest-shard.py" in item8


def _human_gate_callers() -> dict[str, str]:
    return {
        "Makefile": (ROOT / "Makefile").read_text(),
        "AGENTS.md": (ROOT / "AGENTS.md").read_text(),
        "ci.yml": (ROOT / ".github/workflows/ci.yml").read_text(),
    }


def _gate_mod():
    path = ROOT / "factory" / "scripts" / "check-human-gate.py"
    spec = importlib.util.spec_from_file_location("check_human_gate", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_makefile_check_accepts_parked_human_gate() -> None:
    text = (ROOT / "Makefile").read_text()
    assert "factory/scripts/write-ledger.sh --self-test" in text
    assert "factory/scripts/ensure-scala.sh" in text
    assert "factory/scripts/check-human-gate.py" in text
    assert "\tbash factory/scripts/next-job.sh\n" not in text
    assert "python3 factory/scripts/check-human-gate.py" in text
    wrappers = [
        line.strip()
        for line in text.splitlines()
        if line.strip().startswith("python3 -c ") and "human_gate" in line
    ]
    assert wrappers == []
    for name, body in _human_gate_callers().items():
        assert "factory/scripts/check-human-gate.py" in body, name
        assert "import json, subprocess, sys" not in body, name
    next_job = subprocess.run(
        ["bash", "factory/scripts/next-job.sh"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert next_job.returncode == 2
    result = subprocess.run(
        [sys.executable, "factory/scripts/check-human-gate.py"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0


def test_check_human_gate_maps_both_branches() -> None:
    path = ROOT / "factory" / "scripts" / "check-human-gate.py"
    assert path.is_file()
    assert os.access(path, os.X_OK)
    mod = _gate_mod()
    assert mod.mapped_exit({"kind": "parked"}, 2) == 0
    assert mod.mapped_exit({"kind": "parked"}, 0) == 1
    assert mod.mapped_exit(None, 0) == 0
    assert mod.mapped_exit(None, 2) == 1
    self_test = subprocess.run(
        [sys.executable, str(path), "--self-test"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert self_test.returncode == 0


def _publish_pypi_workflow() -> str:
    return (ROOT / ".github/workflows/publish-pypi.yml").read_text()


def test_publish_pypi_job_if_gates_dispatch_to_main() -> None:
    text = _publish_pypi_workflow()
    assert "workflow_dispatch:" in text
    assert "workflow_call:" in text
    assert "(github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main')" in text
    assert "startsWith(github.ref, 'refs/tags/')" in text
    assert "github.event_name == 'workflow_call'" in text


def test_publish_pypi_reads_version_and_asserts_tag() -> None:
    text = _publish_pypi_workflow()
    assert "HONEPAD_VERSION" in text
    assert "tomllib" in text
    assert 'tag="${TAG#v}"' in text
    assert "tag $tag != version $ver" in text
    assert "dist/honepad-${ver}-py3-none-any.whl" in text
    assert "dist/honepad-${ver}.tar.gz" in text


def test_publish_pypi_dispatch_smokes_before_build() -> None:
    text = _publish_pypi_workflow()
    assert "python -m pip install --require-hashes -r requirements-dev.txt" in text
    assert "python -m pip install --no-deps --no-build-isolation -e ." in text
    assert (
        "python -m pytest tests/test_packaging.py tests/test_hidden.py tests/test_session.py -q"
        in text
    )
    assert "python -m honepad.cli run bank_system --lang python3 --level 4" in text
    header = "\n".join(text.splitlines()[:4]).lower()
    assert "tests already ran" not in header
    assert "pyproject.toml" in header
    assert "smoke" in header
