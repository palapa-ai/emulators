Pod::Spec.new do |s|
  s.name             = 'emulator_palapa'
  s.version          = '0.0.1'
  s.summary          = 'libretro host for Palapa.'
  s.description      = 'Thin native host that pumps frames, audio and input from a libretro core.'
  s.homepage         = 'https://palapa.ai'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Palapa' => 'saad@palapa.ai' }
  s.source           = { :path => '.' }
  s.source_files     = 'emulator_palapa/Sources/**/*.{c,h,swift}'
  s.public_header_files = 'emulator_palapa/Sources/emulators_host/include/*.h'
  s.dependency         'FlutterMacOS'
  s.platform         = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
