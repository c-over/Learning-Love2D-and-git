local Battle = {}
local Player = require("player")
local Config = require("config")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local MagicManager = require("MagicManager")
local BattleMenu = require("BattleMenu")

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
    state.phase = "acting"
    local enemy = state.enemy
    local dmg = math.floor((Player.data.attack or 10) * (math.random(90,110)/100))
    if math.random() < 0.15 then dmg = math.floor(dmg * 1.5) end -- Crit
    enemy.hp = math.max(enemy.hp - dmg, 0)
    BattleMenu.triggerShake(5)
    BattleMenu.addFloatText(tostring(dmg), "enemy", {1,1,0})
    BattleMenu.addLog("你攻击了 " .. enemy.name)
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
    local state = BattleMenu.state
    if type == "skill" then
        if Player.data.mp < target.mp then BattleMenu.addLog("法力不足"); return end
        if target.type == "damage" then
            Player.data.mp = Player.data.mp - target.mp
            local dmg = target.power + math.floor((Player.data.attack or 0)*0.5)
            state.enemy.hp = math.max(state.enemy.hp - dmg, 0)
            BattleMenu.triggerShake(8)
            BattleMenu.addFloatText(tostring(dmg), "enemy", {0.4,0.6,1})
            if state.enemy.texture then state.enemy.visualState="hurt"; state.animResetTimer=0.5 end
            state.phase="acting"; state.timer=1; state.nextTurn="enemy"
        elseif target.type == "heal" then
            local ok, msg = MagicManager.cast(target.id, Player.data)
            if ok then BattleMenu.addFloatText(msg, "player", {0,1,0}); state.phase="acting"; state.timer=1; state.nextTurn="enemy"
            else BattleMenu.addLog(msg) end
        end
    elseif type == "item" then
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
            state.phase="acting"; state.timer=1; state.nextTurn="enemy"
        else BattleMenu.addLog(msg) end
    elseif type == "equip" then
        if target.equipSlot then Player.unequipItem(target); BattleMenu.addLog("卸下 "..ItemManager.get(target.id).name)
        else Player.equipItem(target); BattleMenu.addLog("装备 "..ItemManager.get(target.id).name) end
        -- 换装不消耗回合
    end
end

-- === 敌人 AI ===
function Battle.processEnemyTurn()
    local state = BattleMenu.state
    if state.enemy.hp <= 0 then return end
    if state.enemy.texture then state.enemy.visualState="attack"; state.animResetTimer=0.5 end
    
    local dmg = math.floor((state.enemy.attack or state.enemy.level*8) * (math.random(90,110)/100))
    if state.isDefending then dmg=math.floor(dmg*0.5); BattleMenu.addLog("防御生效！") end
    Player.takeDamage(dmg)
    BattleMenu.triggerShake(5)
    local actual = math.max(dmg - (Player.data.defense or 0), 1)
    
    -- [修改] 使用 BattleMenu.addLog 确保日志显示在UI上
    BattleMenu.addLog(state.enemy.name .. " 造成 " .. actual .. " 伤害")
    BattleMenu.addFloatText("-"..actual, "player", {1, 0.2, 0.2})
    state.isDefending = false; state.timer = 1.0; state.nextTurn = "player"
end

-- === 更新 ===
function Battle.update(dt)
    local state = BattleMenu.state
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
            else Player.gainExp(m.level*20); Player.addGold(m.level*5) end
        elseif res.result=="lose" then currentScene="gameover"
        elseif res.result=="escape" then m.cooldown=5 end
    end)
end

return Battle 