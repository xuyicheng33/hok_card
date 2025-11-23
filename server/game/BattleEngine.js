// 战斗计算引擎 - 服务器端权威计算
const SkillCalculator = require('./SkillCalculator');

class BattleEngine {
  constructor(roomId, gameState) {
    this.roomId = roomId;
    this.state = gameState;
    this.skillCalculator = new SkillCalculator(this);
  }
  
  // 查找卡牌
  findCard(cardId) {
    // 在蓝方查找
    let card = this.state.blueCards.find(c => c.id === cardId);
    if (card) return card;
    
    // 在红方查找
    card = this.state.redCards.find(c => c.id === cardId);
    return card;
  }
  
  // 🎲 计算攻击（权威）
  calculateAttack(attackerId, targetId) {
    const attacker = this.findCard(attackerId);
    const target = this.findCard(targetId);
    
    if (!attacker || !target) {
      console.error('❌ [攻击计算] 卡牌未找到:', attackerId, targetId);
      return null;
    }
    
    console.log(`⚔️  [攻击计算] ${attacker.card_name} → ${target.card_name}`);
    console.log(`   攻击方: ATK:${attacker.attack} 暴击:${(attacker.crit_rate*100).toFixed(1)}% 暴伤:${(attacker.crit_damage*100).toFixed(1)}%`);
    console.log(`   防守方: HP:${target.health}/${target.max_health} 护甲:${target.armor}`);
    
    // 计算基础伤害（新公式：攻击力 × 200/(护甲+200)）
    let baseDamage = attacker.attack * (200 / (target.armor + 200));
    const damageReduction = (target.armor / (target.armor + 200) * 100).toFixed(1);
    console.log(`   💥 基础伤害 = ${attacker.attack} × (200/${target.armor + 200}) = ${baseDamage.toFixed(1)} (减伤率:${damageReduction}%)`);
    
    // 🎯 澜的被动技能：狩猎（目标血量<50%时增伤30%）
    if (attacker.card_name === '澜' && target.health < target.max_health * 0.5) {
      const bonusDamage = Math.floor(baseDamage * 0.3);
      baseDamage = baseDamage + bonusDamage;
      console.log(`   ⭐ 澜被动「狩猎」触发！目标血量${target.health}/${target.max_health} < 50%`);
      console.log(`   💀 斩杀增伤: +30% (${baseDamage - bonusDamage} → ${baseDamage})`);
    }
    
    // 🎲 暴击判定（服务器端权威）
    const isCritical = Math.random() < attacker.crit_rate;
    let finalDamage = baseDamage;
    
    if (isCritical) {
      finalDamage = Math.floor(baseDamage * attacker.crit_damage);
      console.log(`   💢 暴击! ${baseDamage} × ${(attacker.crit_damage*100).toFixed(1)}% = ${finalDamage}`);
    } else {
      console.log(`   🎯 普通攻击 (暴击率:${(attacker.crit_rate*100).toFixed(1)}%)`);
    }
    
    // 🎲 闪避判定（公孙离）
    let isDodged = false;
    if (target.card_name === '公孙离' && target.dodge_rate) {
      isDodged = Math.random() < target.dodge_rate;
      if (isDodged) {
        console.log(`   💨 ${target.card_name}闪避! (闪避率:${(target.dodge_rate*100).toFixed(1)}%)`);
        
        // 🎯 公孙离被动：闪避成功增益
        target.attack += 10;
        target.crit_rate = Math.min(target.crit_rate + 0.05, 1.0); // 暴击率上限100%
        console.log(`   ⭐ ${target.card_name}被动触发：攻击力+10 (${target.attack}), 暴击率+5% (${(target.crit_rate*100).toFixed(1)}%)`);
      }
    }
    
    // 🎯 公孙离被动：暴击后闪避增益
    if (isCritical && attacker.card_name === '公孙离') {
      if (!attacker.dodge_bonus) attacker.dodge_bonus = 0;
      if (attacker.dodge_bonus < 0.20) {
        attacker.dodge_bonus += 0.05;
        attacker.dodge_rate = 0.30 + attacker.dodge_bonus;
        console.log(`   ⭐ ${attacker.card_name}攻击暴击：闪避率+5% (当前:${(attacker.dodge_rate*100).toFixed(1)}%)`);
      }
    }
    
    const actualDamage = isDodged ? 0 : finalDamage;
    const originalDamage = finalDamage;  // 🎯 保存闪避前的原始伤害
    
    // 应用伤害（先消耗护盾，再扣生命值）
    const oldHealth = target.health;
    const oldShield = target.shield || 0;
    let remainingDamage = actualDamage;
    
    // 先消耗护盾
    if (oldShield > 0 && remainingDamage > 0) {
      const shieldAbsorbed = Math.min(oldShield, remainingDamage);
      target.shield = oldShield - shieldAbsorbed;
      remainingDamage -= shieldAbsorbed;
      console.log(`   🛡️ 护盾吸收 ${shieldAbsorbed} 伤害 (护盾: ${oldShield} → ${target.shield})`);
    }
    
    // 剩余伤害扣生命值
    if (remainingDamage > 0) {
      target.health = Math.max(0, target.health - remainingDamage);
      console.log(`   💔 生命值扣除 ${remainingDamage} (生命: ${oldHealth} → ${target.health})`);
    }
    
    console.log(`   📊 最终伤害: ${actualDamage}, ${target.card_name} HP:${target.health}/${target.max_health} 护盾:${target.shield || 0}`);
    if (target.health <= 0) {
      console.log(`   ☠️  ${target.card_name} 被击败!`);
    }
    
    // 🎯 孙尚香被动技能：千金重弩（攻击命中时50%概率获得1技能点）
    let skillPointGained = false;
    let skillPointChange = null;
    
    if (attacker.card_name === '孙尚香' && !isDodged && actualDamage > 0) {
      const triggerChance = Math.random();
      if (triggerChance < 0.5) {
        // 判断攻击者所属阵营
        const isAttackerBlue = this.state.blueCards.some(c => c.id === attackerId);
        const currentSkillPoints = isAttackerBlue ? this.state.blueSkillPoints : this.state.redSkillPoints;
        const maxSkillPoints = 6;
        
        if (currentSkillPoints < maxSkillPoints) {
          // 增加技能点
          if (isAttackerBlue) {
            this.state.blueSkillPoints++;
          } else {
            this.state.redSkillPoints++;
          }
          
          skillPointGained = true;
          skillPointChange = {
            team: isAttackerBlue ? 'blue' : 'red',
            old_value: currentSkillPoints,
            new_value: currentSkillPoints + 1
          };
          
          console.log(`   ⭐ 孙尚香被动「千金重弩」触发！获得1点技能点 (${currentSkillPoints} → ${currentSkillPoints + 1})`);
        } else {
          console.log(`   ⭐ 孙尚香被动「千金重弩」触发！但技能点已满 (${maxSkillPoints}/${maxSkillPoints})`);
        }
      }
    }
    
    const result = {
      attacker_id: attackerId,
      target_id: targetId,
      damage: actualDamage,
      original_damage: originalDamage,  // 🎯 闪避前的原始伤害
      is_critical: isCritical,
      is_dodged: isDodged,
      target_health: target.health,
      target_shield: target.shield || 0,  // 🛡️ 同步护盾值
      target_dead: target.health <= 0,
      // 🎯 孙尚香被动技能点获取
      passive_skill_triggered: skillPointGained,
      skill_point_change: skillPointChange,
      // 🎯 同步卡牌属性变化（用于被动技能）
      attacker_stats: {
        attack: attacker.attack,
        crit_rate: attacker.crit_rate,
        crit_damage: attacker.crit_damage,
        dodge_rate: attacker.dodge_rate || 0,
        shield: attacker.shield || 0
      },
      target_stats: {
        attack: target.attack,
        crit_rate: target.crit_rate,
        crit_damage: target.crit_damage,
        dodge_rate: target.dodge_rate || 0,
        shield: target.shield || 0
      }
    };
    
    return result;
  }
  
  // 🎮 计算技能（完整版 - 使用SkillCalculator）
  calculateSkill(casterId, skillName, params) {
    console.log('[BattleEngine] 计算技能:', casterId, skillName, params);
    
    // 使用SkillCalculator进行完整的技能计算
    const result = this.skillCalculator.executeSkill(casterId, skillName, params);
    
    if (result && result.success) {
      console.log('[BattleEngine] 技能计算成功:', result.effect_type);
    } else {
      console.error('[BattleEngine] 技能计算失败:', result ? result.error : '未知错误');
    }
    
    return result;
  }
  
  // 获取当前游戏状态
  getState() {
    return this.state;
  }
}

module.exports = BattleEngine;
