local MagicManager = {}
local json = require("dkjson")
local Player = require("player")

-- 缓存
local definitions = {}
local sortedIds = {}
local textureCache = {}

-- 1. 加载数据
local function loadJSON()
    local content = love.filesystem.read("data/magic.json")
    local data = json.decode(content)
    for k, v in pairs(data) do
        local id = tonumber(k)
        definitions[id] = v
        table.insert(sortedIds, id)
    end
    table.sort(sortedIds)
end
loadJSON()

-- 2. 获取图标 (逻辑复用 ItemManager 的思路)
function MagicManager.getIcon(id)
    local def = definitions[id]
    if not def then return nil end
    if def._cachedIcon then return def._cachedIcon.img, def._cachedIcon.quad end

    local path = def.iconSheet or "assets/icon.png"
    if not textureCache[path] then textureCache[path] = love.graphics.newImage(path) end
    local img = textureCache[path]

    local quad = nil
    if def.iconIndex then
        local GRID = 64 -- 魔法图标大小
        local cols = math.floor(img:getWidth() / GRID)
        local r = math.floor(def.iconIndex / cols)
        local c = def.iconIndex % cols
        quad = love.graphics.newQuad(c*GRID, r*GRID, GRID, GRID, img:getDimensions())
    end

    def._cachedIcon = {img=img, quad=quad}
    return img, quad
end

-- 3. 获取玩家当前解锁的所有魔法
function MagicManager.getPlayerSpells()
    local list = {}
    local pLevel = Player.data.level or 1
    for _, id in ipairs(sortedIds) do
        local def = definitions[id]
        if pLevel >= def.level then
            -- 注入ID方便索引
            local spell = {id=id}
            setmetatable(spell, {__index=def})
            table.insert(list, spell)
        end
    end
    return list
end

-- 4. 释放魔法 (处理扣蓝和效果)
-- target: 目标对象 (菜单里通常是 Player)
function MagicManager.cast(spellId, target)
    local def = definitions[spellId]
    if not def then return false, "魔法不存在" end
    
    -- 检查 MP
    if Player.data.mp < def.mp then return false, "法力不足" end
    
    -- 执行效果
    if def.type == "heal" then
        if target.hp >= target.maxHp then return false, "生命值已满" end
        target.hp = math.min(target.hp + def.power, target.maxHp)
        Player.data.mp = Player.data.mp - def.mp -- 扣蓝
        return true, "恢复了 " .. def.power .. " 点生命"
        
    elseif def.type == "damage" then
        -- 战斗外不能放伤害技能
        return false, "只能在战斗中使用"
        
    elseif def.type == "buff" then
        -- 这里写 Buff 逻辑
        Player.data.mp = Player.data.mp - def.mp
        return true, "释放了 " .. def.name
    end
    
    return false, "未知效果"
end

return MagicManager