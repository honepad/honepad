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


def test_java_ident_replaces_hyphens() -> None:
    assert java_ident("l1-create") == "l1_create"
    assert java_ident("2go") == "case_2go"


def test_render_junit_l1_hides_later_methods() -> None:
    text = render_junit("bank_system", load_cases("bank_system", 1))
    assert "@Test" in text
    assert "createAccount" in text
    assert "mergeAccounts" not in text
    assert "topSpenders" not in text
    assert '@DisplayName("l1-create")' in text
    assert "void l1_create()" in text
    assert "import java.util.List;" not in text


def test_render_junit_l2_uses_list_of() -> None:
    text = render_junit("bank_system", load_cases("bank_system", 2))
    assert "topSpenders" in text
    assert "List.of(" in text
    assert "import java.util.List;" in text
