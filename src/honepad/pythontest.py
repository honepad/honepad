"""Generate pytest tests from unlocked public traces."""

from __future__ import annotations

import re
from typing import Any

from honepad.traces import method_name
from honepad.workstub import class_name_for


def pytest_ident(case_id: str) -> str:
    name = re.sub(r"[^A-Za-z0-9_]", "_", case_id)
    if not name or name[0].isdigit():
        name = f"case_{name}"
    return f"test_{name}"


def render_pytest(problem: str, cases: list[dict[str, Any]]) -> str:
    class_name = class_name_for(problem)
    methods = [_render_case(class_name, case) for case in cases]
    body = "\n\n".join(methods)
    return f"from work import {class_name}\n\n{body}\n"


def _render_case(class_name: str, case: dict[str, Any]) -> str:
    ident = pytest_ident(str(case["id"]))
    lines = [f"def {ident}() -> None:", f"    sim = {class_name}()"]
    for call in case["calls"]:
        name = method_name(str(call["m"]), "snake")
        args = ", ".join(repr(item) for item in call["a"])
        expr = f"sim.{name}({args})"
        expected = call["e"]
        if expected is True or expected is False or expected is None:
            lines.append(f"    assert {expr} is {expected!r}")
        else:
            lines.append(f"    assert {expr} == {expected!r}")
    return "\n".join(lines)
