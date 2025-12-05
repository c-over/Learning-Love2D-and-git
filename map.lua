local Map = {}
local Debug = nil 

Map.chunkSize = 64
Map.tileSize = 32
Map.seedX = 0
Map.seedY = 0

local tilesetImage = love.graphics.newImage("assets/tiles.png")
tilesetImage:setFilter("nearest", "nearest")

-- === 1. 瓦片定义 (请使用 TileSelector 仔细核对坐标) ===
local T = {
    -- 基础地面
    water = { x=3, y=1 },   -- 纯水面
    
    -- 装饰物
    tree  = { x=13, y=9 },   -- 树
    rock  = { x=56, y=21 },   -- 石头
    flower= { x=30, y=9 },   -- 花
    
    -- 道路 (假设是中心路)
    road  = { x=9, y=1 },  
    
    -- ===  沙地九宫格 ===
    sand_C  = { x=8, y=22 }, -- 中间 (全满)
    sand_N  = { x=8, y=21 }, -- 上边
    sand_S  = { x=8, y=23 }, -- 下边
    sand_W  = { x=7, y=22 }, -- 左边
    sand_E  = { x=9, y=22 }, -- 右边
    sand_TL = { x=7, y=21 }, -- 左上角 (扇形)
    sand_TR = { x=9, y=21 }, -- 右上角
    sand_BL = { x=7, y=23 }, -- 左下角
    sand_BR = { x=9, y=23 }, -- 右下角

    -- ===  草地九宫格 ===
    grass_C  = { x=3, y=16 },
    grass_N  = { x=3, y=15 }, 
    grass_S  = { x=3, y=17 }, 
    grass_W  = { x=2, y=16 }, 
    grass_E  = { x=4, y=16 }, 
    grass_TL = { x=2, y=15 }, 
    grass_TR = { x=4, y=15 }, 
    grass_BL = { x=2, y=17 }, 
    grass_BR = { x=4, y=17 }, 
    -- 桥梁 (Bridge)
    -- 垂直桥 (Vertical)
    bridge_V_L = { x=10, y=20 }, -- 左护栏 (阻挡)
    bridge_V_M = { x=11, y=20 }, -- 中间路面 (可行走)
    bridge_V_R = { x=12, y=20 }, -- 右护栏 (阻挡)
    
    -- 水平桥 (Horizontal)
    bridge_H_T = { x=11, y=19 }, -- 上护栏 (阻挡)
    bridge_H_M = { x=11, y=20 }, -- 中间路面 (可行走)
    bridge_H_B = { x=11, y=21 }, -- 下护栏 (阻挡)
    bridge_center = { x=11, y=20 }, -- 十字路口
}

-- === 2. 生成 Quads ===
Map.quads = {}
local iw, ih = tilesetImage:getDimensions()

local function getQuad(def)
    if not def then return nil end
    local padding = 1 
    local x = def.x * (Map.sourceSize + padding)
    local y = def.y * (Map.sourceSize + padding)
    return love.graphics.newQuad(x, y, Map.sourceSize, Map.sourceSize, iw, ih)
end

Map.sourceSize = 16 
for name, def in pairs(T) do
    Map.quads[name] = getQuad(def)
end

Map.layerOrder = { "water", "sand", "grass", "road", "flower", "rock", "tree" }
Map.drawScale = Map.tileSize / Map.sourceSize
Map.data = {}

-- === 碰撞逻辑 ===
function Map.isSolid(tile)
    local box = Map.getTileCollision(tile, 0, 0)
    return box ~= nil
end
-- === 地形生成 ===
-- 辅助：判断是否为任意陆地 (沙、草、树、石、路都算)
local function isAnyLand(tile)
    return tile and tile ~= "water"
end

