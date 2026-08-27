import json

from honepad.catalog import language, languages, load_catalog, repo_root, required_ids
from honepad.runner import _RUNNERS


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
    for lang in (
        "clojure",
        "haskell",
        "ocaml",
        "nim",
        "fortran",
        "fsharp",
        "smalltalk",
        "freepascal",
    ):
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
    assert language("java")["adapter"] == "javac"
    assert language("typescript")["adapter"] == "node"
    assert language("csharp")["adapter"] == "dotnet"
    assert language("kotlin")["adapter"] == "kotlinc"
    assert language("kotlin")["ci"] is True
    assert language("cpp")["adapter"] == "g++"
    assert language("cpp")["ci"] is True
    assert language("swift")["adapter"] == "swiftc"
    assert language("swift")["ci"] is True
    assert language("perl")["adapter"] == "perl"
    assert language("lua")["adapter"] == "lua"
    assert language("c")["adapter"] == "gcc"
    assert language("c")["ci"] is True
    assert language("tcl")["adapter"] == "tclsh"
    assert language("tcl")["ci"] is True
    assert language("r")["adapter"] == "Rscript"
    assert language("r")["ci"] is True
    assert language("octave")["adapter"] == "octave"
    assert language("octave")["ci"] is True
    assert language("nim")["adapter"] == "nim"
    assert language("nim")["ci"] is True
    assert language("groovy")["adapter"] == "groovy"
    assert language("groovy")["ci"] is True
    assert language("dart")["adapter"] == "dart"
    assert language("dart")["ci"] is True
    assert language("elixir")["adapter"] == "elixir"
    assert language("elixir")["ci"] is True
    assert language("erlang")["adapter"] == "escript"
    assert language("erlang")["ci"] is True
    assert language("haskell")["adapter"] == "ghc"
    assert language("haskell")["ci"] is True
    assert language("ocaml")["adapter"] == "ocamlopt"
    assert language("ocaml")["ci"] is True
    assert language("scala")["adapter"] == "scalac"
    assert language("scala")["ci"] is True
    assert language("d")["adapter"] == "gdc"
    assert language("d")["ci"] is True
    assert language("julia")["adapter"] == "julia"
    assert language("julia")["ci"] is True
    assert language("coffeescript")["adapter"] == "coffee"
    assert language("coffeescript")["ci"] is True
    assert language("bash")["adapter"] == "bash"
    assert language("bash")["ci"] is True
    assert language("common-lisp")["adapter"] == "sbcl"
    assert language("common-lisp")["ci"] is True
    assert language("fortran")["adapter"] == "gfortran"
    assert language("fortran")["ci"] is True
    assert language("fsharp")["adapter"] == "dotnet"
    assert language("fsharp")["ci"] is True
    assert language("freepascal")["adapter"] == "fpc"
    assert language("freepascal")["ci"] is True
    assert language("smalltalk")["adapter"] == "gst"
    assert language("smalltalk")["ci"] is True
    assert language("clojure")["adapter"] == "clojure"
    assert language("clojure")["ci"] is True
    assert language("powershell")["adapter"] == "pwsh"
    assert language("powershell")["ci"] is True
    assert language("shell")["adapter"] == "bash"
    assert language("shell")["ci"] is True


def test_implemented_langs_do_not_keep_adapter_stub() -> None:
    by_id = {row["id"]: row for row in languages()}
    assert _RUNNERS
    for lang_id in _RUNNERS:
        assert lang_id in by_id, lang_id
        assert by_id[lang_id].get("adapter") != "stub", lang_id
        meta = json.loads(
            (repo_root() / "langs" / lang_id / "meta.json").read_text(encoding="utf-8")
        )
        assert meta.get("adapter") != "stub", lang_id
    for row in languages():
        if row["id"] in _RUNNERS:
            assert row.get("adapter") != "stub", row["id"]
