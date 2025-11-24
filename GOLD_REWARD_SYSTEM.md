# 💰 金币奖励系统实现文档

## ✅ 已完成功能

### 1. 击杀奖励系统

**数值设计：**
- 击杀敌方1张卡牌 → **+20金币**
- 奖励立即生效，可用于下一次操作

**实现位置：**
- `server/game/BattleEngine.js` Line 126-139
- 在`calculateAttack()`中检测目标死亡
- 自动判断击杀方阵营并增加金币

**触发条件：**
- ✅ 目标生命值 ≤ 0
- ✅ 未被闪避（isDodged = false）
- ✅ 自动同步到 blueGold/redGold 和 hostGold/guestGold

**日志输出：**
```
💰 击杀奖励: 澜 获得 20 金币!
💰 [击杀奖励] 广播金币变化: 房主💰30 | 客户端💰10
```

---

### 2. 阵亡补偿系统

**数值设计：**
- 己方阵亡 ≥ 2张卡牌 → **+30金币**（一次性）
- 补偿立即生效，帮助劣势方翻盘

**实现位置：**
- `server/server.js` Line 413-458
- 在攻击结果处理后检测双方阵亡数
- 使用标记防止重复触发

**触发条件：**
- ✅ 己方存活卡牌数 ≤ 1（即阵亡 ≥ 2张）
- ✅ 未触发过补偿（blueCompensationGiven/redCompensationGiven = false）
- ✅ 只触发一次，不会重复获得

**日志输出：**
```
💰 [阵亡补偿] 蓝方/房主阵亡2张，获得30金币补偿！
💰 [阵亡补偿] 红方/客户端阵亡2张，获得30金币补偿！
```

---

## 📊 金币流动示例

### 场景1：优势方连杀
```
初始状态：
- 蓝方: 💰10金币，3张卡牌存活
- 红方: 💰10金币，3张卡牌存活

回合1：蓝方击杀红方1张
- 蓝方: 💰30金币 (+20击杀奖励)
- 红方: 💰10金币，2张存活

回合2：蓝方再击杀红方1张
- 蓝方: 💰50金币 (+20击杀奖励)
- 红方: 💰40金币 (+30阵亡补偿)，1张存活

结果：蓝方领先10金币，但红方获得翻盘机会
```

### 场景2：劣势方翻盘
```
红方阵亡2张后获得30金币补偿
→ 可购买2次装备（2×15=30）
→ 强化最后1张卡牌
→ 有机会逆转战局
```

---

## 🎮 游戏平衡性分析

### 优势方收益
- 每击杀1张：+20金币
- 全灭对方（3张）：+60金币
- **雪球效应**：经济优势 → 装备优势 → 战力优势

### 劣势方保护
- 阵亡2张：+30金币（一次性）
- 相当于1.5次击杀奖励
- **翻盘机会**：可购买装备强化最后的英雄

### 净差距
- 优势方连杀2人：+40金币
- 劣势方补偿：+30金币
- **净差距**：+10金币（优势方仍领先，但不会一边倒）

---

## 🔧 技术实现细节

### 1. BattleEngine.js 修改

**添加的代码：**
```javascript
// 💰 击杀奖励系统
let killReward = 0;
if (target.health <= 0 && !isDodged) {
  killReward = 20;
  const isAttackerBlue = this.state.blueCards.some(c => c.id === attackerId);
  if (isAttackerBlue) {
    this.state.blueGold = (this.state.blueGold || 0) + killReward;
    this.state.hostGold = this.state.blueGold;
  } else {
    this.state.redGold = (this.state.redGold || 0) + killReward;
    this.state.guestGold = this.state.redGold;
  }
  console.log(`   💰 击杀奖励: ${attacker.card_name} 获得 ${killReward} 金币!`);
}
```

**返回结果添加：**
```javascript
kill_reward: killReward,  // 击杀奖励金额
```

### 2. server.js 修改

