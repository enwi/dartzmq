Pod::Spec.new do |s|
  s.name             = 'dartzmq'
  s.version          = '1.0.0-dev.18'
  s.summary          = 'A simple dart zeromq implementation/wrapper around the libzmq C++ library'
  s.description      = <<-DESC
A simple dart zeromq implementation/wrapper around the libzmq C++ library.
                       DESC
  s.homepage         = 'https://github.com/enwi/dartzmq'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'wirmo' => 'contact@wirmo.de' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '11.0'
  s.swift_version    = '5.0'

  # The bundled simulator archive supports x86_64 only.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64 i386',
    'OTHER_LDFLAGS' => "$(inherited) -force_load $(PODS_TARGET_SRCROOT)/Frameworks/libzmq.a -lstdc++",
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => "$(inherited) -force_load $(PODS_TARGET_SRCROOT)/Frameworks/libzmq_simulator.a -lstdc++"
  }

end
