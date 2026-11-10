from honepad.catalog import languages, repo_root


def test_every_language_has_problem_stubs() -> None:
    root = repo_root()
    missing = []
    for problem in (
        "bank_system",
        "in_memory_database",
        "file_storage",
        "workers",
    ):
        for row in languages():
            stub = root / "langs" / row["id"] / "problems" / problem / f"stub.{row['ext']}"
            if not stub.is_file():
                missing.append(str(stub))
    assert missing == []


def test_file_storage_stubs_list_copy_when_they_list_add() -> None:
    """Level 1 traces call copy. A stub that lists add must list copy too."""
    root = repo_root()
    missing = []
    for row in languages():
        stub = root / "langs" / row["id"] / "problems" / "file_storage" / f"stub.{row['ext']}"
        if not stub.is_file():
            continue
        text = stub.read_text(encoding="utf-8")
        lists_add = "add_file" in text or "addFile" in text
        lists_copy = "copy_file" in text or "copyFile" in text
        if lists_add and not lists_copy:
            missing.append(row["id"])
    assert missing == []
