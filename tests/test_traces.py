import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from honepad.catalog import language, repo_root
from honepad.runner import (
    _RUNNERS,
    COMPILE_TIMEOUT_S,
    RUN_TIMEOUT_S,
    report_from_proc,
    run,
    run_compiled,
    run_prepare_cmd,
    run_python,
    run_script,
)
from honepad.traces import load_cases

# Same sentinel as tests/test_cli.py. Must stay off _RUNNERS.
UNIMPLEMENTED_CATALOG_LANG = "vb"

_GST = shutil.which("gst")


def test_bank_level2_spec_shows_worked_example() -> None:
    text = (repo_root() / "problems" / "bank_system" / "spec" / "level2.md").read_text(
        encoding="utf-8"
    )
    assert "top_spenders(5, 2)" in text
    assert '["acc1(500)", "acc2(0)"]' in text
    assert '["acc1(500)", "acc2(500)", "acc3(300)"]' in text


@pytest.mark.parametrize(
    ("problem", "level", "needles"),
    [
        (
            "bank_system",
            3,
            (
                'pay(3, "acc1", 500) -> "payment1"',
                'get_payment_status(4, "acc1", "payment1") -> "IN_PROGRESS"',
                'get_payment_status(86400003, "acc1", "payment1") -> "CASHBACK_RECEIVED"',
                'deposit(100800000, "acc1", 0) -> 510',
                '["acc1(800)", "acc2(200)"]',
            ),
        ),
        (
            "bank_system",
            4,
            (
                'merge_accounts(5, "acc2", "acc1") -> true',
                'get_payment_status(6, "acc2", "payment1") -> "IN_PROGRESS"',
                'deposit(86400005, "acc2", 0) -> 510',
                '["acc1(1300)"]',
                'get_balance(4, "acc1", 3) -> 700',
                'get_balance(86400005, "acc1", 86400003) -> 706',
            ),
        ),
        (
            "file_storage",
            2,
            (
                'get_n_largest("/dir", 2) -> "/dir/file2(20), /dir/deeper/file3.mov(9)"',
                'get_n_largest("/dir/file", 3) -> "/dir/file2(20), /dir/file1.txt(5)"',
                'get_n_largest("/another_dir", 3) -> ""',
                'get_n_largest("/", 2) -> "/big_file.mp4(20), /dir/file2(20)"',
            ),
        ),
        (
            "file_storage",
            3,
            (
                'add_user("user1", 200) -> "true"',
                'add_file_by("user1", "/dir/file.med", 50) -> "150"',
                'add_file_by("user1", "/file-small", 20) -> ""',
                'merge_user("user1", "user2") -> "70"',
                'copy_file("/x.txt", "/z.txt") -> ""',
            ),
        ),
        (
            "file_storage",
            4,
            (
                'backup_user("user") -> "2"',
                'restore_user("user") -> "2"',
                'restore_user("user") -> "0"',
                'backup_user("ghost") -> ""',
            ),
        ),
        (
            "in_memory_database",
            2,
            (
                'scan("user1") -> "abc(123), age(30), city(NY), name(Alice)"',
                'scan("non_existent") -> ""',
                'scan_by_prefix("user1", "a") -> "abc(123), age(30)"',
                'scan_by_prefix("user1", "xyz") -> ""',
            ),
        ),
        (
            "in_memory_database",
            3,
            (
                'get_at("user1", "name", 105) -> "Alice"',
                'get_at("user1", "name", 110) -> ""',
                'scan_at("user1", 105) -> "age(30), city(NY), name(Alice)"',
                'scan_at("user1", 117) -> ""',
                'scan("user1") -> "age(30), city(NY), name(Alice)"',
            ),
        ),
        (
            "in_memory_database",
            4,
            (
                'backup(3) -> "1"',
                'backup(12) -> "0"',
                'restore(10, 7) -> ""',
                'scan_at("A", 15) -> "B(C), D(E)"',
                'scan_at("A", 16) -> "D(E)"',
            ),
        ),
        (
            "workers",
            2,
            (
                'top_n_workers(5, "Junior Developer") -> "Jason(50), John(50), Ashley(0)"',
                'top_n_workers(1, "Junior Developer") -> "Jason(50)"',
                'top_n_workers(3, "Junior Developer") -> "Jason(350), Ashley(100), John(50)"',
                'top_n_workers(3, "Middle Developer") -> ""',
            ),
        ),
        (
            "workers",
            3,
            (
                'promote("John", "Senior Developer", 500, 200) -> "success"',
                'promote("John", "Senior Developer", 350, 250) -> "invalid_request"',
                'calc_salary("John", 0, 500) -> "35000"',
                'top_n_workers(3, "Senior Developer") -> "John(0)"',
                'calc_salary("John", 900, 1400) -> "0"',
            ),
        ),
    ],
)
def test_spec_shows_worked_example(problem: str, level: int, needles: tuple[str, ...]) -> None:
    text = (repo_root() / "problems" / problem / "spec" / f"level{level}.md").read_text(
        encoding="utf-8"
    )
    missing = [needle for needle in needles if needle not in text]
    assert missing == []


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
    assert report.failed
    assert "NoSuchMethod" not in str(report.failed[0].actual)


