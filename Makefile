all: env-check repo-setup dependencies templates
.PHONY: env-check repo-setup dependencies clean templates \
		lint lint-cpp license-check \
		test test-ios test-ios-all test-tvos test-tvos-all test-visionos test-visionos-all \
		ui-test ui-test-all ui-test-podinstall \
		tools-test \
		smoke-test smoke-test-ios smoke-test-ios-all smoke-test-tvos smoke-test-tvos-all \
		spm-build spm-build-ios spm-build-tvos spm-build-visionos spm-build-macos spm-build-watchos \
		models-generate rum-models-generate sr-models-generate rc-models-generate models-verify rum-models-verify sr-models-verify rc-models-verify \
		api-surface spi-docs-build \
		profiling-protoc \
		release-build release-validate release-publish-github \
		release-publish-podspec release-publish-internal-podspecs release-publish-dependent-podspecs \
		set-ci-secret

REPO_ROOT := $(PWD)
include tools/utils/common.mk

# Default ENV for setting up the repo
DEFAULT_ENV := dev

env-check:
	@$(ECHO_TITLE) "make env-check"
	./tools/env-check.sh

repo-setup:
	@:$(eval ENV ?= $(DEFAULT_ENV))
	@$(ECHO_TITLE) "make repo-setup ENV='$(ENV)'"
	./tools/repo-setup/repo-setup.sh --env "$(ENV)"

dependencies:
	@$(ECHO_TITLE) "make dependencies"
	./tools/repo-setup/carthage-bootstrap.sh

clean:
	@$(ECHO_TITLE) "make clean"
	./tools/clean.sh --derived-data --pods --xcconfigs

clean-carthage:
	@$(ECHO_TITLE) "make clean-carthage"
	./tools/clean.sh --carthage

lint:
	@$(ECHO_TITLE) "make lint"
	./tools/lint/run-linter.sh

lint-cpp:
	@$(ECHO_TITLE) "make lint-cpp"
	./tools/lint/run-cpp-linter.sh

license-check:
	@$(ECHO_TITLE) "make license-check"
	./tools/license/check-license.sh

# Test env for running iOS tests in local:
DEFAULT_IOS_OS := latest
DEFAULT_IOS_PLATFORM := iOS Simulator
DEFAULT_IOS_DEVICE := iPhone 17 Pro

# Test env for running tvOS tests in local:
DEFAULT_TVOS_OS := latest
DEFAULT_TVOS_PLATFORM := tvOS Simulator
DEFAULT_TVOS_DEVICE := Apple TV

# Test env for running watchOS tests in local:
DEFAULT_WATCHOS_OS := latest
DEFAULT_WATCHOS_PLATFORM := watchOS Simulator
DEFAULT_WATCHOS_DEVICE := Apple Watch Series 11 (46mm)

# Test env for running visionOS tests in local:
DEFAULT_VISIONOS_OS := latest
DEFAULT_VISIONOS_PLATFORM := visionOS Simulator
DEFAULT_VISIONOS_DEVICE := Apple Vision Pro

# Default location for deploying artifacts
DEFAULT_ARTIFACTS_PATH := artifacts

# Whether Test Visibility product is enabled by default
DEFAULT_USE_TEST_VISIBILITY := 0

SKIP_OBJC_TYPES ?= TelemetryUsageEvent

# Run unit tests for specified SCHEME
test:
	@$(call require_param,SCHEME)
	@$(call require_param,OS)
	@$(call require_param,PLATFORM)
	@$(call require_param,DEVICE)
	@:$(eval USE_TEST_VISIBILITY ?= $(DEFAULT_USE_TEST_VISIBILITY))
	@$(ECHO_TITLE) "make test SCHEME='$(SCHEME)' OS='$(OS)' PLATFORM='$(PLATFORM)' DEVICE='$(DEVICE)' USE_TEST_VISIBILITY='$(USE_TEST_VISIBILITY)'"
	USE_TEST_VISIBILITY=$(USE_TEST_VISIBILITY) ./tools/test.sh --scheme "$(SCHEME)" --os "$(OS)" --platform "$(PLATFORM)" --device "$(DEVICE)"

# Run unit tests for specified SCHEME using iOS Simulator
test-ios:
	@$(call require_param,SCHEME)
	@:$(eval OS ?= $(DEFAULT_IOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_IOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_IOS_DEVICE))
	@$(MAKE) test SCHEME="$(SCHEME)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run unit tests for all iOS schemes
