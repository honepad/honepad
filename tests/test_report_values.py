"""Non-JSON returns stay on the failure row instead of breaking the report."""

from __future__ import annotations

from pathlib import Path

from honepad import packspec
from honepad.runner import Report, run_script


def _argv(lang_id: str, src: Path) -> list[str]:
    spec = packspec.load_meta(lang_id)["run"]
    ctx = packspec.context(lang_id, class_name="InMemoryDatabase", src=src)
    tool = packspec.resolve_tool(spec, lang_id)
    return packspec.render_argv(list(spec["argv"]), ctx, tool)


def _case(name: str, method: str, expected: object) -> dict[str, object]:
    return {"id": name, "calls": [{"m": method, "a": [], "e": expected}]}


def _run(
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
        _argv(lang, src),
        src=src,
        cases=cases,
    )
    assert report.passed + len(report.failed) == len(cases)
    return report


def _failed(report: Report) -> dict[str, object]:
    return {row.case: row.actual for row in report.failed}


def _assert_failed(report: Report, name: str, actual: object, expected: object) -> None:
    row = next(item for item in report.failed if item.case == name)
    assert row.actual == actual
    assert row.expected == expected


def _assert_passed(report: Report, name: str) -> None:
    assert name not in _failed(report)


def test_typescript_recipe_uses_javascript_adapter() -> None:
    spec = packspec.load_meta("typescript")["run"]
    assert spec["argv"][1] == "{{langs}}/javascript/adapter.js"


def test_javascript_undefined_and_non_json_values(tmp_path: Path) -> None:
    source = """
module.exports = class InMemoryDatabase {
  set() {}
  retUndef() { return undefined; }
  retNull() { return null; }
  retNan() { return NaN; }
  retInf() { return Infinity; }
  retNinf() { return -Infinity; }
  retHole() { return [undefined]; }
  retNest() { return { a: undefined, b: 1 }; }
  retDrop() { return { a: 1, b: undefined }; }
  retFn() { return function () {}; }
  retBig() { return 1n; }
  retStr() { return "undefined"; }
  retSym() { return Symbol("s"); }
  retCirc() { const box = {}; box.self = box; return box; }
  retNode() {
    class Node { constructor() { this.val = NaN; this.next = null; } }
    return new Node();
  }
  retBox() {
    class Box {}
    const box = new Box();
    box.n = 1n;
    return box;
  }
  retDate() { return new Date(NaN); }
  retBoxed() { return new Number(NaN); }
  retBoxedField() { return { v: new Number(Infinity) }; }
};
"""
    cases = [
        _case("empty", "set", ""),
        _case("undef", "retUndef", None),
        _case("undef-str", "retUndef", "undefined"),
        _case("null", "retNull", None),
        _case("nan", "retNan", None),
        _case("nan-zero", "retNan", 0),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("hole", "retHole", [None]),
        _case("nest", "retNest", {"b": 1}),
        _case("drop", "retDrop", {"a": 1}),
        _case("fn", "retFn", None),
        _case("big", "retBig", None),
        _case("str", "retStr", "undefined"),
        _case("sym", "retSym", None),
        _case("circ", "retCirc", {}),
        _case("node", "retNode", {"val": None, "next": None}),
        _case("box", "retBox", None),
        _case("date", "retDate", None),
        _case("boxed", "retBoxed", None),
        _case("boxed-field", "retBoxedField", {"v": None}),
    ]
    report = _run("javascript", tmp_path, "js", source, cases)
    assert report.passed == 2
    _assert_failed(report, "empty", "undefined", "")
    _assert_failed(report, "undef", "undefined", None)
    _assert_failed(report, "undef-str", "undefined", "undefined")
    _assert_passed(report, "null")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "nan-zero", "NaN", 0)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_failed(report, "hole", ["undefined"], [None])
    _assert_failed(report, "nest", {"a": "undefined", "b": 1}, {"b": 1})
    _assert_failed(report, "drop", {"a": 1, "b": "undefined"}, {"a": 1})
    _assert_failed(report, "fn", "function", None)
    _assert_failed(report, "big", "bigint:1", None)
    _assert_passed(report, "str")
    _assert_failed(report, "sym", "symbol", None)
    _assert_failed(report, "circ", {"self": "circular"}, {})
    _assert_failed(report, "node", {"val": "NaN", "next": None}, {"val": None, "next": None})
    _assert_failed(report, "box", {"n": "bigint:1"}, None)
    _assert_failed(report, "date", "Invalid Date", None)
    _assert_failed(report, "boxed", "NaN", None)
    _assert_failed(report, "boxed-field", {"v": "Infinity"}, {"v": None})


def test_typescript_undefined_return_uses_shared_adapter(tmp_path: Path) -> None:
    source = "module.exports = class InMemoryDatabase { set() {} };\n"
    cases = [_case("empty", "set", "")]
    report = _run("typescript", tmp_path, "ts", source, cases)
    _assert_failed(report, "empty", "undefined", "")