-- [修改] 宽松版桥梁检测
-- 逻辑：
-- 1. 向两端发射射线。
-- 2. 只要碰到非水方块（沙子、草地、树木等），就视为岸边。
-- 3. 为了防止连到水面上 1x1 的噪点孤岛，我们只多检查一格：岸边后面必须还是陆地。
local function checkBridgeLine(gx, gy, bridgeType, offset)
    local maxLen = 60  -- 增加最大搜索长度，增加生成几率
    local minLen = 6   -- 最小桥长
    
    -- 当前点必须是水
    if getRawBiome(gx, gy) ~= "water" then return nil end

    -- 确定路面中心线 (忽略护栏偏移)
    local centerX = (bridgeType == "V") and (gx - offset) or gx
    local centerY = (bridgeType == "H") and (gy - offset) or gy

    -- === 1. 向负方向扫描 (上/左) ===
    local negDist = 0
    local foundStart = false
    
    for i = 1, maxLen do
        local tx, ty
        if bridgeType == "V" then ty = gy - i; tx = centerX
        else tx = gx - i; ty = centerY end
        
        local tile = getRawBiome(tx, ty)
        
        -- 遇到陆地 (不再局限于沙子，草地也可以连)
        if isAnyLand(tile) then
            -- [防悬空逻辑] 唯一的限制：再往里探一格，不能是水
            -- 这样可以过滤掉 1 格宽的微型孤岛，但允许不平整的岸边
            local backX, backY
            if bridgeType == "V" then backX, backY = tx, ty - 1
            else backX, backY = tx - 1, ty end
            
            if isAnyLand(getRawBiome(backX, backY)) then
                foundStart = true
                negDist = i
                break
            else
                return nil -- 连到了孤岛/薄片，放弃这座桥
            end
        end
    end
    
    if not foundStart then return nil end

    -- === 2. 向正方向扫描 (下/右) ===
    local posDist = 0
    local foundEnd = false
    
    for i = 1, maxLen do
        local tx, ty
        if bridgeType == "V" then ty = gy + i; tx = centerX
        else tx = gx + i; ty = centerY end
        
        local tile = getRawBiome(tx, ty)
        
        if isAnyLand(tile) then
            -- 同样的防孤岛检查
            local backX, backY
            if bridgeType == "V" then backX, backY = tx, ty + 1
            else backX, backY = tx + 1, ty end
            
            if isAnyLand(getRawBiome(backX, backY)) then
                foundEnd = true
                posDist = i
                break
            else
                return nil
            end
        end
    end

    if not foundEnd then return nil end

    -- === 3. 生成判定 ===
    local totalLen = negDist + posDist - 1
    if totalLen >= minLen then
        if bridgeType == "V" then
            if offset == -1 then return "bridge_V_L" end
            if offset == 0  then return "bridge_V_M" end
            if offset == 1  then return "bridge_V_R" end
        else
            if offset == -1 then return "bridge_H_T" end
            if offset == 0  then return "bridge_H_M" end
            if offset == 1  then return "bridge_H_B" end
        end
    end
    return nil
end
-- 获取原始地貌 (不包含桥梁)
function getRawBiome(gx, gy)
    local nx = gx + Map.seedX
    local ny = gy + Map.seedY

    local biomeNoise = love.math.noise(nx * 0.015, ny * 0.015)
    
    -- 水
    if biomeNoise < 0.45 then return "water" end

    -- 沙滩 / 草地海岸
    local detailNoise = love.math.noise(nx * 0.1, ny * 0.1)
    if biomeNoise < 0.52 then
        if detailNoise < 0.5 then return "sand" else return "grass" end
    end

    -- 内陆资源
    if detailNoise < 0.3 then return "tree" 
    elseif detailNoise > 0.45 and detailNoise < 0.47 then return "rock" 
    end

    -- 原始道路
    local roadNoise = love.math.noise(nx * 0.03, ny * 0.03)
    if math.abs(roadNoise - 0.5) < 0.015 then return "road" end

    -- 默认
    if detailNoise > 0.75 then return "flower" else return "grass" end
end

function Map.getTile(gx, gy)
    local key = gx .. "," .. gy
    if Map.data[key] then return Map.data[key] end

    local density = 15
    
    -- 1. 获取垂直桥的可能结果
    local tileV = nil
    local modX = gx % density
    if modX == density - 1 then modX = -1 end
    if modX >= -1 and modX <= 1 then
        tileV = checkBridgeLine(gx, gy, "V", modX)
    end

    -- 2. 获取水平桥的可能结果
    local tileH = nil
    local modY = gy % density
    if modY == density - 1 then modY = -1 end
    if modY >= -1 and modY <= 1 then
        tileH = checkBridgeLine(gx, gy, "H", modY)
    end

    -- 3. [核心] 交叉逻辑处理
    if tileV and tileH then
        -- 两个桥重叠了！
        -- 如果任何一方是路面(M)，那么这里就是路口，应该完全通行
        -- 比如 V_M 和 H_L 重叠，应该显示路面，去掉护栏
        if tileV == "bridge_V_M" or tileH == "bridge_H_M" then
            return "bridge_center" -- 无护栏的全通地板
        end
        
        -- 如果是护栏撞护栏 (角落)，为了防止死角，也变成路面，或者保留一种
        -- 简单起见，十字路口的 3x3 区域全部变成地板
        return "bridge_center"
    elseif tileV then
        return tileV
    elseif tileH then
        return tileH
    end

    return getRawBiome(gx, gy)
end

