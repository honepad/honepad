from honepad.catalog import language, languages, load_catalog, required_ids


def test_required_ids_match_rows() -> None:
    catalog = load_catalog()
    ids = [row["id"] for row in catalog["languages"]]
    assert ids == required_ids()
    assert len(set(ids)) == len(ids)


def test_gca_and_ica_present() -> None:
    ids = {row["id"] for row in languages()}
    for lang in (
        "python3",
        "javascript",
        "java",
        "go",
        "rust",
        "cpp",
        "csharp",
        "kotlin",
        "php",
        "ruby",
        "swift",
        "typescript",
    ):
        assert lang in ids
        assert "ica" in language(lang)["suites"]
    for lang in ("clojure", "haskell", "ocaml", "nim", "fortran", "smalltalk"):
        assert lang in ids
        assert "gca" in language(lang)["suites"]
    for lang in ("mysql", "postgresql", "mssql", "react-ts", "vue-js", "angular-ts"):
        assert lang in ids


def test_python3_is_import_adapter() -> None:
    assert language("python3")["adapter"] == "python-import"
    assert language("python3")["ci"] is True
    assert language("javascript")["adapter"] == "node"
    assert language("go")["adapter"] == "go-run"
    assert language("rust")["adapter"] == "cargo-run"
    assert language("ruby")["adapter"] == "ruby"
    assert language("php")["adapter"] == "php"