def test_coffeescript_undefined_and_nan(tmp_path: Path) -> None:
    source = """
module.exports = class InMemoryDatabase
  set: ->
  retNull: -> null
  retNan: -> NaN
  retInf: -> Infinity
  retHole: -> [undefined]
  retStr: -> "undefined"
"""
    cases = [
        _case("empty", "set", ""),
        _case("null", "retNull", None),
        _case("nan", "retNan", None),
        _case("inf", "retInf", None),
        _case("hole", "retHole", [None]),
        _case("str", "retStr", "undefined"),
    ]
    report = _run("coffeescript", tmp_path, "coffee", source, cases)
    assert report.passed == 2
    _assert_failed(report, "empty", "undefined", "")
    _assert_passed(report, "null")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "hole", ["undefined"], [None])
    _assert_passed(report, "str")


def test_php_nonfinite_is_a_mismatch(tmp_path: Path) -> None:
    source = """<?php
class Box {
  public float $val;
  public function __construct() { $this->val = NAN; }
}
class InMemoryDatabase {
  public function set() {}
  public function retBox() { return new Box(); }
  public function retNull() { return null; }
  public function retNan() { return NAN; }
  public function retInf() { return INF; }
  public function retNinf() { return -INF; }
  public function retOne() { return 1; }
}
"""
    cases = [
        _case("empty", "set", ""),
        _case("null", "retNull", None),
        _case("nan", "retNan", None),
        _case("nan-zero", "retNan", 0),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("one", "retOne", 1),
        _case("box", "retBox", {"val": None}),
    ]
    report = _run("php", tmp_path, "php", source, cases)
    assert report.passed == 2
    _assert_failed(report, "empty", None, "")
    _assert_passed(report, "null")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "nan-zero", "NaN", 0)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_passed(report, "one")
    _assert_failed(report, "box", {"val": "NaN"}, {"val": None})


def test_ruby_nonfinite_is_a_mismatch(tmp_path: Path) -> None:
    source = """
class InMemoryDatabase
  def set
  end
  def ret_null
    nil
  end
  def ret_nan
    Float::NAN
  end
  def ret_inf
    Float::INFINITY
  end
  def ret_ninf
    -Float::INFINITY
  end
  def ret_one
    1
  end
end
"""
    cases = [
        _case("empty", "set", ""),
        _case("null", "ret_null", None),
        _case("nan", "ret_nan", None),
        _case("inf", "ret_inf", None),
        _case("ninf", "ret_ninf", None),
        _case("one", "ret_one", 1),
    ]
    report = _run("ruby", tmp_path, "rb", source, cases)
    assert report.passed == 2
    _assert_failed(report, "empty", None, "")
    _assert_passed(report, "null")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_passed(report, "one")


def test_lua_nonfinite_is_a_mismatch(tmp_path: Path) -> None:
    source = """
InMemoryDatabase = {}
InMemoryDatabase.__index = InMemoryDatabase
function InMemoryDatabase.new()
  return setmetatable({}, InMemoryDatabase)
end
function InMemoryDatabase:set()
end
function InMemoryDatabase:ret_null()
  return nil
end
function InMemoryDatabase:ret_nan()
  return 0/0
end
function InMemoryDatabase:ret_inf()
  return math.huge
end
function InMemoryDatabase:ret_ninf()
  return -math.huge
end
function InMemoryDatabase:ret_dag()
  local shared = {}
  return { { math.huge }, { shared, shared } }
end
"""
    cases = [
        _case("empty", "set", ""),
        _case("null", "ret_null", None),
        _case("nan", "ret_nan", None),
        _case("inf", "ret_inf", None),
        _case("ninf", "ret_ninf", None),
        _case("dag", "ret_dag", None),
    ]
    report = _run("lua", tmp_path, "lua", source, cases)
    assert report.passed == 1
    _assert_failed(report, "empty", None, "")
    _assert_passed(report, "null")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_failed(report, "dag", [["Infinity"], [[], []]], None)


def test_perl_nonfinite_is_a_mismatch(tmp_path: Path) -> None:
    source = """
package InMemoryDatabase;
sub new { bless {}, shift }
sub set { undef }
sub ret_nan { 0 + "nan" }
sub ret_inf { 0 + "inf" }
sub ret_ninf { 0 + "-inf" }
sub ret_word { "NaN" }
sub ret_one { 1 }
1;
"""
    cases = [
        _case("empty", "set", ""),
        _case("nan", "ret_nan", None),
        _case("inf", "ret_inf", None),
        _case("ninf", "ret_ninf", None),
        _case("word", "ret_word", "NaN"),
        _case("one", "ret_one", 1),
    ]
    report = _run("perl", tmp_path, "pl", source, cases)
    assert report.passed == 2
    _assert_failed(report, "empty", None, "")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_passed(report, "word")
    _assert_passed(report, "one")


