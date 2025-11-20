-- core.lua
local Core = {}

-- 地图判定：格子是否为墙
function Core.isSolidTile(tx, ty, noiseScale, wallThreshold)
    local n = love.math.noise(tx * noiseScale, ty * noiseScale)
    return n < wallThreshold
end
-- 取玩家附近需要检测的瓷砖集合
function Core.tilesAroundAABB(ax, ay, aw, ah, tileSize)
    local left   = math.floor(ax / tileSize)
    local right  = math.floor((ax + aw - 1) / tileSize)
    local top    = math.floor(ay / tileSize)
    local bottom = math.floor((ay + ah - 1) / tileSize)
    return left, right, top, bottom
end
-- 与瓷砖矩形碰撞（AABB vs tile rect），返回是否相交
function Core.aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- 通用对象碰撞检测
function Core.checkCollision(objA, objB)
    local ax = objA.x - objA.w/2
    local ay = objA.y - objA.h/2
    local bx = objB.x - objB.w/2
    local by = objB.y - objB.h/2
    return Core.aabbOverlap(ax, ay, objA.w, objA.h, bx, by, objB.w, objB.h)
end

-- 玩家移动逻辑
function Core.updatePlayerMovement(player, dt, tileSize,noiseScale, wallThreshold, PlayerAnimation)
    local vx, vy = 0, 0

    -- 按键输入
    if love.keyboard.isDown("left")  or love.keyboard.isDown("a") then vx = vx - 1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then vx = vx + 1 end
    if love.keyboard.isDown("up")    or love.keyboard.isDown("w") then vy = vy - 1 end
    if love.keyboard.isDown("down")  or love.keyboard.isDown("s") then vy = vy + 1 end

    -- 归一化
    if vx ~= 0 or vy ~= 0 then
        local len = math.sqrt(vx*vx + vy*vy)
        vx, vy = vx/len, vy/len
    end

    player.vx, player.vy = vx, vy

    -- 设置动画方向
    if vx > 0 then player.anim.dir = "right"
    elseif vx < 0 then player.anim.dir = "left"
    elseif vy > 0 then player.anim.dir = "down"
    elseif vy < 0 then player.anim.dir = "up" end

    local isMoving = (vx ~= 0 or vy ~= 0)

    -- 位移
    local dx = vx * player.speed * dt
    local dy = vy * player.speed * dt

    -- X 方向移动
    if dx ~= 0 then
        local newX = player.x + dx
        local left, right, top, bottom = Core.tilesAroundAABB(newX, player.y, player.w, player.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty, noiseScale, wallThreshold) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(newX, player.y, player.w, player.h, tileX, tileY, tileSize, tileSize) then
                        if dx > 0 then
                            newX = tileX - player.w
                        else
                            newX = tileX + tileSize
                        end
                    end
                end
            end
        end
        player.x = newX
    end

    -- Y 方向移动
    if dy ~= 0 then
        local newY = player.y + dy
        local left, right, top, bottom = Core.tilesAroundAABB(player.x, newY, player.w, player.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty, noiseScale, wallThreshold) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(player.x, newY, player.w, player.h, tileX, tileY, tileSize, tileSize) then
                        if dy > 0 then
                            newY = tileY - player.h
                        else
                            newY = tileY + tileSize
                        end
                    end
                end
            end
        end
        player.y = newY
    end

    return isMoving
end

-- ✅ 新增：怪物移动逻辑
-- 参数 monster: 怪物对象 (x,y,w,h,speed,vx,vy)
-- 参数 dt: 帧间隔
-- 参数 tileSize, noiseScale, wallThreshold: 地图参数
-- 参数 target: 可选，目标对象（比如玩家），用于追踪
function Core.updateMonsterMovement(monster, dt, tileSize, noiseScale, wallThreshold, target)
    local vx, vy = monster.vx or 0, monster.vy or 0

    -- 如果有目标（例如玩家），简单追踪逻辑
    if target then
        local dx = target.x - monster.x
        local dy = target.y - monster.y
        local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then
            vx, vy = dx/len, dy/len
        end
    else
        -- 没有目标时，可以随机游走（这里先保持原方向）
        -- 后续可以扩展为随机选择方向
    end

    -- 位移
    local dx = vx * monster.speed * dt
    local dy = vy * monster.speed * dt

    -- X方向移动
    if dx ~= 0 then
        local newX = monster.x + dx
        local left, right, top, bottom = Core.tilesAroundAABB(newX, monster.y, monster.w, monster.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty, noiseScale, wallThreshold) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(newX, monster.y, monster.w, monster.h, tileX, tileY, tileSize, tileSize) then
                        if dx > 0 then
                            newX = tileX - monster.w
                        else
                            newX = tileX + tileSize
                        end
                    end
                end
            end
        end
        monster.x = newX
    end

    -- Y方向移动
    if dy ~= 0 then
        local newY = monster.y + dy
        local left, right, top, bottom = Core.tilesAroundAABB(monster.x, newY, monster.w, monster.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty, noiseScale, wallThreshold) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(monster.x, newY, monster.w, monster.h, tileX, tileY, tileSize, tileSize) then
                        if dy > 0 then
                            newY = tileY - monster.h
                        else
                            newY = tileY + tileSize
                        end
                    end
                end
            end
        end
        monster.y = newY
    end

    -- 保存方向
    monster.vx, monster.vy = vx, vy
end

return Core
