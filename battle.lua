local Battle = {}
local Player = require("player")
local Config = require("config")
local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local MagicManager = require("MagicManager")
local BattleMenu = require("BattleMenu")
local MonsterAI = require("MonsterAI")
local EffectManager = require("EffectManager") 
-- 启动
function Battle.start(enemyPayload, enemyIndex, onResolve)
    BattleMenu.init(enemyPayload, enemyIndex, onResolve)
    if bossMusic and BattleMenu.state.enemy.isBoss then bgMusic:pause(); bossMusic:play() end
    currentScene = "battle"
    BattleMenu.addLog("遭遇了 " .. BattleMenu.state.enemy.name)
end

function Battle.resolveBattle(result)
    if bossMusic and bossMusic:isPlaying() then bossMusic:stop(); bgMusic:play() end
    if BattleMenu.state.onResolve then BattleMenu.state.onResolve(result, BattleMenu.state.enemyIndex) end
    if currentScene == "battle" then currentScene = "game" end
end

-- === 玩家行动 ===
function Battle.playerAttackAction()
    local state = BattleMenu.state
    if state.phase ~= "idle" then return end
    state.phase = "acting"
    
    local enemy = state.enemy
    local baseDmg = Player.data.attack or 10
    local dmg = math.floor(baseDmg * (math.random(90, 110) / 100))
    local isCrit = math.random() < 0.15
    if isCrit then dmg = math.floor(dmg * 1.5) end
    
    enemy.hp = math.max(enemy.hp - dmg, 0)
    
    BattleMenu.triggerShake(isCrit and 8 or 3)
    BattleMenu.addLog("你攻击了 " .. enemy.name)
    
    local text = isCrit and "暴击 " .. dmg or tostring(dmg)
    local color = isCrit and {1, 1, 0} or {1, 1, 1}
    BattleMenu.addFloatText(text, "enemy", color)
    
    -- [新增] 1. 怪物受击发光 (持续 0.15秒)
    enemy.flashTimer = 0.15
    
    -- [新增] 2. 播放 Sword 特效
    -- 获取怪物屏幕坐标
    local w, h = Layout.virtualWidth, Layout.virtualHeight
    local panelH = 160
    local cx, cy = w/2, (h - panelH)/2
    
    -- 生成剑击特效，稍微随机一点角度
    local angle = math.random() * math.pi * 2
    EffectManager.spawn("sword", cx, cy, {1,1,1}, 2, angle)
    
    if enemy.texture then enemy.visualState = "hurt"; state.animResetTimer = 0.5 end
    state.timer = 1.0; state.nextTurn = "enemy"
end

function Battle.playerDefendAction()
    BattleMenu.addLog("防御姿态！")
    BattleMenu.state.isDefending = true
    BattleMenu.state.phase = "acting"; BattleMenu.state.timer = 0.5; BattleMenu.state.nextTurn = "enemy"
end

function Battle.playerEscapeAction()
    if math.random() < BattleMenu.state.enemy.escapeChance then
        BattleMenu.addLog("逃跑成功！")
        Battle.resolveBattle({ result = "escape" })
    else
        BattleMenu.addLog("逃跑失败！")
        BattleMenu.state.phase = "acting"; BattleMenu.state.timer = 1.0; BattleMenu.state.nextTurn = "enemy"
    end
end

function Battle.onBattleMenuAction(type, target)
    -- 计算特效坐标
    -- 怪物位置: 屏幕水平中心, 垂直方向是 (屏幕高 - UI高)/2
    -- 必须与 Battle.draw 中的绘制坐标公式保持一致
    local w, h = Layout.virtualWidth, Layout.virtualHeight
    local panelH = 160
    local enemyX = w / 2
    local enemyY = (h - panelH) / 2 
        
    -- 玩家位置: 屏幕左下角上方
    local playerX = 100
    local playerY = h - 150
    if type == "skill" then
        if Player.data.mp < target.mp then BattleMenu.addLog("法力不足"); return end

        -- [伤害类魔法]
        if target.type == "damage" then
            Player.data.mp = Player.data.mp - target.mp
            local dmg = target.power + math.floor((Player.data.attack or 0) * 0.5)
            BattleMenu.state.enemy.hp = math.max(BattleMenu.state.enemy.hp - dmg, 0)
            
            BattleMenu.triggerShake(8)
            BattleMenu.addFloatText(tostring(dmg), "enemy", {0.4, 0.6, 1})
            BattleMenu.addLog("使用了 " .. target.name)
            -- [新增] 播放特效 (在怪物身上)
            -- 默认特效为 "explosion"，默认颜色为白色
            local effName = target.effect or "explosion"
            local effColor = target.effectColor or {1, 1, 1}
            -- scale = 2 (放大一点更有气势)
            EffectManager.spawn(effName, enemyX, enemyY, effColor, 2)
            
            if BattleMenu.state.enemy.texture then 
                BattleMenu.state.enemy.visualState = "hurt" 
                BattleMenu.state.animResetTimer = 0.5 
            end
            
            BattleMenu.state.phase = "acting"
            BattleMenu.state.timer = 1.0
            BattleMenu.state.nextTurn = "enemy"
            return true
            
        -- [治疗类魔法]
        elseif target.type == "heal" then
            -- 这里我们手动处理回血，以便插入特效
            local healAmount = target.power + math.floor((Player.data.level or 1) * 5)
            local success = Player.addHP(healAmount)
            
            if success then
                Player.data.mp = Player.data.mp - target.mp
                BattleMenu.addFloatText("+"..healAmount, "player", {0,1,0})
                BattleMenu.addLog("使用了 " .. target.name)
                
                -- [新增] 播放特效 (在玩家身上)
                local effName = target.effect or "heal"
                local effColor = target.effectColor or {1, 1, 1}
                EffectManager.spawn(effName, playerX, playerY, effColor, 2)
                
                BattleMenu.state.phase = "acting"
                BattleMenu.state.timer = 1.0
                BattleMenu.state.nextTurn = "enemy"
                return true
            else
                return false, "生命值已满"
            end
        end
    elseif type == "item" then
        local state = BattleMenu.state
        local proxy = {
            hp=Player.data.hp, maxHp=Player.data.maxHp, mp=Player.data.mp, maxMp=Player.data.maxMp,
            addHP=function(v) return Player.addHP(v) end, addMP=function(v) return Player.addMP(v) end,
            dealDamage=function(v) 
                local d=tonumber(v) or 0; state.enemy.hp=math.max(state.enemy.hp-d,0)
                BattleMenu.addFloatText("-"..d,"enemy",{1,0,0})
                if state.enemy.texture then state.enemy.visualState="hurt"; state.animResetTimer=0.5 end; return true
            end
        }
        local ok, msg = ItemManager.use(target.id, proxy)
        if ok then
            Inventory:removeItem(target.id, 1); BattleMenu.refreshLists()
            BattleMenu.addLog(msg or "使用了物品")
            
            -- [新增] 播放喝药音效/特效 (在玩家身上)
            local w, h = Layout.virtualWidth, Layout.virtualHeight
            local px, py = 100, h - 150
            -- 假设 "potion_use" 在 effects.json 里配置了 sound
            EffectManager.spawn("potion_use", px, py, {1,1,1}, 1)
            
            state.phase="acting"; state.timer=1.0; state.nextTurn="enemy"
        else BattleMenu.addLog(msg) end
    elseif type == "equip" then
        if target.equipSlot then Player.unequipItem(target); BattleMenu.addLog("卸下 "..ItemManager.get(target.id).name)
        else Player.equipItem(target); BattleMenu.addLog("装备 "..ItemManager.get(target.id).name) end
        -- 换装不消耗回合
    end
