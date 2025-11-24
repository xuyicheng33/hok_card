/**
 * 🔨 装备合成配方系统
 * 阶段1：定向合成（BASIC → ADVANCED）
 * 阶段2（预留）：分级合成（ADVANCED → EPIC → LEGENDARY）
 */

const { EquipmentTier } = require('./EquipmentDatabase');

class CraftingRecipes {
  constructor() {
    /**
     * 🎯 阶段1：进阶装备配方
     * 格式：{
     *   id: 装备ID,
     *   name: 装备名称,
     *   tier: 'advanced',
     *   category: 'attack' | 'defense',
     *   description: 描述,
     *   icon: 图标文件名（可选）,
     *   effects: [{ type: 效果类型, value: 数值 }],
     *   cost: 合成金币消耗,
     *   materials: [{ id: 材料ID, name: 材料名 }]
     * }
     */
    this.advancedRecipes = {
      // ⚔️ 攻击类进阶装备
      'adv_001': {
        id: 'adv_001',
        name: '风暴巨剑',
        tier: 'advanced',
        category: 'attack',
        description: '增加50点攻击力',
        icon: '铁剑.png',  // 使用铁剑图标
        effects: [
          { type: 'attack', value: 50 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_001', name: '铁剑' },
          { id: 'basic_001', name: '铁剑' }
        ]
      },
      'adv_002': {
        id: 'adv_002',
        name: '穿云弓',
        tier: 'advanced',
        category: 'attack',
        description: '增加15%暴击率和5%伤害增幅',
        icon: '搏击拳套.png',  // 使用搏击拳套图标
        effects: [
          { type: 'crit_rate', value: 0.15 },
          { type: 'damage_amplify', value: 0.05 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_002', name: '搏击拳套' },
          { id: 'basic_004', name: '匕首' }
        ]
      },
      'adv_003': {
        id: 'adv_003',
        name: '速击之枪',
        tier: 'advanced',
        category: 'attack',
        description: '增加25点攻击力和7%伤害增幅',
        icon: '匕首.png',  // 使用匕首图标
        effects: [
          { type: 'attack', value: 25 },
          { type: 'damage_amplify', value: 0.07 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_001', name: '铁剑' },
          { id: 'basic_004', name: '匕首' }
        ]
      },
      'adv_004': {
        id: 'adv_004',
        name: '狂暴双刃',
        tier: 'advanced',
        category: 'attack',
        description: '增加13%暴击率和10%暴击效果',
        icon: '雷鸣刃.png',  // 使用雷鸣刃图标
        effects: [
          { type: 'crit_rate', value: 0.13 },
          { type: 'crit_damage', value: 0.10 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_002', name: '搏击拳套' },
          { id: 'basic_003', name: '雷鸣刃' }
        ]
      },
      'adv_005': {
        id: 'adv_005',
        name: '日冕',
        tier: 'advanced',
        category: 'attack',
        description: '增加25点攻击力和250点最大生命值',
        icon: '红玛瑙.png',  // 使用红玛瑙图标
        effects: [
          { type: 'attack', value: 25 },
          { type: 'max_health', value: 250 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_005', name: '红玛瑙' },
          { id: 'basic_001', name: '铁剑' }
        ]
      },
      
      // 🛡️ 防御类进阶装备
      'adv_006': {
        id: 'adv_006',
        name: '力量腰带',
        tier: 'advanced',
        category: 'defense',
        description: '增加500点最大生命值',
        icon: '红玛瑙.png',  // 使用红玛瑙图标
        effects: [
          { type: 'max_health', value: 500 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_005', name: '红玛瑙' },
          { id: 'basic_005', name: '红玛瑙' }
        ]
      },
      'adv_007': {
        id: 'adv_007',
        name: '荆棘护手',
        tier: 'advanced',
        category: 'defense',
        description: '增加25点攻击力和40点护甲',
        icon: '布甲.png',  // 使用布甲图标
        effects: [
          { type: 'attack', value: 25 },
          { type: 'armor', value: 40 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_001', name: '铁剑' },
          { id: 'basic_006', name: '布甲' }
        ]
      },
      'adv_008': {
        id: 'adv_008',
        name: '守护者之铠',
        tier: 'advanced',
        category: 'defense',
        description: '增加300点最大生命值和40点护甲',
        icon: '布甲.png',  // 使用布甲图标
        effects: [
          { type: 'max_health', value: 300 },
          { type: 'armor', value: 40 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_005', name: '红玛瑙' },
          { id: 'basic_006', name: '布甲' }
        ]
      },
      'adv_009': {
        id: 'adv_009',
        name: '熔炼之心',
        tier: 'advanced',
        category: 'defense',
        description: '每回合恢复50点生命值，增加400点最大生命值',
        icon: '提神水晶.png',  // 使用提神水晶图标
        effects: [
          { type: 'heal_per_turn', value: 50 },
          { type: 'max_health', value: 400 }
        ],
        cost: 10,
        materials: [
          { id: 'basic_007', name: '提神水晶' },
          { id: 'basic_005', name: '红玛瑙' }
        ]
      }
    };
    
    /**
     * 🔑 阶段2（预留）：史诗装备配方
     * ADVANCED + ADVANCED → EPIC
     */
    this.epicRecipes = {
      // 预留...
    };
    
    /**
     * 🔑 阶段2（预留）：传说装备配方
     * EPIC + EPIC → LEGENDARY
     */
    this.legendaryRecipes = {
      // 预留...
    };
  }
  
  /**
   * 添加进阶装备配方（用于动态添加用户设计的配方）
   * @param {Object} recipe - 配方对象
   */
  addAdvancedRecipe(recipe) {
    if (!recipe.id || !recipe.name || !recipe.materials) {
      console.error('❌ [配方错误] 缺少必要字段:', recipe);
      return false;
    }
    
    if (recipe.materials.length !== 2) {
      console.error('❌ [配方错误] 材料数量必须为2:', recipe.materials);
      return false;
    }
    
    this.advancedRecipes[recipe.id] = recipe;
    console.log('✅ [配方添加] 成功添加配方:', recipe.name);
    return true;
  }
  
  /**
   * 批量添加进阶装备配方
   * @param {Array} recipes - 配方数组
   */
  addAdvancedRecipesBatch(recipes) {
    let successCount = 0;
    for (const recipe of recipes) {
      if (this.addAdvancedRecipe(recipe)) {
        successCount++;
      }
    }
    console.log(`✅ [批量添加] 成功添加 ${successCount}/${recipes.length} 个配方`);
    return successCount;
  }
  
  /**
   * 根据材料查找配方
   * @param {Array} materialIds - 材料装备ID数组（必须2个）
   * @returns {Object|null} - 配方对象或null
   */
  findRecipeByMaterials(materialIds) {
    if (!materialIds || materialIds.length !== 2) {
      return null;
    }
    
    // 排序后比较（顺序无关）
    const sortedMaterials = [...materialIds].sort();
    
    // 搜索进阶装备配方
    for (const recipeId in this.advancedRecipes) {
      const recipe = this.advancedRecipes[recipeId];
      const recipeMaterials = recipe.materials.map(m => m.id).sort();
      
      // 比较两个数组是否相同
      if (JSON.stringify(sortedMaterials) === JSON.stringify(recipeMaterials)) {
        return recipe;
      }
    }
    
    // 🔑 阶段2：搜索史诗装备配方
    // TODO: 实现史诗装备配方查找
    
    return null; // 没有匹配的配方
  }
  
  /**
   * 根据ID获取配方
   * @param {String} recipeId - 配方ID
   * @returns {Object|null}
   */
  getRecipe(recipeId) {
    return this.advancedRecipes[recipeId] || 
           this.epicRecipes[recipeId] || 
           this.legendaryRecipes[recipeId] || 
           null;
  }
  
  /**
   * 获取所有进阶装备配方（用于客户端展示合成表）
   * @returns {Array}
   */
  getAllAdvancedRecipes() {
    return Object.values(this.advancedRecipes);
  }
  
  /**
   * 获取所有配方
   * @returns {Object}
   */
  getAllRecipes() {
    return {
      advanced: Object.values(this.advancedRecipes),
      epic: Object.values(this.epicRecipes),
      legendary: Object.values(this.legendaryRecipes)
    };
  }
  
  /**
   * 🔑 阶段2扩展：获取装备升级路径
   * @param {String} equipmentId - 装备ID
   * @returns {Object|null} - { current, next, canUpgrade }
   */
  getUpgradePath(equipmentId) {
    const recipe = this.advancedRecipes[equipmentId];
    if (!recipe || !recipe.upgradeTo) {
      return null;
    }
    
    return {
      current: recipe,
      next: this.epicRecipes[recipe.upgradeTo] || null,
      canUpgrade: !!this.epicRecipes[recipe.upgradeTo]
    };
  }
  
  /**
   * 获取配方统计信息
   * @returns {Object}
   */
  getStats() {
    return {
      advanced: Object.keys(this.advancedRecipes).length,
      epic: Object.keys(this.epicRecipes).length,
      legendary: Object.keys(this.legendaryRecipes).length,
      total: Object.keys(this.advancedRecipes).length + 
             Object.keys(this.epicRecipes).length + 
             Object.keys(this.legendaryRecipes).length
    };
  }
}

// 导出单例
const craftingDB = new CraftingRecipes();

module.exports = {
  CraftingRecipes,
  craftingDB
};
