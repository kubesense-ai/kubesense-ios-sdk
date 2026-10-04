Pod::Spec.new do |s|
  s.name         = "KubesenseCore"
  s.version      = "1.0.0"
  s.summary      = "Official Kubesense Swift SDK for iOS."
  
  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '5.9'
  s.ios.deployment_target = '15.0'
  # iOS only for now. tvOS, visionOS and watchOS are planned; upstream declares them.

  s.source = { :git => "https://github.com/kubesense-ai/kubesense-ios-sdk.git", :tag => s.version.to_s }
  
  s.source_files = ["KubesenseCore/Sources/**/*.swift",
                    "KubesenseCore/Private/**/*.{h,m}"]

  s.resource_bundle = {
    "KubesenseCore" => "KubesenseCore/Resources/PrivacyInfo.xcprivacy"
  }

  s.dependency 'KubesenseInternal', s.version.to_s

end
