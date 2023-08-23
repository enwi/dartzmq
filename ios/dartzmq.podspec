Pod::Spec.new do |s|
  s.name             = 'dartzmq'
  s.version          = '1.0.0-dev.15'
  s.summary          = 'A simple dart zeromq implementation/wrapper around the libzmq C++ library'
  s.description      = <<-DESC
A simple dart zeromq implementation/wrapper around the libzmq C++ library.
                       DESC
  s.homepage         = 'https://github.com/enwi/dartzmq'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'wirmo' => 'contact@wirmo.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '11.0'
  s.swift_version    = '5.0'

  # Exclude i386 and arm64 from iOS Simulator build
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.pod_target_xcconfig = { "OTHER_LDFLAGS" => "$(inherited) -force_load $(PODS_TARGET_SRCROOT)/Frameworks/libzmq.a -lstdc++" }

end
