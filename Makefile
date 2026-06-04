.PHONY: analyze test coverage integration-test

analyze:
	flutter analyze

test:
	flutter test

coverage:
	flutter test --coverage

# Requires a connected device or running emulator/simulator.
integration-test:
	scripts/integration_test.sh
