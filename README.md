# Honepad

Local CLI for public practice problems.

[![PyPI](https://img.shields.io/pypi/v/honepad?logo=pypi&logoColor=white)](https://pypi.org/project/honepad/)
[![Release](https://img.shields.io/github/v/release/honepad/honepad?logo=github&sort=semver)](https://github.com/honepad/honepad/releases/latest)
[![License](https://img.shields.io/github/license/honepad/honepad)](https://github.com/honepad/honepad/blob/main/LICENSE)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/14574/badge)](https://www.bestpractices.dev/projects/14574)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/honepad/honepad/badge)](https://securityscorecards.dev/viewer/?uri=github.com/honepad/honepad)
[![FOSSA](https://app.fossa.com/api/projects/custom%2B62586%2Fgithub.com%2Fhonepad%2Fhonepad.svg?type=shield&issueType=license)](https://app.fossa.com/projects/custom%2B62586%2Fgithub.com%2Fhonepad%2Fhonepad?ref=badge_shield&issueType=license)

![Honepad live console](demo/demo.gif)

Timed desks. You implement methods, run public tests, and unlock the
next level. Python 3, Java, C#, Go, JavaScript, TypeScript, and C++
run on Linux, macOS, native Windows, and Windows WSL. The other
language runners are tested on Ubuntu Linux.

This tree ships public practice problems only. It does not include
live assessment items. It is not affiliated with any interview vendor.

## Install

```bash
pip install honepad
```

Homebrew (tap, then trust on Homebrew 6+):

```bash
brew tap honepad/tap
brew trust honepad/tap
brew install honepad/tap/honepad
```

Scoop (add the org bucket first):

```powershell
scoop bucket add honepad https://github.com/honepad/scoop-bucket
scoop install honepad/honepad
```

`pip` is the primary channel. Homebrew and Scoop install the same
PyPI/GitHub Release wheel. There is no winget package yet (that
needs a Windows portable archive).

From a clone:

```bash
git clone https://github.com/honepad/honepad.git
cd honepad
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
```

## Start a desk

```bash
honepad start bank_system python3
```

That opens a live console. `1` runs public tests. `2` submits and
unlocks the next level. `q` quits.

`honepad langs` lists catalog languages. The last column is `runner`
or `no-runner`.

## Scope

These seven languages have a runner on Linux, macOS, native Windows,
and WSL: Python 3, Java, C#, Go, JavaScript, TypeScript, and C++.

Install the matching toolchain on that machine: a JDK for Java
(`javac` and `java`), `dotnet` for C#, `go` for Go, `node` for
JavaScript and TypeScript, and a C++ compiler (`c++`, `g++`,
`clang++`, or MSVC `cl`) for C++.

The other 31 runners are tested on Ubuntu CI.

Catalog ids without a runner: `objc`, `vb`, `angular-ts`,
`react-js`, `react-ts`, `vue-js`, `vue-ts`, `mysql`, `postgresql`,
`mssql`, `hack`, `mongodb`.

## License

Apache-2.0. See [LICENSE](LICENSE).
