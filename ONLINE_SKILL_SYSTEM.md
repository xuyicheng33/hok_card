# 在线技能系统实现文档

## 📋 概述

在线技能系统采用**服务器权威**架构，确保双方客户端技能效果完全一致，避免随机性导致的不同步问题。

## 🏗️ 架构设计

```
客户端A                    服务器                     客户端B
   |                        |                          |
   | 1. 发送技能请求          |                          |
   |----------------------->|                          |
   |  {caster_id, skill,   |                          |
   |   target_id, is_ally} |                          |
   |                        |                          |
   |                        | 2. 权威计算技能效果        |
   |                        |    - 伤害/治疗           |
   |                        |    - 属性变化            |
   |                        |    - 状态更新            |
   |                        |                          |
   | 3. 接收技能结果          |  4. 广播技能结果          | 5. 接收技能结果
   |<-----------------------|------------------------->|
   | {effect_type, data}   |                          | {effect_type, data}
   |                        |                          |
   | 6. 应用结果到本地卡牌    |                          | 7. 应用结果到本地卡牌
   |                        |                          |
```

## 📁 文件结构

### 服务器端

```
server/
├── game/
│   ├── CardDatabase.js        # 完整8个英雄数据
│   ├── SkillCalculator.js     # 技能计算器（核心）
│   └── BattleEngine.js        # 战斗引擎（集成技能计算）
└── server.js                  # WebSocket服务器（技能消息处理）
```

### 客户端

```
scripts/
└── core/
    ├── NetworkManager.gd           # 发送技能请求
    ├── BattleManager.gd            # 技能结果应用
    └── BattleManagerSkillSync.gd   # 辅助函数（未使用，可删除）
```

## 🎮 技能实现清单

### 已实现的8个英雄技能

| 英雄 | 技能名 | 效果类型 | 服务器计算 | 客户端应用 |
|------|--------|----------|-----------|-----------|
| 朵莉亚 | 人鱼之赐 | 治疗 | ✅ | ✅ |
| 澜 | 鲨之猎刃 | 攻击力增强 | ✅ | ✅ |
| 公孙离 | 晚云落 | 暴击率增强+溢出转换 | ✅ | ✅ |
| 孙尚香 | 红莲爆弹 | 减护甲+真实伤害 | ✅ | ✅ |
| 瑶 | 鹿灵守心 | 护盾+暴击+护甲 | ✅ | ✅ |
| 大乔 | 沧海之曜 | AOE真实伤害 | ✅ | ✅ |
| 少司缘 | 两同心 | 治疗或伤害 | ✅ | ✅ |
| 杨玉环 | 惊鸿曲 | AOE伤害或治疗 | ✅ | ✅ |

## 🔄 工作流程

### 1. 客户端发送技能

```gdscript
# BattleManager.gd
func execute_skill(card: Card, skill_name: String, targets: Array, is_player: bool):
    # 准备参数
    var target_id = targets[0].card_id if targets.size() > 0 else ""
    var is_ally = is_card_in_player_side(target) == is_card_in_player_side(card)
    
    # 发送到服务器
    NetworkManager.send_skill(card.card_id, skill_name, target_id, is_ally)
```

### 2. 服务器计算技能

```javascript
// server.js
else if (data.action === 'skill') {
    const skillParams = {
        target_id: skillData.target_id || null,
        is_host: (clientId === room.host),
        is_ally: skillData.is_ally || false
    };
    
    // 调用技能计算器
    result = engine.calculateSkill(
        skillData.caster_id,
        skillData.skill_name,
        skillParams
    );
    
    // 广播结果给双方
    room.players.forEach(playerId => {
        sendToClient(playerId, {
            type: 'opponent_action',
            action: 'skill',
            data: result,
            from_player_id: clientId
        });
    });
}
```

### 3. 客户端应用结果

```gdscript
# BattleManager.gd
func _handle_opponent_skill(data: Dictionary):
    var effect_type = data.get("effect_type", "")
    
    match effect_type:
        "heal":
            _apply_heal_result(data)
        "attack_buff":
            _apply_attack_buff_result(data)
        "crit_buff":
            _apply_crit_buff_result(data)
        # ... 其他技能类型
    
    # 更新所有实体显示
    _update_all_entities_display()
```

## 📊 技能效果数据格式

### 治疗效果（朵莉亚、少司缘）

```json
{
  "success": true,
  "effect_type": "heal",
  "caster_id": "duoliya_001_blue_0",
  "target_id": "gongsunli_003_blue_1",
  "heal_amount": 130,
  "target_health": 600
}
```