def test_r_nonfinite_does_not_match_null(tmp_path: Path) -> None:
    source = """
InMemoryDatabase <- function() {
  env <- new.env(parent = emptyenv())
  env$retNull <- function() NULL
  env$retNa <- function() NA_real_
  env$retNan <- function() NaN
  env$retInf <- function() Inf
  env$retNinf <- function() -Inf
  env$retOne <- function() 1
  env
}
"""
    cases = [
        _case("null", "retNull", None),
        _case("na", "retNa", None),
        _case("nan", "retNan", None),
        _case("nan-zero", "retNan", 0),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("one", "retOne", 1),
    ]
    report = _run("r", tmp_path, "R", source, cases)
    assert report.passed == 3
    _assert_passed(report, "null")
    _assert_passed(report, "na")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "nan-zero", "NaN", 0)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_passed(report, "one")


def test_groovy_nan_is_not_zero(tmp_path: Path) -> None:
    source = """
class Box {
  double val = Double.NaN
}
class Holder {
  double[] vals = [Double.NaN] as double[]
}
class InMemoryDatabase {
  Object retNull() { return null }
  Box retBox() { return new Box() }
  double[] retArr() { return [Double.NaN] as double[] }
  Double[] retBoxed() { return [Double.NaN] as Double[] }
  Holder retHolder() { return new Holder() }
  double retNan() { return Double.NaN }
  double retInf() { return Double.POSITIVE_INFINITY }
  double retNinf() { return Double.NEGATIVE_INFINITY }
  List retList() { return [Double.NaN] }
  int retOne() { return 1 }
}
"""
    cases = [
        _case("null", "retNull", None),
        _case("nan", "retNan", None),
        _case("nan-zero", "retNan", 0),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("list", "retList", [0]),
        _case("one", "retOne", 1),
        _case("box", "retBox", {"val": None}),
        _case("arr", "retArr", [None]),
        _case("boxed", "retBoxed", [None]),
        _case("holder", "retHolder", {"vals": [None]}),
    ]
    report = _run("groovy", tmp_path, "groovy", source, cases)
    assert report.passed == 2
    _assert_passed(report, "null")
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "nan-zero", "NaN", 0)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_failed(report, "list", ["NaN"], [0])
    _assert_passed(report, "one")
    _assert_failed(report, "box", {"val": "NaN"}, {"val": None})
    _assert_failed(report, "arr", ["NaN"], [None])
    _assert_failed(report, "boxed", ["NaN"], [None])
    _assert_failed(report, "holder", {"vals": ["NaN"]}, {"vals": [None]})


def test_dart_nonfinite_is_a_mismatch(tmp_path: Path) -> None:
    source = """
class InMemoryDatabase {
  double retNan() => double.nan;
  double retInf() => double.infinity;
  double retNinf() => double.negativeInfinity;
  int retOne() => 1;
}
"""
    cases = [
        _case("nan", "retNan", None),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("one", "retOne", 1),
    ]
    report = _run("dart", tmp_path, "dart", source, cases)
    assert report.passed == 1
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_passed(report, "one")


def test_julia_infinity_is_a_mismatch(tmp_path: Path) -> None:
    source = """
mutable struct InMemoryDatabase end
retNan(::InMemoryDatabase) = NaN
retInf(::InMemoryDatabase) = Inf
retNinf(::InMemoryDatabase) = -Inf
retOne(::InMemoryDatabase) = 1
"""
    cases = [
        _case("nan", "retNan", None),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("one", "retOne", 1),
    ]
    report = _run("julia", tmp_path, "jl", source, cases)
    assert report.passed == 1
    _assert_failed(report, "nan", "NaN", None)
    _assert_failed(report, "inf", "Infinity", None)
    _assert_failed(report, "ninf", "-Infinity", None)
    _assert_passed(report, "one")


def test_octave_nonfinite_is_not_null(tmp_path: Path) -> None:
    source = """
function obj = InMemoryDatabase()
  obj.retNan = @() NaN;
  obj.retInf = @() Inf;
  obj.retNinf = @() -Inf;
  obj.retOne = @() 1;
  obj.retStruct = @() struct("a", NaN);
  obj.retCell = @() {struct("a", Inf)};
endfunction
"""
    cases = [
        _case("nan", "retNan", None),
        _case("inf", "retInf", None),
        _case("ninf", "retNinf", None),
        _case("one", "retOne", 1),
        _case("struct", "retStruct", {"a": None}),
        _case("cell", "retCell", [{"a": None}]),
    ]
    report = _run("octave", tmp_path, "m", source, cases)
    assert report.passed == 1
    # Octave loads JSON null as an empty matrix, so the row's expected
    # value is [] rather than None. The actual field is the diagnostic.
    assert _failed(report)["nan"] == "NaN"
    assert _failed(report)["inf"] == "Infinity"
    assert _failed(report)["ninf"] == "-Infinity"
    assert _failed(report)["struct"] == {"a": "NaN"}
    assert _failed(report)["cell"] == [{"a": "Infinity"}]
    _assert_passed(report, "one")
