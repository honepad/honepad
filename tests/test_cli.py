from honepad.cli import main


def test_langs(capsys) -> None:
    assert main(["langs"]) == 0
    out = capsys.readouterr().out
    assert "python3" in out
    assert "javascript" in out


def test_run_bank(capsys) -> None:
    assert main(["run", "bank_system", "--lang", "python3", "--level", "4"]) == 0
    assert "OK" in capsys.readouterr().out


def test_timer_does_not_sleep(capsys) -> None:
    assert main(["timer", "--minutes", "90"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=5400" in out
    assert "NEXT:" in out


def test_run_unimplemented_catalog_lang_exits(capsys) -> None:
    code = main(["run", "bank_system", "--lang", "fortran", "--level", "1"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "fortran" in out
    assert "adapter=" in out
    assert "Traceback" not in out


def test_run_unknown_lang_id_exits(capsys) -> None:
    code = main(["run", "bank_system", "--lang", "notalang", "--level", "1"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "notalang" in out
    assert "Traceback" not in out
