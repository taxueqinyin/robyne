// 加载 browserify 打包的库模块
// 先保存原有的 require（可能不存在）
var _origRequire = typeof require !== 'undefined' ? require : undefined;

// 加载 bundle - 它会设置全局 require 函数