function Map.getTileCollision(tile, gx, gy)
    if not tile then return nil end
    
    if tile == "tree" or tile == "rock" or tile == "water" then
        return {x=0, y=0, w=32, h=32}
    end
    
    -- [新增] 桥梁中心/十字路口：完全通行，无阻挡
    if tile == "bridge_center" then return nil end
    
    -- 垂直桥
    if tile == "bridge_V_L" then return {x=0, y=0, w=16, h=32} end
    if tile == "bridge_V_R" then return {x=16, y=0, w=16, h=32} end
    
    -- 水平桥
    if tile == "bridge_H_T" then return {x=0, y=0, w=32, h=16} end
    if tile == "bridge_H_B" then return {x=0, y=16, w=32, h=16} end
    
    return nil
end
function Map.setTile(tx, ty, typeName)
    local key = tx .. "," .. ty
    Map.data[key] = typeName
end

-- 辅助：判断某格是不是水
local function isWater(tile)
    return tile == "water" or tile == nil -- nil(虚空)也当水处理
end

-- === [核心] 绘制函数 ===
function Map.draw(Game, camX, camY)
    if not Debug then Debug = require("debug_utils") end
    
    local w, h = love.graphics.getDimensions()
    local tileSize = Map.tileSize
    
    local startX = math.floor(camX / tileSize) - 1
    local startY = math.floor(camY / tileSize) - 1
    local tilesX = math.ceil(w / tileSize) + 2
    local tilesY = math.ceil(h / tileSize) + 2

    if not Map.mainBatch then
        Map.mainBatch = love.graphics.newSpriteBatch(tilesetImage, 20000, "dynamic")
    end
    Map.mainBatch:clear()

    for j = 0, tilesY do
        for i = 0, tilesX do
            local gx = startX + i
            local gy = startY + j
            
            local tile = Map.getTile(gx, gy)
            
            -- 计算绘制坐标
            local drawX = math.floor(gx * tileSize - camX)
            local drawY = math.floor(gy * tileSize - camY)

            local function add(quadName)
                if Map.quads[quadName] then
                    -- 9-Slice 通常不需要旋转，直接缩放绘制
                    Map.mainBatch:add(Map.quads[quadName], drawX, drawY, 0, Map.drawScale, Map.drawScale)
                end
            end

            -- === 1. 水面总是画 (作为基底) ===
            -- 如果当前格是水，或者是边界的陆地（因为边界陆地是透明的，需要透出水），都先画水
            local needsWaterBase = false
            if tile == "water" then
                needsWaterBase = true
            elseif tile == "sand" or tile == "grass" then
                -- 检查四周是否有水，如果有，说明这是边缘，需要画水底
                local nN = isWater(Map.getTile(gx, gy-1))
                local nS = isWater(Map.getTile(gx, gy+1))
                local nW = isWater(Map.getTile(gx-1, gy))
                local nE = isWater(Map.getTile(gx+1, gy))
                if nN or nS or nW or nE then
                    needsWaterBase = true
                end
            end

            if needsWaterBase then
                add("water")
            end

            -- === 2. 陆地九宫格绘制 ===
            if tile == "sand" or tile == "grass" then
                local prefix = tile -- "sand" 或 "grass"
                
                -- 获取四周是否为水
                local wN = isWater(Map.getTile(gx, gy-1))
                local wS = isWater(Map.getTile(gx, gy+1))
                local wW = isWater(Map.getTile(gx-1, gy))
                local wE = isWater(Map.getTile(gx+1, gy))

                -- [核心] 自动图块逻辑 (Auto-tiling Logic)
                -- 优先级：角落 > 边缘 > 中心
                
                -- 角落 (两个相邻方向都是水)
                if wN and wW then
                    add(prefix .. "_TL") -- 左上圆角
                elseif wN and wE then
                    add(prefix .. "_TR") -- 右上圆角
                elseif wS and wW then
                    add(prefix .. "_BL") -- 左下圆角
                elseif wS and wE then
                    add(prefix .. "_BR") -- 右下圆角
                
                -- 边缘 (只有一个方向是水)
                elseif wN then add(prefix .. "_N")
                elseif wS then add(prefix .. "_S")
                elseif wW then add(prefix .. "_W")
                elseif wE then add(prefix .. "_E")
                
                -- 中心 (周围都不是水)
                else
                    add(prefix .. "_C")
                end
            end

            -- === 3. 其他物体 (树、石、花、路) ===
            if tile ~= "water" and tile ~= "sand" and tile ~= "grass" then
                -- 物体底下先铺草
                if tile ~= "road" then 
                    add("grass_C") 
                else
                    -- 路底下铺草
                    add("grass_C")
                end
                add(tile)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Map.mainBatch)
end

return Map