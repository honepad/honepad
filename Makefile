.PHONY: help install lint test stealth check

help: ## show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-16s %s\n", $$1, $$2}'

install: ## install package in editable mode
	python3 -m pip install -e ".[dev]"

lint: ## ruff
	ruff check src tests
	ruff format --check src tests

test: ## pytest
	bash factory/scripts/ensure-scala.sh
	python3 -m pytest

stealth: ## stealth metadata
	bash factory/scripts/assert-stealth.sh honepad/honepad

check: ## local gate
	ruff check src tests
	ruff format --check src tests
	bash factory/scripts/ensure-scala.sh
	python3 -m pytest
	bash factory/scripts/assert-stealth.sh honepad/honepad
	bash factory/scripts/write-ledger.sh --self-test
	python3 -c 'import json, subprocess, sys; state = json.load(open("factory/STATE.json")); result = subprocess.run(["bash", "factory/scripts/next-job.sh"], check=False); sys.exit(0 if result.returncode == 2 else 1) if state.get("human_gate") else sys.exit(0 if result.returncode == 0 else 1)'
