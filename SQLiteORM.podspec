Pod::Spec.new do |s|
  s.name             = 'SQLiteORM'
  s.version          = '0.1.3'
  s.summary          = 'The swift version of VVSequelize.'

  s.description      = <<-DESC
                       The swift version of VVSequelize.
                       DESC

  s.homepage         = 'https://github.com/pozi119/SQLiteORM'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Valo Lee' => 'pozi119@163.com' }
  s.source           = { :git => 'https://github.com/pozi119/SQLiteORM.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.watchos.deployment_target = '3.0'
  
  s.default_subspec = 'system'
  s.swift_version = '5.0'

  s.subspec 'system' do |ss|
      ss.dependency 'SQLiteORM/core'
      ss.dependency 'SQLiteORM/fts'
      ss.dependency 'SQLiteORM/util'
      ss.libraries = 'sqlite3'
  end
  
  s.subspec 'cipher' do |ss|
      ss.dependency 'SQLiteORM/core'
      ss.dependency 'SQLiteORM/fts'
      ss.dependency 'SQLiteORM/util'
      ss.dependency 'SQLCipher'
      ss.xcconfig = {
          'OTHER_CFLAGS' => '-DSQLITE_HAS_CODEC=1 -DHAVE_USLEEP=1',
          'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/SQLCipher'
      }
  end

  s.subspec 'core' do |ss|
      ss.source_files = 'SQLiteORM/Core/**/*'
      ss.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  end

  s.subspec 'fts' do |ss|
      ss.source_files = 'SQLiteORM/FTS/**/*'
      ss.public_header_files = 'SQLiteORM/FTS/**/*.h'
      ss.resource = ['SQLiteORM/Assets/PinYin.bundle']
      ss.dependency 'SQLiteORM/core'
      ss.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  end

  s.subspec 'util' do |ss|
      ss.source_files = 'SQLiteORM/Util/**/*'
      ss.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  end
end
