// 卡牌数据库 - 服务器端权威数据源
// 优先尝试加载客户端共用的 JSON 数据以保证数值一致；失败时回退到内置表
const fs = require('fs');
const path = require('path');

class CardDatabase {
  constructor() {
    this.cards = {};
    // 先尝试从共享 JSON 加载
    const loaded = this._loadFromSharedJson();
    if (!loaded) {
      console.warn('[CardDatabase] JSON 加载失败，使用内置默认数据');
      this.cards = this._getFallbackCards();
    }
  }

  /**
   * 尝试从客户端共享的 cards_data.json 加载，保证两端数值一致
   * @returns {boolean} 是否加载成功
   */
  _loadFromSharedJson() {
    try {
      // 服务器目录为 server/，客户端资源在仓库根 assets/ 下
      const jsonPath = path.resolve(__dirname, '../../assets/data/cards_data.json');
      if (!fs.existsSync(jsonPath)) {
        console.warn('[CardDatabase] 未找到共享 JSON 文件:', jsonPath);
        return false;
      }
      const raw = fs.readFileSync(jsonPath, 'utf-8');
      const parsed = JSON.parse(raw);
      if (!parsed.cards || typeof parsed.cards !== 'object') {
        console.warn('[CardDatabase] JSON 结构缺少 cards 字段');
        return false;
      }

      const mapped = {};
      for (const [id, card] of Object.entries(parsed.cards)) {
        // 将客户端字段映射到服务器结构
        mapped[id] = {
          card_name: card.name,
          max_health: card.health,
          attack: card.attack,
          armor: card.armor,
          crit_rate: card.crit_rate ?? 0,
          crit_damage: card.crit_damage ?? 1.3,
          dodge_rate: card.dodge_rate ?? 0,
          dodge_bonus: 0,
          skill_name: card.skill_name,
          skill_cost: card.skill_cost ?? 2,
          skill_ends_turn: card.skill_ends_turn ?? false,
          stolen_points: 0,
          skill_used: false,
          daqiao_passive_used: false
        };
      }

      this.cards = mapped;
      console.log('[CardDatabase] 已从共享 JSON 加载 %d 张卡牌', Object.keys(mapped).length);
      return true;
    } catch (err) {
      console.error('[CardDatabase] 读取共享 JSON 失败:', err);
      return false;
    }
  }

  /**
   * 内置默认数据（仅作为兜底）
   */
  _getFallbackCards() {
    return {
      duoliya_001: {
        card_name: '朵莉亚',
        max_health: 900,
        attack: 330,
        armor: 325,
        crit_rate: 0.05,
        crit_damage: 1.3,
        skill_name: '人鱼之赐',
        skill_cost: 1,
        skill_ends_turn: false
      },
      lan_002: {
        card_name: '澜',
        max_health: 700,
        attack: 400,
        armor: 250,
        crit_rate: 0.1,
        crit_damage: 1.3,
        skill_name: '鲨之猎刃',
        skill_cost: 2,
        skill_ends_turn: false
      },
      gongsunli_003: {
        card_name: '公孙离',
        max_health: 600,
        attack: 575,
        armor: 150,
        crit_rate: 0.2,
        crit_damage: 1.3,
        dodge_rate: 0.25,
        dodge_bonus: 0.0,
        skill_name: '晚云落',
        skill_cost: 3,
        skill_ends_turn: false
      },
      sunshangxiang_004: {
        card_name: '孙尚香',
        max_health: 625,
        attack: 550,
        armor: 175,
        crit_rate: 0.15,
        crit_damage: 1.3,
        skill_name: '红莲爆弹',
        skill_cost: 2,
        skill_ends_turn: true
      },
      yao_005: {
        card_name: '瑶',
        max_health: 850,
        attack: 280,
        armor: 200,
        crit_rate: 0.0,
        crit_damage: 1.3,
        skill_name: '鹿灵守心',
        skill_cost: 2,
        skill_ends_turn: true
      },
      daqiao_006: {
        card_name: '大乔',
        max_health: 800,
        attack: 300,
        armor: 150,
        crit_rate: 0.1,
        crit_damage: 1.3,
        skill_name: '沧海之曜',
        skill_cost: 4,
        skill_ends_turn: true
      },
      shaosiyuan_007: {
        card_name: '少司缘',
        max_health: 750,
        attack: 350,
        armor: 225,
        crit_rate: 0.1,
        crit_damage: 1.3,
        stolen_points: 0,
        skill_name: '两同心',
        skill_cost: 2,
        skill_ends_turn: false
      },
      yangyuhuan_008: {
        card_name: '杨玉环',
        max_health: 700,
        attack: 400,
        armor: 150,
        crit_rate: 0.15,
        crit_damage: 1.3,
        skill_used: false,
        skill_name: '惊鸿曲',
        skill_cost: 2,
        skill_ends_turn: true
      }
    };
  }

  getCard(cardId) {
    const baseCard = this.cards[cardId];
    if (!baseCard) {
      console.error('未找到卡牌:', cardId);
      return null;
    }
    // 返回副本，避免污染原始数据
    return JSON.parse(JSON.stringify(baseCard));
  }
}

module.exports = CardDatabase;