test-ios-all:
	@$(MAKE) test-ios SCHEME="KubesenseCore"
	@$(MAKE) test-ios SCHEME="KubesenseInternal"
	@$(MAKE) test-ios SCHEME="KubesenseRUM"
	@$(MAKE) test-ios SCHEME="KubesenseSessionReplay"
	@$(MAKE) test-ios SCHEME="KubesenseLogs"
	@$(MAKE) test-ios SCHEME="KubesenseTrace"
	@$(MAKE) test-ios SCHEME="KubesenseCrashReporting"
	@$(MAKE) test-ios SCHEME="KubesenseWebViewTracking"
	@$(MAKE) test-ios SCHEME="KubesenseFlags"
	@$(MAKE) test-ios SCHEME="KubesenseProfiling"
	@$(MAKE) test-ios SCHEME="KubesenseIntegrationTests"

# Run unit tests for specified SCHEME using tvOS Simulator
test-tvos:
	@$(call require_param,SCHEME)
	@:$(eval OS ?= $(DEFAULT_TVOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_TVOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_TVOS_DEVICE))
	@$(MAKE) test SCHEME="$(SCHEME)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run unit tests for all tvOS schemes
test-tvos-all:
	@$(MAKE) test-tvos SCHEME="KubesenseCore"
	@$(MAKE) test-tvos SCHEME="KubesenseInternal"
	@$(MAKE) test-tvos SCHEME="KubesenseRUM"
	@$(MAKE) test-tvos SCHEME="KubesenseLogs"
	@$(MAKE) test-tvos SCHEME="KubesenseTrace"
	@$(MAKE) test-tvos SCHEME="KubesenseCrashReporting"
	@$(MAKE) test-tvos SCHEME="KubesenseFlags"
	@$(MAKE) test-tvos SCHEME="KubesenseProfiling"
	@$(MAKE) test-tvos SCHEME="KubesenseIntegrationTests"

# Run unit tests for specified SCHEME using watchOS Simulator
test-watchos:
	@$(call require_param,SCHEME)
	@:$(eval OS ?= $(DEFAULT_WATCHOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_WATCHOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_WATCHOS_DEVICE))
	@$(MAKE) test SCHEME="$(SCHEME)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run unit tests for all watchOS schemes
test-watchos-all:
	@$(MAKE) test-watchos SCHEME="KubesenseCore"
	@$(MAKE) test-watchos SCHEME="KubesenseInternal"
	@$(MAKE) test-watchos SCHEME="KubesenseRUM"
	@$(MAKE) test-watchos SCHEME="KubesenseLogs"
	@$(MAKE) test-watchos SCHEME="KubesenseTrace"
	@$(MAKE) test-watchos SCHEME="KubesenseCrashReporting"
	@$(MAKE) test-watchos SCHEME="KubesenseFlags"
	@$(MAKE) test-watchos SCHEME="KubesenseIntegrationTests"

# Run unit tests for specified SCHEME using visionOS Simulator
test-visionos:
	@$(call require_param,SCHEME)
	@:$(eval OS ?= $(DEFAULT_VISIONOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_VISIONOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_VISIONOS_DEVICE))
	@$(MAKE) test SCHEME="$(SCHEME)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run unit tests for all visionOS schemes
test-visionos-all:
	@$(MAKE) test-visionos SCHEME="KubesenseCore"
	@$(MAKE) test-visionos SCHEME="KubesenseInternal"
	@$(MAKE) test-visionos SCHEME="KubesenseRUM"
	@$(MAKE) test-visionos SCHEME="KubesenseLogs"
	@$(MAKE) test-visionos SCHEME="KubesenseTrace"
	@$(MAKE) test-visionos SCHEME="KubesenseCrashReporting"
	@$(MAKE) test-visionos SCHEME="KubesenseWebViewTracking"
	@$(MAKE) test-visionos SCHEME="KubesenseFlags"
	@$(MAKE) test-visionos SCHEME="KubesenseProfiling"
	@$(MAKE) test-visionos SCHEME="KubesenseIntegrationTests"

# Run UI tests for specified TEST_PLAN
ui-test:
	@$(call require_param,TEST_PLAN)
	@:$(eval OS ?= $(DEFAULT_IOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_IOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_IOS_DEVICE))
	@$(ECHO_TITLE) "make ui-test TEST_PLAN='$(TEST_PLAN)' OS='$(OS)' PLATFORM='$(PLATFORM)' DEVICE='$(DEVICE)'"
	./tools/ui-test.sh --test-plan "$(TEST_PLAN)" --os "$(OS)" --platform "$(PLATFORM)" --device "$(DEVICE)"

