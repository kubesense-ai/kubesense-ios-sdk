Pod::Spec.new do |s|
  s.name         = "KubesenseProfiling"
  s.version      = "1.0.0"
  s.summary      = "Official Kubesense Profiling module of the Swift SDK."
  
  s.homepage     = "https://www.kubesense.ai"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { "Kubesense" => "info@kubesense.ai" }

  s.swift_version = '6.0'
  s.ios.deployment_target = '15.0'
  s.tvos.deployment_target = '15.0'
  s.visionos.deployment_target = '1.0'

  s.source = { :git => "https://github.com/kubesense-ai/kubesense-ios-sdk.git", :tag => s.version.to_s }
  
  s.source_files = ["KubesenseProfiling/Sources/**/*.swift",
                    "KubesenseProfiling/Mach/**/*.{h,c,cpp}"]
  
  s.private_header_files = ["KubesenseProfiling/Mach/**/*.h"]

  s.preserve_paths = "KubesenseProfiling/Mach/include/module.modulemap"

  s.dependency 'KubesenseInternal', s.version.to_s

  # Configure C++ compilation
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/KubesenseProfiling/Mach/include'
  }

end
