const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const CardDatabase = require('./game/CardDatabase');
const BattleEngine = require('./game/BattleEngine');
const { equipmentDB, EquipmentTier } = require('./game/EquipmentDatabase');

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

// 初始化游戏状态
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
    { id: 'yao_005_blue_0', ...yaoData, health: yaoData.max_health, shield: 0 },
    { id: 'daqiao_006_blue_1', ...daqiaoData, health: daqiaoData.max_health, shield: 0, daqiao_passive_used: false },
    { id: 'gongsunli_003_blue_2', ...gongsunliData, health: gongsunliData.max_health, shield: 0 }
  ];
  
  // 红方（客户端）：澜 + 孙尚香 + 朵莉亚
  const redCards = [
    { id: 'lan_002_red_0', ...lanData, health: lanData.max_health, shield: 0 },
    { id: 'sunshangxiang_004_red_1', ...sunshangxiangData, health: sunshangxiangData.max_health, shield: 0 },
    { id: 'duoliya_001_red_2', ...duoliyaData, health: duoliyaData.max_health, shield: 0 }
  ];
  
  room.gameState = {
    blueCards,
    redCards,
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
    // 💰 金币系统（新增）
    hostGold: 10,         // 房主金币
    guestGold: 10         // 客户端金币
  };
  
  // 创建战斗引擎
  const engine = new BattleEngine(roomId, room.gameState);
  battleEngines.set(roomId, engine);
  
  console.log('[游戏初始化]', roomId, '战斗引擎创建完成');
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
              room.status = 'playing';
              
              // 🎮 初始化游戏状态
              initGameState(data.room_id);
              
              // 🎯 准备发送给客户端的卡牌数据（包含所有必要信息）
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
                // 🎯 特殊属性（公孙离、大乔等）
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
                // 🎯 特殊属性（公孙离、大乔等）
                dodge_rate: card.dodge_rate || 0,
                dodge_bonus: card.dodge_bonus || 0,
                daqiao_passive_used: card.daqiao_passive_used || false,
                skill_ends_turn: card.skill_ends_turn || false
              }));
              
              broadcastToRoom(data.room_id, { 
                type: 'game_start', 
                room_id: data.room_id, 
                players: room.players, 
                player_names: room.playerNames, 
                host: room.host,
                // 🎯 发送完整卡牌数据
                blue_cards: blueCardsData,
                red_cards: redCardsData,
                // 🎯 发送卡牌数量信息，让客户端知道是几v几
                blue_cards_count: room.gameState.blueCards.length,
                red_cards_count: room.gameState.redCards.length,
                // 🎯 初始技能点和行动点
                initial_skill_points: 4,
                actions_per_turn: 3,
                // 💰 初始金币（新增）
                host_gold: room.gameState.hostGold,
                guest_gold: room.gameState.guestGold
              });
              console.log('[游戏开始]', data.room_id);
            }, 500);
          }
        }
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
                if (result.effect_type === 'true_damage' || result.effect_type === 'true_damage_with_armor_reduction') {
                  console.log('   伤害类型: 真实伤害');
                  if (result.armor_reduction) {
                    console.log('   护甲削减: %d', result.armor_reduction);
                  }
                  console.log('   伤害数值: %d', result.damage_amount || 0);
                  console.log('   目标: %s', result.target ? result.target.card_name : '未知');
                } else if (result.effect_type === 'heal') {
                  console.log('   治疗数值: %d', result.heal_amount || 0);
                  console.log('   目标: %s', result.target ? result.target.card_name : '未知');
                } else if (result.effect_type === 'shield_and_buff') {
                  console.log('   护盾数值: %d', result.shield_amount || 0);
                  console.log('   暴击率提升: +%d%%', (result.crit_rate_buff || 0) * 100);
                  console.log('   护甲提升: +%d', result.armor_buff || 0);
                  console.log('   目标: %s', result.target ? result.target.card_name : '未知');
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
                    guest_skill_points: gameState.guestSkillPoints
                  });
                });
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
          // 💰 购买装备（抽取3个随机装备）
          const gameState = room.gameState;
          const isHost = (clientId === room.host);
          const playerGold = isHost ? gameState.hostGold : gameState.guestGold;
          const equipmentCost = 15; // 固定15金币
          
          console.log('[装备购买] 玩家:', isHost ? '房主' : '客户端', '金币:', playerGold);
          
          // 检查金币是否足够
          if (playerGold < equipmentCost) {
            console.error('[装备购买失败] 金币不足:', playerGold, '<', equipmentCost);
            sendToClient(clientId, {
              type: 'buy_equipment_failed',
              error: `金币不足 (需要${equipmentCost}金币，当前${playerGold}金币)`
            });
            return;
          }
          
          // 扣除金币
          if (isHost) {
            gameState.hostGold -= equipmentCost;
          } else {
            gameState.guestGold -= equipmentCost;
          }
          
          // 抽取3个随机装备
          const drawnEquipment = equipmentDB.drawRandomEquipment(EquipmentTier.BASIC, 3);
          console.log('[装备抽取] 抽到:', drawnEquipment.map(e => e.name).join(', '));
          
          // 发送抽取结果给玩家
          sendToClient(clientId, {
            type: 'equipment_drawn',
            equipment_options: drawnEquipment,
            remaining_gold: isHost ? gameState.hostGold : gameState.guestGold
          });
          
          // 广播金币变化给双方
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'gold_changed',
              host_gold: gameState.hostGold,
              guest_gold: gameState.guestGold,
              income_data: {} // 购买装备不算收入
            });
          });
          
        } else if (data.action === 'equip_item') {
          // 🎒 装备物品到英雄
          const { equipment_id, card_id } = data.data;
          const isHost = (clientId === room.host);
          
          console.log('[装备物品] 装备ID:', equipment_id, '英雄ID:', card_id);
          
          // 查找英雄卡牌
          const card = engine.findCard(card_id);
          if (!card) {
            console.error('[装备失败] 英雄未找到:', card_id);
            sendToClient(clientId, {
              type: 'equip_failed',
              error: '英雄未找到'
            });
            return;
          }
          
          // 检查英雄所属
          const cardIsHost = room.gameState.blueTeam.some(c => c.id === card_id);
          if (cardIsHost !== isHost) {
            console.error('[装备失败] 不能给对方英雄装备');
            sendToClient(clientId, {
              type: 'equip_failed',
              error: '不能给对方英雄装备'
            });
            return;
          }
          
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
          
          // 添加装备
          card.equipment.push(equipment);
          console.log('✅ [装备成功] %s 装备了 %s (当前%d件)', card.card_name, equipment.name, card.equipment.length);
          
          // 应用装备效果
          equipmentDB.applyEquipmentEffects(card, equipment);
          
          // 广播装备结果给双方
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'item_equipped',
              card_id: card_id,
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
          
          // 💰 金币结算（回合开始时增加，立即可用）
          let goldIncome = null;
          if (isHostTurn) {
            // 房主回合开始，结算房主金币
            goldIncome = calculateGoldIncome(gameState.hostGold);
            gameState.hostGold = goldIncome.newGold;
            console.log('💰 [金币结算] 房主/蓝方');
            console.log('   当前金币: %d → %d', goldIncome.newGold - goldIncome.total, goldIncome.newGold);
            console.log('   基础收入: +%d, 利息: +%d (总收入: +%d)', 
              goldIncome.base, goldIncome.interest, goldIncome.total);
          } else {
            // 客户端回合开始，结算客户端金币
            goldIncome = calculateGoldIncome(gameState.guestGold);
            gameState.guestGold = goldIncome.newGold;
            console.log('💰 [金币结算] 客户端/红方');
            console.log('   当前金币: %d → %d', goldIncome.newGold - goldIncome.total, goldIncome.newGold);
            console.log('   基础收入: +%d, 利息: +%d (总收入: +%d)', 
              goldIncome.base, goldIncome.interest, goldIncome.total);
          }
          
          // 🎯 触发回合开始被动技能
          const passiveResults = [];
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
            gameState.hostGold, gameState.guestGold);
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
              // 💰 金币信息（新增）
              host_gold: gameState.hostGold,
              guest_gold: gameState.guestGold,
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
