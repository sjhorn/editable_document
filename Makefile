.PHONY: analyze test golden-update coverage docs benchmark

analyze:
	dart format --line-length 100 --set-exit-if-changed .
	flutter analyze --fatal-infos

test:
	flutter test

golden-update:
	flutter test --update-goldens --tags golden

coverage:
	flutter test --coverage
	@echo "Coverage report at coverage/lcov.info"

docs:
	dart doc --validate-links

benchmark:
	@if [ -d benchmark ]; then \
		dart run benchmark/; \
	else \
		echo "No benchmark/ directory yet."; \
	fi
