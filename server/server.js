const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const CardDatabase = require('./game/CardDatabase');
const BattleEngine = require('./game/BattleEngine');
const GoldManager = require('./game/GoldManager');
const GoldValidator = require('./utils/GoldValidator');
const { equipmentDB, EquipmentTier } = require('./game/EquipmentDatabase');
const { craftingDB } = require('./game/CraftingRecipes'); // 🔨 合成系统

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });
const PORT = process.env.PORT || 3000;

const rooms = new Map();
const clients = new Map();
const playerRooms = new Map();
const battleEngines = new Map(); // 每个房间的战斗引擎
const cardDB = new CardDatabase();

// 🛡️ 安全配置：最大连接数限制
const MAX_CONNECTIONS = 2;  // 最多2个玩家连接（1v1对战）

function generateRoomId() {
  return Math.floor(Math.random() * 9 + 1).toString();
}

function generateClientId() {
  return 'player_' + Math.random().toString(36).substr(2, 9);
}

function sendToClient(clientId, message) {
  const ws = clients.get(clientId);
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

function broadcastToRoom(roomId, message, excludeClient = null) {
  const room = rooms.get(roomId);
  if (!room) return;
  room.players.forEach(playerId => {
    if (playerId !== excludeClient) {
      sendToClient(playerId, message);
    }
  });
}

// 💰 计算金币收入
function calculateGoldIncome(currentGold) {
  const baseIncome = 5;         // 基础收入
  const interestRate = 0.1;     // 利息率10%
  const maxInterest = 5;        // 利息上限5金币
  
  const interest = Math.min(Math.floor(currentGold * interestRate), maxInterest);
  const totalIncome = baseIncome + interest;
  
  return {
    base: baseIncome,
    interest: interest,
    total: totalIncome,
    newGold: currentGold + totalIncome
  };
}

// 序列化完整游戏状态（用于客户端校验/重建）
function buildFullState(room) {
  const gameState = room.gameState;
  const goldMgr = room.goldManager;

  const serializeCard = (card) => ({
    id: card.id,
    card_name: card.card_name,
    max_health: card.max_health,
    health: card.health,
    attack: card.attack,
    armor: card.armor,
    shield: card.shield || 0,
    crit_rate: card.crit_rate || 0,
    crit_damage: card.crit_damage || 1.3,
    dodge_rate: card.dodge_rate || 0,
    dodge_bonus: card.dodge_bonus || 0,
    equipment: card.equipment || [],
    daqiao_passive_used: card.daqiao_passive_used || false,
    skill_name: card.skill_name,
    skill_cost: card.skill_cost,
    skill_ends_turn: card.skill_ends_turn
  });

  return {
    type: 'full_state',
    turn: gameState.currentTurn,
    current_player: gameState.currentPlayer,
    host_skill_points: gameState.hostSkillPoints,
    guest_skill_points: gameState.guestSkillPoints,
    blue_actions_used: gameState.blueActionsUsed,
    red_actions_used: gameState.redActionsUsed,
    actions_per_turn: gameState.actionsPerTurn,
    host_gold: goldMgr ? goldMgr.hostGold : gameState.blueGold,
    guest_gold: goldMgr ? goldMgr.guestGold : gameState.redGold,
    blue_ougi_points: gameState.blueOugiPoints || 0,
    red_ougi_points: gameState.redOugiPoints || 0,
    max_ougi_points: gameState.maxOugiPoints || 5,
    blue_cards: gameState.blueCards.map(serializeCard),
    red_cards: gameState.redCards.map(serializeCard)
  };
}

// 🏆 检查游戏是否结束（服务器权威）
function checkGameOver(roomId, room) {
  const gameState = room.gameState;
  const goldMgr = room.goldManager;  // 获取金币管理器
  
  // 统计存活卡牌
  const blueAlive = gameState.blueCards.filter(c => c.health > 0).length;
  const redAlive = gameState.redCards.filter(c => c.health > 0).length;
  
  // 检查是否有队伍全灭
  if (blueAlive === 0) {
    console.log('\n🎉═══════════════════════════════════════════════════════');
    console.log('   游戏结束：红方（客户端）获胜！');
    console.log('   回合数: %d', gameState.currentTurn);
    console.log('   蓝方存活: %d/3 | 红方存活: %d/3', blueAlive, redAlive);
    console.log('═══════════════════════════════════════════════════════\n');
    
    // 广播游戏结束
    broadcastToRoom(roomId, {
      type: 'game_over',
      winner: 'red',
      winner_name: room.playerNames[room.guest] || '红方',
      loser: 'blue',
      loser_name: room.playerNames[room.host] || '蓝方',
      turns: gameState.currentTurn,
      reason: 'team_eliminated',
      final_state: {
        blue_alive: blueAlive,
        red_alive: redAlive,
        host_gold: goldMgr ? goldMgr.hostGold : 0,  // 安全访问
        guest_gold: goldMgr ? goldMgr.guestGold : 0  // 安全访问
      }
    });
    
    // 清理房间资源
    console.log('[房间清理] 游戏结束，清理房间:', roomId);
    rooms.delete(roomId);
    battleEngines.delete(roomId);
    
    // 断开玩家连接映射
    room.players.forEach(playerId => {
      playerRooms.delete(playerId);
    });
    
    return true;
  }
  
  if (redAlive === 0) {
    console.log('\n🎉═══════════════════════════════════════════════════════');
    console.log('   游戏结束：蓝方（房主）获胜！');
    console.log('   回合数: %d', gameState.currentTurn);
    console.log('   蓝方存活: %d/3 | 红方存活: %d/3', blueAlive, redAlive);
    console.log('═══════════════════════════════════════════════════════\n');
    
    // 广播游戏结束
    broadcastToRoom(roomId, {
      type: 'game_over',
      winner: 'blue',
      winner_name: room.playerNames[room.host] || '蓝方',
      loser: 'red',
      loser_name: room.playerNames[room.guest] || '红方',
      turns: gameState.currentTurn,
      reason: 'team_eliminated',
      final_state: {
        blue_alive: blueAlive,
        red_alive: redAlive,
        host_gold: goldMgr ? goldMgr.hostGold : 0,  // 安全访问
        guest_gold: goldMgr ? goldMgr.guestGold : 0  // 安全访问
      }
    });
    
    // 清理房间资源
    console.log('[房间清理] 游戏结束，清理房间:', roomId);
    rooms.delete(roomId);
    battleEngines.delete(roomId);
    
    // 断开玩家连接映射
    room.players.forEach(playerId => {
      playerRooms.delete(playerId);
    });
    
    return true;
  }
  
  // 游戏继续
  return false;
}

// ═══════════════════════════════════════════════════════
// 🎯 英雄选择系统 - 1-2-2-1 选人顺序
// ═══════════════════════════════════════════════════════

// 所有可选英雄列表
const ALL_HEROES = [
  { id: 'duoliya_001', name: '朵莉亚', role: '辅助' },
  { id: 'lan_002', name: '澜', role: '刺客' },
  { id: 'gongsunli_003', name: '公孙离', role: '射手' },
  { id: 'sunshangxiang_004', name: '孙尚香', role: '射手' },
  { id: 'yao_005', name: '瑶', role: '辅助' },
  { id: 'daqiao_006', name: '大乔', role: '辅助' },
  { id: 'shaosiyuan_007', name: '少司缘', role: '法师' },
  { id: 'yangyuhuan_008', name: '杨玉环', role: '法师' }
];

// 选人顺序: 1-2-2-1 (蓝1, 红2, 蓝2, 红1)
const PICK_ORDER = ['blue', 'red', 'red', 'blue', 'blue', 'red'];

// 开始选人阶段
function startPickPhase(roomId, room) {
  console.log('\n🎯═══════════════════════════════════════════════════════');
  console.log('   英雄选择阶段开始');
  console.log('   房间: %s', roomId);
  console.log('   选人顺序: 蓝1 → 红2 → 蓝2 → 红1');
  console.log('═══════════════════════════════════════════════════════\n');
  
  // 初始化选人状态
  room.pickState = {
    availableHeroes: [...ALL_HEROES],  // 可选英雄
    bluePicks: [],     // 蓝方已选
    redPicks: [],      // 红方已选
    currentPickIndex: 0,  // 当前选人顺序索引
    currentTeam: 'blue'   // 当前选人方
  };
  
  // 广播选人阶段开始
  broadcastToRoom(roomId, {
    type: 'pick_phase_start',
    available_heroes: room.pickState.availableHeroes,
    pick_order: PICK_ORDER,
    current_team: 'blue',
    current_pick_index: 0,
    blue_picks: [],
    red_picks: [],
    host_name: room.playerNames[room.host],
    guest_name: room.playerNames[room.guest]
  });
}

// 处理英雄选择
function handleHeroPick(roomId, room, clientId, heroId) {
  const pickState = room.pickState;
  if (!pickState) {
    console.error('[选人失败] 选人状态不存在');
    return { success: false, error: '选人阶段未开始' };
  }
  
  // 检查是否轮到该玩家
  const isHost = clientId === room.host;
  const currentTeam = pickState.currentTeam;
  const shouldBeHost = currentTeam === 'blue';
  
  if (isHost !== shouldBeHost) {
    console.error('[选人失败] 不是你的回合');
    return { success: false, error: '不是你的选人回合' };
  }
  
  // 检查英雄是否可选
  const heroIndex = pickState.availableHeroes.findIndex(h => h.id === heroId);
  if (heroIndex === -1) {
    console.error('[选人失败] 英雄不可选:', heroId);
    return { success: false, error: '该英雄已被选择或不存在' };
  }
  
  // 选择英雄
  const selectedHero = pickState.availableHeroes.splice(heroIndex, 1)[0];
  
  if (currentTeam === 'blue') {
    pickState.bluePicks.push(selectedHero);
    console.log('🔵 蓝方选择: %s', selectedHero.name);
  } else {
    pickState.redPicks.push(selectedHero);
    console.log('🔴 红方选择: %s', selectedHero.name);
  }
  
  // 更新选人顺序
  pickState.currentPickIndex++;
  
  // 检查是否选人完成
  if (pickState.currentPickIndex >= PICK_ORDER.length) {
    console.log('\n✅ 选人完成！');
    console.log('   蓝方: %s', pickState.bluePicks.map(h => h.name).join(', '));
    console.log('   红方: %s', pickState.redPicks.map(h => h.name).join(', '));
    
    // 广播选人结果
    broadcastToRoom(roomId, {
      type: 'pick_complete',
      blue_picks: pickState.bluePicks,
      red_picks: pickState.redPicks
    });
    
    // 延迟后开始游戏
    setTimeout(() => {
      finishPickPhase(roomId, room);
    }, 1000);
    
    return { success: true, complete: true };
  }
  
  // 更新当前选人方
  pickState.currentTeam = PICK_ORDER[pickState.currentPickIndex];
  
  // 广播选人更新
  broadcastToRoom(roomId, {
    type: 'pick_update',
    picked_hero: selectedHero,
    picked_by: currentTeam,
    available_heroes: pickState.availableHeroes,
    current_team: pickState.currentTeam,
    current_pick_index: pickState.currentPickIndex,
    blue_picks: pickState.bluePicks,
    red_picks: pickState.redPicks
  });
  
  return { success: true, complete: false };
}

// 选人完成，开始游戏
function finishPickPhase(roomId, room) {
  const pickState = room.pickState;
  
  console.log('\n🎮 初始化游戏...');
  
  // 使用选择的英雄初始化游戏
  initGameStateWithPicks(roomId, room, pickState.bluePicks, pickState.redPicks);
  
  // 切换房间状态
  room.status = 'playing';
  
  // 准备发送给客户端的卡牌数据
  const blueCardsData = room.gameState.blueCards.map(card => ({
    id: card.id,
    card_name: card.card_name,
    max_health: card.max_health,
    health: card.health,
    attack: card.attack,
    armor: card.armor,
    shield: card.shield || 0,
    crit_rate: card.crit_rate || 0,
    crit_damage: card.crit_damage || 1.3,
    skill_name: card.skill_name,
    skill_cost: card.skill_cost,
    dodge_rate: card.dodge_rate || 0,
    dodge_bonus: card.dodge_bonus || 0,
    daqiao_passive_used: card.daqiao_passive_used || false,
    skill_ends_turn: card.skill_ends_turn || false
  }));
  
  const redCardsData = room.gameState.redCards.map(card => ({
    id: card.id,
    card_name: card.card_name,
    max_health: card.max_health,
    health: card.health,
    attack: card.attack,
    armor: card.armor,
    shield: card.shield || 0,
    crit_rate: card.crit_rate || 0,
    crit_damage: card.crit_damage || 1.3,
    skill_name: card.skill_name,
    skill_cost: card.skill_cost,
    dodge_rate: card.dodge_rate || 0,
    dodge_bonus: card.dodge_bonus || 0,
    daqiao_passive_used: card.daqiao_passive_used || false,
    skill_ends_turn: card.skill_ends_turn || false
  }));
  
  // 广播游戏开始
  broadcastToRoom(roomId, { 
    type: 'game_start', 
    room_id: roomId, 
    players: room.players, 
    player_names: room.playerNames, 
    host: room.host,
    blue_cards: blueCardsData,
    red_cards: redCardsData,
    blue_cards_count: room.gameState.blueCards.length,
    red_cards_count: room.gameState.redCards.length,
    initial_skill_points: 4,
    actions_per_turn: 3,
    host_gold: room.goldManager ? room.goldManager.hostGold : 10,
    guest_gold: room.goldManager ? room.goldManager.guestGold : 10
  });
  
  console.log('[游戏开始]', roomId);
}

// 使用选择的英雄初始化游戏状态
function initGameStateWithPicks(roomId, room, bluePicks, redPicks) {
  // 创建蓝方卡牌
  const blueCards = bluePicks.map((hero, index) => {
    const cardData = cardDB.getCard(hero.id);
    return {
      id: `${hero.id}_blue_${index}`,
      ...cardData,
      health: cardData.max_health,
      shield: 0,
      equipment: [],
      daqiao_passive_used: hero.id === 'daqiao_006' ? false : undefined
    };
  });
  
  // 创建红方卡牌
  const redCards = redPicks.map((hero, index) => {
    const cardData = cardDB.getCard(hero.id);
    return {
      id: `${hero.id}_red_${index}`,
      ...cardData,
      health: cardData.max_health,
      shield: 0,
      equipment: [],
      daqiao_passive_used: hero.id === 'daqiao_006' ? false : undefined
    };
  });
  
  room.gameState = {
    blueCards,
    redCards,
    blueTeam: blueCards,
    redTeam: redCards,
    currentTurn: 1,
    currentPlayer: 'host',
    hostSkillPoints: 4,
    guestSkillPoints: 4,
    blueSkillPoints: 4,
    redSkillPoints: 4,
    blueActionsUsed: 0,
    redActionsUsed: 0,
    actionsPerTurn: 3,
    blueGold: 10,
    redGold: 10,
    // ⭐ 奥义点系统
    blueOugiPoints: 0,
    redOugiPoints: 0,
    maxOugiPoints: 5,
    blueDeathCount: 0,
    redDeathCount: 0,
    blueCompensationGiven: false,
    redCompensationGiven: false
  };
  
  // 创建战斗引擎
  const engine = new BattleEngine(roomId, room.gameState);
  battleEngines.set(roomId, engine);
  
  // 创建金币管理器
  const goldManager = new GoldManager(room.gameState);
  room.goldManager = goldManager;

  console.log('[游戏初始化]', roomId, '战斗引擎创建完成');
  console.log('💰 [金币管理器] 已创建 - 蓝方:%d, 红方:%d', goldManager.hostGold, goldManager.guestGold);
  console.log('⭐ [奥义点初始化] 蓝方:%d, 红方:%d, 上限:%d', room.gameState.blueOugiPoints, room.gameState.redOugiPoints, room.gameState.maxOugiPoints);
  console.log('  蓝方:', blueCards.map(c => `${c.card_name}(${c.health}/${c.max_health}, ATK:${c.attack})`));
  console.log('  红方:', redCards.map(c => `${c.card_name}(${c.health}/${c.max_health}, ATK:${c.attack})`));
}

// 初始化游戏状态（保留原函数用于兼容）
function initGameState(roomId) {
  const room = rooms.get(roomId);
  if (!room) return;
  
  // 🎯 创建初始卡牌状态 3v3：瑶+大乔+公孙离 vs 澜+孙尚香+朵莉亚
  const lanData = cardDB.getCard('lan_002');
  const sunshangxiangData = cardDB.getCard('sunshangxiang_004');
  const gongsunliData = cardDB.getCard('gongsunli_003');
  const yaoData = cardDB.getCard('yao_005');
  const daqiaoData = cardDB.getCard('daqiao_006');
  const duoliyaData = cardDB.getCard('duoliya_001');
  
  // 蓝方（房主）：瑶 + 大乔 + 公孙离
  const blueCards = [
    { id: 'yao_005_blue_0', ...yaoData, health: yaoData.max_health, shield: 0, equipment: [] },
    { id: 'daqiao_006_blue_1', ...daqiaoData, health: daqiaoData.max_health, shield: 0, daqiao_passive_used: false, equipment: [] },
    { id: 'gongsunli_003_blue_2', ...gongsunliData, health: gongsunliData.max_health, shield: 0, equipment: [] }
  ];
  
  // 红方（客户端）：澜 + 孙尚香 + 朵莉亚
  const redCards = [
    { id: 'lan_002_red_0', ...lanData, health: lanData.max_health, shield: 0, equipment: [] },
    { id: 'sunshangxiang_004_red_1', ...sunshangxiangData, health: sunshangxiangData.max_health, shield: 0, equipment: [] },
    { id: 'duoliya_001_red_2', ...duoliyaData, health: duoliyaData.max_health, shield: 0, equipment: [] }
  ];
  
  room.gameState = {
    blueCards,
    redCards,
    blueTeam: blueCards,  // 🎒 装备系统需要
    redTeam: redCards,    // 🎒 装备系统需要
    currentTurn: 1,  // 回合从1开始
    currentPlayer: 'host',  // 房主先手
    hostSkillPoints: 4,  // 房主技能点
    guestSkillPoints: 4,  // 客户端技能点
    // 🎯 为BattleEngine添加蓝/红方技能点映射
    blueSkillPoints: 4,  // 蓝方技能点（房主）
    redSkillPoints: 4,    // 红方技能点（客户端）
    // 🎯 行动点系统（新增）
    blueActionsUsed: 0,   // 蓝方已使用行动次数
    redActionsUsed: 0,    // 红方已使用行动次数
    actionsPerTurn: 3,     // 每回合行动次数上限
    // 💰 金币系统（统一变量 - 长期方案）
    blueGold: 10,         // 蓝方金币（房主）
    redGold: 10,          // 红方金币（客户端）
    // 注：hostGold/guestGold 已移除，通过 GoldManager 的 getter 访问
    // ⭐ 奥义点系统（新增）
    blueOugiPoints: 0,    // 蓝方奥义点
    redOugiPoints: 0,     // 红方奥义点
    maxOugiPoints: 5,     // 奥义点上限
    // 💰 阵亡补偿系统
    blueDeathCount: 0,    // 蓝方阵亡数
    redDeathCount: 0,     // 红方阵亡数
    blueCompensationGiven: false,  // 蓝方是否已获得补偿
    redCompensationGiven: false    // 红方是否已获得补偿
  };
  
  // 创建战斗引擎
  const engine = new BattleEngine(roomId, room.gameState);
  battleEngines.set(roomId, engine);
  
  // 💰 创建金币管理器（长期方案）
  const goldManager = new GoldManager(room.gameState);
  room.goldManager = goldManager; // 保存到房间对象
  
  console.log('[游戏初始化]', roomId, '战斗引擎创建完成');
  console.log('💰 [金币管理器] 已创建 - 蓝方:%d, 红方:%d', goldManager.hostGold, goldManager.guestGold);
  console.log('  蓝方:', blueCards.map(c => `${c.card_name}(${c.health}/${c.max_health}, ATK:${c.attack})`));
  console.log('  红方:', redCards.map(c => `${c.card_name}(${c.health}/${c.max_health}, ATK:${c.attack})`));
  console.log('  初始回合:', room.gameState.currentTurn, '当前玩家:', room.gameState.currentPlayer);
}

wss.on('connection', (ws) => {
  // 🛡️ 检查连接数限制
  if (clients.size >= MAX_CONNECTIONS) {
    console.log('[拒绝连接] 已达到最大连接数:', MAX_CONNECTIONS);
    ws.send(JSON.stringify({ 
      type: 'error', 
      message: '服务器已满，当前最多支持' + MAX_CONNECTIONS + '个玩家' 
    }));
    ws.close();
    return;
  }
  
  const clientId = generateClientId();
  clients.set(clientId, ws);
  console.log('[连接] 玩家连接:', clientId, '(当前连接数:', clients.size + '/' + MAX_CONNECTIONS + ')');
  
  ws.send(JSON.stringify({ type: 'welcome', player_id: clientId }));
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log('[消息]', clientId, ':', data.type);
      
      if (data.type === 'create_room') {
        const roomId = generateRoomId();
        const room = {
          id: roomId, 
          host: clientId, 
          guest: null,  // 客人ID
          players: [clientId],
          playerNames: { [clientId]: data.player_name || '玩家1' },
          battleMode: data.battle_mode || '2v2', 
          status: 'waiting', 
          createdAt: Date.now()
        };
        rooms.set(roomId, room);
        playerRooms.set(clientId, roomId);
        sendToClient(clientId, { type: 'room_created', room_id: roomId, player_id: clientId, is_host: true });
        console.log('[房间创建]', roomId);
      }
      else if (data.type === 'join_room') {
        const room = rooms.get(data.room_id);
        if (!room) {
          sendToClient(clientId, { type: 'error', message: '房间不存在' });
        } else if (room.players.length >= 2) {
          sendToClient(clientId, { type: 'error', message: '房间已满' });
        } else {
          room.players.push(clientId);
          room.guest = clientId;  // 设置客人ID
          room.playerNames[clientId] = data.player_name || '玩家2';
          playerRooms.set(clientId, data.room_id);
          sendToClient(clientId, { type: 'room_joined', room_id: data.room_id, player_id: clientId, is_host: false });
          sendToClient(room.host, { type: 'opponent_joined', opponent_id: clientId, opponent_name: room.playerNames[clientId] });
          console.log('[加入房间]', clientId, '加入', data.room_id);
          if (room.players.length === 2) {
            setTimeout(() => {
              // 🎯 进入选人阶段而不是直接开始游戏
              room.status = 'picking';
              startPickPhase(data.room_id, room);
            }, 500);
          }
        }
      }
      // 🎯 处理英雄选择
      else if (data.type === 'pick_hero') {
        const roomId = playerRooms.get(clientId);
        const room = rooms.get(roomId);
        
        if (!roomId || !room) {
          sendToClient(clientId, { type: 'pick_failed', error: '房间不存在' });
          return;
        }
        
        if (room.status !== 'picking') {
          sendToClient(clientId, { type: 'pick_failed', error: '当前不在选人阶段' });
          return;
        }
        
        const result = handleHeroPick(roomId, room, clientId, data.hero_id);
        
        if (!result.success) {
          sendToClient(clientId, { type: 'pick_failed', error: result.error });
        }
      }
      // 🎯 主动请求完整状态（用于客户端纠偏/重连）
      else if (data.type === 'request_state') {
        const roomId = playerRooms.get(clientId);
        const room = rooms.get(roomId);
        if (!room) {
          sendToClient(clientId, { type: 'error', message: '房间不存在或已结束' });
          return;
        }
        const snapshot = buildFullState(room);
        sendToClient(clientId, snapshot);
        console.log('[状态同步] 已向 %s 返回完整状态（回合:%d）', clientId, snapshot.turn);
      }
      else if (data.type === 'game_action') {
        const roomId = playerRooms.get(clientId);
        const room = rooms.get(roomId);
        const engine = battleEngines.get(roomId);
        
        if (!roomId || !engine || !room) {
          console.error('[游戏操作] 房间或引擎不存在');
          sendToClient(clientId, {
            type: 'error',
            message: '房间不存在或已结束'
          });
          return;
        }
        
        console.log('[游戏操作]', roomId, data.action);
        
        // 🔒 验证回合（所有操作都需要是当前玩家）
        const isHost = (clientId === room.host);
        const isCurrentPlayer = (isHost && room.gameState.currentPlayer === 'host') || 
                                (!isHost && room.gameState.currentPlayer === 'guest');
        
        if (!isCurrentPlayer) {
          console.error('[操作失败] 不是该玩家的回合:', data.action);
          sendToClient(clientId, {
            type: 'action_failed',
            action: data.action,
            error: '不是你的回合'
          });
          return;
        }
        
        // 🔒 验证行动点（攻击和技能需要检查）
        if (data.action === 'attack' || data.action === 'skill') {
          const currentActions = isHost ? room.gameState.blueActionsUsed : room.gameState.redActionsUsed;
          if (currentActions >= room.gameState.actionsPerTurn) {
            console.error('[操作失败] 行动次数已用尽:', currentActions, '/', room.gameState.actionsPerTurn);
            sendToClient(clientId, {
              type: 'action_failed',
              action: data.action,
              error: '行动次数已用尽'
            });
            return;
          }
        }
        
        let result = null;
        
        // 🎮 服务器端权威计算
        if (data.action === 'attack') {
          result = engine.calculateAttack(
            data.data.attacker_id,
            data.data.target_id
          );
          
          // 检查结果是否有效
          if (!result) {
            console.error('[攻击失败] 无法计算攻击结果');
            sendToClient(clientId, {
              type: 'action_failed',
              action: 'attack',
              error: '攻击计算失败'
            });
            return;
          }
          
          // 📊 详细攻击日志
          console.log('═══════════════════════════════════════════════════════');
          console.log('⚔️  [攻击详情]');
          console.log('   攻击者: %s (ID: %s)', result.attacker ? result.attacker.card_name : result.attacker_id, result.attacker_id);
          console.log('   目标:   %s (ID: %s)', result.target ? result.target.card_name : result.target_id, result.target_id);
          console.log('───────────────────────────────────────────────────────');
          console.log('   原始伤害: %d', result.original_damage || 0);
          console.log('   是否暴击: %s', result.is_critical ? '✅ 是' : '❌ 否');
          if (result.is_critical) {
            console.log('   暴击后伤害: %d', result.damage || 0);
          }
          console.log('   是否闪避: %s', result.is_dodged ? '✅ 是' : '❌ 否');
          if (!result.is_dodged) {
            console.log('   实际伤害: %d', result.damage || 0);
            if (result.target) {
              const actualDamage = result.damage || 0;
              console.log('   目标血量: %d → %d', result.target.health + actualDamage, result.target.health);
              console.log('   目标护盾: %d → %d', (result.target.shield || 0) + Math.min(actualDamage, result.target.shield || 0), result.target.shield || 0);
            }
            console.log('   目标存活: %s', result.target_dead ? '❌ 死亡' : '✅ 存活');
          }
          // 被动技能触发
          if (result.daqiao_passive_triggered) {
            console.log('   🌟 被动技能: 大乔「宿命之海」触发！生命值→1，技能点+3');
            if (result.daqiao_passive_data) {
              console.log('      技能点: %d → %d (实际+%d)', 
                result.daqiao_passive_data.old_skill_points,
                result.daqiao_passive_data.new_skill_points,
                result.daqiao_passive_data.actual_gained_points);
              if (result.daqiao_passive_data.overflow_points > 0) {
                console.log('      溢出: %d点技能点 → %d护盾', 
                  result.daqiao_passive_data.overflow_points,
                  result.daqiao_passive_data.shield_amount);
              }
            }
          }
          if (result.lan_passive_triggered) {
            console.log('   🎯 被动技能: 澜「狩猎」触发！增伤+50%%');
          }
          if (result.sunshangxiang_passive_triggered) {
            console.log('   🎯 被动技能: 孙尚香「千金重弩」触发！获得1技能点');
          }
          if (result.yao_passive_triggered) {
            console.log('   🎯 被动技能: 瑶「山鬼白鹿」触发！为%s提供%d护盾', 
              result.yao_passive_target ? result.yao_passive_target.name : '目标', result.yao_shield_amount);
          }
          console.log('═══════════════════════════════════════════════════════');
          
          // 🎯 孙尚香被动可能修改了blueSkillPoints/redSkillPoints，需要同步到host/guest
          room.gameState.hostSkillPoints = room.gameState.blueSkillPoints;
          room.gameState.guestSkillPoints = room.gameState.redSkillPoints;
          
          // 🎯 使用行动点
          const isHost = (clientId === room.host);
          const isHostAction = isHost;
          if (isHostAction) {
            room.gameState.blueActionsUsed++;
            const remaining = room.gameState.actionsPerTurn - room.gameState.blueActionsUsed;
            console.log('[行动点] 蓝方/房主 已用%d次，剩余%d次 (%d/3)', 
              room.gameState.blueActionsUsed, remaining, room.gameState.blueActionsUsed);
          } else {
            room.gameState.redActionsUsed++;
            const remaining = room.gameState.actionsPerTurn - room.gameState.redActionsUsed;
            console.log('[行动点] 红方/客户端 已用%d次，剩余%d次 (%d/3)', 
              room.gameState.redActionsUsed, remaining, room.gameState.redActionsUsed);
          }
          
          // 广播攻击结果（包含行动点信息）
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'opponent_action',
              action: 'attack',
              data: result,
              from: clientId,
              // 🎯 附加行动点信息
              blue_actions_used: room.gameState.blueActionsUsed,
              red_actions_used: room.gameState.redActionsUsed,
              actions_per_turn: room.gameState.actionsPerTurn
            });
          });
          
          // 💰 击杀奖励广播（长期方案 - 使用 GoldManager）
          if (result.kill_reward && result.kill_reward > 0 && result.killer_team) {
            const goldMgr = room.goldManager;
            if (!goldMgr) {
              console.error('⚠️ [错误] GoldManager 不存在，无法发放击杀奖励');
              return;
            }
            goldMgr.grantKillReward(result.killer_team, result.kill_reward);
            
            // 广播金币变化
            const goldState = goldMgr.getState();
            console.log('💰 [击杀奖励] 广播金币变化: 房主💰%d | 客户端💰%d', 
              goldState.hostGold, goldState.guestGold);
            
            room.players.forEach(playerId => {
              sendToClient(playerId, {
                type: 'gold_changed',
                host_gold: goldState.hostGold,
                guest_gold: goldState.guestGold,
                income_data: { reason: 'kill_reward', amount: result.kill_reward }
              });
            });
            
            // 🔍 校验金币一致性
            GoldValidator.validate(room.gameState, '击杀奖励后');
          }
          
          // 💰 阵亡补偿检测（死亡2张卡牌时触发）
          if (result.target_dead) {
            // 统计当前双方阵亡数
            const blueAliveCount = room.gameState.blueCards.filter(c => c.health > 0).length;
            const redAliveCount = room.gameState.redCards.filter(c => c.health > 0).length;
            const blueDeaths = 3 - blueAliveCount;
            const redDeaths = 3 - redAliveCount;
            
            // 蓝方阵亡补偿（长期方案 - 使用 GoldManager）
            if (blueDeaths >= 2 && !room.gameState.blueCompensationGiven) {
              const goldMgr = room.goldManager;
              if (!goldMgr) {
                console.error('⚠️ [错误] GoldManager 不存在，无法发放蓝方补偿');
                return;
              }
              const compensation = 30;
              
              console.log('💰 [阵亡补偿] 蓝方/房主阵亡%d张，获得%d金币补偿！', blueDeaths, compensation);
              goldMgr.grantDeathCompensation('blue', compensation);
              room.gameState.blueCompensationGiven = true;
              
              // 广播补偿金币
              const goldState = goldMgr.getState();
              console.log('💰 [阵亡补偿] 广播金币变化: 房主💰%d | 客户端💰%d', 
                goldState.hostGold, goldState.guestGold);
              
              room.players.forEach(playerId => {
                sendToClient(playerId, {
                  type: 'gold_changed',
                  host_gold: goldState.hostGold,
                  guest_gold: goldState.guestGold,
                  income_data: { reason: 'death_compensation', amount: compensation, team: 'blue' }
                });
              });
              
              // 🔍 校验金币一致性
              GoldValidator.validate(room.gameState, '蓝方阵亡补偿后');
            }
            
            // 红方阵亡补偿（长期方案 - 使用 GoldManager）
            if (redDeaths >= 2 && !room.gameState.redCompensationGiven) {
              const goldMgr = room.goldManager;
              if (!goldMgr) {
                console.error('⚠️ [错误] GoldManager 不存在，无法发放红方补偿');
                return;
              }
              const compensation = 30;
              
              console.log('💰 [阵亡补偿] 红方/客户端阵亡%d张，获得%d金币补偿！', redDeaths, compensation);
              goldMgr.grantDeathCompensation('red', compensation);
              room.gameState.redCompensationGiven = true;
              
              // 广播补偿金币
              const goldState = goldMgr.getState();
              console.log('💰 [阵亡补偿] 广播金币变化: 房主💰%d | 客户端💰%d', 
                goldState.hostGold, goldState.guestGold);
              
              room.players.forEach(playerId => {
                sendToClient(playerId, {
                  type: 'gold_changed',
                  host_gold: goldState.hostGold,
                  guest_gold: goldState.guestGold,
                  income_data: { reason: 'death_compensation', amount: compensation, team: 'red' }
                });
              });
              
              // 🔍 校验金币一致性
              GoldValidator.validate(room.gameState, '红方阵亡补偿后');
            }
            
            // 🏆 检查游戏是否结束（服务器权威判定）
            const gameOver = checkGameOver(roomId, room);
            if (gameOver) {
              console.log('⚠️ 游戏已结束，停止处理后续逻辑');
              return;  // 游戏结束，直接返回，不再处理后续消息
            }
          }
          
          // 🌟 如果大乔被动触发，需要广播技能点更新
          if (result.daqiao_passive_triggered && result.daqiao_passive_data) {
            const daqiaoData = result.daqiao_passive_data;
            console.log('🌟 [大乔被动] 广播技能点更新: %s方 %d→%d (溢出%d点→%d护盾)',
              daqiaoData.team, daqiaoData.old_skill_points, daqiaoData.new_skill_points,
              daqiaoData.overflow_points, daqiaoData.shield_amount);
            
            // 同步技能点到 host/guest
            room.gameState.hostSkillPoints = room.gameState.blueSkillPoints;
            room.gameState.guestSkillPoints = room.gameState.redSkillPoints;
            
            // 广播技能点更新
            room.players.forEach(playerId => {
              const isPlayerHost = (playerId === room.host);
              const isMyTurn = (room.gameState.currentPlayer === 'host' && isPlayerHost) || 
                               (room.gameState.currentPlayer === 'guest' && !isPlayerHost);
              sendToClient(playerId, {
                type: 'turn_changed',
                turn: room.gameState.currentTurn,  // 🔧 添加回合信息
                current_player: room.gameState.currentPlayer,
                is_my_turn: isMyTurn,  // 🔧 添加is_my_turn字段
                is_skill_points_only: true,  // 标记为仅技能点更新
                host_skill_points: room.gameState.hostSkillPoints,
                guest_skill_points: room.gameState.guestSkillPoints,
                // 保持行动点不变
                blue_actions_used: room.gameState.blueActionsUsed,
                red_actions_used: room.gameState.redActionsUsed,
                actions_per_turn: room.gameState.actionsPerTurn,
                passive_results: []  // 空数组，避免客户端报错
              });
            });
          }
        } else if (data.action === 'skill') {
          // 🎯 技能计算（服务器权威）
          const skillData = data.data;
          const gameState = room.gameState;
          const isHost = (clientId === room.host);
          
          // 查找施法者卡牌获取技能消耗
          const caster = engine.findCard(skillData.caster_id);
          if (!caster) {
            console.error('[技能请求] 施法者未找到:', skillData.caster_id);
            sendToClient(clientId, {
              type: 'skill_failed',
              error: '施法者未找到'
            });
          } else {
            const skillCost = caster.skill_cost || 2;
            const currentPoints = isHost ? gameState.hostSkillPoints : gameState.guestSkillPoints;
            
            console.log('[技能请求]', skillData.caster_id, skillData.skill_name, 
              `消耗:${skillCost} 当前:${currentPoints}`, isHost ? '房主' : '客户端');
            
            // 🔒 验证技能点是否足够
            if (currentPoints < skillCost) {
              console.error('[技能点不足]', `需要:${skillCost} 当前:${currentPoints}`);
              sendToClient(clientId, {
                type: 'skill_failed',
                error: `技能点不足 (需要${skillCost}点，当前${currentPoints}点)`
              });
            } else {
              // 准备技能计算参数
              const skillParams = {
                target_id: skillData.target_id || null,
                is_host: isHost,
                is_ally: skillData.is_ally || false
              };
              
              // 计算技能效果
              result = engine.calculateSkill(
                skillData.caster_id,
                skillData.skill_name,
                skillParams
              );
              
              if (result && result.success) {
                // ✅ 扣除技能点（使用Math.max确保不为负）
                const oldHostSP = gameState.hostSkillPoints;
                const oldGuestSP = gameState.guestSkillPoints;
                if (isHost) {
                  gameState.hostSkillPoints = Math.max(0, gameState.hostSkillPoints - skillCost);
                  gameState.blueSkillPoints = gameState.hostSkillPoints;  // 同步蓝方
                } else {
                  gameState.guestSkillPoints = Math.max(0, gameState.guestSkillPoints - skillCost);
                  gameState.redSkillPoints = gameState.guestSkillPoints;  // 同步红方
                }
                
                // 📊 详细技能日志
                console.log('═══════════════════════════════════════════════════════');
                console.log('✨ [技能详情]');
                console.log('   施法者: %s', caster ? caster.card_name : skillData.caster_id);
                console.log('   技能名: %s', skillData.skill_name);
                console.log('   消耗:   %d点', skillCost);
                console.log('   效果类型: %s', result.effect_type);
                console.log('───────────────────────────────────────────────────────');
                
                // 根据技能类型显示详情
                // 辅助函数：获取目标名称
                const getTargetName = (res) => {
                  if (res.target && res.target.card_name) return res.target.card_name;
                  if (res.target_id) {
                    const t = engine.findCard(res.target_id);
                    return t ? t.card_name : res.target_id;
                  }
                  return '未知';
                };

                if (result.effect_type === 'true_damage' || result.effect_type === 'true_damage_with_armor_reduction') {
                  console.log('   伤害类型: 真实伤害');
                  if (result.armor_reduction) {
                    console.log('   护甲削减: %d', result.armor_reduction);
                  }
                  console.log('   伤害数值: %d', result.damage_amount || 0);
                  console.log('   目标: %s', getTargetName(result));
                } else if (result.effect_type === 'heal') {
                  console.log('   治疗数值: %d', result.heal_amount || 0);
                  console.log('   目标: %s', getTargetName(result));
                } else if (result.effect_type === 'shield_and_buff') {
                  console.log('   护盾数值: %d', result.shield_amount || 0);
                  console.log('   暴击率提升: +%d%%', (result.crit_rate_buff || 0) * 100);
                  console.log('   护甲提升: +%d', result.armor_buff || 0);
                  console.log('   目标: %s', getTargetName(result));
                } else if (result.effect_type === 'self_buff') {
                  console.log('   攻击力提升: +%d', result.attack_buff || 0);
                } else if (result.effect_type === 'daqiao_true_damage') {
                  console.log('   AOE真实伤害');
                  console.log('   总伤害: %d', result.total_damage || 0);
                  console.log('   受击目标数: %d', (result.damage_results || []).length);
                } else if (result.effect_type === 'yangyuhuan_damage' || result.effect_type === 'yangyuhuan_heal') {
                  const isDamage = result.effect_type === 'yangyuhuan_damage';
                  console.log('   效果: %s', isDamage ? 'AOE伤害' : 'AOE治疗');
                  console.log('   总量: %d', isDamage ? result.total_damage : result.total_heal || 0);
                  console.log('   受影响目标数: %d', (isDamage ? result.damage_results : result.heal_results || []).length);
                }
                
                console.log('───────────────────────────────────────────────────────');
                console.log('   技能点: 房主 %d→%d | 客户端 %d→%d',
                  oldHostSP, gameState.hostSkillPoints,
                  oldGuestSP, gameState.guestSkillPoints);
                console.log('═══════════════════════════════════════════════════════');

                // ⭐ 增加奥义点（使用技能后）
                // 🔧 防御性初始化：确保奥义点字段存在
                if (typeof gameState.blueOugiPoints !== 'number') gameState.blueOugiPoints = 0;
                if (typeof gameState.redOugiPoints !== 'number') gameState.redOugiPoints = 0;
                if (typeof gameState.maxOugiPoints !== 'number') gameState.maxOugiPoints = 5;

                const oldBlueOugi = gameState.blueOugiPoints;
                const oldRedOugi = gameState.redOugiPoints;
                if (isHost) {
                  gameState.blueOugiPoints = Math.min(gameState.maxOugiPoints, gameState.blueOugiPoints + 1);
                  console.log('⭐ [奥义点] 蓝方/房主 %d→%d (释放技能)', oldBlueOugi, gameState.blueOugiPoints);
                } else {
                  gameState.redOugiPoints = Math.min(gameState.maxOugiPoints, gameState.redOugiPoints + 1);
                  console.log('⭐ [奥义点] 红方/客户端 %d→%d (释放技能)', oldRedOugi, gameState.redOugiPoints);
                }

                // 🎯 使用行动点
                if (isHost) {
                  gameState.blueActionsUsed++;
                  const remaining = gameState.actionsPerTurn - gameState.blueActionsUsed;
                  console.log('[行动点] 蓝方/房主 已用%d次，剩余%d次 (%d/3)',
                    gameState.blueActionsUsed, remaining, gameState.blueActionsUsed);
                } else {
                  gameState.redActionsUsed++;
                  const remaining = gameState.actionsPerTurn - gameState.redActionsUsed;
                  console.log('[行动点] 红方/客户端 已用%d次，剩余%d次 (%d/3)',
                    gameState.redActionsUsed, remaining, gameState.redActionsUsed);
                }
                
                // 广播技能结果给双方（包含行动点信息）
                room.players.forEach(playerId => {
                  sendToClient(playerId, {
                    type: 'opponent_action',
                    action: 'skill',
                    data: result,
                    from: clientId,  // ✅ 统一使用 from 字段名
                    // 🎯 附加行动点信息
                    blue_actions_used: gameState.blueActionsUsed,
                    red_actions_used: gameState.redActionsUsed,
                    actions_per_turn: gameState.actionsPerTurn
                  });
                });
                
                // 🌟 广播技能点更新（使用专门的消息类型）
                room.players.forEach(playerId => {
                  const isPlayerHost = (playerId === room.host);
                  sendToClient(playerId, {
                    type: 'skill_points_updated',
                    host_skill_points: gameState.hostSkillPoints,
                    guest_skill_points: gameState.guestSkillPoints,
                    // ⭐ 附加奥义点信息
                    blue_ougi_points: gameState.blueOugiPoints,
                    red_ougi_points: gameState.redOugiPoints,
                    max_ougi_points: gameState.maxOugiPoints
                  });
                });
                
                // 🏆 检查技能是否导致游戏结束（伤害型技能可能击杀角色）
                const hasDeaths = 
                  (result.target_dead) || // 单体技能击杀
                  (result.results && result.results.some(r => r.target_dead)) || // AOE技能击杀
                  (result.damage_results && result.damage_results.some(r => r.target_dead)); // 其他伤害结果
                
                if (hasDeaths) {
                  const gameOver = checkGameOver(roomId, room);
                  if (gameOver) {
                    console.log('⚠️ 技能导致游戏结束，停止处理后续逻辑');
                    return;  // 游戏结束，直接返回
                  }
                }
              } else {
                console.error('[技能失败]', result ? result.error : '未知错误');
                
                // 只通知施法者失败
                sendToClient(clientId, {
                  type: 'skill_failed',
                  error: result ? result.error : '技能执行失败'
                });
              }
            }
          }
        } else if (data.action === 'buy_equipment') {
          // 💰 购买装备（长期方案 - 使用 GoldManager）
          const gameState = room.gameState;
          const goldMgr = room.goldManager;
          if (!goldMgr) {
            console.error('⚠️ [错误] GoldManager 不存在，无法购买装备');
            sendToClient(clientId, {
              type: 'buy_equipment_failed',
              error: '服务器错误，请重试'
            });
            return;
          }
          const isHost = (clientId === room.host);
          const playerTeam = isHost ? 'blue' : 'red';
          
          // 🔒 验证回合（防止非当前回合玩家操作）
          const currentTurn = gameState.currentTurn || 1;
          const isHostTurn = (currentTurn % 2 === 1);
          const isPlayerTurn = (isHost === isHostTurn);
          
          if (!isPlayerTurn) {
            console.error('[装备购买失败] 不是该玩家的回合');
            sendToClient(clientId, {
              type: 'buy_equipment_failed',
              error: '不是你的回合'
            });
            return;
          }
          
          const equipmentCost = 15; // 固定15金币
          
          console.log('\n═══════════════════════════════════════════════════════');
          console.log('💰 [装备购买请求]');
          console.log('   玩家:', isHost ? '房主/蓝方' : '客户端/红方');
          console.log('   当前金币:', goldMgr.getGold(playerTeam));
          console.log('   购买消耗:', equipmentCost);
          console.log('───────────────────────────────────────────────────────');
          
          // 使用 GoldManager 扣除金币
          const deductResult = goldMgr.purchaseEquipment(playerTeam, equipmentCost);
          
          if (!deductResult.success) {
            console.error('[装备购买失败] 金币不足');
            sendToClient(clientId, {
              type: 'buy_equipment_failed',
              error: `金币不足 (需要${equipmentCost}金币，当前${deductResult.oldGold}金币)`
            });
            return;
          }
          
          console.log('✅ 扣除金币成功: %d → %d (-%d)', 
            deductResult.oldGold, deductResult.newGold, equipmentCost);
          
          // 抽取3个随机装备
          const drawnEquipment = equipmentDB.drawRandomEquipment(EquipmentTier.BASIC, 3);
          console.log('🎲 抽取装备结果 (%d个):', drawnEquipment.length);
          drawnEquipment.forEach((equip, index) => {
            console.log('   %d. [%s] %s - %s', index + 1, equip.category === 'attack' ? '攻击' : '防御', equip.name, equip.description);
          });
          
          // 发送抽取结果给玩家
          console.log('📤 发送装备选项给玩家');
          sendToClient(clientId, {
            type: 'equipment_drawn',
            equipment_options: drawnEquipment,
            remaining_gold: goldMgr.getGold(playerTeam)
          });
          
          // 广播金币变化给双方
          const goldState = goldMgr.getState();
          console.log('📢 广播金币变化: 房主💰%d | 客户端💰%d', goldState.hostGold, goldState.guestGold);
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'gold_changed',
              host_gold: goldState.hostGold,
              guest_gold: goldState.guestGold,
              income_data: {} // 购买装备不算收入
            });
          });
          
          // 🔍 校验金币一致性
          GoldValidator.validate(gameState, '购买装备后');
          console.log('═══════════════════════════════════════════════════════\n');
          
        } else if (data.action === 'equip_item') {
          // 🎒 装备物品到英雄
          const { equipment_id, card_name } = data.data;
          const isHost = (clientId === room.host);
          const gameState = room.gameState;
          
          // 🔒 验证回合（防止非当前回合玩家操作）
          const currentTurn = gameState.currentTurn || 1;
          const isHostTurn = (currentTurn % 2 === 1);
          const isPlayerTurn = (isHost === isHostTurn);
          
          if (!isPlayerTurn) {
            console.error('[装备失败] 不是该玩家的回合');
            sendToClient(clientId, {
              type: 'equip_failed',
              error: '不是你的回合'
            });
            return;
          }
          
          console.log('\n═══════════════════════════════════════════════════════');
          console.log('🎒 [装备物品请求]');
          console.log('   玩家:', isHost ? '房主/蓝方' : '客户端/红方');
          console.log('   装备ID:', equipment_id);
          console.log('   英雄名字:', card_name);
          console.log('───────────────────────────────────────────────────────');
          
          // 根据玩家身份确定队伍
          const myTeam = isHost ? room.gameState.blueTeam : room.gameState.redTeam;
          
          // 在我方队伍中按名字查找英雄
          const card = myTeam.find(c => c.card_name === card_name);
          if (!card) {
            console.error('[装备失败] 英雄未找到:', card_name);
            sendToClient(clientId, {
              type: 'equip_failed',
              error: '英雄未找到: ' + card_name
            });
            return;
          }
          
          console.log('✅ 找到英雄: %s (ID: %s)', card.card_name, card.id);
          
          // 初始化装备数组
          if (!card.equipment) {
            card.equipment = [];
          }
          
          // 检查装备数量限制
          if (card.equipment.length >= 2) {
            console.error('[装备失败] 装备已满:', card.card_name, '已有', card.equipment.length, '件装备');
            sendToClient(clientId, {
              type: 'equip_failed',
              error: '该英雄装备已满（最多2件）'
            });
            return;
          }
          
          // 获取装备数据
          const equipment = equipmentDB.getEquipmentById(equipment_id);
          if (!equipment) {
            console.error('[装备失败] 装备数据未找到:', equipment_id);
            sendToClient(clientId, {
              type: 'equip_failed',
              error: '装备数据错误'
            });
            return;
          }
          
          // 记录装备前属性
          const oldStats = {
            attack: card.attack,
            max_health: card.max_health,
            health: card.health,
            armor: card.armor,
            crit_rate: card.crit_rate,
            crit_damage: card.crit_damage,
            dodge_rate: card.dodge_rate
          };
          
          // 添加装备
          card.equipment.push(equipment);
          console.log('✅ 装备成功添加到英雄');
          console.log('   英雄: %s', card.card_name);
          console.log('   装备: [%s] %s', equipment.category === 'attack' ? '攻击' : '防御', equipment.name);
          console.log('   当前装备数: %d/2', card.equipment.length);
          
          // 应用装备效果
          console.log('🔧 应用装备效果:');
          equipmentDB.applyEquipmentEffects(card, equipment);
          
          // 显示属性变化
          console.log('📊 属性变化汇总:');
          if (card.attack !== oldStats.attack) console.log('   ⚔️  攻击: %d → %d (+%d)', oldStats.attack, card.attack, card.attack - oldStats.attack);
          if (card.max_health !== oldStats.max_health) console.log('   ❤️  生命: %d/%d → %d/%d', oldStats.health, oldStats.max_health, card.health, card.max_health);
          if (card.armor !== oldStats.armor) console.log('   🛡️  护甲: %d → %d (+%d)', oldStats.armor, card.armor, card.armor - oldStats.armor);
          if (card.crit_rate !== oldStats.crit_rate) console.log('   💥 暴击率: %.1f%% → %.1f%%', oldStats.crit_rate * 100, card.crit_rate * 100);
          if (card.crit_damage !== oldStats.crit_damage) console.log('   💢 暴击伤害: %.1f%% → %.1f%%', oldStats.crit_damage * 100, card.crit_damage * 100);
          if (card.dodge_rate !== oldStats.dodge_rate) console.log('   💨 闪避率: %.1f%% → %.1f%%', oldStats.dodge_rate * 100, card.dodge_rate * 100);
          
          // 广播装备结果给双方
          console.log('📢 广播装备结果给双方玩家');
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'item_equipped',
              card_id: card.id,  // 🎒 使用找到的卡牌的ID
              equipment: equipment,
              card_stats: {
                attack: card.attack,
                max_health: card.max_health,
                health: card.health,
                armor: card.armor,
                crit_rate: card.crit_rate,
                crit_damage: card.crit_damage,
                dodge_rate: card.dodge_rate
              }
            });
          });
          console.log('═══════════════════════════════════════════════════════\n');
          
        } else if (data.action === 'craft_equipment') {
          // 🔨 装备合成（阶段1：定向合成 BASIC → ADVANCED）
          const gameState = room.gameState;
          const goldMgr = room.goldManager;
          
          console.log('\n═══════════════════════════════════════════════════════');
          console.log('🔨 [装备合成请求]');
          
          // 防御性检查
          if (!goldMgr) {
            console.error('⚠️ [错误] GoldManager 不存在，无法合成装备');
            sendToClient(clientId, {
              type: 'craft_failed',
              error: '服务器错误，请重试'
            });
            return;
          }
          
          const isHost = (clientId === room.host);
          const playerTeam = isHost ? 'blue' : 'red';
          
          // 🔒 验证回合（防止非当前回合玩家操作）
          const currentTurn = gameState.currentTurn || 1;
          const isHostTurn = (currentTurn % 2 === 1);
          const isPlayerTurn = (isHost === isHostTurn);
          
          if (!isPlayerTurn) {
            console.error('[合成失败] 不是该玩家的回合');
            sendToClient(clientId, {
              type: 'craft_failed',
              error: '不是你的回合'
            });
            return;
          }
          
          // 解析请求数据
          const { material_ids, hero_id } = data.data || {};
          
          console.log('   玩家:', isHost ? '房主/蓝方' : '客户端/红方');
          console.log('   材料:', material_ids);
          console.log('   目标英雄ID:', hero_id);
          
          // 验证材料数量
          if (!material_ids || material_ids.length !== 2) {
            console.error('[合成失败] 材料数量错误');
            sendToClient(clientId, {
              type: 'craft_failed',
              error: '需要选择2个装备进行合成'
            });
            return;
          }
          
          // 查找配方
          const recipe = craftingDB.findRecipeByMaterials(material_ids);
          
          if (!recipe) {
            console.error('[合成失败] 没有匹配的配方');
            console.log('   尝试的材料组合:', material_ids);
            sendToClient(clientId, {
              type: 'craft_failed',
              error: '这两个装备无法合成'
            });
            return;
          }
          
          console.log('✅ 找到配方: %s', recipe.name);
          console.log('   合成费用: %d金币', recipe.cost);
          console.log('   📦 配方icon字段: %s', recipe.icon);
          console.log('───────────────────────────────────────────────────────');
          
          // 查找英雄
          const hero = [...gameState.blueCards, ...gameState.redCards]
            .find(c => c.id === hero_id);
          
          if (!hero) {
            console.error('[合成失败] 英雄不存在:', hero_id);
            sendToClient(clientId, {
              type: 'craft_failed',
              error: '目标英雄不存在'
            });
            return;
          }
          
          // 验证英雄拥有这些装备（需要考虑同一装备可能有多个的情况）
          const heroEquipment = hero.equipment || [];
          
          // 统计英雄拥有的每种装备数量
          const equipmentCount = {};
          for (const equip of heroEquipment) {
            equipmentCount[equip.id] = (equipmentCount[equip.id] || 0) + 1;
          }
          
          // 统计需要的每种材料数量
          const requiredCount = {};
          for (const materialId of material_ids) {
            requiredCount[materialId] = (requiredCount[materialId] || 0) + 1;
          }
          
          // 验证每种材料的数量是否足够
          for (const materialId in requiredCount) {
            const required = requiredCount[materialId];
            const owned = equipmentCount[materialId] || 0;
            if (owned < required) {
              console.error('[合成失败] 英雄未装备足够的物品');
              console.log('   需要 %s x%d, 拥有 x%d', materialId, required, owned);
              console.log('   英雄装备:', heroEquipment.map(e => e.id));
              sendToClient(clientId, {
                type: 'craft_failed',
                error: '该英雄未装备足够的材料'
              });
              return;
            }
          }
          
          // 使用 GoldManager 扣除金币
          const deductResult = goldMgr.craftEquipment(playerTeam, recipe.cost, recipe.tier);
          
          if (!deductResult.success) {
            console.error('[合成失败] 金币不足: 需要%d, 当前%d', 
              recipe.cost, deductResult.oldGold);
            sendToClient(clientId, {
              type: 'craft_failed',
              error: `金币不足 (需要${recipe.cost}金币，当前${deductResult.oldGold}金币)`
            });
            return;
          }
          
          console.log('✅ 扣除合成费用: %d → %d (-%d)', 
            deductResult.oldGold, deductResult.newGold, recipe.cost);
          
          // 🔧 先移除材料装备的属性加成（精确移除指定数量）
          console.log('🔧 [移除材料装备效果]');
          
          // 统计需要移除的每种装备数量
          const toRemoveCount = {};
          for (const materialId of material_ids) {
            toRemoveCount[materialId] = (toRemoveCount[materialId] || 0) + 1;
          }
          
          // 精确移除装备效果和装备本身
          const newEquipment = [];
          for (const equip of hero.equipment) {
            if (toRemoveCount[equip.id] && toRemoveCount[equip.id] > 0) {
              // 需要移除这个装备
              equipmentDB.removeEquipmentEffects(hero, equip);
              toRemoveCount[equip.id]--;
              console.log('   移除: %s', equip.name);
            } else {
              // 保留这个装备
              newEquipment.push(equip);
            }
          }
          hero.equipment = newEquipment;
          
          // 创建合成的进阶装备
          const craftedEquipment = {
            id: recipe.id,
            tier: recipe.tier,
            name: recipe.name,
            category: recipe.category,
            description: recipe.description,
            effects: recipe.effects,
            icon: recipe.icon || null
          };
          
          // 添加到英雄装备
          hero.equipment = hero.equipment || [];
          hero.equipment.push(craftedEquipment);
          
          console.log('🎉 合成成功: %s', recipe.name);
          console.log('   移除材料: %s', recipe.materials.map(m => m.name).join(', '));
          console.log('   获得装备: %s', recipe.name);
          console.log('   📦 发送的craftedEquipment:', JSON.stringify(craftedEquipment));
          
          // 应用装备效果到英雄属性
          equipmentDB.applyEquipmentEffects(hero, craftedEquipment);
          
          // 发送合成结果给玩家
          sendToClient(clientId, {
            type: 'equipment_crafted',
            hero_id: hero.id,
            crafted_equipment: craftedEquipment,
            removed_materials: material_ids,
            remaining_gold: goldMgr.getGold(playerTeam),
            hero_stats: {
              id: hero.id,
              health: hero.health,
              max_health: hero.max_health,
              attack: hero.attack,
              armor: hero.armor,
              crit_rate: hero.crit_rate || 0,
              crit_damage: hero.crit_damage || 1.3,
              dodge_rate: hero.dodge_rate || 0,
              shield: hero.shield || 0
            }
          });
          
          // 广播给对手（包含装备信息以更新UI）
          const opponentId = isHost ? room.guest : room.host;
          sendToClient(opponentId, {
            type: 'opponent_crafted',
            team: playerTeam,
            hero_id: hero.id,
            crafted_equipment: craftedEquipment,
            removed_materials: material_ids,
            hero_stats: {
              id: hero.id,
              health: hero.health,
              max_health: hero.max_health,
              attack: hero.attack,
              armor: hero.armor,
              crit_rate: hero.crit_rate || 0,
              crit_damage: hero.crit_damage || 1.3,
              dodge_rate: hero.dodge_rate || 0,
              shield: hero.shield || 0
            }
          });
          
          // 广播金币变化给双方
          const goldState = goldMgr.getState();
          console.log('📢 广播金币变化: 房主💰%d | 客户端💰%d', 
            goldState.hostGold, goldState.guestGold);
          
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'gold_changed',
              host_gold: goldState.hostGold,
              guest_gold: goldState.guestGold,
              income_data: {} // 合成不算收入
            });
          });
          
          // 🔍 校验金币一致性
          GoldValidator.validate(gameState, '装备合成后');
          console.log('═══════════════════════════════════════════════════════\n');

        } else if (data.action === 'use_ougi') {
          // ⭐ 发动奥义技能
          const { hero_id } = data.data;
          const isHost = (clientId === room.host);
          const gameState = room.gameState;

          console.log('\n⭐══════════════════════════════════════════════════════');
          console.log('⭐ [发动奥义]');
          console.log('   玩家:', isHost ? '房主/蓝方' : '客户端/红方');
          console.log('   英雄ID:', hero_id);

          // 🔒 验证回合
          const currentTurn = gameState.currentTurn || 1;
          const isHostTurn = (currentTurn % 2 === 1);
          const isPlayerTurn = (isHost === isHostTurn);

          if (!isPlayerTurn) {
            console.error('[奥义失败] 不是该玩家的回合');
            sendToClient(clientId, {
              type: 'use_ougi_failed',
              error: '不是你的回合'
            });
            return;
          }

          // 🔒 检查奥义点是否满5
          const ougiPoints = isHost ? gameState.blueOugiPoints : gameState.redOugiPoints;
          if (ougiPoints < 5) {
            console.error('[奥义失败] 奥义点不足:', ougiPoints, '/5');
            sendToClient(clientId, {
              type: 'use_ougi_failed',
              error: `奥义点不足 (当前${ougiPoints}/5)`
            });
            return;
          }

          // 🔍 查找英雄
          const myTeam = isHost ? gameState.blueTeam : gameState.redTeam;
          const hero = myTeam.find(c => c.id === hero_id);

          if (!hero) {
            console.error('[奥义失败] 英雄未找到:', hero_id);
            sendToClient(clientId, {
              type: 'use_ougi_failed',
              error: '英雄未找到'
            });
            return;
          }

          if (hero.health <= 0) {
            console.error('[奥义失败] 英雄已死亡:', hero.card_name);
            sendToClient(clientId, {
              type: 'use_ougi_failed',
              error: '该英雄已阵亡'
            });
            return;
          }

          console.log('✅ 找到英雄: %s (ID: %s)', hero.card_name, hero.id);

          // ⭐ 清空奥义点
          const oldOugi = ougiPoints;
          if (isHost) {
            gameState.blueOugiPoints = 0;
          } else {
            gameState.redOugiPoints = 0;
          }
          console.log('⭐ 奥义点清空: %d → 0', oldOugi);

          // TODO: 实际的奥义技能效果（暂时占位）
          const ougiResult = {
            success: true,
            hero_id: hero.id,
            hero_name: hero.card_name,
            effect_type: 'ougi_placeholder',
            description: `${hero.card_name} 发动了奥义技能！（效果待实现）`
          };

          console.log('⭐ 奥义效果占位: %s', ougiResult.description);

          // 📢 广播奥义使用结果
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'ougi_used',
              data: ougiResult,
              from: clientId,
              // ⭐ 附加奥义点信息
              blue_ougi_points: gameState.blueOugiPoints,
              red_ougi_points: gameState.redOugiPoints
            });
          });

          // 🔄 发动奥义后直接结束回合（不需要手动end_turn）
          console.log('⭐ 奥义发动，自动结束回合');

          // 切换回合
          gameState.currentTurn++;
          gameState.currentPlayer = (gameState.currentPlayer === 'host') ? 'guest' : 'host';

          // 判断新回合是谁的
          const newIsHostTurn = (gameState.currentTurn % 2 === 1);
          const newTeam = newIsHostTurn ? 'blue' : 'red';

          // 重置行动点（新回合方）
          if (newIsHostTurn) {
            gameState.blueActionsUsed = 0;
          } else {
            gameState.redActionsUsed = 0;
          }

          // 🌟 增加技能点（第3回合开始）
          if (gameState.currentTurn > 2) {
            if (newIsHostTurn) {
              gameState.hostSkillPoints = Math.min(6, gameState.hostSkillPoints + 1);
              gameState.blueSkillPoints = gameState.hostSkillPoints;
              console.log('[技能点] 房主/蓝方 +1 → ', gameState.hostSkillPoints);
            } else {
              gameState.guestSkillPoints = Math.min(6, gameState.guestSkillPoints + 1);
              gameState.redSkillPoints = gameState.guestSkillPoints;
              console.log('[技能点] 客户端/红方 +1 → ', gameState.guestSkillPoints);
            }
          }

          // 💰 金币结算（新回合开始时，给新回合方结算）
          const goldMgr = room.goldManager;
          let goldIncome = null;
          if (goldMgr) {
            const currentGold = goldMgr.getGold(newTeam);
            goldIncome = calculateGoldIncome(currentGold);
            goldMgr.grantTurnIncome(newTeam, goldIncome.base, goldIncome.interest);
            console.log('💰 [金币结算] %s方: +%d (基础:%d 利息:%d)',
              newTeam === 'blue' ? '蓝' : '红',
              goldIncome.total, goldIncome.base, goldIncome.interest);
          }

          // 📢 广播回合切换（包含奥义点信息）
          room.players.forEach(playerId => {
            const isPlayerHost = (playerId === room.host);
            const isMyNewTurn = (isPlayerHost === newIsHostTurn);

            sendToClient(playerId, {
              type: 'turn_changed',
              turn: gameState.currentTurn,
              is_my_turn: isMyNewTurn,
              host_skill_points: gameState.hostSkillPoints,
              guest_skill_points: gameState.guestSkillPoints,
              blue_actions_used: gameState.blueActionsUsed,
              red_actions_used: gameState.redActionsUsed,
              // 💰 金币信息
              host_gold: goldMgr ? goldMgr.getGold('blue') : 10,
              guest_gold: goldMgr ? goldMgr.getGold('red') : 10,
              gold_income: goldIncome,
              // ⭐ 奥义点信息
              blue_ougi_points: gameState.blueOugiPoints,
              red_ougi_points: gameState.redOugiPoints,
              max_ougi_points: gameState.maxOugiPoints
            });
          });

          console.log('⭐══════════════════════════════════════════════════════\n');

        } else if (data.action === 'end_turn') {
          // 🎯 服务器权威管理回合切换
          const gameState = room.gameState;
          
          // 📊 回合切换详细日志
          console.log('\n');
          console.log('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
          console.log('┃          🔄 回合切换                               ┃');
          console.log('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
          
          // 回合数+1
          const oldTurn = gameState.currentTurn;
          gameState.currentTurn++;
          
          // 判断下一回合是谁的
          // 奇数回合=房主(host)，偶数回合=客户端(guest)
          const isHostTurn = (gameState.currentTurn % 2 === 1);
          gameState.currentPlayer = isHostTurn ? 'host' : 'guest';
          
          console.log('   回合: 第%d回合 → 第%d回合', oldTurn, gameState.currentTurn);
          console.log('   当前玩家: %s', isHostTurn ? '房主/蓝方' : '客户端/红方');
          
          // 🎯 重置行动点（新回合开始）
          if (isHostTurn) {
            gameState.blueActionsUsed = 0;
            console.log('[行动点] 🔄 蓝方/房主 回合开始，重置为0/3（剩余3次）');
          } else {
            gameState.redActionsUsed = 0;
            console.log('[行动点] 🔄 红方/客户端 回合开始，重置为0/3（剩余3次）');
          }
          
          // 🌟 增加技能点（第3回合开始，上限6点）
          if (gameState.currentTurn > 2) {
            if (isHostTurn) {
              gameState.hostSkillPoints = Math.min(6, gameState.hostSkillPoints + 1);
              gameState.blueSkillPoints = gameState.hostSkillPoints;  // 同步蓝方
              console.log('[技能点] 房主/蓝方 +1 → ', gameState.hostSkillPoints);
            } else {
              gameState.guestSkillPoints = Math.min(6, gameState.guestSkillPoints + 1);
              gameState.redSkillPoints = gameState.guestSkillPoints;  // 同步红方
              console.log('[技能点] 客户端/红方 +1 → ', gameState.guestSkillPoints);
            }
          }
          
          // 💰 金币结算（长期方案 - 使用 GoldManager）
          const goldMgr = room.goldManager;
          let goldIncome = null;
          const passiveResults = []; // 移到 goldMgr 检查之外
          
          if (!goldMgr) {
            console.error('⚠️ [错误] GoldManager 不存在，跳过金币结算');
          } else {
          const currentTeam = isHostTurn ? 'blue' : 'red';
          
          // 计算金币收入
          const currentGold = goldMgr.getGold(currentTeam);
          goldIncome = calculateGoldIncome(currentGold);
          
          // 使用 GoldManager 增加金币
          goldMgr.grantTurnIncome(currentTeam, goldIncome.base, goldIncome.interest);
          
          console.log('💰 [金币结算] %s', isHostTurn ? '房主/蓝方' : '客户端/红方');
          
          // 🔍 校验金币一致性
          GoldValidator.validate(gameState, '回合结算后');
          }
          
          // 🎯 触发回合开始被动技能
          const activeCards = isHostTurn ? gameState.blueCards : gameState.redCards;
          
          activeCards.forEach(card => {
            if (card.health > 0) {  // 只处理存活的卡牌
              // 朵莉亚的被动技能：欢歌（自己+队友各50）
              if (card.card_name === '朵莉亚') {
                const healAmount = 50;
                
                // 1. 为朵莉亚自己恢复50点
                const oldHealth = card.health;
                const oldShield = card.shield || 0;
                
                card.health = Math.min(card.max_health, card.health + healAmount);
                const actualHeal = card.health - oldHealth;
                
                // 计算溢出护盾（只给朵莉亚自己）
                let overflowShield = 0;
                if (oldHealth + healAmount > card.max_health) {
                  overflowShield = (oldHealth + healAmount) - card.max_health;
                  card.shield = (card.shield || 0) + overflowShield;
                }
                
                console.log(`⭐ [朵莉亚被动-欢歌] 回合开始恢复`);
                console.log(`   朵莉亚自己: ${oldHealth} → ${card.health} (+${actualHeal})`);
                if (overflowShield > 0) {
                  console.log(`   溢出护盾: +${overflowShield} (总护盾: ${card.shield})`);
                }
                
                // 2. 为血量最低的队友（不包括自己）恢复50点
                let lowestHpAlly = null;
                let lowestHp = 999999;
                
                activeCards.forEach(ally => {
                  if (ally.health > 0 && ally.id !== card.id && ally.health < lowestHp) {
                    lowestHp = ally.health;
                    lowestHpAlly = ally;
                  }
                });
                
                let allyHealAmount = 0;
                if (lowestHpAlly) {
                  const allyOldHealth = lowestHpAlly.health;
                  lowestHpAlly.health = Math.min(lowestHpAlly.max_health, lowestHpAlly.health + healAmount);
                  allyHealAmount = lowestHpAlly.health - allyOldHealth;
                  
                  console.log(`   队友${lowestHpAlly.card_name}: ${allyOldHealth} → ${lowestHpAlly.health} (+${allyHealAmount})`);
                }
                
                passiveResults.push({
                  type: 'passive_triggered',
                  card_id: card.id,
                  card_name: card.card_name,
                  passive_name: '欢歌',
                  effect: {
                    self_heal: actualHeal,
                    overflow_shield: overflowShield,
                    ally_id: lowestHpAlly ? lowestHpAlly.id : null,
                    ally_name: lowestHpAlly ? lowestHpAlly.card_name : null,
                    ally_heal: allyHealAmount,
                    new_health: card.health,
                    new_shield: card.shield,
                    ally_new_health: lowestHpAlly ? lowestHpAlly.health : null
                  }
                });
              }
            }
          });
          
          // 💚 装备效果：提神水晶（每回合开始恢复30生命）
          const allCards = [...gameState.blueCards, ...gameState.redCards];
          allCards.forEach(card => {
            if (card.health > 0 && card.equipment && card.equipment.length > 0) {
              for (const equip of card.equipment) {
                if (equip.effects) {
                  for (const effect of equip.effects) {
                    if (effect.type === 'heal_per_turn') {
                      const oldHealth = card.health;
                      const healAmount = Math.min(effect.value, card.max_health - card.health);
                      card.health += healAmount;
                      
                      if (healAmount > 0) {
                        console.log(`💚 [装备-${equip.name}] ${card.card_name} 回合开始恢复`);
                        console.log(`   生命值: ${oldHealth} → ${card.health} (+${healAmount})`);
                        
                        // 添加到被动结果中（方便客户端显示）
                        passiveResults.push({
                          type: 'equipment_heal',
                          card_id: card.id,
                          card_name: card.card_name,
                          equipment_name: equip.name,
                          heal_amount: healAmount,
                          new_health: card.health
                        });
                      }
                    }
                  }
                }
              }
            }
          });
          
          // 📊 回合切换总结
          console.log('───────────────────────────────────────────────────────');
          console.log('   技能点: 房主 %d/6 | 客户端 %d/6', 
            gameState.hostSkillPoints, gameState.guestSkillPoints);
          console.log('   金币: 房主 💰%d | 客户端 💰%d',
            goldMgr ? goldMgr.hostGold : 0, goldMgr ? goldMgr.guestGold : 0);
          const blueRemaining = gameState.actionsPerTurn - gameState.blueActionsUsed;
          const redRemaining = gameState.actionsPerTurn - gameState.redActionsUsed;
          console.log('   行动点: 蓝方已用%d剩余%d | 红方已用%d剩余%d',
            gameState.blueActionsUsed, blueRemaining, gameState.redActionsUsed, redRemaining);
          console.log('   被动触发: %d个', passiveResults.length);
          
          // 显示卡牌状态
          console.log('   蓝方状态:');
          gameState.blueCards.forEach(card => {
            if (card.health > 0) {
              console.log('      %s: HP %d/%d, 护盾 %d, 攻击 %d',
                card.card_name, card.health, card.max_health, card.shield || 0, card.attack);
            } else {
              console.log('      %s: ❌ 死亡', card.card_name);
            }
          });
          console.log('   红方状态:');
          gameState.redCards.forEach(card => {
            if (card.health > 0) {
              console.log('      %s: HP %d/%d, 护盾 %d, 攻击 %d',
                card.card_name, card.health, card.max_health, card.shield || 0, card.attack);
            } else {
              console.log('      %s: ❌ 死亡', card.card_name);
            }
          });
          console.log('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\n');
          
          // 广播回合变化给双方
          room.players.forEach(playerId => {
            const isHost = (playerId === room.host);
            const isMyTurn = (isHost && isHostTurn) || (!isHost && !isHostTurn);
            
            sendToClient(playerId, {
              type: 'turn_changed',
              turn: gameState.currentTurn,
              current_player: gameState.currentPlayer,
              is_my_turn: isMyTurn,
              host_skill_points: gameState.hostSkillPoints,
              guest_skill_points: gameState.guestSkillPoints,
              // 🎯 行动点信息
              blue_actions_used: gameState.blueActionsUsed,
              red_actions_used: gameState.redActionsUsed,
              actions_per_turn: gameState.actionsPerTurn,
              passive_results: passiveResults,  // 包含被动技能结果
              // 💰 金币信息（长期方案 - 通过 GoldManager）
              host_gold: goldMgr ? goldMgr.hostGold : 0,
              guest_gold: goldMgr ? goldMgr.guestGold : 0,
              gold_income: goldIncome  // 本次收入详情（base, interest, total, newGold）
            });
          });
        }
      }
    } catch (error) {
      console.error('[错误]', error);
    }
  });
  
  ws.on('close', () => {
    console.log('[断开]', clientId);
    const roomId = playerRooms.get(clientId);
    if (roomId) {
      const room = rooms.get(roomId);
      if (room) {
        broadcastToRoom(roomId, { type: 'opponent_disconnected' }, clientId);
        room.players = room.players.filter(p => p !== clientId);
        
        // 清理房间
        if (room.players.length === 0) {
          rooms.delete(roomId);
          battleEngines.delete(roomId); // 删除战斗引擎
          console.log('[房间清理]', roomId);
        }
      }
      playerRooms.delete(clientId);
    }
    clients.delete(clientId);
  });
});

app.get('/', (req, res) => {
  res.json({ status: 'ok', name: '王者荣耀卡牌游戏服务器', clients: clients.size, rooms: rooms.size, uptime: process.uptime() });
});

server.listen(PORT, () => {
  console.log('=================================');
  console.log('王者荣耀卡牌游戏服务器已启动');
  console.log('监听端口:', PORT);
  console.log('WebSocket: ws://localhost:' + PORT);
  console.log('=================================');
});