**初始化添加：**
```javascript
blueGold: 10,         // 蓝方金币（房主）
redGold: 10,          // 红方金币（客户端）
blueDeathCount: 0,    // 蓝方阵亡数
redDeathCount: 0,     // 红方阵亡数
blueCompensationGiven: false,  // 蓝方是否已获得补偿
redCompensationGiven: false    // 红方是否已获得补偿
```

**攻击后检测：**
```javascript
// 统计当前双方阵亡数
const blueAliveCount = gameState.blueCards.filter(c => c.health > 0).length;
const redAliveCount = gameState.redCards.filter(c => c.health > 0).length;
const blueDeaths = 3 - blueAliveCount;
const redDeaths = 3 - redAliveCount;

// 蓝方阵亡补偿（死2张且未获得过补偿）
if (blueDeaths >= 2 && !gameState.blueCompensationGiven) {
  const compensation = 30;
  gameState.blueGold += compensation;
  gameState.hostGold = gameState.blueGold;
  gameState.blueCompensationGiven = true;
  // 广播金币变化...
}
```

---

## 🧪 测试步骤

### 测试1：击杀奖励
1. 启动3v3对战
2. 蓝方击杀红方1张卡牌
3. **预期**：蓝方金币 +20
4. **检查**：服务器日志显示 `💰 击杀奖励: XXX 获得 20 金币!`
5. **检查**：客户端UI显示金币增加

### 测试2：阵亡补偿
1. 红方被击杀2张卡牌
2. **预期**：红方金币 +30（仅一次）
3. **检查**：服务器日志显示 `💰 [阵亡补偿] 红方/客户端阵亡2张，获得30金币补偿！`
4. **检查**：再击杀不会再次触发补偿

### 测试3：完整流程
```
初始：双方各10金币
回合1：蓝方击杀红方1张 → 蓝方30金币
回合2：蓝方击杀红方1张 → 蓝方50金币，红方40金币（补偿触发）
回合3：红方用40金币购买装备（2次×15=30）→ 红方10金币
回合4：红方反击击杀蓝方1张 → 红方30金币
```

---

## 📝 客户端兼容性

**无需修改客户端代码！**

- ✅ 客户端已有 `gold_changed` 信号处理
- ✅ 自动接收服务器广播的金币变化
- ✅ UI自动更新显示
- ✅ 收入详情包含原因（kill_reward / death_compensation）

**客户端日志示例：**
```
💰 收到金币变化: 房主💰30 | 客户端💰10
💰 服务器金币同步: 我方💰30, 敌方💰10
   本次收入: 原因=击杀奖励, 金额=20
```

---

## 🚀 5v5扩展建议

当前3v3数值已经平衡，未来扩展到5v5时建议：

**方案A（保守）：**
- 击杀奖励：+15金币/人
- 阵亡补偿：死2张 → +30金币，死4张 → 再+30金币

**方案B（激进）：**
- 击杀奖励：+20金币/人（保持不变）
- 阵亡补偿：死2张 → +40金币，死4张 → 再+40金币

**实现方式：**
只需修改 `server.js` 中的补偿检测逻辑：
```javascript
// 第一次补偿（死2张）
if (blueDeaths >= 2 && !gameState.blueFirstCompensationGiven) {
  // 给予30金币...
}

// 第二次补偿（死4张）
if (blueDeaths >= 4 && !gameState.blueSecondCompensationGiven) {
  // 给予30金币...
}
```

---

## ✅ 完成状态

- ✅ 击杀奖励系统（+20金币）
- ✅ 阵亡补偿系统（死2张 +30金币）
- ✅ 服务器端完整实现
- ✅ 客户端自动兼容
- ✅ 日志输出完善
- ✅ 防止重复触发

**当前状态：功能完整，可以开始测试！** 🎉

---

## 📦 修改文件清单

1. **server/game/BattleEngine.js**
   - Line 126-139: 添加击杀奖励逻辑
   - Line 280: 返回结果添加 kill_reward 字段

2. **server/server.js**
   - Line 110-116: 初始化金币系统和补偿标记
   - Line 399-458: 添加击杀奖励广播和阵亡补偿检测

**总计修改：2个文件，约80行代码**