# Run UI tests for all test plans
ui-test-all:
	@$(MAKE) ui-test TEST_PLAN="Default"
	@$(MAKE) ui-test TEST_PLAN="RUM"
	@$(MAKE) ui-test TEST_PLAN="CrashReporting"
	@$(MAKE) ui-test TEST_PLAN="NetworkInstrumentation"

# Update UI test project with latest SDK
ui-test-podinstall:
	@$(ECHO_TITLE) "make ui-test-podinstall"
	cd IntegrationTests/ && bundle exec pod install

# Run tests for repo tools
tools-test:
	@$(ECHO_TITLE) "make tools-test"
	./tools/tools-test.sh

# Run smoke tests
smoke-test:
	@$(call require_param,TEST_DIRECTORY)
	@$(call require_param,OS)
	@$(call require_param,PLATFORM)
	@$(call require_param,DEVICE)
	@$(ECHO_TITLE) "make smoke-test TEST_DIRECTORY='$(TEST_DIRECTORY)' OS='$(OS)' PLATFORM='$(PLATFORM)' DEVICE='$(DEVICE)'"
	./tools/smoke-test.sh --test-directory "$(TEST_DIRECTORY)" --os "$(OS)" --platform "$(PLATFORM)" --device "$(DEVICE)"

# Run smoke tests for specified TEST_DIRECTORY using iOS Simulator
smoke-test-ios:
	@$(call require_param,TEST_DIRECTORY)
	@:$(eval OS ?= $(DEFAULT_IOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_IOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_IOS_DEVICE))
	@$(MAKE) smoke-test TEST_DIRECTORY="$(TEST_DIRECTORY)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run all smoke tests using iOS Simulator
smoke-test-ios-all:
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/spm"
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/spm-6"
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/carthage"
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/cocoapods"
	@$(MAKE) smoke-test-ios TEST_DIRECTORY="SmokeTests/xcframeworks"

# Run smoke tests for specified TEST_DIRECTORY using tvOS Simulator
smoke-test-tvos:
	@$(call require_param,TEST_DIRECTORY)
	@:$(eval OS ?= $(DEFAULT_TVOS_OS))
	@:$(eval PLATFORM ?= $(DEFAULT_TVOS_PLATFORM))
	@:$(eval DEVICE ?= $(DEFAULT_TVOS_DEVICE))
	@$(MAKE) smoke-test TEST_DIRECTORY="$(TEST_DIRECTORY)" OS="$(OS)" PLATFORM="$(PLATFORM)" DEVICE="$(DEVICE)"

# Run all smoke tests using tvOS Simulator
smoke-test-tvos-all:
	@$(MAKE) smoke-test-tvos TEST_DIRECTORY="SmokeTests/spm"
	@$(MAKE) smoke-test-tvos TEST_DIRECTORY="SmokeTests/spm-6"
	@$(MAKE) smoke-test-tvos TEST_DIRECTORY="SmokeTests/carthage"
	@$(MAKE) smoke-test-tvos TEST_DIRECTORY="SmokeTests/cocoapods"
	@$(MAKE) smoke-test-tvos TEST_DIRECTORY="SmokeTests/xcframeworks"

# Builds SPM package SCHEME for specified DESTINATION
spm-build:
	@$(call require_param,SCHEME)
	@$(call require_param,DESTINATION)
	@$(ECHO_TITLE) "make spm-build SCHEME='$(SCHEME)' DESTINATION='$(DESTINATION)'"
	./tools/spm-build.sh --scheme "$(SCHEME)" --destination "$(DESTINATION)"

# Builds SPM package for iOS
spm-build-ios:
	@$(MAKE) spm-build SCHEME="Kubesense-Package" DESTINATION="generic/platform=ios"

# Builds SPM package for tvOS
spm-build-tvos:
	@$(MAKE) spm-build SCHEME="Kubesense-Package" DESTINATION="generic/platform=tvOS"

# Builds SPM package for visionOS
spm-build-visionos:
	@$(MAKE) spm-build SCHEME="Kubesense-Package" DESTINATION="generic/platform=visionOS"

# Builds SPM package for watchOS
spm-build-watchos:
	# Build only compatible schemes for watchOS:
	@$(MAKE) spm-build SCHEME="Kubesense-Package" DESTINATION="generic/platform=watchOS"

