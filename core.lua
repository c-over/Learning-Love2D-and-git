local Core = {}
local Map = require("map")  -- 引入 Map 模块

-- 地图判定：格子是否为墙/不可通行
function Core.isSolidTile(tx, ty)
    local tile = Map.getTile(tx, ty)
    return tile == "tree" or tile == "rock" or tile == "water"
end

-- AABB：左上角坐标 + 宽高
function Core.tilesAroundAABB(ax, ay, aw, ah, tileSize)
    local left   = math.floor(ax / tileSize)
    local right  = math.floor((ax + aw - 1) / tileSize)
    local top    = math.floor(ay / tileSize)
    local bottom = math.floor((ay + ah - 1) / tileSize)
    return left, right, top, bottom
end

function Core.aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- 通用对象碰撞检测（中心点）
function Core.checkCollision(objA, objB)
    local ax = objA.x - objA.w/2
    local ay = objA.y - objA.h/2
    local bx = objB.x - objB.w/2
    local by = objB.y - objB.h/2
    return Core.aabbOverlap(ax, ay, objA.w, objA.h, bx, by, objB.w, objB.h)
end

-- 玩家移动逻辑（中心点）
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
    local dx = vx * player.speed * dt
    local dy = vy * player.speed * dt

    -- X方向
    if dx ~= 0 then
        local newX = player.x + dx
        local ax = newX - player.w/2
        local ay = player.y - player.h/2
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, player.w, player.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, player.w, player.h, tileX, tileY, tileSize, tileSize) then
                        if dx > 0 then
                            newX = tileX - player.w/2
                        else
                            newX = tileX + tileSize + player.w/2
                        end
                        ax = newX - player.w/2
                    end
                end
            end
        end
        player.x = newX
    end

    -- Y方向
    if dy ~= 0 then
        local newY = player.y + dy
        local ax = player.x - player.w/2
        local ay = newY - player.h/2
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, player.w, player.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, player.w, player.h, tileX, tileY, tileSize, tileSize) then
                        if dy > 0 then
                            newY = tileY - player.h/2
                        else
                            newY = tileY + tileSize + player.h/2
                        end
                        ay = newY - player.h/2
                    end
                end
            end
        end
        player.y = newY
    end

    return isMoving
end

-- 怪物移动逻辑（中心点）
function Core.updateMonsterMovement(monster, dt, tileSize, target)
    local vx, vy = monster.vx or 0, monster.vy or 0

    if target then
        local dx = target.x - monster.x
        local dy = target.y - monster.y
        local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then
            vx, vy = dx/len, dy/len
        end
    end

    local dx = vx * monster.speed * dt
    local dy = vy * monster.speed * dt

    -- X方向
    if dx ~= 0 then
        local newX = monster.x + dx
        local ax = newX - monster.w/2
        local ay = monster.y - monster.h/2
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, monster.w, monster.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, monster.w, monster.h, tileX, tileY, tileSize, tileSize) then
                        if dx > 0 then
                            newX = tileX - monster.w/2
                        else
                            newX = tileX + tileSize + monster.w/2
                        end
                        ax = newX - monster.w/2
                    end
                end
            end
        end
        monster.x = newX
    end

    -- Y方向
    if dy ~= 0 then
        local newY = monster.y + dy
        local ax = monster.x - monster.w/2
        local ay = newY - monster.h/2
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, monster.w, monster.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, monster.w, monster.h, tileX, tileY, tileSize, tileSize) then
                        if dy > 0 then
                            newY = tileY - monster.h/2
                        else
                            newY = tileY + tileSize + monster.h/2
                        end
                        ay = newY - monster.h/2
                    end
                end
            end
        end
        monster.y = newY
    end

    monster.vx, monster.vy = vx, vy
end

-- 查找一个安全的出生点（环形搜索最近的草地格子）
function Core.findSpawnPoint(tileSize)
    local radius = 0
    while true do
        for ty = -radius, radius do
            for tx = -radius, radius do
                if not Core.isSolidTile(tx, ty) then
                    -- 返回像素坐标（格子中心点）
                    return tx * tileSize + tileSize/2,
                           ty * tileSize + tileSize/2
                end
            end
        end
        radius = radius + 1
    end
end

return Core
