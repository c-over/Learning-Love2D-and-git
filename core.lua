local Core = {}
-- 延迟引用 Map，防止循环依赖问题（虽然 Lua require 会缓存，但稳妥起见）
local Map 

-- 初始化引用
function Core.init()
    Map = require("map")
end

-- === 1. 基础物理与碰撞 ===

-- AABB 碰撞检测 (矩形重叠)
function Core.aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- 计算两点距离 (中心点)
function Core.getDistance(objA, objB)
    -- 兼容 obj.data 写法 (针对 Player)
    local a = objA.data or objA
    local b = objB.data or objB
    
    local acx = a.x + (a.w or 32)/2
    local acy = a.y + (a.h or 32)/2
    local bcx = b.x + (b.w or 32)/2
    local bcy = b.y + (b.h or 32)/2
    
    return math.sqrt((acx - bcx)^2 + (acy - bcy)^2)
end

-- 检查某个【格子】是否阻挡
function Core.isSolidTile(gx, gy)
    if not Map then Map = require("map") end
    local tile = Map.getTile(gx, gy)
    return Map.isSolid(tile)
end

-- 检查某个【像素坐标】是否安全 (即所在的格子不是墙)
function Core.isPositionSafe(x, y, w, h)
    local tileSize = 32
    
    -- 计算物体覆盖的格子范围 (扩大一圈检测，防止贴边穿透)
    local left   = math.floor(x / tileSize)
    local right  = math.floor((x + w - 0.1) / tileSize) -- -0.1 防止正好压线算进下一格
    local top    = math.floor(y / tileSize)
    local bottom = math.floor((y + h - 0.1) / tileSize)
    
    for gy = top, bottom do
        for gx = left, right do
            -- 获取该格子的地形类型
            local tile = Map.getTile(gx, gy)
            
            -- 获取该格子的精确碰撞盒
            local box = Map.getTileCollision(tile, gx, gy)
            
            if box then
                -- 将相对坐标转换为世界绝对坐标
                local wallX = gx * tileSize + box.x
                local wallY = gy * tileSize + box.y
                local wallW = box.w
                local wallH = box.h
                
                -- AABB 检测：玩家 vs 墙
                if Core.aabbOverlap(x, y, w, h, wallX, wallY, wallW, wallH) then
                    return false -- 发生碰撞，位置不安全
                end
            end
        end
    end
    return true
end

-- === 2. 玩家/怪物移动逻辑 ===

function Core.updatePlayerMovement(player, dt, tileSize)
    local vx, vy = 0, 0
    if love.keyboard.isDown("left")  or love.keyboard.isDown("a") then vx = vx - 1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then vx = vx + 1 end
    if love.keyboard.isDown("up")    or love.keyboard.isDown("w") then vy = vy - 1 end
    if love.keyboard.isDown("down")  or love.keyboard.isDown("s") then vy = vy + 1 end

    if vx ~= 0 or vy ~= 0 then
        local len = math.sqrt(vx*vx + vy*vy)
        vx, vy = vx/len, vy/len
    end

    player.vx, player.vy = vx, vy
    if vx > 0 then player.anim.dir = "right"
    elseif vx < 0 then player.anim.dir = "left"
    elseif vy > 0 then player.anim.dir = "down"
    elseif vy < 0 then player.anim.dir = "up" end

    local isMoving = (vx ~= 0 or vy ~= 0)
    local nextX = player.x + vx * player.speed * dt
    local nextY = player.y + vy * player.speed * dt

    -- 分轴碰撞检测 (X轴)
    if Core.isPositionSafe(nextX, player.y, player.w, player.h) then
        player.x = nextX
    end
    
    -- 分轴碰撞检测 (Y轴)
    if Core.isPositionSafe(player.x, nextY, player.w, player.h) then
        player.y = nextY
    end

    return isMoving
end

function Core.updateMonsterMovement(monster, dt, tileSize, target)
    local vx, vy = monster.vx or 0, monster.vy or 0

    if target then
        local t = target.data or target
        local dx = t.x - monster.x
        local dy = t.y - monster.y
        local len = math.sqrt(dx*dx + dy*dy)
        
        -- 简单追逐逻辑
        if len > 0 then
            vx, vy = dx/len, dy/len
        end
    end

    local nextX = monster.x + vx * monster.speed * dt
    local nextY = monster.y + vy * monster.speed * dt

    -- 怪物简单的碰撞 (卡住就滑行)
    if Core.isPositionSafe(nextX, monster.y, monster.w, monster.h) then
        monster.x = nextX
    end
    if Core.isPositionSafe(monster.x, nextY, monster.w, monster.h) then
        monster.y = nextY
    end
    
    monster.vx, monster.vy = vx, vy
end

-- === 3. 生成逻辑 (防卡墙算法) ===

-- 螺旋搜索算法：从 (centerX, centerY) 开始，向外寻找最近的安全点
-- maxRadius: 最大搜索半径（格子数）
function Core.findSpawnPoint(pixelX, pixelY, maxRadius)
    local tileSize = 32
    local startGx = math.floor(pixelX / tileSize)
    local startGy = math.floor(pixelY / tileSize)
    
    -- 如果起点本身就是安全的，直接返回
    if not Core.isSolidTile(startGx, startGy) then
        return startGx * tileSize, startGy * tileSize
    end
    
    -- 螺旋遍历
    -- 算法：层层向外扩展
    for r = 1, maxRadius do
        for x = -r, r do
            for y = -r, r do
                -- 只检查当前这一圈 (外壳)，避免重复检查内部
                if math.abs(x) == r or math.abs(y) == r then
                    local gx, gy = startGx + x, startGy + y
                    if not Core.isSolidTile(gx, gy) then
                        -- 找到空地！
                        return gx * tileSize, gy * tileSize
                    end
                end
            end
        end
    end
    
    print("Warning: No safe spawn point found near " .. pixelX .. "," .. pixelY)
    return pixelX, pixelY -- 找不到就硬着头皮返回原点（或者返回 nil）
end

return Core