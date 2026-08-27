import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


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


def test_ci_test_job_splits_apt_install() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    assert text.count("apt-get update") == 1
    assert "sudo apt-get update && sudo apt-get install -y lua5.4" not in text
    wanted = {
        "lua5.4",
        "tcl",
        "r-base",
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
    assert "Install jvm/beam langs" in text
    assert "Install GNU Smalltalk" in text
    assert "gnu-smalltalk_${ver}_amd64.deb" in text
    assert "Install PowerShell" in text


def test_ci_test_job_keeps_short_cli_smoke() -> None:
    text = (ROOT / ".github/workflows/ci.yml").read_text()
    assert "pytest covers the matrix; these are CLI smokes" in text
    runs = [line.strip() for line in text.splitlines() if "honepad.cli run" in line]
    assert runs == [
        "- run: python3 -m honepad.cli run bank_system --lang python3 --level 4",
        "- run: python3 -m honepad.cli run in_memory_database --lang python3 --level 4",
        "- run: python3 -m honepad.cli run file_storage --lang python3 --level 4",
        "- run: python3 -m honepad.cli run workers --lang python3 --level 3",
        "- run: python3 -m honepad.cli run bank_system --lang go --level 4",
        "- run: python3 -m honepad.cli run bank_system --lang perl --level 4",
    ]
    assert "python3 -m pytest" in text
    assert "name: Stealth" in text
    assert "name: Lint" in text
    assert "name: Next job respects human_gate" in text
    assert 'if state.get("human_gate"):' in text
    assert "- run: bash factory/scripts/next-job.sh\n" not in text


def test_makefile_check_accepts_parked_human_gate() -> None:
    text = (ROOT / "Makefile").read_text()
    assert "factory/scripts/write-ledger.sh --self-test" in text
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
