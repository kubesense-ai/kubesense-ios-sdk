Pod::Spec.new do |s|
  s.name         = "KubesenseSessionReplay"
  s.version      = "1.0.0"
  s.summary      = "Official Kubesense Session Replay SDK for iOS."

  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '5.9'
  s.ios.deployment_target = '15.0'
  s.tvos.deployment_target = '15.0'

  s.source = { :git => "https://github.com/kubesense-ai/kubesense-ios-sdk.git", :tag => s.version.to_s }

  s.source_files = ["KubesenseSessionReplay/Sources/**/*.swift"]
  s.dependency 'KubesenseInternal', s.version.to_s
end
