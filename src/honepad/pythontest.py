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


_SAME_HELPER = """\
def _same(actual, expected):
    if (
        actual is True
        or actual is False
        or actual is None
        or expected is True
        or expected is False
        or expected is None
    ):
        return actual is expected
    if isinstance(actual, list) or isinstance(expected, list):
        if (
            not isinstance(actual, list)
            or not isinstance(expected, list)
            or len(actual) != len(expected)
        ):
            return False
        return all(_same(left, right) for left, right in zip(actual, expected))
    if isinstance(actual, dict) or isinstance(expected, dict):
        if not isinstance(actual, dict) or not isinstance(expected, dict):
            return False
        if actual.keys() != expected.keys():
            return False
        return all(_same(actual[key], expected[key]) for key in expected)
    return actual == expected


"""


def render_pytest(problem: str, cases: list[dict[str, Any]]) -> str:
    class_name = class_name_for(problem)
    methods = [_render_case(class_name, case) for case in cases]
    body = "\n\n".join(methods)
    helper = _SAME_HELPER if _expects_container(cases) else ""
    return f"from work import {class_name}\n\n{helper}{body}\n"


def _expects_container(cases: list[dict[str, Any]]) -> bool:
    return any(isinstance(call["e"], (list, dict)) for case in cases for call in case["calls"])


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
        elif isinstance(expected, (list, dict)):
            lines.append(f"    actual = {expr}")
            lines.append(f"    assert _same(actual, {expected!r}), repr(actual)")
        else:
            # True == 1. One binding: the call may have side effects.
            lines.append(f"    actual = {expr}")
            lines.append(f"    assert actual == {expected!r} and not isinstance(actual, bool)")
    return "\n".join(lines)