# Builds SPM package for macOS (and Mac Catalyst)
spm-build-macos:
	# Whole package for Mac Catalyst:
	@$(MAKE) spm-build SCHEME="Kubesense-Package" DESTINATION="platform=macOS,variant=Mac Catalyst"
	# Only compatible schemes for macOS:
	@$(MAKE) spm-build DESTINATION="platform=macOS" SCHEME="KubesenseCore"
	@$(MAKE) spm-build DESTINATION="platform=macOS" SCHEME="KubesenseLogs"
	@$(MAKE) spm-build DESTINATION="platform=macOS" SCHEME="KubesenseTrace"
	@$(MAKE) spm-build DESTINATION="platform=macOS" SCHEME="KubesenseCrashReporting"

xcodeproj-session-replay:
		@echo "⚙️  Generating 'KubesenseSessionReplay.xcodeproj'..."
		@cd KubesenseSessionReplay/ && swift package generate-xcodeproj
		@echo "OK 👌"

templates:
	@$(ECHO_TITLE) "make templates"
	./tools/xcode-templates/install-xcode-templates.sh

# Generate data models from rum-events-format ('rum', 'sr') or kubesense-go ('rc')
models-generate:
	@$(call require_param,PRODUCT) # 'rum', 'sr', or 'rc'
	@$(call require_param,GIT_REF)
	@$(ECHO_TITLE) "make models-generate PRODUCT='$(PRODUCT)' GIT_REF='$(GIT_REF)'"
	./tools/rum-models-generator/run.py generate $(PRODUCT) --git_ref=$(GIT_REF) --skip_objc $(SKIP_OBJC_TYPES)

# Validate data models against rum-events-format ('rum', 'sr') or kubesense-go ('rc')
models-verify:
	@$(call require_param,PRODUCT) # 'rum', 'sr', or 'rc'
	@$(ECHO_TITLE) "make models-verify PRODUCT='$(PRODUCT)'"
	./tools/rum-models-generator/run.py verify $(PRODUCT) --skip_objc $(SKIP_OBJC_TYPES)

# Generate RUM data models
rum-models-generate:
	@:$(eval GIT_REF ?= master)
	@$(MAKE) models-generate PRODUCT="rum" GIT_REF="$(GIT_REF)"

# Validate RUM data models
rum-models-verify:
	@$(MAKE) models-verify PRODUCT="rum"

# Generate SR data models
sr-models-generate:
	@:$(eval GIT_REF ?= master)
	@$(MAKE) models-generate PRODUCT="sr" GIT_REF="$(GIT_REF)"

# Validate SR data models
sr-models-verify:
	@$(MAKE) models-verify PRODUCT="sr"

# Generate RC data models (uses gh CLI to authenticate against the private kubesense-go repo)
rc-models-generate:
	@:$(eval GIT_REF ?= prod)
	GITHUB_TOKEN="$$(gh auth token)" $(MAKE) models-generate PRODUCT="rc" GIT_REF="$(GIT_REF)"

# Validate RC data models (uses gh CLI to authenticate against the private kubesense-go repo)
rc-models-verify:
	GITHUB_TOKEN="$$(gh auth token)" $(MAKE) models-verify PRODUCT="rc"

# Generate profiling protobuf-c files from pprof proto
protoc-pprof:
	@$(ECHO_TITLE) "protoc-pprof"
	./tools/protoc-pprof.sh --proto-path KubesenseProfiling/Protos/profile.proto --output-dir KubesenseProfiling/Mach

# Define default paths for API output files
SWIFT_OUTPUT_PATH ?= api-surface-swift
OBJC_OUTPUT_PATH ?= api-surface-objc

# Use different paths when running in CI
ifeq ($(ENV),ci)
  SWIFT_OUTPUT_PATH := api-surface-swift-generated
  OBJC_OUTPUT_PATH := api-surface-objc-generated
endif

# Define the list of Kubesense modules for API surface generation
KUBESENSE_MODULES := KubesenseCore KubesenseLogs KubesenseTrace KubesenseRUM KubesenseCrashReporting KubesenseWebViewTracking KubesenseSessionReplay KubesenseFlags KubesenseProfiling

# Generate api-surface files for Kubesense APIs.
# Builds and parses each module once, emitting both the Swift and ObjC surfaces in a single run.
api-surface:
	@$(ECHO_TITLE) "make api-surface"
	@echo "Generating api-surface (swift + objc)"
	@cd tools/api-surface && \
		swift run api-surface generate \
		--path ../../ \
		$(foreach module,$(KUBESENSE_MODULES),--library-name $(module)) \
		--language swift --output-file ../../$(SWIFT_OUTPUT_PATH) \
		--language objc --output-file ../../$(OBJC_OUTPUT_PATH)

