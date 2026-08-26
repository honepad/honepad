#!/usr/bin/env python3
"""Write JSON traces ported from public LibreSignal pytest (MIT)."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def dump(problem: str, cases: list[dict]) -> None:
    dest = ROOT / "problems" / problem / "cases"
    dest.mkdir(parents=True, exist_ok=True)
    by_level: dict[int, list] = {}
    for case in cases:
        by_level.setdefault(case["level"], []).append(case)
    for level, group in by_level.items():
        path = dest / f"level{level}.json"
        path.write_text(json.dumps(group, indent=2) + "\n", encoding="utf-8")
        print(path, len(group))


def c(mid: str, level: int, calls: list) -> dict:
    return {"id": mid, "level": level, "calls": calls}


def call(m, *a, e=None):
    return {"m": m, "a": list(a), "e": e}


def bank() -> list[dict]:
    return [
        c(
            "l1-create",
            1,
            [
                call("create_account", 1, "acc1", e=True),
                call("create_account", 2, "acc1", e=False),
                call("create_account", 3, "acc2", e=True),
            ],
        ),
        c(
            "l1-deposit",
            1,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 500, e=500),
                call("deposit", 3, "acc1", 300, e=800),
                call("deposit", 4, "non_existent", 100, e=None),
            ],
        ),
        c(
            "l1-transfer",
            1,
            [
                call("create_account", 1, "acc1", e=True),
                call("create_account", 2, "acc2", e=True),
                call("deposit", 3, "acc1", 1000, e=1000),
                call("transfer", 4, "acc1", "acc2", 300, e=700),
                call("transfer", 5, "acc1", "acc2", 800, e=None),
                call("transfer", 6, "acc1", "non_existent", 100, e=None),
                call("transfer", 7, "acc1", "acc1", 100, e=None),
            ],
        ),
        c(
            "l1-spec",
            1,
            [
                call("create_account", 1, "account1", e=True),
                call("create_account", 2, "account1", e=False),
                call("create_account", 3, "account2", e=True),
                call("deposit", 4, "non_existent", 100, e=None),
                call("deposit", 5, "account1", 2700, e=2700),
                call("transfer", 6, "account1", "account2", 2701, e=None),
                call("transfer", 7, "account1", "account2", 200, e=2500),
            ],
        ),
        c(
            "l2-empty",
            2,
            [
                call("top_spenders", 1, 0, e=[]),
                call("top_spenders", 2, 5, e=[]),
            ],
        ),
        c(
            "l2-single",
            2,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("create_account", 3, "acc2", e=True),
                call("transfer", 4, "acc1", "acc2", 500, e=500),
                call("top_spenders", 5, 1, e=["acc1(500)"]),
            ],
        ),
        c(
            "l2-tie",
            2,
            [
                call("create_account", 1, "acc1", e=True),
                call("create_account", 2, "acc2", e=True),
                call("create_account", 3, "acc3", e=True),
                call("deposit", 4, "acc1", 1000, e=1000),
                call("deposit", 5, "acc2", 1500, e=1500),
                call("deposit", 6, "acc3", 1200, e=1200),
                call("transfer", 8, "acc2", "acc3", 500, e=1000),
                call("transfer", 7, "acc1", "acc2", 500, e=500),
                call("transfer", 9, "acc3", "acc1", 300, e=1400),
                call("top_spenders", 10, 3, e=["acc1(500)", "acc2(500)", "acc3(300)"]),
            ],
        ),
        c(
            "l3-pay-missing",
            3,
            [
                call("pay", 1, "non_existent", 100, e=None),
                call("get_payment_status", 2, "non_existent", "payment1", e=None),
            ],
        ),
        c(
            "l3-pay-funds",
            3,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 100, e=100),
                call("pay", 3, "acc1", 200, e=None),
            ],
        ),
        c(
            "l3-pay-ids",
            3,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("pay", 3, "acc1", 500, e="payment1"),
                call("pay", 4, "acc1", 300, e="payment2"),
                call("create_account", 5, "acc2", e=True),
                call("deposit", 6, "acc2", 800, e=800),
                call("transfer", 7, "acc2", "acc1", 200, e=600),
                call("top_spenders", 8, 2, e=["acc1(800)", "acc2(200)"]),
            ],
        ),
        c(
            "l3-status-missing-payment",
            3,
            [
                call("create_account", 1, "acc1", e=True),
                call("get_payment_status", 2, "acc1", "payment1", e=None),
            ],
        ),
        c(
            "l3-status-wrong-account",
            3,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("pay", 3, "acc1", 500, e="payment1"),
                call("create_account", 4, "acc2", e=True),
                call("get_payment_status", 5, "acc2", "payment1", e=None),
            ],
        ),
        c(
            "l3-cashback",
            3,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("pay", 3, "acc1", 500, e="payment1"),
                call("get_payment_status", 4, "acc1", "payment1", e="IN_PROGRESS"),
                call(
                    "get_payment_status",
                    24 * 60 * 60 * 1000 + 3,
                    "acc1",
                    "payment1",
                    e="CASHBACK_RECEIVED",
                ),
                call("deposit", 28 * 60 * 60 * 1000, "acc1", 0, e=510),
            ],
        ),
        c(
            "l4-merge-missing-1",
            4,
            [
                call("create_account", 1, "acc2", e=True),
                call("merge_accounts", 2, "acc1", "acc2", e=False),
            ],
        ),
        c(
            "l4-merge-missing-2",
            4,
            [
                call("create_account", 1, "acc1", e=True),
                call("merge_accounts", 2, "acc1", "acc2", e=False),
            ],
        ),
        c(
            "l4-merge-cashback",
            4,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("pay", 3, "acc1", 500, e="payment1"),
                call("create_account", 4, "acc2", e=True),
                call("merge_accounts", 5, "acc2", "acc1", e=True),
                call("get_payment_status", 6, "acc2", "payment1", e="IN_PROGRESS"),
                call(
                    "get_payment_status",
                    24 * 60 * 60 * 1000 + 3,
                    "acc2",
                    "payment1",
                    e="CASHBACK_RECEIVED",
                ),
                call("deposit", 24 * 60 * 60 * 1000 + 5, "acc2", 0, e=510),
            ],
        ),
        c(
            "l4-merge-top",
            4,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("pay", 3, "acc1", 500, e="payment1"),
                call("create_account", 4, "acc2", e=True),
                call("deposit", 5, "acc2", 2000, e=2000),
                call("pay", 6, "acc2", 800, e="payment2"),
                call("merge_accounts", 7, "acc1", "acc2", e=True),
                call("top_spenders", 8, 1, e=["acc1(1300)"]),
            ],
        ),
        c(
            "l4-history",
            4,
            [
                call("create_account", 1, "acc1", e=True),
                call("deposit", 2, "acc1", 1000, e=1000),
                call("pay", 3, "acc1", 300, e="payment1"),
                call("get_balance", 4, "acc1", 3, e=700),
                call("get_balance", 24 * 60 * 60 * 1000 + 5, "acc1", 24 * 60 * 60 * 1000 + 2, e=700),
                call("get_balance", 24 * 60 * 60 * 1000 + 5, "acc1", 24 * 60 * 60 * 1000 + 3, e=706),
            ],
        ),
    ]


def db() -> list[dict]:
    return [
        c(
            "db-l1-set-get",
            1,
            [
                call("set", "user1", "name", "Alice", e=""),
                call("set", "user1", "age", "30", e=""),
                call("get", "user1", "name", e="Alice"),
                call("get", "user1", "age", e="30"),
            ],
        ),
        c(
            "db-l1-overwrite",
            1,
            [
                call("set", "user1", "name", "Alice", e=""),
                call("set", "user1", "name", "Bob", e=""),
                call("get", "user1", "name", e="Bob"),
            ],
        ),
        c(
            "db-l1-missing",
            1,
            [
                call("get", "user1", "field", e=""),
                call("set", "user1", "name", "Alice", e=""),
                call("get", "user1", "non_existent", e=""),
            ],
        ),
        c(
            "db-l1-delete",
            1,
            [
                call("set", "user1", "name", "Alice", e=""),
                call("delete", "user1", "name", e="true"),
                call("get", "user1", "name", e=""),
                call("delete", "user1", "name", e="false"),
                call("delete", "non_existent", "field", e="false"),
            ],
        ),
        c(
            "db-l2-scan",
            2,
            [
                call("set", "user1", "name", "Alice", e=""),
                call("set", "user1", "age", "30", e=""),
                call("set", "user1", "city", "NY", e=""),
                call("set", "user1", "abc", "123", e=""),
                call("scan", "user1", e="abc(123), age(30), city(NY), name(Alice)"),
                call("scan", "non_existent", e=""),
            ],
        ),
        c(
            "db-l2-prefix",
            2,
            [
                call("set", "user1", "name", "Alice", e=""),
                call("set", "user1", "age", "30", e=""),
                call("set", "user1", "city", "NY", e=""),
                call("set", "user1", "abc", "123", e=""),
                call("scan_by_prefix", "user1", "a", e="abc(123), age(30)"),
                call("scan_by_prefix", "user1", "n", e="name(Alice)"),
                call("scan_by_prefix", "user1", "xyz", e=""),
            ],
        ),
        c(
            "db-l3-set-at",
            3,
            [
                call("set_at", "user1", "name", "Alice", 100, e=""),
                call("set_at", "user1", "age", "30", 101, e=""),
                call("get_at", "user1", "name", 102, e="Alice"),
                call("get_at", "user1", "age", 103, e="30"),
            ],
        ),
        c(
            "db-l3-get-missing",
            3,
            [
                call("get_at", "user2", "name", 100, e=""),
                call("get_at", "user1", "non_existent", 101, e=""),
            ],
        ),
        c(
            "db-l3-ttl",
            3,
            [
                call("set_at_with_ttl", "user1", "name", "Alice", 100, 10, e=""),
                call("get_at", "user1", "name", 105, e="Alice"),
                call("get_at", "user1", "name", 110, e=""),
                call("get_at", "user1", "name", 115, e=""),
            ],
        ),
        c(
            "db-l3-ttl-overwrite-none",
            3,
            [
                call("set_at_with_ttl", "user1", "name", "Alice", 100, 10, e=""),
                call("set_at", "user1", "name", "Bob", 105, e=""),
                call("get_at", "user1", "name", 110, e="Bob"),
                call("get_at", "user1", "name", 140, e="Bob"),
            ],
        ),
        c(
            "db-l3-ttl-overwrite",
            3,
            [
                call("set_at_with_ttl", "user1", "name", "Alice", 100, 10, e=""),
                call("get_at", "user1", "name", 105, e="Alice"),
                call("set_at_with_ttl", "user1", "name", "Bob", 106, 10, e=""),
                call("get_at", "user1", "name", 110, e="Bob"),
                call("get_at", "user1", "name", 117, e=""),
            ],
        ),
        c(
            "db-l3-scan-at",
            3,
            [
                call("set_at_with_ttl", "user1", "name", "Alice", 100, 10, e=""),
                call("set_at_with_ttl", "user1", "age", "30", 101, 5, e=""),
                call("set_at_with_ttl", "user1", "city", "NY", 102, 15, e=""),
                call("scan_at", "user1", 105, e="age(30), city(NY), name(Alice)"),
                call("scan_at", "user1", 106, e="city(NY), name(Alice)"),
                call("scan_at", "user1", 110, e="city(NY)"),
                call("scan_at", "user1", 116, e="city(NY)"),
                call("scan_at", "user1", 117, e=""),
            ],
        ),
        c(
            "db-l3-scan-ignores-ttl",
            3,
            [
                call("set_at_with_ttl", "user1", "name", "Alice", 100, 10, e=""),
                call("set_at_with_ttl", "user1", "age", "30", 101, 5, e=""),
                call("set_at_with_ttl", "user1", "city", "NY", 102, 15, e=""),
                call("scan", "user1", e="age(30), city(NY), name(Alice)"),
            ],
        ),
        c(
            "db-l3-prefix-at",
            3,
            [
                call("set_at_with_ttl", "user1", "name", "Alice", 100, 10, e=""),
                call("set_at_with_ttl", "user1", "age", "30", 101, 5, e=""),
                call("set_at_with_ttl", "user1", "city", "NY", 102, 15, e=""),
                call("set_at_with_ttl", "user1", "nationality", "free_country", 103, 5, e=""),
                call("scan_by_prefix_at", "user1", "a", 105, e="age(30)"),
                call("scan_by_prefix_at", "user1", "a", 106, e=""),
                call(
                    "scan_by_prefix_at",
                    "user1",
                    "n",
                    107,
                    e="name(Alice), nationality(free_country)",
                ),
                call("scan_by_prefix_at", "user1", "n", 109, e="name(Alice)"),
            ],
        ),
        c(
            "db-l4-backup-count",
            4,
            [
                call("set_at_with_ttl", "A", "B", "C", 1, 10, e=""),
                call("backup", 3, e="1"),
            ],
        ),
        c(
            "db-l4-backup-expired",
            4,
            [
                call("set_at_with_ttl", "A", "B", "C", 1, 10, e=""),
                call("backup", 12, e="0"),
            ],
        ),
        c(
            "db-l4-restore",
            4,
            [
                call("set_at_with_ttl", "A", "B", "C", 1, 10, e=""),
                call("backup", 3, e="1"),
                call("set_at", "A", "D", "E", 4, e=""),
                call("backup", 5, e="1"),
                call("delete_at", "A", "B", 8, e="true"),
                call("backup", 9, e="1"),
                call("restore", 10, 7, e=""),
                call("set_at", "B", "C", "D", 11, e=""),
                call("scan_at", "A", 15, e="B(C), D(E)"),
                call("scan_at", "A", 16, e="D(E)"),
                call("scan_at", "B", 17, e="C(D)"),
            ],
        ),
    ]


def main() -> None:
    dump("bank_system", bank())
    dump("in_memory_database", db())


if __name__ == "__main__":
    main()
