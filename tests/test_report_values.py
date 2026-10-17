"""Non-JSON returns stay on the failure row instead of breaking the report."""

from __future__ import annotations

import importlib.util
from pathlib import Path

from honepad import packspec


def _helpers():
    path = Path(__file__).with_name("report_helpers.py")
    spec = importlib.util.spec_from_file_location("report_helpers", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_H = _helpers()
_case = _H.case
_run = _H.run
_assert_failed = _H.assert_failed
_assert_passed = _H.assert_passed


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