# Verify API surface files for Kubesense APIs (Swift + ObjC) in a single run.
api-surface-verify:
	@$(ECHO_TITLE) "make api-surface-verify"
	@echo "Verifying api-surface (swift + objc)"
	@cd tools/api-surface && \
		swift run api-surface verify \
		--path ../../ \
		$(foreach module,$(KUBESENSE_MODULES),--library-name $(module)) \
		--language swift --output-file /tmp/api-surface-swift-generated --reference-file ../../api-surface-swift \
		--language objc --output-file /tmp/api-surface-objc-generated --reference-file ../../api-surface-objc

# Verify feature doc files are up to date
feature-docs-verify:
	@$(ECHO_TITLE) "make feature-docs-verify"
	@./tools/feature-docs-verify.sh

# Builds API documentation using the same process as Swift Package Index.
spi-docs-build:
	@$(ECHO_TITLE) "make spi-docs-build"
	./tools/doc-build.sh --spi-path .spi.yml

# Builds release artifacts for given tag
release-build:
	@$(call require_param,GIT_TAG)
	@$(call require_param,ARTIFACTS_PATH)
	@$(ECHO_TITLE) "make release-build GIT_TAG='$(GIT_TAG)' ARTIFACTS_PATH='$(ARTIFACTS_PATH)'"
	./tools/release/build.sh --tag "$(GIT_TAG)" --artifacts-path "$(ARTIFACTS_PATH)"

# Validate release artifacts for given tag
release-validate:
	@$(call require_param,GIT_TAG)
	@$(call require_param,ARTIFACTS_PATH)
	@$(ECHO_TITLE) "make release-validate GIT_TAG='$(GIT_TAG)' ARTIFACTS_PATH='$(ARTIFACTS_PATH)'"
	./tools/release/validate-version.sh --artifacts-path "$(ARTIFACTS_PATH)" --tag "$(GIT_TAG)"
	./tools/release/validate-xcframeworks.sh --artifacts-path "$(ARTIFACTS_PATH)"

# Publish GitHub asset to GH release
release-publish-github:
	@$(call require_param,GIT_TAG)
	@$(call require_param,ARTIFACTS_PATH)
	@:$(eval DRY_RUN ?= 1)
	@:$(eval OVERWRITE_EXISTING ?= 0)
	@$(ECHO_TITLE) "make release-publish-github GIT_TAG='$(GIT_TAG)' ARTIFACTS_PATH='$(ARTIFACTS_PATH)' DRY_RUN='$(DRY_RUN)' OVERWRITE_EXISTING='$(OVERWRITE_EXISTING)'"
	DRY_RUN=$(DRY_RUN) OVERWRITE_EXISTING=$(OVERWRITE_EXISTING) ./tools/release/publish-github.sh \
		 --artifacts-path "$(ARTIFACTS_PATH)" \
		 --tag "$(GIT_TAG)"

# Publish Cocoapods podspec to trunk
release-publish-podspec:
	@$(call require_param,PODSPEC_NAME)
	@$(call require_param,ARTIFACTS_PATH)
	@:$(eval DRY_RUN ?= 1)
	@$(ECHO_TITLE) "make release-publish-podspec PODSPEC_NAME='$(PODSPEC_NAME)' ARTIFACTS_PATH='$(ARTIFACTS_PATH)' DRY_RUN='$(DRY_RUN)'"
	DRY_RUN=$(DRY_RUN) ./tools/release/publish-podspec.sh \
		 --artifacts-path "$(ARTIFACTS_PATH)" \
		 --podspec-name "$(PODSPEC_NAME)"

# Publish KubesenseInternal podspec
release-publish-internal-podspecs:
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseInternal.podspec"

# Publish podspecs that depend on KubesenseInternal
release-publish-dependent-podspecs:
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseCore.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseLogs.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseTrace.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseRUM.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseSessionReplay.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseCrashReporting.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseWebViewTracking.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseFlags.podspec"
	@$(MAKE) release-publish-podspec PODSPEC_NAME="KubesenseProfiling.podspec"

# Set ot update CI secrets
set-ci-secret:
	@$(ECHO_TITLE) "make set-ci-secret"
	@./tools/secrets/set-secret.sh

bump:
	@read -p "Enter version number: " version;  \
	echo "// GENERATED FILE: Do not edit directly\n\ninternal let __sdkVersion = \"$$version\"" > KubesenseCore/Sources/Versioning.swift; \
	./tools/podspec_bump_version.sh $$version; \
	git add . ; \
	git commit -m "Bumped version to $$version"; \
	echo Bumped version to $$version
