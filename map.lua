-- Map.lua
local Map = {}

local Debug = require("debug_utils")

-- 配置
Map.chunkSize = 64

-- 1. 加载图片
Map.textures = {
    water   = love.graphics.newImage("assets/water.png"),
    shore   = love.graphics.newImage("assets/shore.png"),
    sand    = love.graphics.newImage("assets/sand.png"),
    rock    = love.graphics.newImage("assets/rock.png"),
    grass   = love.graphics.newImage("assets/grass.png"),
    flower  = love.graphics.newImage("assets/flower.png"),
    tree    = love.graphics.newImage("assets/tree.png"),
}

-- 2. 定义渲染层级顺序 (关键修复：解决树木被草覆盖的问题)
Map.layerOrder = {
    "water",
    "shore",
    "sand",
    "rock",
    "grass",   -- 草在树下面
    "flower",
    "tree"     -- 树在最上面
}

-- 3. 初始化 SpriteBatch
Map.spriteBatches = {}
for name, tex in pairs(Map.textures) do
    -- 关键修复：增加容量上限到 20000，防止同屏物体过多导致后面的画不出来
    Map.spriteBatches[name] = love.graphics.newSpriteBatch(tex, 20000, "dynamic")
end

-- 缓存
Map.chunks = {}
Map.colliders = {}

-- 群系判定
function Map.getBiome(x, y)
    local b = love.math.noise(x * 0.02, y * 0.02)
    if b < 0.25 then return "lake"
    elseif b < 0.5 then return "desert"
    elseif b < 0.75 then return "grassland"
    else return "forest" end
end

-- 地形判定
function Map.getTile(x, y)
    local biome = Map.getBiome(x, y)
    local n = love.math.noise(x * 0.1, y * 0.1)

    if biome == "lake" then
        return (n < 0.7) and "water" or "shore"
    elseif biome == "desert" then
        return (n < 0.6) and "sand" or "rock"
    elseif biome == "grassland" then
        if n > 0.8 then return "flower" else return "grass" end
    elseif biome == "forest" then
        if n < 0.5 then return "tree" else return "grass" end
    end
end

-- 生成 Chunk
function Map.generateChunk(cx, cy, Game)
    local key = cx .. "," .. cy
    if Map.chunks[key] then return Map.chunks[key] end

    local chunk = {}
    for j = 0, Map.chunkSize-1 do
        chunk[j] = {}
        for i = 0, Map.chunkSize-1 do
            local gx = cx * Map.chunkSize + i
            local gy = cy * Map.chunkSize + j
            local tile = Map.getTile(gx, gy)
            chunk[j][i] = tile

            -- 记录碰撞盒 (仅在首次生成时记录)
            if tile == "tree" then
                local tex = Map.textures["tree"]
                local scaleX = Game.tileSize / tex:getWidth()
                local scaleY = Game.tileSize / tex:getHeight()
                local w = tex:getWidth() * scaleX
                local h = tex:getHeight() * scaleY
                local x = gx * Game.tileSize
                local y = gy * Game.tileSize
                
                -- 使用坐标作为key，避免重复添加
                Map.colliders[gx .. "," .. gy] = {x=x, y=y, w=w, h=h}
            end
        end
    end
    Map.chunks[key] = chunk
    return chunk
end

-- 绘制地图
function Map.draw(Game, camX, camY)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- 多渲染一圈，防止边缘闪烁
    local tilesX = math.ceil(w / Game.tileSize) + 1
    local tilesY = math.ceil(h / Game.tileSize) + 1

    local startX = math.floor(camX / Game.tileSize)
    local startY = math.floor(camY / Game.tileSize)

    -- 清空 Batch
    for _, batch in pairs(Map.spriteBatches) do
        batch:clear()
    end

    -- 填充 Batch
    for j = -1, tilesY do -- 从 -1 开始，防止上方边缘裁切
        for i = -1, tilesX do -- 从 -1 开始，防止左侧边缘裁切
            local gx = startX + i
            local gy = startY + j

            local cx = math.floor(gx / Map.chunkSize)
            local cy = math.floor(gy / Map.chunkSize)
            local chunk = Map.generateChunk(cx, cy, Game)

            -- 修正负数取模的问题 (Lua的 % 已经是正确处理负数的，但为了保险起见对应chunk逻辑)
            local tx = gx % Map.chunkSize
            local ty = gy % Map.chunkSize
            
            -- 安全检查：防止 chunk 生成逻辑出错导致索引越界
            if chunk and chunk[ty] and chunk[ty][tx] then
                local tile = chunk[ty][tx]

                -- 坐标取整，防止像素画在移动时出现裂缝或抖动
                local drawX = math.floor(gx * Game.tileSize - camX)
                local drawY = math.floor(gy * Game.tileSize - camY)

                -- 逻辑：如果是树或花，先在 "grass" 层画底图
                if tile == "tree" or tile == "flower" then
                    local grassTex = Map.textures["grass"]
                    local scaleX = Game.tileSize / grassTex:getWidth()
                    local scaleY = Game.tileSize / grassTex:getHeight()
                    Map.spriteBatches["grass"]:add(drawX, drawY, 0, scaleX, scaleY)
                end

                -- 添加当前 tile 到对应层的 batch
                local tex = Map.textures[tile]
                if tex then
                    local scaleX = Game.tileSize / tex:getWidth()
                    local scaleY = Game.tileSize / tex:getHeight()
                    Map.spriteBatches[tile]:add(drawX, drawY, 0, scaleX, scaleY)
                end
            end
        end
    end

    -- 绘制 Batches (关键修复：按照固定顺序绘制)
    love.graphics.setColor(1, 1, 1, 1)
    for _, layerName in ipairs(Map.layerOrder) do
        if Map.spriteBatches[layerName] then
            love.graphics.draw(Map.spriteBatches[layerName])
        end
    end

    -- Debug 绘制优化
    if debugMode then
        local debugEntities = {}
        -- 优化：只遍历当前屏幕附近的碰撞箱，而不是全图遍历
        -- 这里使用简单的范围估算，实际项目中可用空间哈希优化
        local checkRange = 2 -- 检查视野外几格
        for j = -checkRange, tilesY + checkRange do
            for i = -checkRange, tilesX + checkRange do
                local gx = startX + i
                local gy = startY + j
                local key = gx .. "," .. gy
                local c = Map.colliders[key]
                if c then
                    table.insert(debugEntities, {
                        x = c.x + c.w / 2,
                        y = c.y + c.h / 2,
                        w = c.w,
                        h = c.h
                    })
                end
            end
        end

        if #debugEntities > 0 then
            -- 确保 debug 库已加载
            if Debug and Debug.drawHitboxes then
                Debug.drawHitboxes(debugEntities, camX, camY, 0, 1, 0)
            end
        end
    end
end

return Map