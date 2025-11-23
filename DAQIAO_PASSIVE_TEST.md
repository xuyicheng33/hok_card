# 大乔被动技能测试指南

## ✅ **已实现：宿命之海**

### 触发条件
- 大乔受到致命伤害（health <= 0）
- 被动未使用过（daqiao_passive_used == false）

### 效果
1. **生命值恢复**：设置为1点
2. **技能点获取**：己方技能点+3
3. **溢出转护盾**：
   - 如果技能点超过上限（6点），每溢出1点转换为150点护盾
   - 例如：当前5点→+3→8点→实际6点（上限）→溢出2点→300护盾
4. **一次性效果**：每局游戏只能触发一次

---

## 🧪 **测试方法**

### 方案1：修改服务器配置（推荐）

#### 步骤：
1. 打开 `server/server.js`
2. 找到 line 56-68（initGameState函数）
3. 取消注释大乔相关代码：

```javascript
// 修改前（line 55-67）：
const duoliyaData = cardDB.getCard('duoliya_001');
// const daqiaoData = cardDB.getCard('daqiao_006');  // 🌟 大乔测试

const redCards = [
  { id: 'gongsunli_003_red_0', ...gongsunliData, health: gongsunliData.max_health, shield: 0 },
  { id: 'duoliya_001_red_1', ...duoliyaData, health: duoliyaData.max_health, shield: 0 }
  // { id: 'daqiao_006_red_1', ...daqiaoData, health: daqiaoData.max_health, shield: 0, daqiao_passive_used: false }  // 🌟 大乔测试：替换朵莉亚
];

// 修改后：
const duoliyaData = cardDB.getCard('duoliya_001');
const daqiaoData = cardDB.getCard('daqiao_006');  // ✅ 启用大乔

const redCards = [
  { id: 'gongsunli_003_red_0', ...gongsunliData, health: gongsunliData.max_height, shield: 0 },
  // { id: 'duoliya_001_red_1', ...duoliyaData, health: duoliyaData.max_health, shield: 0 }  // ❌ 禁用朵莉亚
  { id: 'daqiao_006_red_1', ...daqiaoData, health: daqiaoData.max_health, shield: 0, daqiao_passive_used: false }  // ✅ 启用大乔
];
```

4. 保存文件
5. SSH连接服务器：
```bash
ssh root@你的服务器IP
cd ~/hok_card_server
git pull origin main  # 拉取最新代码
pm2 restart hok-card-server
```

### 方案2：本地测试（如果有本地服务器）

```bash
# 1. 修改server.js（同上）
# 2. 启动本地服务器
cd server
node server.js

# 3. 修改客户端连接地址
# NetworkManager.gd line 12
var server_url: String = "ws://localhost:3000"  # 使用本地服务器
```

---

## 🎮 **测试场景**

### 场景1：基础触发测试
```
房间配置：澜+孙尚香 vs 公孙离+大乔

操作步骤：
1. 用澜/孙尚香持续攻击大乔
2. 将大乔打至0血
3. 观察被动触发

预期结果：
✅ 大乔生命值：0 → 1
✅ 己方技能点：X → X+3（或6）
✅ 如果溢出，显示护盾值
✅ 控制台日志清晰
```

### 场景2：溢出转护盾测试
```
前置条件：
- 让己方技能点达到5点
- 然后触发大乔被动

操作：
1. 用技能消耗到只剩5点
2. 攻击大乔至0血

预期结果：
✅ 技能点：5 + 3 → 6（上限）
✅ 溢出：2点
✅ 护盾：2 × 150 = 300
✅ 大乔总护盾：300（或+300）
```

### 场景3：一次性验证
```
操作：
1. 第一次触发被动（大乔复活到1血）
2. 再次攻击大乔至0血

预期结果：
✅ 第一次：被动触发，生命→1
✅ 第二次：被动不触发，大乔死亡
✅ daqiao_passive_used = true
```

---

## 📊 **观察要点**

### 服务器端日志
```
⚔️  [攻击计算] 澜 → 大乔
   💔 生命值扣除 XXX (生命: 1 → 0)
   ☠️  大乔 被击败!
   ⭐ 大乔被动「宿命之海」触发！生命值→1
   💫 技能点: 4 + 3 → 6 (实际+2)
   🛡️ 溢出1点技能点 → 150护盾 (总护盾:150)
🌟 [大乔被动] 广播技能点更新: red方 4→6 (溢出1点→150护盾)
```

