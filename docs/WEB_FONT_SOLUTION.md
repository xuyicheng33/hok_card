# Web导出中文字体解决方案

## 🔍 问题分析
Godot Web导出中文乱码的根本原因是：
1. **缺少中文字体**: 项目中没有包含支持中文字符的字体文件
2. **Web平台限制**: Web平台无法访问系统默认中文字体
3. **字体未正确配置**: 字体文件存在但未在项目中正确配置和应用

## ✅ 已完成的解决步骤

### 1. 字体文件添加
- ✅ 复制了 `Arial Unicode.ttf` 到 `assets/fonts/` 目录
- ✅ 创建了 `chinese_theme.tres` 主题文件
- ✅ 字体文件大小：23.3MB，支持完整的中文字符集

### 2. 项目配置更新
在 `project.godot` 中添加了：
```ini
[gui]
theme/custom="res://assets/fonts/chinese_theme.tres"
theme/custom_font="res://assets/fonts/Arial Unicode.ttf"

[internationalization]
locale/include_text_server_data=true
```

### 3. 脚本字体应用
已为以下脚本中的所有动态创建Label添加中文字体：

#### ✅ BattleModeSelection.gd
- 标题标签：`选择战斗模式`
- 描述标签：模式描述文本

#### ✅ BattleScene.gd
- 模式信息标签：`当前模式: 2V2`
- 回合信息标签：`第 1 回合 - 玩家回合`
- 技能点标签：`敌方技能点: 4/6`、`我方技能点: 4/6`
- 状态标签：`选择攻击或发动技能`
- 区域标签：`敌方卡牌`、`我方卡牌`、`VS`
- 消息标题：`战斗记录`

#### ✅ BattleEntity.gd
- 卡牌名称标签
- 属性标签：`⚔300`、`❤900/900`、`🛡300`、`🔵0`
- 占位符标签：`无图片`

#### ✅ CardSelection2v2.gd
- 卡牌名称标签
- 属性标签：`攻击: 300 | 生命: 900`
- 技能标签：`技能: 人鱼之赐`

#### ✅ BattleMessageSystem.gd
- 回合标签：`第 1 回合`

## 🎯 Web导出步骤

### 方法1：使用Godot编辑器导出
1. 打开Godot编辑器
2. 选择 `项目` → `导出`
3. 添加 `Web` 导出模板（如果没有）
4. 配置Web导出设置：
   - **导出路径**: `/Users/xuyicheng/hok/builds/web/index.html`
   - **嵌入PCK**: 启用
   - **头部包含**: 启用
5. 点击 `导出项目`

### 方法2：命令行导出（如果已配置）
```bash
cd /Users/xuyicheng/hok
# 使用Godot命令行导出
godot --headless --export-release "Web" builds/web/index.html
```

## 🧪 测试方法

### 1. 本地字体测试
打开项目根目录的 `font_test.html` 文件，检查中文字符是否正确显示。

### 2. Web游戏测试
导出完成后，使用Web服务器运行：
```bash
cd /Users/xuyicheng/hok/builds/web
python3 -m http.server 8000
```
然后访问：`http://localhost:8000`

### 3. 检查项目
确认以下中文文本显示正常：
- 主菜单界面的中文按钮
- 战斗模式选择的中文描述
- 战斗界面的中文状态信息
- 卡牌名称和属性描述
- 战斗记录消息

## 🔧 故障排除

### 如果仍然出现乱码：

#### 1. 检查字体文件
```bash
ls -la assets/fonts/
# 应该看到：
# Arial Unicode.ttf (约23MB)
# chinese_theme.tres
```

#### 2. 验证项目配置
确认 `project.godot` 包含正确的字体配置。

#### 3. 重新导入资源
在Godot编辑器中：
- 选择字体文件
- 右键 → `重新导入`
- 确保导入设置正确

#### 4. 清理重新导出
```bash
rm -rf builds/web
# 然后重新导出
```

#### 5. 检查Web服务器
确保使用HTTP服务器运行，不要直接打开HTML文件。

#### 6. 浏览器开发者工具
按F12检查是否有字体加载错误：
- Console标签页查看错误信息
- Network标签页确认字体文件加载成功

## 📋 技术要点总结

### 关键修改内容：
1. **字体资源**: 添加了支持中文的Arial Unicode字体
2. **项目配置**: 设置了默认中文字体和文本服务器数据
3. **代码修改**: 为所有动态Label添加了字体覆盖
4. **主题文件**: 创建了统一的中文字体主题

### 字体应用模式：
```gdscript
# 预加载字体
var chinese_font = preload("res://assets/fonts/Arial Unicode.ttf")

# 应用到Label
label.add_theme_font_override("font", chinese_font)
```

### Web导出优化：
- 启用了文本服务器数据包含
- 使用了统一的字体主题
- 覆盖了所有动态创建的UI文本组件

## ✨ 预期效果

完成以上步骤后，Web版本游戏应该能够：
- ✅ 正确显示所有中文字符
- ✅ 中文文本清晰可读，无乱码
- ✅ 字体样式与桌面版本一致
- ✅ 所有游戏界面文本正常显示

## 📞 后续支持

如果问题仍然存在，可能需要：
1. 尝试其他中文字体（如思源黑体）
2. 调整导出设置中的文本相关选项
3. 检查Godot版本兼容性
4. 验证Web服务器的MIME类型配置