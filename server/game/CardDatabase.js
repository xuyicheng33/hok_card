// 卡牌数据库 - 服务器端权威数据源
class CardDatabase {
  constructor() {
    // 完整的8个英雄数据
    this.cards = {
      'duoliya_001': {
        card_name: '朵莉亚',
        max_health: 900,
        attack: 300,
        armor: 300,
        crit_rate: 0.05,
        crit_damage: 1.30,
        skill_name: '人鱼之赐',
        skill_cost: 1,
        skill_ends_turn: false
      },
      'lan_002': {
        card_name: '澜',
        max_health: 700,
        attack: 400,
        armor: 250,
        crit_rate: 0.10,
        crit_damage: 1.30,
        skill_name: '鲨之猎刃',
        skill_cost: 2,
        skill_ends_turn: false
      },
      'gongsunli_003': {
        card_name: '公孙离',
        max_health: 600,
        attack: 600,
        armor: 150,
        crit_rate: 0.20,
        crit_damage: 1.30,
        dodge_rate: 0.30,
        dodge_bonus: 0.0,
        skill_name: '晚云落',
        skill_cost: 3,
        skill_ends_turn: false
      },
      'sunshangxiang_004': {
        card_name: '孙尚香',
        max_health: 625,
        attack: 550,
        armor: 175,
        crit_rate: 0.15,
        crit_damage: 1.30,
        skill_name: '红莲爆弹',
        skill_cost: 2,
        skill_ends_turn: true
      },
      'yao_005': {
        card_name: '瑶',
        max_health: 850,
        attack: 280,
        armor: 200,
        crit_rate: 0.0,
        crit_damage: 1.30,
        skill_name: '鹿灵守心',
        skill_cost: 2,
        skill_ends_turn: true
      },
      'daqiao_006': {
        card_name: '大乔',
        max_health: 800,
        attack: 300,
        armor: 150,
        crit_rate: 0.10,
        crit_damage: 1.30,
        skill_name: '沧海之曜',
        skill_cost: 4,
        skill_ends_turn: true
      },
      'shaosiyuan_007': {
        card_name: '少司缘',
        max_health: 750,
        attack: 350,
        armor: 225,
        crit_rate: 0.10,
        crit_damage: 1.30,
        stolen_points: 0,
        skill_name: '两同心',
        skill_cost: 2,
        skill_ends_turn: false
      },
      'yangyuhuan_008': {
        card_name: '杨玉环',
        max_health: 700,
        attack: 400,
        armor: 150,
        crit_rate: 0.15,
        crit_damage: 1.30,
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
