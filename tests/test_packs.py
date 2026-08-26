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
