.PHONY: check lint format

check:
	@scripts/check.sh

lint:
	@scripts/lint.sh

format:
	@scripts/format.sh

.PHONY: tools
tools:
	./scripts/install-check-tools.sh
