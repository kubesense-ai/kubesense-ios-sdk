Pod::Spec.new do |s|
  s.name         = "KubesenseFlags"
  s.version      = "1.0.0"
  s.summary      = "Official Kubesense Feature Flags module of the Swift SDK."

  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '5.9'
  s.ios.deployment_target = '15.0'
  s.tvos.deployment_target = '15.0'
  s.watchos.deployment_target = '9.0'
  s.visionos.deployment_target = '1.0'

  s.source = { :git => "https://github.com/kubesense-ai/kubesense-ios-sdk.git", :tag => s.version.to_s }

  s.source_files = "KubesenseFlags/Sources/**/*.swift"

  s.dependency 'KubesenseInternal', s.version.to_s

end
