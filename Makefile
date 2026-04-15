.PHONY: help init plan apply apply-auto destroy destroy-auto fmt validate check clean setup output

TOFU_DIR := tofu

## Show this help message
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //' | paste - - | awk -F'\t' '{ printf "  %-20s %s\n", $$2, $$1 }'

## Initialize OpenTofu working directory
init:
	tofu -chdir=$(TOFU_DIR) init

## Preview infrastructure changes
plan:
	tofu -chdir=$(TOFU_DIR) plan

## Apply infrastructure changes (interactive)
apply:
	tofu -chdir=$(TOFU_DIR) apply

## Apply infrastructure changes (non-interactive)
apply-auto:
	tofu -chdir=$(TOFU_DIR) apply -auto-approve

## Destroy all managed infrastructure (interactive)
destroy:
	tofu -chdir=$(TOFU_DIR) destroy

## Destroy all managed infrastructure (non-interactive)
destroy-auto:
	tofu -chdir=$(TOFU_DIR) destroy -auto-approve

## Format all .tf files
fmt:
	tofu -chdir=$(TOFU_DIR) fmt -recursive

## Validate configuration files
validate:
	tofu -chdir=$(TOFU_DIR) validate

## Run format check and validation (used in CI)
check: fmt validate

## Show all outputs from the current state
output:
	tofu -chdir=$(TOFU_DIR) output

## Remove local .terraform directories and lock files
clean:
	rm -rf $(TOFU_DIR)/.terraform $(TOFU_DIR)/.terraform.lock.hcl

## Full setup: init + validate
setup: init validate
