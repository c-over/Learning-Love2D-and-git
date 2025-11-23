-- Map.lua
local Map = {}

local Debug = require("debug_utils")

-- 配置
Map.chunkSize = 64
Map.textures = {
    water   = love.graphics.newImage("assets/water.png"),
    shore   = love.graphics.newImage("assets/shore.png"),
    sand    = love.graphics.newImage("assets/sand.png"),
    rock    = love.graphics.newImage("assets/rock.png"),
    grass   = love.graphics.newImage("assets/grass.png"),
    flower  = love.graphics.newImage("assets/flower.png"),
    tree    = love.graphics.newImage("assets/tree.png"),
}

-- 为每种贴图准备一个 SpriteBatch
Map.spriteBatches = {}
for name, tex in pairs(Map.textures) do
    Map.spriteBatches[name] = love.graphics.newSpriteBatch(tex, 5000, "dynamic")
end

-- 缓存已生成的chunk
Map.chunks = {}
-- 树的碰撞盒
Map.colliders = {}

-- 群系判定
function Map.getBiome(x, y)
    local b = love.math.noise(x * 0.02, y * 0.02)
    if b < 0.25 then return "lake"
    elseif b < 0.5 then return "desert"
    elseif b < 0.75 then return "grassland"
    else return "forest" end
end

-- 主地形判定
function Map.getTile(x, y)
    local biome = Map.getBiome(x, y)
    local n = love.math.noise(x * 0.1, y * 0.1)

    if biome == "lake" then
        return (n < 0.7) and "water" or "shore"
    elseif biome == "desert" then
        return (n < 0.6) and "sand" or "rock"
    elseif biome == "grassland" then
        if n > 0.8 then
            return "flower"
        else
            return "grass"
        end
    elseif biome == "forest" then
        if n < 0.5 then
            return "tree"   -- 树作为主tile
        else
            return "grass"
        end
    end
end

-- 生成一个chunk
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

            -- 如果是树，记录碰撞盒
            if tile == "tree" then
                local tex = Map.textures["tree"]
                local scaleX = Game.tileSize / tex:getWidth()
                local scaleY = Game.tileSize / tex:getHeight()
                local w = tex:getWidth() * scaleX
                local h = tex:getHeight() * scaleY
                local x = gx * Game.tileSize
                local y = gy * Game.tileSize
                Map.colliders[gx .. "," .. gy] = {x=x, y=y, w=w, h=h}
            end
        end
    end
    Map.chunks[key] = chunk
    return chunk
end

-- 绘制地图（SpriteBatch）
function Map.draw(Game, camX, camY)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local tilesX = math.floor(w / Game.tileSize) + 2
    local tilesY = math.floor(h / Game.tileSize) + 2

    local startX = math.floor(camX / Game.tileSize)
    local startY = math.floor(camY / Game.tileSize)

    -- 清空所有 SpriteBatch
    for _, batch in pairs(Map.spriteBatches) do
        batch:clear()
    end

    for j = 0, tilesY do
        for i = 0, tilesX do
            local gx = startX + i
            local gy = startY + j

            local cx = math.floor(gx / Map.chunkSize)
            local cy = math.floor(gy / Map.chunkSize)
            local chunk = Map.generateChunk(cx, cy, Game)

            local tx = gx % Map.chunkSize
            local ty = gy % Map.chunkSize
            local tile = chunk[ty][tx]

            local drawX = gx * Game.tileSize - camX
            local drawY = gy * Game.tileSize - camY

            -- 如果是树或花，先画草背景
            if tile == "tree" or tile == "flower" then
                local grassTex = Map.textures["grass"]
                local scaleX = Game.tileSize / grassTex:getWidth()
                local scaleY = Game.tileSize / grassTex:getHeight()
                Map.spriteBatches["grass"]:add(drawX, drawY, 0, scaleX, scaleY)
            end

            -- 再画 tile 本身
            local tex = Map.textures[tile]
            if tex then
                local scaleX = Game.tileSize / tex:getWidth()
                local scaleY = Game.tileSize / tex:getHeight()
                Map.spriteBatches[tile]:add(drawX, drawY, 0, scaleX, scaleY)
            end
        end
    end

    for _, batch in pairs(Map.spriteBatches) do
        love.graphics.draw(batch)
    end
    -- 如果开启了 debugMode，绘制树的碰撞箱
    if debugMode then
        local debugEntities = {}
        for _, c in pairs(Map.colliders) do
            -- 转换为 Debug 期望的结构：中心坐标 + w/h
            table.insert(debugEntities, {
                x = c.x + c.w / 2,
                y = c.y + c.h / 2,
                w = c.w,
                h = c.h
            })
        end
        -- 只有在 debugEntities 非空时才调用
        if #debugEntities > 0 then
            Debug.drawHitboxes(debugEntities, camX, camY, 0, 1, 0)
        end
    end
end


return Map
