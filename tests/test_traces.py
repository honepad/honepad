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
