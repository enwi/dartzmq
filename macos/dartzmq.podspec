#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint dartzmq.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'dartzmq'
  s.version          = '1.0.0-dev.15'
  s.summary          = 'A simple dart zeromq implementation/wrapper around the libzmq C++ library'
  s.description      = <<-DESC
A simple dart zeromq implementation/wrapper around the libzmq C++ library.
                       DESC
  s.homepage         = 'https://github.com/enwi/dartzmq'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'wirmo' => 'contact@wirmo.de' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.pod_target_xcconfig = { "OTHER_LDFLAGS" => "$(inherited) -force_load $(PODS_TARGET_SRCROOT)/Frameworks/$(ARCHS)/libzmq.a -lstdc++" }

end
