Pod::Spec.new do |s|
  s.name             = 'SQLiteORM'
  s.version          = '0.1.0-beta1'
  s.summary          = 'The swift version of VVSequelize.'

  s.description      = <<-DESC
                       The swift version of VVSequelize.
                       DESC

  s.homepage         = 'https://github.com/pozi119/SQLiteORM'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Valo Lee' => 'pozi119@163.com' }
  s.source           = { :git => 'https://github.com/pozi119/SQLiteORM.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.default_subspec = 'system'
  
  s.subspec 'system' do |ss|
      ss.dependency 'SQLiteORM/common'
      ss.libraries = 'sqlite3'
  end
  
  s.subspec 'cipher' do |ss|
      ss.dependency 'SQLiteORM/common'
      ss.dependency 'SQLCipher'
      ss.pod_target_xcconfig = {
          'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1',
          'HEADER_SEARCH_PATHS' => 'SQLCipher'
      }
  end

  s.subspec 'common' do |ss|
      ss.source_files = 'SQLiteORM/Classes/**/*'
      # ss.private_header_files = 'SQLiteORM/Classes/**/*.h'
      ss.public_header_files = 'SQLiteORM/Classes/**/*.h'
      ss.resource = ['SQLiteORM/Assets/Jieba.bundle','SQLiteORM/Assets/PinYin.bundle']
      ss.dependency 'Runtime'
      ss.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  end
end
