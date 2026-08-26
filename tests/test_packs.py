from honepad.catalog import languages, repo_root


def test_every_language_has_bank_stub() -> None:
    root = repo_root()
    missing = []
    for row in languages():
        stub = root / "langs" / row["id"] / "problems" / "bank_system" / f"stub.{row['ext']}"
        if not stub.is_file():
            missing.append(str(stub))
    assert missing == []
