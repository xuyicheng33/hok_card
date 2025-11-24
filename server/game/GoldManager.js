/**
 * 💰 金币管理器（长期方案）
 * 单一职责：负责所有金币相关的操作
 * 特性：
 * - 统一金币变量（只使用blueGold/redGold）
 * - 提供虚拟属性（hostGold/guestGold）用于向后兼容
 * - 自动同步和校验
 */

class GoldManager {
  constructor(gameState) {
    this.state = gameState;
  }
  
  /**
   * 虚拟属性：房主金币（自动映射到blueGold）
   */
  get hostGold() {
    return this.state.blueGold;
  }
  
  set hostGold(value) {
    this.state.blueGold = value;
  }
  
  /**
   * 虚拟属性：客户端金币（自动映射到redGold）
   */
  get guestGold() {
    return this.state.redGold;
  }
  
  set guestGold(value) {
    this.state.redGold = value;
  }
  
  /**
   * 获取指定队伍的金币
   * @param {String} team - 'blue' 或 'red'
   * @returns {Number}
   */
  getGold(team) {
    return team === 'blue' ? this.state.blueGold : this.state.redGold;
  }
  
  /**
   * 设置指定队伍的金币
   * @param {String} team - 'blue' 或 'red'
   * @param {Number} amount - 金币数量
   */
  setGold(team, amount) {
    if (team === 'blue') {
      this.state.blueGold = amount;
      this.state.hostGold = amount;  // 自动同步
    } else {
      this.state.redGold = amount;
      this.state.guestGold = amount;  // 自动同步
    }
    console.log('💰 [金币设置] %s方: %d', team === 'blue' ? '蓝' : '红', amount);
  }
  
  /**
   * 增加金币
   * @param {String} team - 'blue' 或 'red'
   * @param {Number} amount - 增加数量
   * @param {String} reason - 原因（用于日志）
   * @returns {Object} - { oldGold, newGold, amount }
   */
  addGold(team, amount, reason = '未知') {
    const oldGold = this.getGold(team);
    const newGold = oldGold + amount;
    this.setGold(team, newGold);
    
    console.log('💰 [金币增加] %s方: %d + %d = %d (原因: %s)', 
      team === 'blue' ? '蓝' : '红', oldGold, amount, newGold, reason);
    
    return { oldGold, newGold, amount };
  }
  
  /**
   * 扣除金币
   * @param {String} team - 'blue' 或 'red'
   * @param {Number} amount - 扣除数量
   * @param {String} reason - 原因（用于日志）
   * @returns {Object} - { success, oldGold, newGold, amount }
   */
  deductGold(team, amount, reason = '未知') {
    const oldGold = this.getGold(team);
    
    // 检查金币是否足够
    if (oldGold < amount) {
      console.error('❌ [金币不足] %s方金币不足: 需要%d, 当前%d', 
        team === 'blue' ? '蓝' : '红', amount, oldGold);
      return { success: false, oldGold, newGold: oldGold, amount: 0 };
    }
    
    const newGold = oldGold - amount;
    this.setGold(team, newGold);
    
    console.log('💰 [金币扣除] %s方: %d - %d = %d (原因: %s)', 
      team === 'blue' ? '蓝' : '红', oldGold, amount, newGold, reason);
    
    return { success: true, oldGold, newGold, amount };
  }
  
  /**
   * 击杀奖励
   * @param {String} killerTeam - 击杀者队伍 ('blue' 或 'red')
   * @param {Number} reward - 奖励金额（默认20）
   */
  grantKillReward(killerTeam, reward = 20) {
    return this.addGold(killerTeam, reward, '击杀奖励');
  }
  
  /**
   * 阵亡补偿
   * @param {String} team - 队伍 ('blue' 或 'red')
   * @param {Number} compensation - 补偿金额（默认30）
   */
  grantDeathCompensation(team, compensation = 30) {
    return this.addGold(team, compensation, '阵亡补偿');
  }
  
  /**
   * 回合收入
   * @param {String} team - 队伍 ('blue' 或 'red')
   * @param {Number} baseIncome - 基础收入
   * @param {Number} interest - 利息
   */
  grantTurnIncome(team, baseIncome, interest) {
    const total = baseIncome + interest;
    const result = this.addGold(team, total, '回合收入');
    
    console.log('   基础收入: +%d, 利息: +%d (总计: +%d)', 
      baseIncome, interest, total);
    
    return result;
  }
  
  /**
   * 购买装备
   * @param {String} team - 队伍 ('blue' 或 'red')
   * @param {Number} cost - 装备价格（默认15）
   */
  purchaseEquipment(team, cost = 15) {
    return this.deductGold(team, cost, '购买装备');
  }
  
  /**
   * 获取当前状态（用于广播）
   * @returns {Object} - { hostGold, guestGold }
   */
  getState() {
    return {
      hostGold: this.state.blueGold,
      guestGold: this.state.redGold
    };
  }
}

module.exports = GoldManager;
