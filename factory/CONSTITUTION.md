# Constitution

Immutable. Changing this file requires a PR titled `chore: amend constitution`. Auto-merge is skipped for that title and for diffs that touch this file or `factory/scripts/assert-stealth.sh`.

1. **Stealth until the drop-stealth gate.** Empty GitHub description, no topics, no FUNDING, README is `# honepad` / `Not ready.` Stealth is a job inside `ci.yml` and a `needs:` of aggregator `CI`.
2. **Not a CodeSignal scrape.** Public practice traces only. No live assessment text.
3. **Apache-2.0.** DCO on every commit (`git commit -s`). No CLA.
4. **Independent org.** `honepad/honepad` only.
5. **Executable tests.** Traces fail CI before a language pack is claimed done. Impl + tests + related docs in the same commit.
6. **Find many, land few.** One session branch. At most one ready feature PR.
7. **Catalog is the language list.** Adding or removing a CodeSignal language is a catalog change plus a stub. The completeness test must stay green.
8. **No auto-merge** for release, publish, constitution amend, or stealth-script PRs.
9. **Methodology.** Constitution + `/design` + executable tests. Spec Kit is ritual only.
