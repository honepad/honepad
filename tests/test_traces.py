from honepad.catalog import language
from honepad.runner import run, run_python
from honepad.traces import load_cases


def test_bank_solution_all_levels() -> None:
    report = run_python("bank_system", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("bank_system", 4))


def test_db_solution_all_levels() -> None:
    report = run_python("in_memory_database", 4, "solution")
    assert report.ok, report.failed
    assert report.passed == len(load_cases("in_memory_database", 4))


def test_stub_fails() -> None:
    report = run_python("bank_system", 1, "stub")
    assert not report.ok


def test_go_stub_fails() -> None:
    report = run("bank_system", "go", 1, "stub")
    assert not report.ok


def test_rust_stub_fails() -> None:
    report = run("bank_system", "rust", 1, "stub")
    assert not report.ok


def test_java_stub_fails() -> None:
    report = run("bank_system", "java", 1, "stub")
    assert not report.ok


def test_csharp_stub_fails() -> None:
    report = run("bank_system", "csharp", 1, "stub")
    assert not report.ok


def test_kotlin_stub_fails() -> None:
    report = run("bank_system", "kotlin", 1, "stub")
    assert not report.ok


def test_cpp_stub_fails() -> None:
    report = run("bank_system", "cpp", 1, "stub")
    assert not report.ok


def test_swift_stub_fails() -> None:
    report = run("bank_system", "swift", 1, "stub")
    assert not report.ok


def test_perl_stub_fails() -> None:
    report = run("bank_system", "perl", 1, "stub")
    assert not report.ok


def test_lua_stub_fails() -> None:
    report = run("bank_system", "lua", 1, "stub")
    assert not report.ok


def test_javascript_bank_and_db() -> None:
    bank = run("bank_system", "javascript", 4, "solution")
    assert bank.ok, bank.failed
    db = run("in_memory_database", "javascript", 4, "solution")
    assert db.ok, db.failed


def test_file_storage_python_and_js() -> None:
    py = run_python("file_storage", 4, "solution")
    assert py.ok, py.failed
    assert py.passed == len(load_cases("file_storage", 4))
    js = run("file_storage", "javascript", 4, "solution")
    assert js.ok, js.failed


def test_workers_python_and_js() -> None:
    py = run_python("workers", 3, "solution")
    assert py.ok, py.failed
    assert py.passed == len(load_cases("workers", 3))
    js = run("workers", "javascript", 3, "solution")
    assert js.ok, js.failed


def test_ruby_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "ruby", level, "solution")
        assert report.ok, report.failed


def test_ruby_stub_fails() -> None:
    report = run("bank_system", "ruby", 1, "stub")
    assert not report.ok


def test_script_stubs_fail() -> None:
    for lang in ("javascript", "php", "typescript"):
        report = run("bank_system", lang, 1, "stub")
        assert not report.ok, lang


def test_go_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "go", level, "solution")
        assert report.ok, report.failed


def test_php_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "php", level, "solution")
        assert report.ok, report.failed


def test_rust_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "rust", level, "solution")
        assert report.ok, report.failed


def test_java_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "java", level, "solution")
        assert report.ok, report.failed


def test_typescript_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "typescript", level, "solution")
        assert report.ok, report.failed


def test_csharp_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "csharp", level, "solution")
        assert report.ok, report.failed


def test_kotlin_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "kotlin", level, "solution")
        assert report.ok, report.failed


def test_cpp_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "cpp", level, "solution")
        assert report.ok, report.failed


def test_swift_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "swift", level, "solution")
        assert report.ok, report.failed


def test_perl_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "perl", level, "solution")
        assert report.ok, report.failed


def test_lua_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "lua", level, "solution")
        assert report.ok, report.failed


def test_prove_python3_and_go_all_problems() -> None:
    for lang in ("python3", "go"):
        for problem, level in (
            ("bank_system", 4),
            ("in_memory_database", 4),
            ("file_storage", 4),
            ("workers", 3),
        ):
            report = run(problem, lang, level, "solution")
            assert report.ok, (lang, problem, report.failed)


def test_run_unknown_language_is_not_implemented() -> None:
    adapter = language("fortran")["adapter"]
    try:
        run("bank_system", "fortran", 1, "stub")
    except NotImplementedError as exc:
        msg = str(exc)
        assert "fortran" in msg
        assert "adapter=" in msg
        assert f"adapter={adapter}" in msg
        return
    raise AssertionError("expected NotImplementedError")
