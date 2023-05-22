Pod::Spec.new do |s|
  s.name             = 'SQLiteORM'
  s.version          = '0.2.2'
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
  
  s.default_subspec = 'cipher'
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
        'OTHER_SWIFT_FLAGS' => '$(inherited) -D SQLITE_HAS_CODEC -D SQLITE_ENABLE_FTS5',
        'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DSQLITE_ENABLE_FTS5',
        'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SQLITE_HAS_CODEC=1 SQLITE_ENABLE_FTS5=1',
        'HEADER_SEARCH_PATHS' => "{PODS_ROOT}/SQLCipher"
      }
  end

  s.subspec 'core' do |ss|
      ss.source_files = 'SQLiteORM/Core/**/*'
      ss.dependency 'AnyCoder', '~> 0.1.5'
      ss.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  end

  s.subspec 'fts' do |ss|
      ss.source_files = 'SQLiteORM/FTS/**/*'
      ss.public_header_files = 'SQLiteORM/FTS/**/*.h'
      ss.resource = ['SQLiteORM/Assets/PinYin.bundle']
      ss.dependency 'SQLiteORM/core'
      ss.pod_target_xcconfig = {
        'SWIFT_VERSION' => '5.0',
        'OTHER_SWIFT_FLAGS' => '-D SQLITEORM_FTS',
        'OTHER_CFLAGS' => '-DSQLITEORM_FTS',
        'GCC_PREPROCESSOR_DEFINITIONS' => 'SQLITEORM_FTS=1',
      }
  end

  s.subspec 'util' do |ss|
      ss.source_files = 'SQLiteORM/Util/**/*'
      ss.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  end
end
