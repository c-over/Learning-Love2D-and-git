local MonsterAI = {}
-- 注意：这里只引用 BattleMenu 用于显示 UI，不引用 Battle 用于逻辑，防止循环
local BattleMenu = require("BattleMenu") 
local Player = require("player")
local EffectManager = require("EffectManager")
local Layout = require("layout") 

-- AI 行为库
local Behaviors = {}

-- 1. 默认 AI
Behaviors["default"] = function(enemy)
    return {
        type = "attack",
        name = "普通攻击",
        damageMult = 1.0,
        effect = "hit_physical",
        color = {1, 1, 1}
    }
end
-- 2. 蝙蝠 AI
Behaviors["bat"] = function(enemy)
    -- 30% 概率使用毒牙
    if love.math.random() < 0.3 then
        return {
            type = "debuff", -- 新类型
            name = "剧毒之牙",
            damageMult = 0.8,
            buffId = "poison",
            turns = 3,    -- 战斗持续 3 回合
            duration = 15, -- 地图持续 15 秒
            value = 5,    -- 每跳 5 点伤害
            effect = "hit_physical",
            color = {0.4, 0, 0.8}
        }
    end
    
    -- 默认攻击
    return {
        type = "attack",
        name = "超声波",
        damageMult = 1.0,
        effect = "hit_physical",
        color = {0.8, 0.8, 1}
    }
end
-- 3. 魔王 BOSS AI
Behaviors["demon_king"] = function(enemy)
    local hpPct = enemy.hp / enemy.maxHp
    
    -- 阶段 3: < 30% 血
    if hpPct < 0.3 then
        local roll = love.math.random()
        if roll < 0.3 then
            return {
                type = "heal",
                name = "暗影治愈",
                amount = math.floor(enemy.maxHp * 0.15),
                effect = "heal",
                color = {0.5, 0, 0.5}
            }
        elseif roll < 0.6 then
            return {
                type = "attack",
                name = "深渊爆裂",
                damageMult = 2.5,
                effect = "explosion",
                color = {0.6, 0, 0.8}
            }
        end
    end

    -- 阶段 2: < 70% 血
    if hpPct < 0.7 then
        if love.math.random() < 0.4 then
            return {
                type = "attack",
                name = "毁灭重击",
                damageMult = 1.5,
                effect = "explosion",
                color = {1, 0.5, 0}
            }
        end
    end

    -- 阶段 1: 默认
    return {
        type = "attack",
        name = "暗黑之触",
        damageMult = 1.0,
        effect = "hit_physical",
        color = {0.8, 0, 0}
    }
end

-- === 执行入口 ===
function MonsterAI.executeTurn(enemy)
    -- 1. 查找 AI，如果找不到则使用默认
    local aiType = enemy.aiType or "default"
    local aiFunc = Behaviors[aiType] or Behaviors["default"]
    
    -- 2. 决策
    local action = aiFunc(enemy)
    
    -- 3. 执行
    local w, h = Layout.virtualWidth, Layout.virtualHeight
    if action.type == "debuff" then
        -- 既造成伤害，又施加 Buff
        local baseDmg = enemy.attack or (enemy.level * 8)
        local rawDmg = math.floor(baseDmg * action.damageMult)
        
        -- 扣血
        if BattleMenu.state.isDefending then rawDmg = math.floor(rawDmg * 0.5) end
        Player.takeDamage(rawDmg)
        
        -- 施加状态
        Player.addBuff(action.buffId, action.duration, action.turns, action.value)
        
        -- 反馈
        BattleMenu.triggerShake(5)
        BattleMenu.addLog(enemy.name.." 使用 "..action.name.."！你中毒了！")
        BattleMenu.addFloatText("中毒", "player", {0.6, 0, 0.8})
        
        -- 特效
        local h = Layout.virtualHeight
        EffectManager.spawn(action.effect, 100, h-150, action.color, 2)

    elseif action.type == "heal" then
        -- 回血
        enemy.hp = math.min(enemy.hp + action.amount, enemy.maxHp)
        
        BattleMenu.addLog(enemy.name .. " 使用了 " .. action.name)
        BattleMenu.addFloatText("+"..action.amount, "enemy", {0, 1, 0})
        
        -- 特效位置：怪物中心 (居中偏上)
        local cx = w / 2
        local cy = (h - 160) / 2 
        EffectManager.spawn(action.effect, cx, cy, action.color, 3)
        
    elseif action.type == "attack" then
        -- 攻击
        local baseDmg = enemy.attack or (enemy.level * 10)
        local rawDmg = math.floor(baseDmg * action.damageMult * love.math.random(90,110)/100)
        
        -- 防御判定 (读取 UI 状态)
        if BattleMenu.state.isDefending then
            rawDmg = math.floor(rawDmg * 0.5)
            BattleMenu.addLog("防御生效！伤害减半。")
        end
        
        -- 扣血
        Player.takeDamage(rawDmg)
        
        local def = Player.data.defense or 0
        local actualDmg = math.max(rawDmg - def, 1)
        
        BattleMenu.triggerShake(action.damageMult > 1.2 and 10 or 5)
        BattleMenu.addLog(enemy.name .. " 施放 " .. action.name .. " 造成 " .. actualDmg .. " 伤害")
        BattleMenu.addFloatText("-"..actualDmg, "player", {1, 0.2, 0.2})
        
        -- 特效位置：玩家位置 (左下角上方)
        local px = 100
        local py = h - 150
        EffectManager.spawn(action.effect, px, py, action.color, 2)
    
    end
end

return MonsterAI