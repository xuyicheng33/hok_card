/**
 * 🔨 装备合成配方系统
 * 阶段1：定向合成（BASIC → ADVANCED）
 * 阶段2（预留）：分级合成（ADVANCED → EPIC → LEGENDARY）
 */

const { EquipmentTier } = require('./EquipmentDatabase');
const fs = require('fs');
const path = require('path');

class CraftingRecipes {
  constructor() {
    // 优先尝试从共享 JSON 加载进阶配方
    this.advancedRecipes = {};
    const loaded = this._loadFromSharedJson();
    if (!loaded) {
      this.advancedRecipes = this._getFallbackRecipes();
      console.warn('[CraftingRecipes] 使用内置配方（未加载到共享 JSON）');
    }
    
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
    const sortedMaterials = [...materialIds].map(id => id).sort();

    // 搜索进阶装备配方
    for (const recipeId in this.advancedRecipes) {
      const recipe = this.advancedRecipes[recipeId];
      const recipeMaterials = recipe.materials.map(m =>
        typeof m === 'object' ? m.id : m
      ).sort();
      
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

  /**
   * 从共享 JSON 加载配方
   * @returns {boolean} 是否成功加载
   */
  _loadFromSharedJson() {
    try {
      const jsonPath = path.resolve(__dirname, '../../assets/data/equipment_data.json');
      if (!fs.existsSync(jsonPath)) {
        console.warn('[CraftingRecipes] 未找到共享 JSON:', jsonPath);
        return false;
      }
      const raw = fs.readFileSync(jsonPath, 'utf-8');
      const parsed = JSON.parse(raw);

      if (Array.isArray(parsed.advanced_recipes)) {
        for (const recipe of parsed.advanced_recipes) {
          this.advancedRecipes[recipe.id] = recipe;
        }
        console.log('[CraftingRecipes] 已从共享 JSON 加载 %d 个配方', parsed.advanced_recipes.length);
        return true;
      }
      return false;
    } catch (err) {
      console.error('[CraftingRecipes] 加载共享 JSON 失败:', err);
      return false;
    }
  }

  /**
   * 获取内置的备用配方
   * @returns {Object} 配方对象
   */
  _getFallbackRecipes() {
    return {
      'advanced_001': {
        id: 'advanced_001',
        name: '暴烈之刃',
        tier: 'advanced',
        category: 'attack',
        icon: '暴烈之刃.png',
        materials: ['basic_001', 'basic_002'],
        effects: [
          { type: 'attack', value: 30 },
          { type: 'crit_rate', value: 0.15 }
        ],
        description: '攻击力+30，暴击率+15%'
      }
    };
  }
}

// 导出单例
const craftingDB = new CraftingRecipes();

module.exports = {
  CraftingRecipes,
  craftingDB
};