end

-- === 敌人回合 ===
function Battle.processEnemyTurn()
    local state = BattleMenu.state
    if state.enemy.hp <= 0 then return end
    
    -- 1. 播放动画 (UI层)
    if state.enemy.texture then 
        state.enemy.visualState = "attack"
        state.animResetTimer = 0.5 
    end
    
    -- 2. 执行 AI 逻辑 (数据层 & 特效层)
    -- MonsterAI 会自动处理 伤害计算、回血、飘字、震动、日志、特效
    MonsterAI.executeTurn(state.enemy)
    
    -- 3. 结算玩家身上的持续伤害 (中毒)
    local died = Player.handleBattleTurnBuffs()
    
    if died then
        -- 玩家被毒死
        BattleMenu.state.phase = "defeat"
        BattleMenu.state.timer = 2.0
    else
        -- 玩家存活，轮到玩家行动
        BattleMenu.state.isDefending = false
        BattleMenu.state.timer = 1.0
        BattleMenu.state.nextTurn = "player"
    end
end
-- === 更新 ===
function Battle.update(dt)
    local state = BattleMenu.state
    -- 更新怪物受击闪白计时器
    if state.enemy and state.enemy.flashTimer > 0 then
        state.enemy.flashTimer = state.enemy.flashTimer - dt
    end
    if state.timer > 0 then
        state.timer = state.timer - dt
        if state.timer <= 0 then
            if state.phase == "acting" then
                state.phase = "idle"; state.turn = state.nextTurn
                if state.enemy.hp <= 0 then state.phase="victory"; state.timer=1.5; if state.enemy.texture then state.enemy.visualState="die" end
                elseif Player.data.hp <= 0 then state.phase="defeat"; state.timer=2.0
                elseif state.turn == "enemy" then state.phase="acting"; Battle.processEnemyTurn() end
            elseif state.phase == "victory" then Battle.resolveBattle({result="win"})
            elseif state.phase == "defeat" then Player.data.deathCount=(Player.data.deathCount or 0)+1; Battle.resolveBattle({result="lose"}) end
        end
    end
    if state.animResetTimer > 0 then
        state.animResetTimer = state.animResetTimer - dt
        if state.animResetTimer <= 0 and state.enemy.hp > 0 then state.enemy.visualState = "idle" end
    end
    local enemy = state.enemy
    if enemy and enemy.texture then
        local frames = enemy.animConfig[enemy.visualState] or {1}
        enemy.animTimer = enemy.animTimer + dt
        if enemy.animTimer > 0.15 then
            enemy.animTimer = 0
            enemy.animFrame = enemy.animFrame + 1
            if enemy.animFrame > #frames then
                if enemy.visualState == "die" then enemy.animFrame = #frames else enemy.animFrame = 1 end
            end
        end
    end
    if state.shake > 0 then state.shake = math.max(0, state.shake - dt * 20) end
end

-- 兼容旧接口
function Battle.enterBattle(i, m)
    if m.cooldown and m.cooldown>0 then return end
    Battle.start(m, i, function(res, idx)
        local Monster = require("monster")
        if res.result=="win" then
            if Monster.list[idx]==m then table.remove(Monster.list, idx) end
            if m.isBoss then Player.data.questStatus="killed"; require("pickup").create(m.x,m.y,"coin",5000)
                Player.addOrUpdateQuest(
                    "kill_boss",
                    "讨伐魔王 (可交付)",
                    "魔王已被击败！快回去找商人领赏。"
                )
            else Player.gainExp(m.level*20); Player.addGold(m.level*5) end
        elseif res.result=="lose" then currentScene="gameover"
        elseif res.result=="escape" then m.cooldown=5 end
    end)
end

return Battle 