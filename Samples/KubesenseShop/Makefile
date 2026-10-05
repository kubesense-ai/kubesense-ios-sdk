# Kubesense Shop for iOS. The Xcode project is generated from project.yml (XcodeGen).

DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: project test ui-test benchmark

project:
	xcodegen generate

# Repository and catalog logic, no network.
test: project
	xcodebuild -project KubesenseShop.xcodeproj -scheme KubesenseShop -destination '$(DESTINATION)' \
		-only-testing:KubesenseShopTests test

# One full shopping journey against the sample API; places a real order.
ui-test: project
	xcodebuild -project KubesenseShop.xcodeproj -scheme KubesenseShop -destination '$(DESTINATION)' \
		-only-testing:KubesenseShopUITests test

# SDK overhead: launch and scrolling with the SDK off, RUM only, and every feature.
benchmark:
	DESTINATION='$(DESTINATION)' ./Benchmarks/run.sh
