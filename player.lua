local Player = {}
local Config = require("config")
local ItemManager = require("ItemManager")

-- 数据容器
Player.data = {}

-- === 1. 数据管理 ===
local function initDefaults()
    Player.data.name   = Player.data.name or "未命名"
    Player.data.level  = Player.data.level or 1
    Player.data.hp     = Player.data.hp or 100
    Player.data.maxHp  = Player.data.maxHp or 100
    Player.data.mp     = Player.data.mp or 50
    Player.data.maxMp  = Player.data.maxMp or 50
    Player.data.exp    = Player.data.exp or 0
    Player.data.attack = Player.data.attack or 10
    Player.data.defense= Player.data.defense or 5
    Player.data.speed  = Player.data.speed or 240
    Player.data.gold   = Player.data.gold or 100
    Player.data.equipment = Player.data.equipment or {}
    Player.data.quests = Player.data.quests or {}
    Player.data.buffs  = Player.data.buffs or {}
    Player.data.deathCount = Player.data.deathCount or 0
end

function Player.save()
    Config.updatePlayer(Player.data)
end

function Player.load()
    Config.load()
    local saveData = Config.get()
    Player.data = saveData.player or {}
    initDefaults()
    cleanupDuplicateQuests()
end

-- === 2. 核心逻辑 ===

function Player.recalcStats()
    -- 1. 重置为基础属性
    local tDef, tAtk = 5, 10
    local tMaxHp, tMaxMp = 100 + (Player.data.level-1)*100, 50 + (Player.data.level-1)*20
    -- (注意：这里假设基础血量公式是 100 + (lv-1)*100，需与 addLevel 逻辑一致)
    
    Player.data.equipment = {} 
    
    -- 2. 累加装备属性
    local inventory = require("config").data.inventory
    if inventory then
        for _, item in ipairs(inventory) do
            if item.equipSlot then
                local def = ItemManager.get(item.id)
                if def then
                    if def.defense then tDef = tDef + def.defense end
                    if def.attack then tAtk = tAtk + def.attack end
                    -- [新增] 累加血蓝上限
                    if def.maxHp then tMaxHp = tMaxHp + def.maxHp end
                    if def.maxMp then tMaxMp = tMaxMp + def.maxMp end
                    
                    local visualEntry = { id = item.id }
                    setmetatable(visualEntry, { __index = def })
                    Player.data.equipment[item.equipSlot] = visualEntry
                end
            end
        end
    end
    
    -- 3. 应用属性
    Player.data.defense = tDef
    Player.data.attack = tAtk
    Player.data.maxHp = tMaxHp
    Player.data.maxMp = tMaxMp
    
    -- [关键修复] 合法性检查 (Clamping)
    -- 如果卸下装备导致 MaxHP 变小，当前 HP 不能超过 MaxHP
    if Player.data.hp > Player.data.maxHp then
        Player.data.hp = Player.data.maxHp
    end
    if Player.data.mp > Player.data.maxMp then
        Player.data.mp = Player.data.maxMp
    end
end

function Player.equipItem(targetItem)
    local def = ItemManager.get(targetItem.id)
    if not def or not def.slot then return end

    local targetSlot = def.slot
    local finalSlot = nil
    local inventory = require("config").data.inventory

    -- 饰品自动填空
    if targetSlot == "accessory" then
        local slots = {"accessory1", "accessory2", "accessory3"}
        for _, s in ipairs(slots) do
            local isOccupied = false
            for _, item in ipairs(inventory) do
                if item.equipSlot == s then isOccupied = true; break end
            end
            if not isOccupied then finalSlot = s; break end
        end
        if not finalSlot then finalSlot = "accessory1" end
    else
        finalSlot = targetSlot
    end

    -- 卸下冲突
    for _, item in ipairs(inventory) do
        if item.equipSlot == finalSlot then item.equipSlot = nil end
    end

    targetItem.equipSlot = finalSlot
    Player.recalcStats()
end

function Player.unequipItem(targetItem)
    targetItem.equipSlot = nil
    Player.recalcStats()
end

-- === 3. 数值操作接口 ===

function Player.takeDamage(amount)
    initDefaults()
    local def = Player.data.defense or 0
    local actualDmg = math.max(amount - def, 1)
    Player.data.hp = math.max(Player.data.hp - actualDmg, 0)
    Player.save()
end

function Player.addHP(v) 
    initDefaults()
    if Player.data.hp >= Player.data.maxHp then return false end
    Player.data.hp = math.min(Player.data.hp + (v or 10), Player.data.maxHp)
    Player.save()
    return true 
end

function Player.addMP(v) 
    initDefaults()
    if Player.data.mp >= Player.data.maxMp then return false end
    Player.data.mp = math.min(Player.data.mp + (v or 10), Player.data.maxMp)
    Player.save()
    return true
end

function Player.useMana(cost)
    initDefaults()
    if Player.data.mp >= cost then
        Player.data.mp = Player.data.mp - cost
        Player.save()
        return true
    else
        return false
    end
