.PHONY: init plan apply destroy fmt validate clean

TOFU_DIR := tofu

## Initialize OpenTofu working directory
init:
	tofu -chdir=$(TOFU_DIR) init

## Preview infrastructure changes
plan:
	tofu -chdir=$(TOFU_DIR) plan

## Apply infrastructure changes
apply:
	tofu -chdir=$(TOFU_DIR) apply

## Destroy all managed infrastructure
destroy:
	tofu -chdir=$(TOFU_DIR) destroy

## Format all .tf files
fmt:
	tofu -chdir=$(TOFU_DIR) fmt -recursive

## Validate configuration files
validate:
	tofu -chdir=$(TOFU_DIR) validate

## Run format check and validation (used in CI)
check: fmt validate

## Remove local .terraform directories and lock files
clean:
	rm -rf $(TOFU_DIR)/.terraform $(TOFU_DIR)/.terraform.lock.hcl

## Full setup: init + validate
setup: init validate