### 客户端日志
```
🌟 大乔被动「宿命之海」触发！
   生命值: 0 → 1
   技能点: 4 → 6 (实际+2)
   溢出: 1点技能点 → 150护盾
🎯 服务器技能点同步: 我方6, 敌方4
✅ 技能点更新完成（不同步行动点，不切换回合）
```

### UI显示
- ✅ 大乔生命值显示：1/800
- ✅ 护盾值显示在卡牌上
- ✅ 技能点UI更新正确
- ✅ 战斗消息记录被动触发

---

## 🐛 **可能的问题**

### 问题1：被动不触发
**症状**：大乔死亡，但没有复活

**检查：**
1. 服务器日志是否有"大乔被动"字样
2. `daqiao_passive_used` 是否已经为true
3. 大乔是否真的到达0血（可能护盾吸收了）

**解决：**
- 确认服务器代码已更新（git pull）
- 确认服务器已重启（pm2 restart）
- 检查是否已触发过一次

### 问题2：技能点不增加
**症状**：生命值恢复了，但技能点没变

**检查：**
1. 客户端日志是否有"技能点更新"
2. 是否收到 turn_changed 消息

**解决：**
- 检查服务器端技能点广播代码
- 确认 is_skill_points_only 标志正确

### 问题3：溢出护盾不显示
**症状**：技能点到6了，但没有护盾

**检查：**
1. 触发时技能点是否<4（不会溢出）
2. 护盾值是否被其他攻击消耗了

**解决：**
- 先将技能点消耗到5点再测试
- 检查大乔的shield属性值

---

## 🎯 **测试检查清单**

- [ ] 服务器代码已更新（git log查看commit ade0ff9）
- [ ] server.js已修改为使用大乔
- [ ] 服务器已重启（pm2 restart）
- [ ] 客户端能正常连接
- [ ] 大乔在红方阵容中
- [ ] 能正常创建房间和开始游戏
- [ ] 第一次触发被动成功
- [ ] 第二次不会触发
- [ ] 技能点正确增加
- [ ] 溢出时护盾正确计算
- [ ] UI和日志都正常显示

---

## 💡 **调试技巧**

### 1. 降低大乔生命值（快速测试）
```javascript
// server.js line 63-68
const daqiaoData = cardDB.getCard('daqiao_006');
const daqiaoDataLowHP = { ...daqiaoData, max_health: 100 };  // 改为100血

const redCards = [
  { id: 'gongsunli_003_red_0', ...gongsunliData, health: gongsunliData.max_health, shield: 0 },
  { id: 'daqiao_006_red_1', ...daqiaoDataLowHP, health: 100, shield: 0, daqiao_passive_used: false }
];
```

### 2. 增加初始技能点（测试溢出）
```javascript
// server.js line 76-77
hostSkillPoints: 5,  // 改为5点
guestSkillPoints: 5,  // 改为5点
```

### 3. 查看实时日志
```bash
# 服务器端
pm2 logs hok-card-server --lines 50

# 或实时查看
pm2 logs hok-card-server
```

---

## 📝 **反馈模板**

如果测试有问题，请提供：

```
1. 服务器版本：
   git log --oneline -1
   输出：______

2. 是否修改了server.js：
   [ ] 是  [ ] 否

3. 服务器是否重启：
   [ ] 是  [ ] 否

4. 测试场景：
   操作：______
   预期：______
   实际：______

5. 服务器日志：
   （粘贴相关日志）

6. 客户端日志（Godot控制台）：
   （粘贴相关日志）

7. 截图：
   （如果有UI问题）
```

---

## 🎉 **成功标志**

当你看到以下所有内容时，说明实现成功：

```
服务器日志：
✅ ⭐ 大乔被动「宿命之海」触发！生命值→1
✅ 💫 技能点: X + 3 → Y (实际+Z)
✅ 🛡️ 溢出时：溢出N点技能点 → M护盾
✅ 🌟 [大乔被动] 广播技能点更新

客户端日志：
✅ 🌟 大乔被动「宿命之海」触发！
✅ 生命值: 0 → 1
✅ 技能点: X → Y (实际+Z)
✅ 溢出时：溢出N点 → M护盾
✅ ✅ 技能点更新完成（不同步行动点，不切换回合）

游戏内UI：
✅ 大乔生命值显示1点
✅ 护盾值显示在卡牌上
✅ 技能点UI正确更新
✅ 战斗消息有被动触发记录
```

**恭喜！大乔被动技能完美实现！** 🎊✨