def test_java_stubs_declare_methods() -> None:
    root = Path(__file__).resolve().parents[1] / "langs" / "java" / "problems"
    bank = (root / "bank_system" / "stub.java").read_text(encoding="utf-8")
    assert "public boolean createAccount(int timestamp, String accountId)" in bank
    db = (root / "in_memory_database" / "stub.java").read_text(encoding="utf-8")
    assert "public String set(String key, String field, String value)" in db
    files = (root / "file_storage" / "stub.java").read_text(encoding="utf-8")
    assert "public String addFile(String name, int size)" in files
    assert "public String copyFile(String source, String dest)" in files
    workers = (root / "workers" / "stub.java").read_text(encoding="utf-8")
    assert "public String addWorker(String workerId, String position, int compensation)" in workers
    assert "/**" in bank
    assert "id(outgoing)" in bank
    assert "/**" in db
    assert "field(value)" in db
    assert "/**" in files
    assert "name(size)" in files
    assert "/**" in workers
    assert "id(time)" in workers


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


def test_bash_bank_empty_top_spenders() -> None:
    report = run("bank_system", "bash", 2, "solution")
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


@pytest.mark.skipif(_GST is None, reason="gst not found")
def test_smalltalk_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "smalltalk", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


@pytest.mark.skipif(_GST is None, reason="gst not found")
def test_smalltalk_bank_stub_fails() -> None:
    report = run("bank_system", "smalltalk", 1, "stub")
    assert not report.ok


def test_clojure_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "clojure", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_clojure_bank_stub_fails() -> None:
    report = run("bank_system", "clojure", 1, "stub")
    assert not report.ok


def test_powershell_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "powershell", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_powershell_bank_stub_fails() -> None:
    report = run("bank_system", "powershell", 1, "stub")
    assert not report.ok


def test_shell_all_problems() -> None:
    for problem, level in (
        ("bank_system", 4),
        ("in_memory_database", 4),
        ("file_storage", 4),
        ("workers", 3),
    ):
        report = run(problem, "shell", level, "solution")
        assert report.passed > 0, report
        assert report.ok, report.failed


def test_shell_bank_stub_fails() -> None:
    report = run("bank_system", "shell", 1, "stub")
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


def test_unimplemented_catalog_lang_not_in_runners() -> None:
    assert UNIMPLEMENTED_CATALOG_LANG not in _RUNNERS


def test_run_unknown_language_is_not_implemented() -> None:
    adapter = language(UNIMPLEMENTED_CATALOG_LANG)["adapter"]
    try:
        run("bank_system", UNIMPLEMENTED_CATALOG_LANG, 1, "stub")
    except NotImplementedError as exc:
        msg = str(exc)
        assert UNIMPLEMENTED_CATALOG_LANG in msg
        assert "adapter=" in msg
        assert f"adapter={adapter}" in msg
        return
    raise AssertionError("expected NotImplementedError")


