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


def test_c_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "c", level, "solution")
        assert report.ok, report.failed


def test_c_bank_stub_fails() -> None:
    report = run("bank_system", "c", 1, "stub")
    assert not report.ok


def test_tcl_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "tcl", level, "solution")
        assert report.ok, report.failed


def test_tcl_bank_stub_fails() -> None:
    report = run("bank_system", "tcl", 1, "stub")
    assert not report.ok


def test_r_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "r", level, "solution")
        assert report.ok, report.failed


def test_r_bank_stub_fails() -> None:
    report = run("bank_system", "r", 1, "stub")
    assert not report.ok


def test_octave_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "octave", level, "solution")
        assert report.ok, report.failed


def test_octave_bank_stub_fails() -> None:
    report = run("bank_system", "octave", 1, "stub")
    assert not report.ok


def test_nim_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "nim", level, "solution")
        assert report.ok, report.failed


def test_nim_bank_stub_fails() -> None:
    report = run("bank_system", "nim", 1, "stub")
    assert not report.ok


def test_groovy_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "groovy", level, "solution")
        assert report.ok, report.failed


def test_groovy_bank_stub_fails() -> None:
    report = run("bank_system", "groovy", 1, "stub")
    assert not report.ok


def test_dart_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "dart", level, "solution")
        assert report.ok, report.failed


def test_dart_bank_stub_fails() -> None:
    report = run("bank_system", "dart", 1, "stub")
    assert not report.ok


def test_elixir_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "elixir", level, "solution")
        assert report.ok, report.failed


def test_elixir_bank_stub_fails() -> None:
    report = run("bank_system", "elixir", 1, "stub")
    assert not report.ok


def test_erlang_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "erlang", level, "solution")
        assert report.ok, report.failed


def test_erlang_bank_stub_fails() -> None:
    report = run("bank_system", "erlang", 1, "stub")
    assert not report.ok


def test_haskell_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "haskell", level, "solution")
        assert report.ok, report.failed


def test_haskell_bank_stub_fails() -> None:
    report = run("bank_system", "haskell", 1, "stub")
    assert not report.ok


def test_ocaml_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "ocaml", level, "solution")
        assert report.ok, report.failed


def test_ocaml_bank_stub_fails() -> None:
    report = run("bank_system", "ocaml", 1, "stub")
    assert not report.ok


def test_scala_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "scala", level, "solution")
        assert report.ok, report.failed


def test_scala_bank_stub_fails() -> None:
    report = run("bank_system", "scala", 1, "stub")
    assert not report.ok


def test_d_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "d", level, "solution")
        assert report.ok, report.failed


def test_d_bank_stub_fails() -> None:
    report = run("bank_system", "d", 1, "stub")
    assert not report.ok


def test_julia_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "julia", level, "solution")
        assert report.ok, report.failed


def test_julia_bank_stub_fails() -> None:
    report = run("bank_system", "julia", 1, "stub")
    assert not report.ok


def test_coffeescript_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "coffeescript", level, "solution")
        assert report.ok, report.failed


def test_coffeescript_bank_stub_fails() -> None:
    report = run("bank_system", "coffeescript", 1, "stub")
    assert not report.ok


def test_bash_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "bash", level, "solution")
        assert report.ok, report.failed


def test_bash_bank_stub_fails() -> None:
    report = run("bank_system", "bash", 1, "stub")
    assert not report.ok


def test_common_lisp_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "common-lisp", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_common_lisp_bank_stub_fails() -> None:
    report = run("bank_system", "common-lisp", 1, "stub")
    assert not report.ok


def test_fortran_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "fortran", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_fortran_bank_stub_fails() -> None:
    report = run("bank_system", "fortran", 1, "stub")
    assert not report.ok


def test_fsharp_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "fsharp", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_fsharp_bank_stub_fails() -> None:
    report = run("bank_system", "fsharp", 1, "stub")
    assert not report.ok


def test_freepascal_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "freepascal", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_freepascal_bank_stub_fails() -> None:
    report = run("bank_system", "freepascal", 1, "stub")
    assert not report.ok


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
    adapter = language("vb")["adapter"]
    try:
        run("bank_system", "vb", 1, "stub")
    except NotImplementedError as exc:
        msg = str(exc)
        assert "vb" in msg
        assert "adapter=" in msg
        assert f"adapter={adapter}" in msg
        return
    raise AssertionError("expected NotImplementedError")
