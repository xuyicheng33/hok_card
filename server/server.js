const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const CardDatabase = require('./game/CardDatabase');
const BattleEngine = require('./game/BattleEngine');

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

// 初始化游戏状态
function initGameState(roomId) {
  const room = rooms.get(roomId);
  if (!room) return;
  
  // 创建初始卡牌状态（health 应该等于 max_health）
  const gongsunliData = cardDB.getCard('gongsunli_003');
  const lanData = cardDB.getCard('lan_002');
  const duoliyaData = cardDB.getCard('duoliya_001');
  
  const blueCards = [
    { id: 'blue_gongsunli', ...gongsunliData, health: gongsunliData.max_health, shield: 0 },
    { id: 'blue_lan', ...lanData, health: lanData.max_health, shield: 0 }
  ];
  
  const redCards = [
    { id: 'red_duoliya', ...duoliyaData, health: duoliyaData.max_health, shield: 0 },
    { id: 'red_lan', ...lanData, health: lanData.max_health, shield: 0 }
  ];
  
  room.gameState = {
    blueCards,
    redCards,
    currentTurn: 1,  // 回合从1开始
    currentPlayer: 'host',  // 房主先手
    hostSkillPoints: 4,  // 房主技能点
    guestSkillPoints: 4  // 客户端技能点
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
              
              broadcastToRoom(data.room_id, { 
                type: 'game_start', 
                room_id: data.room_id, 
                players: room.players, 
                player_names: room.playerNames, 
                host: room.host 
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
          
          // 广播攻击结果
          room.players.forEach(playerId => {
            sendToClient(playerId, {
              type: 'opponent_action',
              action: 'attack',
              data: result,
              from: clientId
            });
          });
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
                if (isHost) {
                  gameState.hostSkillPoints = Math.max(0, gameState.hostSkillPoints - skillCost);
                } else {
                  gameState.guestSkillPoints = Math.max(0, gameState.guestSkillPoints - skillCost);
                }
                
                console.log('[技能成功]', result.effect_type, 
                  `扣除${skillCost}点 剩余:房主${gameState.hostSkillPoints} 客户端${gameState.guestSkillPoints}`);
                
                // 广播技能结果给双方
                room.players.forEach(playerId => {
                  sendToClient(playerId, {
                    type: 'opponent_action',
                    action: 'skill',
                    data: result,
                    from_player_id: clientId
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
        } else if (data.action === 'end_turn') {
          // 🎯 服务器权威管理回合切换
          const gameState = room.gameState;
          
          // 回合数+1
          gameState.currentTurn++;
          
          // 判断下一回合是谁的
          // 奇数回合=房主(host)，偶数回合=客户端(guest)
          const isHostTurn = (gameState.currentTurn % 2 === 1);
          gameState.currentPlayer = isHostTurn ? 'host' : 'guest';
          
          // 🌟 增加技能点（第3回合开始，上限6点）
          if (gameState.currentTurn > 2) {
            if (isHostTurn) {
              gameState.hostSkillPoints = Math.min(6, gameState.hostSkillPoints + 1);
              console.log('[技能点] 房主 +1 → ', gameState.hostSkillPoints);
            } else {
              gameState.guestSkillPoints = Math.min(6, gameState.guestSkillPoints + 1);
              console.log('[技能点] 客户端 +1 → ', gameState.guestSkillPoints);
            }
          }
          
          // 🎯 触发回合开始被动技能
          const passiveResults = [];
          const activeCards = isHostTurn ? gameState.blueCards : gameState.redCards;
          
          activeCards.forEach(card => {
            if (card.health > 0) {  // 只处理存活的卡牌
              // 朵莉亚的被动技能：欢歌
              if (card.card_name === '朵莉亚') {
                const healAmount = 75;
                const oldHealth = card.health;
                const oldShield = card.shield || 0;
                
                card.health = Math.min(card.max_health, card.health + healAmount);
                const actualHeal = card.health - oldHealth;
                
                // 计算溢出护盾
                let overflowShield = 0;
                if (oldHealth + healAmount > card.max_health) {
                  overflowShield = (oldHealth + healAmount) - card.max_health;
                  card.shield = (card.shield || 0) + overflowShield;
                }
                
                console.log(`⭐ [朵莉亚被动-欢歌] 回合开始恢复`);
                console.log(`   生命: ${oldHealth} → ${card.health} (+${actualHeal})`);
                if (overflowShield > 0) {
                  console.log(`   溢出护盾: +${overflowShield} (总护盾: ${card.shield})`);
                }
                
                passiveResults.push({
                  type: 'passive_triggered',
                  card_id: card.id,
                  card_name: card.card_name,
                  passive_name: '欢歌',
                  effect: {
                    heal_amount: actualHeal,
                    overflow_shield: overflowShield,
                    new_health: card.health,
                    new_shield: card.shield
                  }
                });
              }
            }
          });
          
          console.log('[回合切换]', roomId, '第', gameState.currentTurn, '回合，当前玩家:', gameState.currentPlayer,
            '技能点 房主:', gameState.hostSkillPoints, '客户端:', gameState.guestSkillPoints);
          
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
              passive_results: passiveResults  // 包含被动技能结果
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
