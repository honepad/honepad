"""Generate JUnit 5 tests from unlocked public traces."""

from __future__ import annotations

import re
from typing import Any

from honepad.traces import method_name
from honepad.workstub import class_name_for

_JUNIT_VERSION = "5.11.4"
_SUREFIRE_VERSION = "3.5.2"


def java_string(value: str) -> str:
    out: list[str] = ['"']
    for ch in value:
        code = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif code < 32:
            out.append(f"\\u{code:04x}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def java_expr(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        if value > 2_147_483_647 or value < -2_147_483_648:
            return f"{value}L"
        return str(value)
    if isinstance(value, float):
        return str(value)
    if isinstance(value, str):
        return java_string(value)
    if isinstance(value, list):
        if not value:
            return "List.of()"
        inner = ", ".join(java_expr(item) for item in value)
        return f"List.of({inner})"
    raise ValueError(f"cannot emit Java for {type(value).__name__}")


def java_ident(case_id: str) -> str:
    name = re.sub(r"[^A-Za-z0-9_]", "_", case_id)
    if not name or name[0].isdigit():
        name = f"case_{name}"
    return name


def render_junit(problem: str, cases: list[dict[str, Any]]) -> str:
    class_name = class_name_for(problem)
    methods = [_render_case(class_name, case) for case in cases]
    body = "\n\n".join(methods)
    uses_list = "List.of(" in body
    uses_null = "assertNull(" in body
    imports = [
        "import static org.junit.jupiter.api.Assertions.assertEquals;",
    ]
    if uses_null:
        imports.append("import static org.junit.jupiter.api.Assertions.assertNull;")
    extras = []
    if uses_list:
        extras.append("import java.util.List;")
    extras.extend(
        [
            "import org.junit.jupiter.api.DisplayName;",
            "import org.junit.jupiter.api.Test;",
        ]
    )
    header = "\n".join(imports) + "\n\n" + "\n".join(extras) + "\n\n"
    return f"{header}class PublicTracesTest {{\n{body}\n}}\n"


def render_pom(problem: str, lang: str) -> str:
    artifact = f"{problem}-{lang}-public"
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>honepad</groupId>
  <artifactId>{artifact}</artifactId>
  <version>0.0.1</version>
  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <maven.compiler.release>17</maven.compiler.release>
    <junit.version>{_JUNIT_VERSION}</junit.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>${{junit.version}}</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>{_SUREFIRE_VERSION}</version>
      </plugin>
    </plugins>
  </build>
</project>
"""


def _render_case(class_name: str, case: dict[str, Any]) -> str:
    ident = java_ident(str(case["id"]))
    lines = [
        "    @Test",
        f"    @DisplayName({java_string(str(case['id']))})",
        f"    void {ident}() {{",
        f"        {class_name} sim = new {class_name}();",
    ]
    for call in case["calls"]:
        name = method_name(str(call["m"]), "camel")
        args = ", ".join(java_expr(item) for item in call["a"])
        expr = f"sim.{name}({args})"
        expected = call["e"]
        if expected is None:
            lines.append(f"        assertNull({expr});")
        else:
            lines.append(f"        assertEquals({java_expr(expected)}, {expr});")
    lines.append("    }")
    return "\n".join(lines)
