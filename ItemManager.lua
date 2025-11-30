local ItemManager = {}
local json = require("dkjson")

-- 1. [核心优化] 全局纹理缓存池
-- 避免同一张图片被重复加载几百次
local textureCache = {}

-- 加载 JSON
local function loadJSON(path)
    local file = love.filesystem.read(path)
    assert(file, "无法读取文件: " .. path)
    return json.decode(file)
end

local raw = loadJSON("data/items.json")

ItemManager.definitions = {}
ItemManager.ids = {}

for sid, def in pairs(raw) do
    local id = tonumber(sid)
    if id then
        ItemManager.definitions[id] = def
        table.insert(ItemManager.ids, id)
    end
end
table.sort(ItemManager.ids)

-- 解析 onUse
local function parseOnUse(def)
    if not def.onUse or type(def.onUse) ~= "string" or def.onUse == "" then return nil end
    local action, valueStr = def.onUse:match("([^:]+):(.+)")
    if not action then action = def.onUse; valueStr = nil end
    local value = tonumber(valueStr) or valueStr
    
    return function(target)
        if not target then return false end
        local func = target[action]
        if type(func) == "function" then
            func(value) 
            return true
        else
            print(string.format("Error: Target missing method '%s'", tostring(action)))
            return false
        end
    end
end

function ItemManager.get(id)
    local def = ItemManager.definitions[id]
    if def and type(def.onUse) == "string" then
        def.onUse = parseOnUse(def)
    end
    return def
end

function ItemManager.getAllIds() return ItemManager.ids end

-- 获取物品类别
function ItemManager.getCategory(id)
    local def = ItemManager.get(id)
    return (def and def.category) or "material"
end

-- 使用物品
function ItemManager.use(id, player)
    local def = ItemManager.get(id)
    if not def then return false, "物品不存在" end
    if type(def.onUse) == "function" then
        def.onUse(player)
        return true
    else
        return false, "不可使用"
    end
end

-- [核心优化] 获取图标
function ItemManager.getIcon(id)
    local def = ItemManager.get(id)
    if not def then return nil end

    -- 1. 如果已经缓存了 Quad 或 Image，直接返回 (极速路径)
    if def._cachedIcon then
        return def._cachedIcon.img, def._cachedIcon.quad, def._cachedIcon.scale
    end

    -- 2. 确定图片路径
    local path = def.iconSheet or def.icon
    if not path then return nil end

    -- 3. [关键] 从全局缓存池获取图片，如果没有才加载
    if not textureCache[path] then
        print("[ItemManager] Loading texture: " .. path)
        textureCache[path] = love.graphics.newImage(path)
    end
    local img = textureCache[path]

    -- 4. 计算 Quad
    local quad = nil
    local scale = 1
    local ICON_TARGET_SIZE = 64 -- 目标显示大小

    if def.iconSheet and def.iconIndex ~= nil then
        -- 假设 Spritesheet 是 32x32 的网格 (RPG Maker 标准)
        -- 你可以根据实际情况调整这个值，或者在 items.json 里配置 "gridSize": 32
        local CELL_SIZE = 64
        
        local sheetW, sheetH = img:getDimensions()
        local cols = math.floor(sheetW / CELL_SIZE)
        
        -- iconIndex 通常是 0-based (如果json里是 1905 这种 RPGMaker 索引)
        -- 你的 items.json 似乎是直接用索引的
        local index = def.iconIndex 
        
        local row = math.floor(index / cols)
        local col = index % cols
        
        quad = love.graphics.newQuad(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE, sheetW, sheetH)
        
        -- 计算缩放比，使其接近 64px
        scale = ICON_TARGET_SIZE / CELL_SIZE
    else
        -- 单图
        scale = ICON_TARGET_SIZE / img:getWidth()
    end

    -- 5. 缓存结果到 def，下次直接用
    def._cachedIcon = {
        img = img,
        quad = quad,
        scale = scale
    }

    return img, quad, scale
end

-- [优化] 预加载所有资源
function ItemManager.preloadAll()
    print("[ItemManager] Optimizing Preload...")
    local start = love.timer.getTime()
    local count = 0
    
    -- 由于我们加了 textureCache，这里的循环现在非常快
    -- 它实际上只是在计算 Quad 数学坐标，不涉及 IO
    for _, id in ipairs(ItemManager.ids) do
        local img = ItemManager.getIcon(id)
        if img then count = count + 1 end
    end
    
    print(string.format("[ItemManager] Preload finished. Cached %d items in %.4fs", count, love.timer.getTime() - start))
end

return ItemManager