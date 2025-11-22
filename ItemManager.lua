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

-- 将 JSON 中的 onUse 转换为函数（懒转换，首次取用时执行一次）
local function parseOnUse(def)
    if not def.onUse or type(def.onUse) ~= "string" then return nil end
    local action, value = def.onUse:match("([^:]+):(%d+)")
    value = tonumber(value)
    if action == "addLevel" then
        return function(player) player.addLevel(value) end
    elseif action == "addHP" then
        return function(player) player.addHP(value) end
    end
    return nil
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

return ItemManager
