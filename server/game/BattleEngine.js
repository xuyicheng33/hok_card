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
    let baseDamage = Math.floor(attacker.attack * (200 / (target.armor + 200)));
    const damageReduction = (target.armor / (target.armor + 200) * 100).toFixed(1);
    console.log(`   💥 基础伤害 = ${attacker.attack} × (200/${target.armor + 200}) = ${baseDamage} (减伤率:${damageReduction}%)`);
    
    // 🎯 澜的被动技能：狩猎（目标血量<50%时增伤30%）
    if (attacker.card_name === '澜' && target.health < target.max_health * 0.5) {
      const bonusDamage = Math.floor(baseDamage * 0.3);
      baseDamage = baseDamage + bonusDamage;
      console.log(`   ⭐ 澜被动「狩猎」触发！目标血量${target.health}/${target.max_health} < 50%`);
      console.log(`   💀 斩杀增伤: +30% (${baseDamage - bonusDamage} → ${baseDamage})`);
    }
    
    // 🗡️ 装备效果：匕首（增伤+3%）
    if (attacker.equipment && attacker.equipment.length > 0) {
      for (const equip of attacker.equipment) {
        if (equip.effects) {
          for (const effect of equip.effects) {
            if (effect.type === 'damage_amplify') {
              const bonusDamage = Math.floor(baseDamage * effect.value);
              baseDamage = baseDamage + bonusDamage;
              console.log(`   🗡️ 装备「${equip.name}」增伤: +${(effect.value * 100).toFixed(1)}% (${baseDamage - bonusDamage} → ${baseDamage})`);
            }
          }
        }
      }
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
      if (attacker.dodge_bonus < 0.25) {
        attacker.dodge_bonus += 0.05;
        attacker.dodge_rate = 0.25 + attacker.dodge_bonus;
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
    
    // 🌟 大乔被动技能：宿命之海（受到致命伤害时触发）
    let daqiaoPassiveTriggered = false;
    let daqiaoPassiveData = null;
    
    if (target.card_name === '大乔' && target.health <= 0 && !target.daqiao_passive_used) {
      // 标记被动已使用
      target.daqiao_passive_used = true;
      
      // 生命值设置为1点
      target.health = 1;
      
      // 判断大乔所属阵营
      const isDaqiaoBlue = this.state.blueCards.some(c => c.id === targetId);
      const currentSkillPoints = isDaqiaoBlue ? this.state.blueSkillPoints : this.state.redSkillPoints;
      const maxSkillPoints = 6;
      const skillPointsToGain = 3;
      
      // 计算实际获得的技能点和溢出
      const totalAfterGain = currentSkillPoints + skillPointsToGain;
      const newSkillPoints = Math.min(maxSkillPoints, totalAfterGain);
      const actualGainedPoints = newSkillPoints - currentSkillPoints;
      const overflowPoints = Math.max(0, totalAfterGain - maxSkillPoints);
      
      // 更新技能点
      if (isDaqiaoBlue) {
        this.state.blueSkillPoints = newSkillPoints;
      } else {
        this.state.redSkillPoints = newSkillPoints;
      }
      
      // 计算溢出转换的护盾
      const shieldFromOverflow = overflowPoints * 150;
      if (shieldFromOverflow > 0) {
        target.shield = (target.shield || 0) + shieldFromOverflow;
      }
      
      daqiaoPassiveTriggered = true;
      daqiaoPassiveData = {
        team: isDaqiaoBlue ? 'blue' : 'red',
        old_health: 0,
        new_health: 1,
        old_skill_points: currentSkillPoints,
        new_skill_points: newSkillPoints,
        skill_points_gained: skillPointsToGain,
        actual_gained_points: actualGainedPoints,
        overflow_points: overflowPoints,
        shield_amount: shieldFromOverflow,
        new_shield: target.shield || 0
      };
      
      console.log(`   ⭐ 大乔被动「宿命之海」触发！生命值→1`);
      console.log(`   💫 技能点: ${currentSkillPoints} + ${skillPointsToGain} → ${newSkillPoints} (实际+${actualGainedPoints})`);
      if (overflowPoints > 0) {
        console.log(`   🛡️ 溢出${overflowPoints}点技能点 → ${shieldFromOverflow}护盾 (总护盾:${target.shield})`);
      }
    }
    
    // 🎯 孙尚香被动技能：千金重弩（攻击命中时70%概率获得1技能点）
    let skillPointGained = false;
    let skillPointChange = null;
    
    if (attacker.card_name === '孙尚香' && !isDodged && actualDamage > 0) {
      const triggerChance = Math.random();
      if (triggerChance < 0.7) {
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
    
    // 🦌 瑶被动技能：山鬼白鹿（受到伤害时，为绝对血量最低的友方提供护盾）
    let yaoPassiveTriggered = false;
    let yaoPassiveTarget = null;
    let yaoShieldAmount = 0;
    
    if (target.card_name === '瑶' && !isDodged && actualDamage > 0) {
      // 判断瑶所属阵营
      const isYaoBlue = this.state.blueCards.some(c => c.id === targetId);
      const allies = isYaoBlue ? this.state.blueCards : this.state.redCards;
      
      // 查找绝对血量最低的友方（包括瑶自己）
      let lowestHpAlly = null;
      let lowestHealth = 999999;
      
      allies.forEach(ally => {
        if (ally.health > 0 && ally.health < lowestHealth) {  // 只考虑存活的友方
          lowestHealth = ally.health;
          lowestHpAlly = ally;
        }
      });
      
      if (lowestHpAlly) {
        // 计算护盾量：100 + 瑶当前生命值×3%
        yaoShieldAmount = Math.floor(100 + target.health * 0.03);
        lowestHpAlly.shield = (lowestHpAlly.shield || 0) + yaoShieldAmount;
        
        yaoPassiveTriggered = true;
        yaoPassiveTarget = {
          id: lowestHpAlly.id,
          name: lowestHpAlly.card_name,
          shield: lowestHpAlly.shield
        };
        
        console.log(`   🦌 瑶被动「山鬼白鹿」触发！为${lowestHpAlly.card_name}提供${yaoShieldAmount}点护盾 (当前护盾:${lowestHpAlly.shield})`);
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
      // 🌟 大乔被动技能：宿命之海
      daqiao_passive_triggered: daqiaoPassiveTriggered,
      daqiao_passive_data: daqiaoPassiveData,
      // 🎯 孙尚香被动技能点获取
      passive_skill_triggered: skillPointGained,
      skill_point_change: skillPointChange,
      // 🦌 瑶被动技能护盾
      yao_passive_triggered: yaoPassiveTriggered,
      yao_passive_target: yaoPassiveTarget,
      yao_shield_amount: yaoShieldAmount,
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