def test_run_compiled_writes_cases_inside_tmpdir() -> None:
    seen: dict[str, object] = {}

    def prepare(tmpdir: Path, cases_path: str) -> list[str]:
        seen["inside"] = Path(cases_path).resolve().is_relative_to(Path(tmpdir).resolve())
        raise RuntimeError("stop")

    with pytest.raises(RuntimeError, match="stop"):
        run_compiled("bank_system", "python3", 1, prepare)
    assert seen["inside"] is True


def test_report_from_proc_rejects_non_object_json() -> None:
    proc = subprocess.CompletedProcess(["adapter"], 0, stdout="[]\n", stderr="")
    with pytest.raises(RuntimeError, match="invalid JSON"):
        report_from_proc(proc, "bank_system", "java", 1)


def test_report_from_proc_rejects_passed_count_mismatch() -> None:
    proc = subprocess.CompletedProcess(
        ["adapter"], 0, stdout='{"passed": 99, "failed": []}\n', stderr=""
    )
    with pytest.raises(RuntimeError, match="mismatch") as excinfo:
        report_from_proc(proc, "bank_system", "python3", 1)
    text = str(excinfo.value)
    assert "99" in text
    assert "adapter report count mismatch" in text


def test_report_from_proc_reads_json_after_print_prefix() -> None:
    n = len(load_cases("bank_system", 1))
    glued = f'************500{{"passed": {n}, "failed": []}}\n'
    proc = subprocess.CompletedProcess(["adapter"], 0, stdout=glued, stderr="")
    report = report_from_proc(proc, "bank_system", "java", 1)
    assert report.ok
    assert report.passed == n
    assert "************500" in report.debug


def test_java_work_system_out_print_still_reports(monkeypatch, tmp_path: Path, capsys) -> None:
    from honepad.cli import main

    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset", "--no-console"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "java" / "Simulation.java"
    text = (
        repo_root() / "langs" / "java" / "problems" / "bank_system" / "solution.java"
    ).read_text(encoding="utf-8")
    needle = "int result = account.deposit(amount);"
    assert needle in text
    work.write_text(
        text.replace(
            needle,
            'System.out.print("************" + amount);\n        ' + needle,
            1,
        ),
        encoding="utf-8",
    )
    code = main(["run", "bank_system", "--lang", "java", "--level", "1"])
    out = capsys.readouterr().out
    assert code == 0, out
    assert "Expecting value" not in out
    assert "DEBUG:" in out
    assert "************" in out
    assert "passed=" in out


def test_report_from_proc_rejects_nonzero_empty_failed() -> None:
    n = len(load_cases("bank_system", 1))
    proc = subprocess.CompletedProcess(
        ["adapter"],
        1,
        stdout=f'{{"passed": {n}, "failed": []}}\n',
        stderr="adapter boom",
    )
    with pytest.raises(RuntimeError) as excinfo:
        report_from_proc(proc, "bank_system", "python3", 1)
    text = str(excinfo.value)
    assert "adapter boom" in text or "exited" in text
    assert "adapter report count mismatch" not in text


def test_run_script_removes_cases_file(monkeypatch) -> None:
    captured: dict[str, object] = {}

    def fake_run(argv, **_kwargs):
        captured["cases_path"] = argv[-1]
        captured["exists_during"] = Path(argv[-1]).is_file()
        n = len(load_cases("bank_system", 1))
        return subprocess.CompletedProcess(
            argv, 0, stdout=f'{{"passed": {n}, "failed": []}}\n', stderr=""
        )

    monkeypatch.setattr("honepad.runner.subprocess.run", fake_run)
    run_script("bank_system", "javascript", 1, "solution", ["node"])
    assert captured["exists_during"] is True
    assert not Path(str(captured["cases_path"])).exists()


def test_run_prepare_cmd_times_out() -> None:
    with pytest.raises(RuntimeError, match="timed out") as excinfo:
        run_prepare_cmd(
            [sys.executable, "-c", "import time; time.sleep(5)"],
            Path("."),
            "java",
            timeout=0.2,
        )
    assert "timed out" in str(excinfo.value)


def test_run_prepare_cmd_default_timeout_is_compile_budget() -> None:
    assert COMPILE_TIMEOUT_S > RUN_TIMEOUT_S
    assert run_prepare_cmd.__defaults__[-1] == COMPILE_TIMEOUT_S
