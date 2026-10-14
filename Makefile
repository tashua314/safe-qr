.PHONY: check lint format

check:
	@scripts/check.sh

lint:
	@swiftlint lint --strict --no-cache
	@swiftformat SafeQR/SafeQR SafeQR/SafeQRTests SafeQR/SafeQRUITests --lint --cache ignore

format:
	@scripts/format.sh