### 攻击力增强（澜）

```json
{
  "success": true,
  "effect_type": "attack_buff",
  "caster_id": "lan_002_red_0",
  "old_attack": 400,
  "new_attack": 500,
  "buff_amount": 100
}
```

### AOE伤害（大乔、杨玉环）

```json
{
  "success": true,
  "effect_type": "aoe_true_damage",
  "caster_id": "daqiao_006_blue_2",
  "base_damage": 180,
  "results": [
    {
      "target_id": "lan_002_red_0",
      "target_name": "澜",
      "damage": 180,
      "is_critical": false,
      "target_health": 520,
      "target_dead": false
    },
    {
      "target_id": "gongsunli_003_red_1",
      "target_name": "公孙离",
      "damage": 234,
      "is_critical": true,
      "target_health": 366,
      "target_dead": false
    }
  ]
}
```

## 🧪 测试步骤

### 1. 启动服务器

```bash
cd f:/QQ/Downloads/hok_card/server
npm install
npm start
```

服务器运行在 `http://121.199.78.133:3000`

### 2. 启动两个客户端

- 客户端A：打开游戏，创建房间
- 客户端B：打开游戏，加入房间

### 3. 测试技能

#### 测试朵莉亚治疗

1. 选中朵莉亚
2. 点击"技能"按钮
3. 选择友方目标
4. 观察双方客户端是否同步显示治疗效果

#### 测试澜攻击增强

1. 选中澜
2. 点击"技能"按钮
3. 观察双方客户端攻击力是否同步增加100

#### 测试大乔AOE

1. 选中大乔
2. 点击"技能"按钮（消耗4技能点）
3. 观察所有敌方单位是否同步受到伤害

## ⚠️ 注意事项

### 1. 技能点消耗

- **服务器端不检查技能点**，需要客户端在发送前检查
- 客户端发送技能后，等待服务器广播结果后才显示效果
- 技能点扣除由回合系统管理（已实现服务器权威）

### 2. 随机效果

- **所有随机判定在服务器端进行**（暴击、闪避等）
- 确保双方客户端看到的效果完全一致

### 3. 目标选择

- 单体技能：`target_id`指定目标
- AOE技能：`target_id`为空，`is_host`判断阵营
- 友方/敌方：`is_ally`标记目标阵营

### 4. 错误处理

- 服务器计算失败时，只通知施法者
- 客户端不会执行任何效果
- 控制台会输出详细错误日志

## 🐛 调试技巧

### 查看服务器日志

```bash
# 服务器控制台会显示：
[技能请求] duoliya_001_blue_0 人鱼之赐 {target_id: "..."}
[朵莉亚技能] 公孙离 恢复130生命值
[技能成功] heal
```

### 查看客户端日志

```
🎮 已发送技能到服务器: 人鱼之赐 -> gongsunli_003_blue_1 (友方:true)
🌐 处理技能结果: {"success":true,"effect_type":"heal",...}
🌐 应用技能效果: heal (duoliya_001_blue_0)
🌐 应用治疗: 公孙离 恢复130生命值 → 600
✅ 技能结果应用完成
```

## 📈 性能优化

1. **减少网络传输**：只传输必要的状态变化，不传输完整卡牌数据
2. **异步处理**：技能计算不阻塞主线程
3. **批量更新**：AOE技能一次性更新所有目标

## 🚀 部署清单

### 需要上传到服务器的文件

```
server/
├── game/
│   ├── CardDatabase.js      # ✅ 已更新
│   ├── SkillCalculator.js   # ✅ 新增
│   └── BattleEngine.js      # ✅ 已更新
├── server.js                # ✅ 已更新
├── package.json
└── package-lock.json
```

### 需要重新导出的客户端文件

```
scripts/core/
├── NetworkManager.gd    # ✅ 已更新
└── BattleManager.gd     # ✅ 已更新
```

## ✅ 完成状态

- ✅ 服务器端完整技能计算（8个英雄）
- ✅ 客户端技能请求发送
- ✅ 客户端技能结果应用
- ✅ 随机效果同步
- ✅ AOE技能支持
- ✅ 死亡判定同步
- ✅ 技能点检查（客户端）

## 🔮 后续优化

1. **服务器端技能点验证**：防止客户端作弊
2. **技能冷却系统**：为技能添加冷却时间
3. **技能动画同步**：确保双方看到相同的动画效果
4. **断线重连**：恢复技能效果状态
5. **录像回放**：记录技能使用序列

---

**文档版本：** v1.0  
**最后更新：** 2025-01-23  
**作者：** Cascade AI
