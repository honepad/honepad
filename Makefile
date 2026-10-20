# pytest-cov is in the project venv. Ambient python3 often lacks it,
# and then the coverage floor never runs.
PYTHON := $(shell if [ -x .venv/bin/python3 ]; then echo .venv/bin/python3; else echo python3; fi)
# Homebrew ruff is not the CI pin. Prefer the venv binary when it exists.
RUFF := $(shell if [ -x .venv/bin/ruff ]; then echo .venv/bin/ruff; else echo ruff; fi)
PYTEST_COV := --cov=honepad --cov-fail-under=80 --cov-report=term

.PHONY: help install lint test stealth check

help: ## show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-16s %s\n", $$1, $$2}'

install: ## install package in editable mode
	python3 -m pip install -e ".[dev]"

lint: ## ruff
	$(RUFF) check src tests
	$(RUFF) format --check src tests

test: ## pytest
	bash factory/scripts/ensure-scala.sh
	$(PYTHON) -m pytest $(PYTEST_COV)

stealth: ## launch metadata
	bash factory/scripts/assert-stealth.sh honepad/honepad

check: ## local gate
	$(RUFF) check src tests
	$(RUFF) format --check src tests
	bash factory/scripts/ensure-scala.sh
	$(PYTHON) -m pytest $(PYTEST_COV)
	bash factory/scripts/assert-stealth.sh honepad/honepad
	bash factory/scripts/write-ledger.sh --self-test
	python3 factory/scripts/check-human-gate.py
