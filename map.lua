local Map = {}
-- 动态引用 Debug，防止循环依赖
local Debug = nil 

-- 配置
Map.chunkSize = 64
Map.tileSize = 32

-- 1. 加载图片 (确保路径正确)
Map.textures = {
    water   = love.graphics.newImage("assets/water.png"),
    shore   = love.graphics.newImage("assets/shore.png"),
    sand    = love.graphics.newImage("assets/sand.png"),
    rock    = love.graphics.newImage("assets/rock.png"),
    grass   = love.graphics.newImage("assets/grass.png"),
    flower  = love.graphics.newImage("assets/flower.png"),
    tree    = love.graphics.newImage("assets/tree.png"),
}

-- 2. 定义渲染层级顺序 (先画地，再画树)
Map.layerOrder = {
    "water",
    "shore",
    "sand",
    "rock",
    "grass",   -- 地面
    "flower",
    "tree"     -- 遮挡物
}

-- 3. 初始化 SpriteBatch
Map.spriteBatches = {}
for name, tex in pairs(Map.textures) do
    -- 容量设为 20000 足够同屏绘制
    Map.spriteBatches[name] = love.graphics.newSpriteBatch(tex, 20000, "dynamic")
end

-- [关键修复 1] 初始化修改数据表
-- key="x,y", value="tileType"
Map.data = {}

-- 缓存
Map.chunks = {}
Map.colliders = {}

-- 群系判定 (生成逻辑)
function Map.getBiome(x, y)
    local b = love.math.noise(x * 0.02, y * 0.02)
    if b < 0.25 then return "lake"
    elseif b < 0.5 then return "desert"
    elseif b < 0.75 then return "grassland"
    else return "forest" end
end

-- 获取地形 (核心逻辑：优先读修改，其次读生成)
function Map.getTile(gx, gy)
    local key = gx .. "," .. gy
    
    -- [关键修复 2] 优先检查是否有被砍掉的记录
    if Map.data[key] then
        return Map.data[key]
    end

    -- 生成逻辑
    local biome = Map.getBiome(gx, gy)
    local n = love.math.noise(gx * 0.1, gy * 0.1)

    if biome == "lake" then
        return (n < 0.7) and "water" or "shore"
    elseif biome == "desert" then
        return (n < 0.6) and "sand" or "rock"
    elseif biome == "grassland" then
        if n > 0.8 then return "flower" else return "grass" end
    elseif biome == "forest" then
        if n < 0.5 then return "tree" else return "grass" end
    end
    
    return "grass" -- 兜底
end

-- 修改地块 (砍树时调用)
function Map.setTile(tx, ty, typeName)
    local key = tx .. "," .. ty
    Map.data[key] = typeName
    
    -- [关键修复 3] 清除对应的 Chunk 缓存，强制下次重绘时更新
    -- 计算所在的 chunk 坐标
    local cx = math.floor(tx / Map.chunkSize)
    local cy = math.floor(ty / Map.chunkSize)
    local chunkKey = cx .. "," .. cy
    Map.chunks[chunkKey] = nil
    
    -- 同时也需要更新碰撞缓存 (如果树被砍了，碰撞也没了)
    if typeName ~= "tree" and typeName ~= "rock" and typeName ~= "water" then
         Map.colliders[key] = nil
    end
end

-- 生成 Chunk
function Map.generateChunk(cx, cy)
    local key = cx .. "," .. cy
    if Map.chunks[key] then return Map.chunks[key] end

    local chunk = {}
    for j = 0, Map.chunkSize-1 do
        chunk[j] = {}
        for i = 0, Map.chunkSize-1 do
            local gx = cx * Map.chunkSize + i
            local gy = cy * Map.chunkSize + j
            
            -- [关键] 这里调用的 getTile 会自动识别被砍过的树
            local tile = Map.getTile(gx, gy)
            chunk[j][i] = tile

            -- 更新碰撞盒缓存
            -- 注意：只添加阻挡物
            if tile == "tree" or tile == "rock" or tile == "water" then
                -- 简单的碰撞判定逻辑
                Map.colliders[gx .. "," .. gy] = true
            end
        end
    end
    Map.chunks[key] = chunk
    return chunk
end

-- 绘制地图
function Map.draw(Game, camX, camY)
    if not Debug then Debug = require("debug_utils") end
    
    local w, h = love.graphics.getDimensions()
    local tileSize = Game.tileSize or Map.tileSize
    
    -- 计算屏幕内可见的格子范围
    local startX = math.floor(camX / tileSize) - 1
    local startY = math.floor(camY / tileSize) - 1
    local tilesX = math.ceil(w / tileSize) + 2
    local tilesY = math.ceil(h / tileSize) + 2

    -- 清空 Batch
    for _, batch in pairs(Map.spriteBatches) do
        batch:clear()
    end

    -- 填充 Batch (只遍历屏幕范围内的格子)
    for j = 0, tilesY do
        for i = 0, tilesX do
            local gx = startX + i
            local gy = startY + j

            -- [优化] 动态获取 Tile，而不是依赖 Chunk 缓存
            -- 因为我们只画屏幕内的，所以即使每次算 noise 也很快
            -- 而且这样能保证 setTile 的修改是瞬时可见的
            local tile = Map.getTile(gx, gy)
            
            if tile then
                local drawX = math.floor(gx * tileSize - camX)
                local drawY = math.floor(gy * tileSize - camY)

                -- 1. 如果是树或花，先画底下的草，防止穿帮
                if tile == "tree" or tile == "flower" then
                    local grassTex = Map.textures["grass"]
                    local scaleX = tileSize / grassTex:getWidth()
                    local scaleY = tileSize / grassTex:getHeight()
                    Map.spriteBatches["grass"]:add(drawX, drawY, 0, scaleX, scaleY)
                end

                -- 2. 添加到对应层的 batch
                local tex = Map.textures[tile]
                if tex then
                    local scaleX = tileSize / tex:getWidth()
                    local scaleY = tileSize / tex:getHeight()
                    -- 安全检查，防止 Batch 满了报错
                    pcall(function() 
                        Map.spriteBatches[tile]:add(drawX, drawY, 0, scaleX, scaleY) 
                    end)
                end
            end
        end
    end

    -- 提交绘制
    love.graphics.setColor(1, 1, 1, 1)
    for _, layerName in ipairs(Map.layerOrder) do
        if Map.spriteBatches[layerName] then
            love.graphics.draw(Map.spriteBatches[layerName])
        end
    end
end

return Map