/**
 * 💰 金币校验工具
 * 用于检测 blueGold/redGold 与 hostGold/guestGold 是否同步
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
    
    // 检查蓝方金币是否一致
    if (gameState.blueGold !== gameState.hostGold) {
      errors.push(
        `蓝方/房主金币不一致: blueGold=${gameState.blueGold}, hostGold=${gameState.hostGold}`
      );
    }
    
    // 检查红方金币是否一致
    if (gameState.redGold !== gameState.guestGold) {
      errors.push(
        `红方/客户端金币不一致: redGold=${gameState.redGold}, guestGold=${gameState.guestGold}`
      );
    }
    
    // 检查金币是否为负数
    if (gameState.blueGold < 0) {
      errors.push(`蓝方金币为负数: ${gameState.blueGold}`);
    }
    
    if (gameState.redGold < 0) {
      errors.push(`红方金币为负数: ${gameState.redGold}`);
    }
    
    // 如果有错误，打印警告
    if (errors.length > 0) {
      console.error('⚠️ ═══════════════════════════════════════════════');
      console.error('⚠️  金币校验失败！');
      console.error('⚠️  上下文: %s', context);
      console.error('⚠️ ───────────────────────────────────────────────');
      errors.forEach(err => console.error('   ❌ %s', err));
      console.error('⚠️  当前状态:');
      console.error('     blueGold: %d, hostGold: %d', gameState.blueGold, gameState.hostGold);
      console.error('     redGold: %d, guestGold: %d', gameState.redGold, gameState.guestGold);
      console.error('⚠️ ═══════════════════════════════════════════════\n');
      return false;
    }
    
    // 校验通过
    console.log('✅ [金币校验] 通过 - %s (蓝方:%d, 红方:%d)', 
      context, gameState.blueGold, gameState.redGold);
    return true;
  }
  
  /**
   * 强制同步金币（修复不一致）
   * @param {Object} gameState - 游戏状态对象
   */
  static forceSync(gameState) {
    console.log('🔧 [强制同步] 正在同步金币...');
    gameState.hostGold = gameState.blueGold;
    gameState.guestGold = gameState.redGold;
    console.log('✅ [强制同步] 完成 (蓝方:%d, 红方:%d)', 
      gameState.blueGold, gameState.redGold);
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