end

function Player.addGold(v) 
    initDefaults()
    Player.data.gold = Player.data.gold + (v or 10)
    Player.save() 
end

function Player.gainExp(v) 
    initDefaults()
    Player.data.exp = Player.data.exp + (v or 10)
    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.addLevel(1)
    end
    Player.save() 
end

function Player.addLevel(v) 
    initDefaults()
    local inc = v or 1
    Player.data.level = Player.data.level + inc
    Player.data.maxHp = Player.data.maxHp + 100 * inc
    Player.data.maxMp = Player.data.maxMp + 20 * inc
    Player.data.hp = Player.data.maxHp
    Player.data.mp = Player.data.maxMp
    Player.data.attack = Player.data.attack + 5 * inc
    Player.data.defense= Player.data.defense + 3 * inc
    Player.save()
end

function Player.getToolEfficiency(targetType)
    local speed = 1.0
    local mainHand = Player.data.equipment.main_hand
    if mainHand then
        local id = mainHand.id
        if targetType == "tree" and id == 14 then speed = 3.0
        elseif targetType == "rock" and id == 15 then speed = 3.0 end
    end
    return speed
end
-- 任务接口
-- 清理重复任务 (修复坏档)
function cleanupDuplicateQuests()
    if not Player.data.quests then return end
    
    local seen = {}
    -- 倒序遍历以便安全移除
    for i = #Player.data.quests, 1, -1 do
        local q = Player.data.quests[i]
        if seen[q.id] then
            -- 如果已经见过这个ID，说明当前这个是重复的（或者是旧的），移除
            table.remove(Player.data.quests, i)
            print("[Player] 移除了重复任务: " .. q.id)
        else
            seen[q.id] = true
        end
    end
end
function Player.addOrUpdateQuest(id, name, description)
    -- 1. 检查是否已存在
    for _, q in ipairs(Player.data.quests) do
        if q.id == id then
            -- 存在则更新内容 (例如从"进行中"更新为"已完成")
            q.name = name
            q.description = description
            return -- 退出，不添加新条目
        end
    end
    
    -- 2. 不存在则新增
    table.insert(Player.data.quests, {
        id = id,
        name = name,
        description = description
    })
end
--BUFF接口
function Player.addBuff(id, duration, turns, value)
    initDefaults()
    -- 如果已有，刷新时间；如果没有，新增
    Player.data.buffs[id] = {
        timer = duration,   -- 地图模式持续时间 (秒)
        turns = turns,      -- 战斗模式持续回合
        val = value or 0,   -- 强度 (如毒伤害值)
        tickTimer = 0       -- 用于地图上的持续扣血计时
    }
    print("获得 Buff: " .. id)
end

function Player.removeBuff(id)
    if Player.data.buffs[id] then
        Player.data.buffs[id] = nil
        print("Buff 消失: " .. id)
    end
end

function Player.hasBuff(id)
    return Player.data.buffs and Player.data.buffs[id] ~= nil
end

-- 3. [新增] 地图模式下的 Buff 更新 (在 Game.update 调用)
function Player.updateBuffs(dt)
    if not Player.data.buffs then return end
    local GameUI = require("game_ui") -- 用于飘字

    for id, buff in pairs(Player.data.buffs) do
        -- 计时减少
        buff.timer = buff.timer - dt
        
        -- 中毒逻辑 (地图模式：每 2 秒扣一次血)
        if id == "poison" then
            buff.tickTimer = buff.tickTimer + dt
            if buff.tickTimer >= 2.0 then
                buff.tickTimer = 0
                Player.takeDamage(buff.val)
                -- 飘字
                if GameUI.addFloatText then
                    GameUI.addFloatText("中毒 -"..buff.val, Player.data.x, Player.data.y - 40, {0.6, 0, 0.8})
                end
                -- 屏幕闪烁红色提示 (可选)
            end
        end

        -- 过期移除
        if buff.timer <= 0 then
            Player.removeBuff(id)
            if GameUI.addFloatText then
                GameUI.addFloatText(id.." 结束", Player.data.x, Player.data.y - 60, {1, 1, 1})
            end
        end
    end
end

-- 4. [新增] 战斗模式下的 Buff 结算 (在 Battle 回合开始调用)
-- 返回 true 表示因 Buff 死亡
function Player.handleBattleTurnBuffs()
    local GameUI = require("game_ui")
    local died = false
    
    for id, buff in pairs(Player.data.buffs) do
        -- 扣除回合数
        if buff.turns then
            buff.turns = buff.turns - 1
            
            -- 中毒结算
            if id == "poison" then
                Player.takeDamage(buff.val)
                GameUI.addFloatText("中毒 -"..buff.val, 120, 400, {0.6, 0, 0.8}) -- 战斗UI位置
                if Player.data.hp <= 0 then died = true end
            end
            
            -- 回合结束移除
            if buff.turns <= 0 then
                Player.removeBuff(id)
            end
        end
    end
    return died
end
return Player