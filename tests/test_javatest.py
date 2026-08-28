import pytest

from honepad.javatest import java_expr, java_ident, render_junit
from honepad.traces import load_cases


def test_java_expr_literals() -> None:
    assert java_expr(None) == "null"
    assert java_expr(True) == "true"
    assert java_expr(False) == "false"
    assert java_expr(500) == "500"
    assert java_expr("acc1") == '"acc1"'
    assert java_expr([]) == "List.of()"
    assert java_expr(["acc1(500)"]) == 'List.of("acc1(500)")'
    assert java_expr(3_000_000_000) == "3000000000L"


def test_java_expr_rejects_mapping() -> None:
    with pytest.raises(ValueError, match="cannot emit Java"):
        java_expr({})


def test_java_ident_replaces_hyphens() -> None:
    assert java_ident("l1-create") == "l1_create"
    assert java_ident("2go") == "case_2go"


def test_render_junit_l1_hides_later_methods() -> None:
    cases = load_cases("bank_system", 1)
    text = render_junit("bank_system", cases)
    assert text.count("@Test") == len(cases)
    for case in cases:
        assert java_ident(case["id"]) in text
    assert "createAccount" in text
    assert "mergeAccounts" not in text
    assert "topSpenders" not in text
    assert '@DisplayName("l1-create")' in text
    assert "void l1_create()" in text
    assert "import java.util.List;" not in text
    assert "import static org.junit.jupiter.api.Assertions.assertNull;" in text
    assert "assertNull(" in text


def test_render_junit_l2_uses_list_of() -> None:
    cases = load_cases("bank_system", 2)
    text = render_junit("bank_system", cases)
    assert text.count("@Test") == len(cases)
    for case in cases:
        assert java_ident(case["id"]) in text
    assert "topSpenders" in text
    assert "List.of(" in text
    assert "import java.util.List;" in text


def test_render_junit_empty_cases() -> None:
    text = render_junit("bank_system", [])
    assert text.count("@Test") == 0
    assert "class PublicTracesTest {" in text


def test_java_expr_escapes_unicode_quote_breakout() -> None:
    assert java_expr(r"\u0022") == '"\\\\u0022"'
    emitted = java_expr(r"\u0022); evil(); //")
    assert '"); evil' not in emitted
    assert emitted == '"\\\\u0022); evil(); //"'


def test_render_junit_rejects_hostile_method() -> None:
    case = {
        "id": "evil",
        "level": 1,
        "calls": [{"m": "create_account();evil()", "a": [1, "acc1"], "e": True}],
    }
    with pytest.raises(ValueError, match="invalid method name"):
        render_junit("bank_system", [case])


def test_render_pytest_rejects_hostile_method() -> None:
    from honepad.pythontest import render_pytest

    case = {
        "id": "evil",
        "level": 1,
        "calls": [{"m": "create_account();evil()", "a": [1, "acc1"], "e": True}],
    }
    with pytest.raises(ValueError, match="invalid method name"):
        render_pytest("bank_system", [case])
