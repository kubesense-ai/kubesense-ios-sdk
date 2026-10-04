Pod::Spec.new do |s|
  s.name         = "TestUtilities"
  s.version      = "1.0.0"
  s.summary      = "Kubesense Testing Utilities. This module is for internal testing and should not be published."

  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '5.9'
  s.ios.deployment_target = '15.0'
  s.tvos.deployment_target = '15.0'

  s.source = { :git => "https://github.com/kubesense-ai/kubesense-ios-sdk.git", :tag => s.version.to_s }

  s.pod_target_xcconfig = {
    'ENABLE_TESTING_SEARCH_PATHS'=>'YES'
  }

  s.framework = 'XCTest'

  s.source_files = [
    "TestUtilities/Sources/**/*.swift"
  ]

  s.dependency 'KubesenseCore'
  s.dependency 'KubesenseInternal'
  s.dependency 'KubesenseLogs'
  s.dependency 'KubesenseRUM'
  s.dependency 'KubesenseSessionReplay'
  s.dependency 'KubesenseTrace'
  s.dependency 'KubesenseCrashReporting'
  s.dependency 'KubesenseWebViewTracking'

end