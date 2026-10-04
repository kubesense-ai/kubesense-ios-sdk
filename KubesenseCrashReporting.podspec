Pod::Spec.new do |s|
  s.name         = "KubesenseCrashReporting"
  s.version      = "1.0.0"
  s.summary      = "Official Kubesense Crash Reporting SDK for iOS."

  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '5.9'
  s.ios.deployment_target = '15.0'
  # iOS only for now. tvOS, visionOS and watchOS are planned; upstream declares them.

  s.source = { :git => 'https://github.com/kubesense-ai/kubesense-ios-sdk.git', :tag => s.version.to_s }

  s.source_files = "KubesenseCrashReporting/Sources/**/*.swift"
  s.dependency 'KubesenseInternal', s.version.to_s
  s.dependency 'KSCrash/Recording', '2.5.1'
  s.dependency 'KSCrash/Filters', '2.5.1'

  s.resource_bundle = {
    "KubesenseCrashReporting" => "KubesenseCrashReporting/Resources/PrivacyInfo.xcprivacy"
  }
end
