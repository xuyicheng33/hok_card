# 行动点系统完整检查清单

## ✅ 客户端（单机模式）

### 攻击
- [x] execute_attack调用use_action
  - 位置：BattleScene.gd:1455
  - 参数：attacker_is_player（基于BattleManager.is_player_turn()）
  - 检查：should_end，达到3次自动结束回合

### 技能
- [x] execute_skill调用use_action
  - 位置：BattleScene.gd:2280
  - 参数：is_player（基于caster.is_player()）
  - 检查：should_end或skill_ends_turn，任一满足则结束回合

### 行动点管理
- [x] use_action增加计数
  - 位置：BattleManager.gd:1560-1577
  - 玩家：player_actions_used++
  - 敌人：enemy_actions_used++
  - 返回：达到actions_per_turn(3)则返回true

- [x] 回合开始重置
  - 位置：BattleManager.gd:1554-1563（reset_actions）
  - 在start_new_turn中调用
  - 重置为0并发送信号

### UI显示
- [x] 行动点标签存在
  - 位置：BattleScene.gd:35-36
  - player_actions_label
  - enemy_actions_label

- [x] 信号连接
  - 位置：BattleScene.gd:267-268
  - 连接actions_changed信号

- [x] 信号处理
  - 位置：BattleScene.gd:2338-2346
  - _on_actions_changed更新UI

---

## ✅ 客户端（在线模式）

### 攻击
- [x] execute_attack调用use_action
  - 位置：BattleScene.gd:1396
  - 在发送请求后立即调用
  - 检查should_end并可能结束回合

### 技能
- [x] execute_skill调用use_action
  - 位置：BattleScene.gd:2170
  - 在发送请求后立即调用
  - 检查should_end并可能结束回合

### 服务器同步
- [x] turn_changed同步行动点
  - 位置：BattleManager.gd:985-1001
  - 从服务器获取blue_actions_used和red_actions_used
  - 根据角色映射到player/enemy
  - 发送actions_changed信号

- [x] opponent_action同步行动点
  - 位置：BattleManager.gd:949-962
  - 从攻击/技能消息获取行动点
  - 根据角色映射到player/enemy
  - 发送actions_changed信号

---

## ✅ 服务器端

### 初始化
- [x] gameState包含行动点字段
  - 位置：server.js:80-82
  - blueActionsUsed: 0
  - redActionsUsed: 0
  - actionsPerTurn: 3

### 验证
- [x] 回合验证
  - 位置：server.js:185-197
  - 检查是否是当前玩家

- [x] 行动点验证（新增）
  - 位置：server.js:199-211
  - 检查currentActions >= actionsPerTurn
  - 超限则拒绝并返回action_failed

### 攻击处理
- [x] 增加行动点
  - 位置：server.js:258或261
  - 根据isHost增加blue或red的ActionsUsed
  - 日志输出

- [x] 广播包含行动点
  - 位置：server.js:242-244
  - blue_actions_used
  - red_actions_used
  - actions_per_turn

### 技能处理
- [x] 增加行动点
  - 位置：server.js:379或382
  - 根据isHost增加blue或red的ActionsUsed
  - 日志输出

- [x] 广播包含行动点
  - 位置：server.js:393-395
  - blue_actions_used
  - red_actions_used
  - actions_per_turn

### 回合切换
- [x] 重置行动点
  - 位置：server.js:443-449
  - 根据isHostTurn重置blue或red的ActionsUsed为0
  - 日志输出

- [x] 广播包含行动点
  - 位置：server.js:549-552
  - blue_actions_used
  - red_actions_used
  - actions_per_turn

### 详细日志
- [x] 攻击日志
  - 位置：server.js:220-248
  - 完整攻击信息、伤害、被动触发

- [x] 技能日志
  - 位置：server.js:333-375
  - 完整技能信息、效果、技能点变化

- [x] 回合切换日志
  - 位置：server.js:425-535
  - 完整状态快照、所有卡牌状态

---

## ✅ 数据配置

### cards_data.json
- [x] 所有技能skill_ends_turn = false
  - 朵莉亚：false
  - 澜：false
  - 公孙离：false
  - 孙尚香：false
  - 瑶：false
  - 大乔：false
  - 少司缘：false
  - 杨玉环：false

---

## ✅ 边界情况

### 客户端
- [x] 行动点达到3次自动结束
  - use_action返回true时调用end_turn

- [x] skill_ends_turn优先级
  - 如果skill_ends_turn=true，仍然会结束（虽然现在都是false）

- [x] 在线模式客户端行动点与服务器同步
  - 通过actions_changed信号更新

### 服务器端
- [x] 超出3次的请求被拒绝
  - 验证currentActions >= actionsPerTurn

- [x] end_turn不验证行动点
  - 允许提前结束回合

- [x] 并发请求不会导致竞态条件
  - Node.js单线程事件循环，按序处理

---

## ⚠️ 潜在问题（已排查）

### 1. 竞态条件
- 状态：✅ 不存在
- 原因：Node.js单线程，消息按序处理

### 2. 行动点不同步
- 状态：✅ 已修复
- 原因：所有广播都包含行动点信息
- 客户端：正确处理并发送信号

### 3. 技能不消耗行动点（在线模式）
- 状态：✅ 已修复
- 原因：添加了use_action调用

### 4. 服务器端不验证上限
- 状态：✅ 已修复
- 原因：添加了验证逻辑

---

## 🎯 最终结论

**所有检查项已通过！行动点系统完整且正确！**

- ✅ 客户端单机模式：完整
- ✅ 客户端在线模式：完整
- ✅ 服务器端：完整
- ✅ 数据配置：正确
- ✅ UI显示：正常
- ✅ 同步机制：完整
- ✅ 验证逻辑：完整
- ✅ 日志系统：详细

**系统可以投入使用！**
