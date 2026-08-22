.PHONY: fmt validate plan destroy

fmt:
	terraform fmt --recursive

validate:
	@./scripts/validate-all.sh

plan:
	@./scripts/plan-all.sh

destroy:
	@./scripts/destroy-all.sh
