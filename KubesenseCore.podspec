Pod::Spec.new do |s|
  s.name         = "KubesenseCore"
  s.version      = "1.0.0"
  s.summary      = "Official Kubesense Swift SDK for iOS."
  
  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '5.9'
  s.ios.deployment_target = '15.0'
  s.tvos.deployment_target = '15.0'
  s.watchos.deployment_target = '9.0'
  s.visionos.deployment_target = '1.0'

  s.source = { :git => "https://github.com/kubesense-ai/kubesense-ios-sdk.git", :tag => s.version.to_s }
  
  s.source_files = ["KubesenseCore/Sources/**/*.swift",
                    "KubesenseCore/Private/**/*.{h,m}"]

  s.resource_bundle = {
    "KubesenseCore" => "KubesenseCore/Resources/PrivacyInfo.xcprivacy"
  }

  s.dependency 'KubesenseInternal', s.version.to_s

end
