# 🎨 UI/动画设计师工作指南

> **项目：**王者荣耀卡牌对战游戏  
> **引擎：**Godot 4.5  
> **版本：**v1.0-stable  
> **更新日期：**2025-11-23

---

## 📋 目录

1. [项目概览](#项目概览)
2. [工作准备](#工作准备)
3. [可以修改的内容](#可以修改的内容)
4. [禁止修改的内容](#禁止修改的内容)
5. [操作指南](#操作指南)
6. [关键节点清单](#关键节点清单)
7. [常见问题](#常见问题)

---

## 📖 项目概览

### 游戏类型
回合制卡牌对战游戏，支持在线对战

### 核心功能
- ✅ 1v1、2v2、3v3对战
- ✅ 8位英雄，每位有独特技能和被动
- ✅ 在线多人对战
- ✅ BP（Ban Pick）模式

### 技术栈
- 游戏引擎：Godot 4.5
- 脚本语言：GDScript
- 导出平台：Web（HTML5）
- 服务器：Node.js

### 设计目标
- 🎯 打造精美的卡牌UI
- 🎯 流畅的动画效果
- 🎯 王者荣耀主题风格
- 🎯 移动端友好（横屏）

---

## 🛠️ 工作准备

### 第一步：安装Godot

1. **下载Godot 4.5**
   - 官网：https://godotengine.org/download
   - 选择：Godot Engine - .NET版本或标准版

2. **安装并启动**
   - Windows：双击安装包
   - 导入项目：点击"导入" → 选择项目文件夹

### 第二步：备份项目

**⚠️ 非常重要！**

在开始修改前，请务必备份：

```
方法1：复制整个文件夹
hok_card → hok_card_backup_20251123

方法2：使用Git分支（推荐）
当前在：ui-redesign 分支
稳定版本在：master 分支
```

### 第三步：熟悉项目结构

```
hok_card/
├── assets/              # 🎨 美术资源（可以自由修改）
│   ├── images/         # 图片资源
│   ├── fonts/          # 字体文件
│   └── music/          # 音乐音效
├── scenes/             # ⚠️ 场景文件（谨慎修改）
│   ├── main/           # 主要场景
│   ├── modes/          # 游戏模式
│   └── ui/             # UI组件
├── scripts/            # ❌ 代码文件（禁止修改逻辑）
│   ├── battle/         # 战斗相关
│   ├── core/           # 核心系统
│   └── ui/             # UI脚本
└── themes/             # 🎨 主题样式（可以修改）
```

---

## ✅ 可以修改的内容

### 1. 美术资源 🎨 **完全安全**

#### **图片资源**
```
assets/images/
├── backgrounds/        # 背景图
│   └── background.png  # 战斗背景（建议1920x1080）
├── cards/              # 卡牌头像
│   ├── duoliya.png     # 朵莉亚头像
│   ├── lan.png         # 澜头像
│   ├── gongsunli.png   # 公孙离头像
│   └── ...             # 其他英雄
└── ui/                 # UI元素图片
    ├── button_normal.png
    ├── button_hover.png
    └── ...
```

**操作建议：**
- ✅ 直接替换同名文件（保持分辨率合理）
- ✅ 添加新图片资源
- ✅ 使用PNG格式（支持透明）
- ⚠️ 建议分辨率：
  - 背景：1920x1080 或 1280x720
  - 卡牌头像：512x512 或更大
  - UI按钮：根据需要

#### **字体文件**
```
assets/fonts/
└── Arial Unicode.ttf   # 可替换为其他支持中文的字体
```

**注意：**
- ✅ 必须支持中文
- ✅ 推荐：思源黑体、阿里巴巴普惠体、HarmonyOS Sans

#### **音频资源**
```
assets/music/
├── bgm/               # 背景音乐
├── sfx/               # 音效
└── voice/             # 语音（如有）
```

**支持格式：**
- MP3
- OGG（推荐）
- WAV

---

### 2. 主题样式 🎨 **安全修改**

#### **主题文件**
```
themes/chinese_theme.tres
```

**可修改的属性：**
```gdscript
# 字体
default_font = "新字体文件路径"
default_font_size = 24

# 颜色
font_color = Color(1, 1, 1, 1)      # 白色
font_outline_color = Color(0, 0, 0, 1)  # 黑色描边

# 按钮样式
Button/styles/normal     # 正常状态
Button/styles/hover      # 悬停状态
Button/styles/pressed    # 按下状态
Button/styles/disabled   # 禁用状态

# 面板样式
Panel/styles/panel       # 面板背景
```

**修改方法：**
1. 在Godot中打开 `themes/chinese_theme.tres`
2. 在Inspector面板中修改属性
3. 保存（Ctrl+S）

---

### 3. 场景布局 ⚠️ **谨慎修改**

#### **可以调整的属性**

**位置和大小：**
```
Position（位置）        ✅ 可以调整
Size（大小）           ✅ 可以调整
Anchors（锚点）        ✅ 可以调整
Margins（边距）        ✅ 可以调整
Scale（缩放）          ✅ 可以调整
Rotation（旋转）       ✅ 可以调整
```

**外观属性：**
```
Modulate（颜色调制）   ✅ 可以调整
Self Modulate         ✅ 可以调整
Visibility（可见性）   ✅ 可以调整
Texture（纹理）        ✅ 可以替换
Theme Overrides       ✅ 可以调整
```

**可以添加的节点：**
```
✅ Sprite2D           # 装饰图片
✅ AnimatedSprite2D   # 动画精灵
✅ ColorRect          # 颜色矩形
✅ TextureRect        # 纹理矩形
✅ Panel              # 面板
✅ Label              # 文本标签
✅ ParticleSystem2D   # 粒子特效
✅ AnimationPlayer    # 动画播放器
✅ Control            # 容器节点
```

---

## ❌ 禁止修改的内容

### 1. 核心脚本文件 ❌

**完全禁止修改：**
```
scripts/core/
├── BattleManager.gd      # ❌ 战斗逻辑核心
├── Card.gd               # ❌ 卡牌逻辑
├── SkillManager.gd       # ❌ 技能系统
├── NetworkManager.gd     # ❌ 在线通信
└── CardDatabase.gd       # ❌ 数据管理
```

**原因：** 修改会导致游戏逻辑错误、在线对战不同步

### 2. 服务器端代码 ❌

```
server/
├── server.js             # ❌ 服务器主程序
├── game/BattleEngine.js  # ❌ 战斗引擎
└── game/SkillCalculator.js  # ❌ 技能计算
```

**原因：** 修改会导致服务器崩溃、数据不一致

### 3. 关键节点名称 ❌

**以下节点名称禁止修改：**

#### **BattleScene.tscn**
```
❌ 禁止删除或重命名：
- PlayerCards          # 玩家卡牌容器
- EnemyCards           # 敌方卡牌容器
- AttackButton         # 攻击按钮
- SkillButton          # 技能按钮
- EndTurnButton        # 结束回合按钮
- CancelSkillButton    # 取消技能按钮
- TurnLabel            # 回合显示
- StatusLabel          # 状态提示
- PlayerSkillPoints    # 玩家技能点
- EnemySkillPoints     # 敌方技能点
- MessageSystem        # 消息系统
```

#### **BattleEntity.tscn**
```
❌ 禁止删除或重命名：
- CardSprite           # 卡牌图片
- HealthBar            # 生命条
- ShieldBar            # 护盾条
- NameLabel            # 名称标签
- StatsLabel           # 属性标签
```

### 4. 节点类型 ❌

**不要改变节点类型：**
```
❌ 错误示例：
Button → TextureButton  # 会导致信号连接失效
Label → RichTextLabel   # 会导致代码报错
```

### 5. 数据文件 ❌

```
❌ 禁止修改：
assets/data/cards_data.json   # 卡牌数据配置
```

**原因：** 修改会导致卡牌属性错误、技能失效

---

## 📖 操作指南

### 场景1：替换背景图

**步骤：**

1. **准备新背景图**
   - 文件名：`new_background.png`
   - 分辨率：1920x1080
   - 格式：PNG

2. **导入Godot**
   ```
   将文件复制到：
   assets/images/backgrounds/new_background.png
   ```

3. **在场景中替换**
   ```
   打开：scenes/main/BattleScene.tscn
   选择：Background节点
   在Inspector中：
   - Texture → 点击下拉 → Load
   - 选择：new_background.png
   ```

4. **保存并测试**
   ```
   Ctrl+S 保存
   F5 运行测试
   ```

---

### 场景2：美化按钮

**方法1：使用主题**

1. **打开主题文件**
   ```
   双击：themes/chinese_theme.tres
   ```

2. **修改按钮样式**
   ```
   Button → Styles → Normal
   - 修改背景颜色
   - 修改边框
   - 修改圆角
   ```

3. **添加纹理**
   ```
   Button → Styles → Normal → StyleBoxTexture
   - Texture → 选择按钮图片
   ```

**方法2：直接修改场景**

1. **打开场景**
   ```
   scenes/main/BattleScene.tscn
   ```

2. **选择按钮**
   ```
   找到：AttackButton
   ```

3. **添加主题覆盖**
   ```
   Inspector → Theme Overrides
   - Colors → Font Color → 选择颜色
   - Styles → Normal → 创建StyleBoxFlat
     - Bg Color → 背景色
     - Border → 边框设置
     - Corner Radius → 圆角
   ```

---

### 场景3：添加卡牌出场动画

**步骤：**

1. **选择卡牌实体**
   ```
   打开：scenes/ui/（或找到卡牌实例）
   ```

2. **添加AnimationPlayer**
   ```
   右键 → Add Child Node → AnimationPlayer
   ```

3. **创建动画**
   ```
   选择AnimationPlayer
   点击：Animation → New
   命名：spawn_animation
   ```

4. **添加关键帧**
   ```
   时间轴0.0秒：
   - Scale = (0, 0)
   - Modulate Alpha = 0
   
   时间轴0.5秒：
   - Scale = (1, 1)
   - Modulate Alpha = 1
   
   缓动：选择 Ease Out
   ```

5. **保存动画**
   ```
   Ctrl+S
   ```

**注意：** 不要修改触发动画的代码逻辑

---

### 场景4：添加粒子特效

**步骤：**

1. **添加粒子节点**
   ```
   选择要添加特效的节点
   右键 → Add Child Node → CPUParticles2D
   ```

2. **配置粒子**
   ```
   Inspector:
   - Emitting → 勾选
   - Amount → 50（粒子数量）
   - Lifetime → 1.0（生命周期）
   - Texture → 选择粒子贴图
   
   Emission Shape:
   - Shape → Sphere（球形）
   - Radius → 50
   
   Direction:
   - Direction → Vector2(0, -1)（向上）
   - Spread → 45（扩散角度）
   
   Gravity:
   - Gravity → Vector2(0, 100)（向下重力）
   
   Color:
   - Color → 选择颜色
   ```

3. **测试效果**
   ```
   点击播放按钮查看效果
   ```

---

## 🔑 关键节点清单

### BattleScene.tscn（战斗场景）

| 节点名称 | 类型 | 用途 | 可以修改 | 禁止操作 |
|---------|------|------|---------|---------|
| PlayerCards | HBoxContainer | 玩家卡牌容器 | ✅ 位置、大小 | ❌ 删除、改名 |
| EnemyCards | HBoxContainer | 敌方卡牌容器 | ✅ 位置、大小 | ❌ 删除、改名 |
| AttackButton | Button | 攻击按钮 | ✅ 样式、位置 | ❌ 删除、改名、改类型 |
| SkillButton | Button | 技能按钮 | ✅ 样式、位置 | ❌ 删除、改名、改类型 |
| EndTurnButton | Button | 结束回合 | ✅ 样式、位置 | ❌ 删除、改名、改类型 |
| CancelSkillButton | Button | 取消技能 | ✅ 样式、位置 | ❌ 删除、改名、改类型 |
| TurnLabel | Label | 回合显示 | ✅ 字体、颜色、位置 | ❌ 删除、改名 |
| StatusLabel | Label | 状态提示 | ✅ 字体、颜色、位置 | ❌ 删除、改名 |
| MessageSystem | Control | 消息系统 | ✅ 样式 | ❌ 删除、改名 |

### BattleEntity.tscn（卡牌实体）

| 节点名称 | 类型 | 用途 | 可以修改 | 禁止操作 |
|---------|------|------|---------|---------|
| CardSprite | Sprite2D | 卡牌图片 | ✅ 纹理、大小 | ❌ 删除、改名 |
| HealthBar | ProgressBar | 生命条 | ✅ 颜色、样式 | ❌ 删除、改名 |
| ShieldBar | ProgressBar | 护盾条 | ✅ 颜色、样式 | ❌ 删除、改名 |
| NameLabel | Label | 名称 | ✅ 字体、颜色 | ❌ 删除、改名 |
| StatsLabel | Label | 属性显示 | ✅ 字体、颜色 | ❌ 删除、改名 |

---

## ❓ 常见问题

### Q1: 修改后游戏报错怎么办？

**A1:** 
```
1. 检查控制台（Output）的错误信息
2. 查看是否删除了关键节点
3. 回滚到上一个版本：
   - 关闭Godot
   - 从备份文件夹恢复
   - 或使用Git: git checkout master
```

### Q2: 如何测试修改效果？

**A2:**
```
1. 按F5运行整个项目
2. 按F6运行当前场景
3. 使用Godot的Scene面板实时预览
```

### Q3: 节点名称为什么不能改？

**A3:**
```
因为代码中通过节点名称来查找节点：

# 代码示例
@onready var attack_button = $UI/AttackButton

如果改名为 "MyAttackButton"，
代码就找不到节点，会报错。
```

### Q4: 如何知道哪些是装饰节点，可以删除？

**A4:**
```
装饰节点特征：
✅ 名称包含 "Decoration"、"BG"、"Effect"
✅ 没有绑定脚本
✅ 类型是 Sprite2D、ColorRect、Panel

核心节点特征：
❌ 名称在"关键节点清单"中
❌ 绑定了脚本
❌ 类型是 Button、Label、Container
```

### Q5: 如何添加动画效果？

**A5:**
```
推荐方法：
1. 使用AnimationPlayer节点
2. 创建新动画
3. 记录关键帧
4. 设置缓动曲线

不推荐：
❌ 修改现有的动画逻辑代码
```

### Q6: 字体不显示中文怎么办？

**A6:**
```
1. 确保字体文件支持中文
2. 推荐字体：
   - 思源黑体
   - 阿里巴巴普惠体
   - 微软雅黑
   
3. 在Godot中：
   - 打开主题文件
   - Font → 选择新字体
   - 保存
```

### Q7: 如何保持不同分辨率下的适配？

**A7:**
```
使用Godot的布局系统：

1. Container节点（自动布局）
   - VBoxContainer（垂直）
   - HBoxContainer（水平）
   - GridContainer（网格）

2. 锚点系统（Anchors）
   - 左上角：(0, 0)
   - 右下角：(1, 1)
   - 居中：(0.5, 0.5)

3. 最小尺寸（Min Size）
   - 设置节点的最小尺寸
```

---

## 📝 提交检查清单

**在提交修改前，请检查：**

```
UI美化检查清单：

□ 游戏能正常启动
□ 主菜单按钮都能点击
□ 战斗场景能正常进入
□ 卡牌能正常显示
□ 攻击按钮有效
□ 技能按钮有效
□ 结束回合按钮有效
□ 取消按钮有效
□ 生命条正常显示
□ 护盾条正常显示
□ 在线对战能连接
□ 无报错/警告（Console）
□ 所有文本都清晰可读
□ 1280x720分辨率正常
□ 1920x1080分辨率正常
□ 没有删除关键节点
□ 没有修改节点名称
□ 没有修改核心代码
```

---

## 🎨 设计建议

### 色彩方案
```
推荐配色（王者荣耀风格）：

主色调：
- 金色：#D4AF37
- 深蓝：#1A237E
- 紫色：#4A148C

辅助色：
- 生命值：#4CAF50（绿色）
- 护盾值：#2196F3（蓝色）
- 伤害：#F44336（红色）
- 治疗：#00E676（亮绿）

背景：
- 深色背景：#212121
- 半透明面板：rgba(0, 0, 0, 0.7)
```

### 动画时长
```
推荐时长：

UI动画：
- 按钮悬停：0.1-0.2秒
- 面板淡入：0.3-0.5秒
- 卡牌出场：0.5-0.8秒

战斗动画：
- 攻击动作：0.3-0.5秒
- 技能特效：0.5-1.0秒
- 死亡动画：0.8-1.2秒
```

### 字体大小
```
推荐尺寸：

标题：32-48px
正文：18-24px
按钮：20-28px
提示：14-16px
```

---

## 📞 联系与支持

**遇到问题？**

1. **查看文档**
   - Godot官方文档：https://docs.godotengine.org
   - 本项目文档：README.md

2. **检查控制台**
   - 查看Output面板的错误信息
   - 截图发给开发团队

3. **回滚版本**
   - 使用备份文件夹
   - 或使用Git恢复：`git checkout master`

---

## 🎯 设计目标总结

### 优先级1：核心UI美化
- ✅ 卡牌外观设计
- ✅ 按钮样式优化
- ✅ 背景图片更换

### 优先级2：动画效果
- ✅ 卡牌出场动画
- ✅ 按钮交互动画
- ✅ 攻击/技能特效

### 优先级3：细节优化
- ✅ 粒子特效
- ✅ 场景过渡
- ✅ 音效配合

---

**祝设计顺利！有任何问题随时联系开发团队！** 🎨✨
