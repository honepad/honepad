"""Shared runner for adapter report-value tests."""

from __future__ import annotations

from pathlib import Path

from honepad import packspec
from honepad.runner import Report, run_script


def argv(lang_id: str, src: Path) -> list[str]:
    spec = packspec.load_meta(lang_id)["run"]
    ctx = packspec.context(lang_id, class_name="InMemoryDatabase", src=src)
    tool = packspec.resolve_tool(spec, lang_id)
    return packspec.render_argv(list(spec["argv"]), ctx, tool)


def case(name: str, method: str, expected: object) -> dict[str, object]:
    return {"id": name, "calls": [{"m": method, "a": [], "e": expected}]}


def run(
    lang: str,
    tmp_path: Path,
    suffix: str,
    source: str,
    cases: list[dict[str, object]],
) -> Report:
    src = tmp_path / f"work.{suffix}"
    src.write_text(source, encoding="utf-8")
    report = run_script(
        "in_memory_database",
        lang,
        1,
        "work",
        argv(lang, src),
        src=src,
        cases=cases,
    )
    assert report.passed + len(report.failed) == len(cases)
    return report


def failed(report: Report) -> dict[str, object]:
    return {row.case: row.actual for row in report.failed}


def assert_failed(report: Report, name: str, actual: object, expected: object) -> None:
    row = next(item for item in report.failed if item.case == name)
    assert row.actual == actual
    assert row.expected == expected


def assert_passed(report: Report, name: str) -> None:
    assert name not in failed(report)
