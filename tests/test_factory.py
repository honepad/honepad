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
