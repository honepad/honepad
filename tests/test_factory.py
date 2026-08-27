import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_next_job_prints_one_improve_job() -> None:
    state = json.loads((ROOT / "factory" / "STATE.json").read_text())
    result = subprocess.run(
        ["bash", "factory/scripts/next-job.sh"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
    after_ok = False
    json_lines = []
    picked = None
    for line in result.stdout.splitlines():
        if line.startswith("OK: picked"):
            after_ok = True
        if line.startswith("{") and line.endswith("}"):
            json_lines.append(line)
            if after_ok and picked is None:
                picked = line
    assert len(json_lines) == 1
    assert picked is not None
    job = json.loads(picked)
    assert job["work_source"] == state.get("next_work_source", "improve")
    assert job.get("job_id")
    assert job["pr_plan_cursor"] == "pr-75"


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
    assert "python3 -m honepad.cli run bank_system --lang lua --level 4" in text
    assert "python3 -m honepad.cli run bank_system --lang smalltalk --level 4" in text
    assert "python3 -m honepad.cli run bank_system --lang freepascal --level 4" in text
    assert "python3 -m honepad.cli run bank_system --lang clojure --level 4" in text
    assert "python3 -m honepad.cli run bank_system --lang powershell --level 4" in text
    assert "python3 -m honepad.cli run bank_system --lang shell --level 4" in text
