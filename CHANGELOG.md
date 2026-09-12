# Changelog

## [0.2.0](https://github.com/honepad/honepad/compare/v0.1.1...v0.2.0) (2026-09-12)


### Features

* prove seven languages on Linux, macOS, Windows, and WSL ([#261](https://github.com/honepad/honepad/issues/261)) ([9159b5b](https://github.com/honepad/honepad/commit/9159b5b755a4a8b11e92182f7e619e2a1078d22e))


### Bug Fixes

* read Go and C++ reports from a nonce file ([#267](https://github.com/honepad/honepad/issues/267)) ([d6caa31](https://github.com/honepad/honepad/commit/d6caa31803365c2aa994617fa870fe143f8be059))
* reject compiled fake-pass reports and accept C# JS TS tokens ([#265](https://github.com/honepad/honepad/issues/265)) ([955ddee](https://github.com/honepad/honepad/commit/955ddeedf194d0e5cc104dbb6a88760b334781e4))
* reject Go init and C++ static-init fake pass reports ([#266](https://github.com/honepad/honepad/issues/266)) ([d7eb01d](https://github.com/honepad/honepad/commit/d7eb01dbe7bbd3ad5598272a6b2270cce4e9900d)), closes [#264](https://github.com/honepad/honepad/issues/264)


### Documentation

* use Honepad in English sentences ([#263](https://github.com/honepad/honepad/issues/263)) ([d003a59](https://github.com/honepad/honepad/commit/d003a5904a12a7b1a19056c4ce54baffb0571ad2))

## [0.1.1](https://github.com/honepad/honepad/compare/v0.1.0...v0.1.1) (2026-09-11)


### Documentation

* add VHS live-console demo ([#250](https://github.com/honepad/honepad/issues/250)) ([a1036f2](https://github.com/honepad/honepad/commit/a1036f2ffed3aca1d9755368e99a418051ab3da0))
* retake VHS demo as start, pick, run, L4 win ([#252](https://github.com/honepad/honepad/issues/252)) ([7308e87](https://github.com/honepad/honepad/commit/7308e87744d783077471a6fe280de1c7e9a6c810))
* slow the VHS demo and hold the L4 win ([#253](https://github.com/honepad/honepad/issues/253)) ([c416c8f](https://github.com/honepad/honepad/commit/c416c8f40575cc42a969cae46aef2833a75015b7))
* use the live FOSSA license badge ([#258](https://github.com/honepad/honepad/issues/258)) ([c895521](https://github.com/honepad/honepad/commit/c89552196171967b06940f800b189349fc8344b9))

## [Unreleased]

- Use Honepad as the display name in English sentences
- Python 3, Java, C#, Go, JavaScript, TypeScript, and C++ desks
  on Linux, macOS, native Windows, and WSL
- VHS live-console demo on the README
- README badges for PyPI, Release, License, and Scorecard
- release-please on `main` with tag-time PyPI publish
- SLSA provenance and CycloneDX SBOM on GitHub Releases
- Docs-only PRs skip the language shards and OS compat matrix
- Accept C#, C++, JS, and TS as language tokens
- Reject compiled-lang constructor fake pass reports
- Reject Go init and C++ static-init fake pass reports
- Read Go and C++ adapter reports from a nonce file, not stdout
- Skip Compat on factory-only PRs

## [0.1.0] - 2026-09-11

First announced release.

- 38 language runners on Ubuntu CI
- python3 CLI on Linux, macOS, native Windows, and WSL
- Hidden cases through level 4 on the public desks
- OpenSSF Best Practices passing badge (project 14574)
- Hash-pinned CI installs, tag-only PyPI upload, lychee, stale,
  semantic PR titles, actionlint, zizmor, and test summaries

## [0.0.2] - 2026-09-09

PyPI squat. Description was `Reserved.` The wheel and sdist include
`langs/` and `problems/` under `honepad/_data`.
