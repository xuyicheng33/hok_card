/**
 * 💰 金币校验工具（长期方案）
 * 用于检测金币数值的合法性
 * 注：长期方案中只有 blueGold/redGold，hostGold/guestGold 通过 GoldManager 的 getter 访问
 */

class GoldValidator {
  /**
   * 校验金币一致性
   * @param {Object} gameState - 游戏状态对象
   * @param {String} context - 调用上下文（用于日志）
   * @returns {Boolean} - 是否通过校验
   */
  static validate(gameState, context = '未知') {
    const errors = [];
    
    // 检查金币是否为负数
    if (gameState.blueGold < 0) {
      errors.push(`蓝方金币为负数: ${gameState.blueGold}`);
    }
    
    if (gameState.redGold < 0) {
      errors.push(`红方金币为负数: ${gameState.redGold}`);
    }
    
    // 检查金币是否为NaN或undefined
    if (typeof gameState.blueGold !== 'number' || isNaN(gameState.blueGold)) {
      errors.push(`蓝方金币值异常: ${gameState.blueGold}`);
    }
    
    if (typeof gameState.redGold !== 'number' || isNaN(gameState.redGold)) {
      errors.push(`红方金币值异常: ${gameState.redGold}`);
    }
    
    // 如果有错误，打印警告
    if (errors.length > 0) {
      console.error('⚠️ ═══════════════════════════════════════════════');
      console.error('⚠️  金币校验失败！');
      console.error('⚠️  上下文: %s', context);
      console.error('⚠️ ───────────────────────────────────────────────');
      errors.forEach(err => console.error('   ❌ %s', err));
      console.error('⚠️  当前状态:');
      console.error('     blueGold: %d (type: %s)', gameState.blueGold, typeof gameState.blueGold);
      console.error('     redGold: %d (type: %s)', gameState.redGold, typeof gameState.redGold);
      console.error('⚠️ ═══════════════════════════════════════════════\n');
      return false;
    }
    
    // 校验通过
    console.log('✅ [金币校验] 通过 - %s (蓝方:%d, 红方:%d)', 
      context, gameState.blueGold, gameState.redGold);
    return true;
  }
  
  /**
   * 修复金币异常值（长期方案）
   * @param {Object} gameState - 游戏状态对象
   */
  static fixAnomalies(gameState) {
    console.log('🔧 [金币修复] 检查并修复异常金币值...');
    let fixed = false;
    
    // 修复负数金币
    if (gameState.blueGold < 0) {
      console.warn('⚠️ 修复蓝方负数金币: %d → 0', gameState.blueGold);
      gameState.blueGold = 0;
      fixed = true;
    }
    
    if (gameState.redGold < 0) {
      console.warn('⚠️ 修复红方负数金币: %d → 0', gameState.redGold);
      gameState.redGold = 0;
      fixed = true;
    }
    
    // 修复NaN金币
    if (isNaN(gameState.blueGold)) {
      console.warn('⚠️ 修复蓝方NaN金币 → 0');
      gameState.blueGold = 0;
      fixed = true;
    }
    
    if (isNaN(gameState.redGold)) {
      console.warn('⚠️ 修复红方NaN金币 → 0');
      gameState.redGold = 0;
      fixed = true;
    }
    
    if (fixed) {
      console.log('✅ [金币修复] 完成 (蓝方:%d, 红方:%d)', 
        gameState.blueGold, gameState.redGold);
    } else {
      console.log('✅ [金币修复] 无需修复');
    }
    
    return fixed;
  }
  
  /**
   * 记录金币变化
   * @param {Object} gameState - 游戏状态对象
   * @param {String} operation - 操作名称
   * @param {Object} details - 详细信息
   */
  static logChange(gameState, operation, details = {}) {
    console.log('💰 [金币变化] %s', operation);
    console.log('   蓝方: %d | 红方: %d', gameState.blueGold, gameState.redGold);
    if (Object.keys(details).length > 0) {
      console.log('   详情:', JSON.stringify(details));
    }
  }
}

module.exports = GoldValidator;
