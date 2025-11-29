-- ItemManager.lua
local ItemManager = {}
local json = require("dkjson")

-- 加载 JSON 文件
local function loadJSON(path)
    local file = love.filesystem.read(path)
    assert(file, "无法读取文件: " .. path)
    return json.decode(file)
end

-- 读取原始 JSON（键为字符串）
local raw = loadJSON("data/items.json")

-- 统一：内部使用“数字 id 键”的 definitions，并维护一个“有序 ids 数组”
ItemManager.definitions = {}    -- [number] = def
ItemManager.ids = {}            -- { number, ... }

for sid, def in pairs(raw) do
    local id = tonumber(sid)
    if id then
        ItemManager.definitions[id] = def
        table.insert(ItemManager.ids, id)
    end
end
table.sort(ItemManager.ids)      -- 保证顺序稳定

-- 将 JSON 中的 onUse 转换为动态函数
local function parseOnUse(def)
    if not def.onUse or type(def.onUse) ~= "string" then return nil end
    if def.onUse == "" then return nil end -- 防止空字符串报错

    -- 1. 解析字符串 "Action:Value" 或 "Action"
    local action, valueStr = def.onUse:match("([^:]+):(.+)")
    if not action then
        action = def.onUse
        valueStr = nil
    end

    -- 2. 尝试转数字
    local value = tonumber(valueStr)
    if value == nil then value = valueStr end

    -- 3. 返回闭包
    -- 现在的逻辑非常简单：target[action](value)
    return function(target)
        if not target then 
            print("Error: Item used on nil target")
            return false 
        end

        local func = target[action]
        if type(func) == "function" then
            -- 直接调用函数，传入数值参数
            -- 例如: Player.addHP(50) 或 battleProxy.dealDamage(50)
            func(value) 
            return true
        else
            print(string.format("Error: Target missing method '%s'", tostring(action)))
            return false
        end
    end
end
function ItemManager.get(id)
    -- 统一用数字键
    local def = ItemManager.definitions[id]
    if def and type(def.onUse) == "string" then
        def.onUse = parseOnUse(def)
    end
    return def
end

function ItemManager.getAllIds()
    return ItemManager.ids
end

-- 统一图标获取：单文件或 sprite sheet
function ItemManager.getIcon(id)
    local def = ItemManager.get(id)
    if not def then return nil end

    local ICON = 64

    -- 单独文件
    if def.icon then
        def._image = def._image or love.graphics.newImage(def.icon)
        local iw, ih = def._image:getWidth(), def._image:getHeight()
        local scale = math.min(ICON / iw, ICON / ih)
        return def._image, nil, scale
    end

    -- sprite sheet（约定 iconIndex 为从 0 开始；如你实际为 1 开始，请把下面的 -1 去掉）
    if def.iconSheet and def.iconIndex ~= nil then
        def._sheet = def._sheet or love.graphics.newImage(def.iconSheet)
        local sheetW, sheetH = def._sheet:getWidth(), def._sheet:getHeight()
        local cols = math.floor(sheetW / ICON)

        -- 如果你的数据是 1-based，改为：
        local index = def.iconIndex - 1
        -- local index = def.iconIndex

        local row = math.floor(index / cols)
        local col = index % cols
        def._quad = def._quad or love.graphics.newQuad(
            col * ICON, row * ICON,
            ICON, ICON,
            sheetW, sheetH
        )
        return def._sheet, def._quad, 1
    end

    return nil
end

-- 获取物品类别
function ItemManager.getCategory(id)
    local def = ItemManager.get(id)
    if not def then
        return "material" -- 默认类别
    end
    return def.category or "material" -- 默认类别
end

function ItemManager.use(id, player)
    local def = ItemManager.get(id)
    if not def then
        return false, "物品不存在: " .. tostring(id)
    end

    if type(def.onUse) == "function" then
        def.onUse(player)
        return true
    else
        return false, "物品不可使用: " .. tostring(id)
    end
end

function ItemManager.preloadAll()
    print("[ItemManager] 开始预加载资源...")
    local startTime = love.timer.getTime()
    local count = 0
    
    -- 遍历所有已知的 ID
    for _, id in ipairs(ItemManager.ids) do
        -- 调用 getIcon 会强制触发内部的图片加载和缓存逻辑
        local img = ItemManager.getIcon(id)
        if img then count = count + 1 end
    end
    
    local delta = love.timer.getTime() - startTime
    print(string.format("[ItemManager] 预加载完成，耗时 %.3fs，缓存了 %d 个图标", delta, count))
end

return ItemManager
