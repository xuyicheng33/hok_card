/**
 * 装备数据库
 * 管理所有装备的数据和效果
 */

// 装备等级枚举
const EquipmentTier = {
  BASIC: 'basic',       // 基础装备
  ADVANCED: 'advanced', // 进阶装备
  LEGENDARY: 'legendary' // 传说装备
};

// 装备分类枚举
const EquipmentCategory = {
  ATTACK: 'attack',   // 攻击类
  DEFENSE: 'defense'  // 防御类
};

// 效果类型枚举
const EffectType = {
  // 静态属性（战斗开始时应用）
  ATTACK: 'attack',               // 攻击力
  MAX_HEALTH: 'max_health',       // 最大生命值
  ARMOR: 'armor',                 // 护甲
  CRIT_RATE: 'crit_rate',         // 暴击率
  CRIT_DAMAGE: 'crit_damage',     // 暴击伤害
  DODGE_RATE: 'dodge_rate',       // 闪避率
  
  // 战斗效果（战斗中触发）
  DAMAGE_AMPLIFY: 'damage_amplify', // 增伤百分比
  HEAL_PER_TURN: 'heal_per_turn'    // 每回合恢复
};

// 基础装备数据
const BASIC_EQUIPMENT = [
  // 攻击类
  {
    id: 'basic_001',
    name: '铁剑',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.ATTACK,
    icon: '铁剑.png',
    price: 0, // 抽取获得，不单独购买
    effects: [
      { type: EffectType.ATTACK, value: 20 }
    ],
    description: '增加20点攻击力'
  },
  {
    id: 'basic_002',
    name: '搏击拳套',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.ATTACK,
    icon: '搏击拳套.png',
    price: 0,
    effects: [
      { type: EffectType.CRIT_RATE, value: 0.10 }
    ],
    description: '增加10%暴击率'
  },
  {
    id: 'basic_003',
    name: '雷鸣刃',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.ATTACK,
    icon: '雷鸣刃.png',
    price: 0,
    effects: [
      { type: EffectType.CRIT_DAMAGE, value: 0.05 }
    ],
    description: '增加5%暴击效果'
  },
  {
    id: 'basic_004',
    name: '匕首',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.ATTACK,
    icon: '匕首.png',
    price: 0,
    effects: [
      { type: EffectType.DAMAGE_AMPLIFY, value: 0.03 }
    ],
    description: '增加3%伤害'
  },
  
  // 防御类
  {
    id: 'basic_005',
    name: '红玛瑙',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.DEFENSE,
    icon: '红玛瑙.png',
    price: 0,
    effects: [
      { type: EffectType.MAX_HEALTH, value: 200 }
    ],
    description: '增加200点最大生命值'
  },
  {
    id: 'basic_006',
    name: '布甲',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.DEFENSE,
    icon: '布甲.png',
    price: 0,
    effects: [
      { type: EffectType.ARMOR, value: 30 }
    ],
    description: '增加30点护甲'
  },
  {
    id: 'basic_007',
    name: '提神水晶',
    tier: EquipmentTier.BASIC,
    category: EquipmentCategory.DEFENSE,
    icon: '提神水晶.png',
    price: 0,
    effects: [
      { type: EffectType.HEAL_PER_TURN, value: 30 }
    ],
    description: '每回合开始时恢复30点生命值'
  }
];

/**
 * 装备数据库类
 */
class EquipmentDatabase {
  constructor() {
    this.equipment = {
      [EquipmentTier.BASIC]: BASIC_EQUIPMENT,
      [EquipmentTier.ADVANCED]: [], // 未来添加
      [EquipmentTier.LEGENDARY]: [] // 未来添加
    };
  }

  /**
   * 根据ID获取装备
   */
  getEquipmentById(id) {
    for (const tier in this.equipment) {
      const found = this.equipment[tier].find(eq => eq.id === id);
      if (found) return JSON.parse(JSON.stringify(found)); // 深拷贝
    }
    return null;
  }

  /**
   * 获取指定等级的所有装备
   */
  getEquipmentByTier(tier) {
    return JSON.parse(JSON.stringify(this.equipment[tier] || []));
  }

  /**
   * 从指定等级随机抽取N个装备
   */
  drawRandomEquipment(tier, count = 3) {
    const pool = this.getEquipmentByTier(tier);
    if (pool.length === 0) return [];
    
    // 洗牌算法（Fisher-Yates）
    const shuffled = [...pool];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    
    return shuffled.slice(0, Math.min(count, shuffled.length));
  }

  /**
   * 应用装备效果到卡牌
   * @param {Object} card - 卡牌对象
   * @param {Object} equipment - 装备对象
   */
  applyEquipmentEffects(card, equipment) {
    if (!equipment || !equipment.effects) return;

    console.log(`   📦 应用装备「${equipment.name}」到 ${card.card_name}`);
    
    for (const effect of equipment.effects) {
      switch (effect.type) {
        case EffectType.ATTACK:
          card.attack += effect.value;
          console.log(`      ⚔️  攻击力: +${effect.value} (→${card.attack})`);
          break;
          
        case EffectType.MAX_HEALTH:
          card.max_health += effect.value;
          card.health += effect.value; // 当前生命也增加
          console.log(`      ❤️  最大生命: +${effect.value} (→${card.max_health})`);
          break;
          
        case EffectType.ARMOR:
          card.armor += effect.value;
          console.log(`      🛡️  护甲: +${effect.value} (→${card.armor})`);
          break;
          
        case EffectType.CRIT_RATE:
          card.crit_rate += effect.value;
          console.log(`      💥 暴击率: +${(effect.value * 100).toFixed(1)}% (→${(card.crit_rate * 100).toFixed(1)}%)`);
          break;
          
        case EffectType.CRIT_DAMAGE:
          card.crit_damage += effect.value;
          console.log(`      💢 暴击伤害: +${(effect.value * 100).toFixed(1)}% (→${(card.crit_damage * 100).toFixed(1)}%)`);
          break;
          
        case EffectType.DODGE_RATE:
          card.dodge_rate += effect.value;
          console.log(`      💨 闪避率: +${(effect.value * 100).toFixed(1)}% (→${(card.dodge_rate * 100).toFixed(1)}%)`);
          break;
          
        // DAMAGE_AMPLIFY 和 HEAL_PER_TURN 在战斗中处理
        case EffectType.DAMAGE_AMPLIFY:
          console.log(`      🗡️  增伤: +${(effect.value * 100).toFixed(1)}% (战斗中生效)`);
          break;
          
        case EffectType.HEAL_PER_TURN:
          console.log(`      💚 每回合恢复: +${effect.value} (回合开始生效)`);
          break;
      }
    }
  }
}

// 导出单例
const equipmentDB = new EquipmentDatabase();

module.exports = {
  EquipmentDatabase,
  equipmentDB,
  EquipmentTier,
  EquipmentCategory,
  EffectType
};
