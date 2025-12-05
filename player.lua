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
    -- 确保 deathCount 存在
    if not Player.data.deathCount then Player.data.deathCount = 0 end
end

function Player.save()
    Config.updatePlayer(Player.data)
end

function Player.load()
    Config.load()
    local saveData = Config.get()
    Player.data = saveData.player or {}
    initDefaults()
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

return Player