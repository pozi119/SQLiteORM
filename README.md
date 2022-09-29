# SQLiteORM
** [VVSequelize](https://github.com/pozi119/VVSequelize)的swift版本**

## 注意
1. SQLiteORM未在大型项目中使用,未经过严格测试,若遇到bug请自行修改或提交issue
2. 对swift的枚举类型支持并不完美, 目前编码为Int类型,按定义顺序从0依次递增, 请谨慎使用.
3. 大致用法请参考[VVSequelize](https://github.com/pozi119/VVSequelize)

## 改动(0.1.6)
1. 移除Where, OrderBy, GroupBy, Fields，直接使用String
2. 为String添加自定义运算符，用于生产各种SQL子句
3. 将各种查询、更新、删除条件改为闭包方式，可链式调用。

## 安装

```ruby
pod 'SQLiteORM', '~> 0.1.5'
pod 'Runtime', :git => 'https://github.com/wickwirew/Runtime.git' // The version in pods is 2.2.2, which requires 2.2.4
```

## Author

Valo, pozi119@163.com

## License

SQLiteORM is available under the MIT license. See the LICENSE file for more info.
