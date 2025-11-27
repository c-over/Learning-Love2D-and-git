local Core = {}
local Map = require("map")

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

-- [修改] 通用对象碰撞检测（改为左上角对齐）
function Core.checkCollision(objA, objB)
    -- 直接使用 x, y 作为左上角，不再减去 w/2
    return Core.aabbOverlap(objA.x, objA.y, objA.w, objA.h, objB.x, objB.y, objB.w, objB.h)
end

-- [修改] 玩家移动逻辑（改为左上角对齐）
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

    -- 简单的朝向判断
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
        -- [修改] ax 直接是 newX
        local ax = newX 
        local ay = player.y
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, player.w, player.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, player.w, player.h, tileX, tileY, tileSize, tileSize) then
                        if dx > 0 then
                            newX = tileX - player.w
                        else
                            newX = tileX + tileSize
                        end
                        ax = newX -- 更新 ax 用于后续判断（虽然此处循环结束了）
                    end
                end
            end
        end
        player.x = newX
    end

    -- Y方向
    if dy ~= 0 then
        local newY = player.y + dy
        -- [修改] ay 直接是 newY
        local ax = player.x
        local ay = newY
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, player.w, player.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, player.w, player.h, tileX, tileY, tileSize, tileSize) then
                        if dy > 0 then
                            newY = tileY - player.h
                        else
                            newY = tileY + tileSize
                        end
                        ay = newY
                    end
                end
            end
        end
        player.y = newY
    end

    return isMoving
end

-- [修改] 怪物移动逻辑（改为左上角对齐）
function Core.updateMonsterMovement(monster, dt, tileSize, target)
    local vx, vy = monster.vx or 0, monster.vy or 0

    if target then
        -- 这里的 target.x 也是左上角，所以计算中心点距离需要加上宽高的一半
        local mcx, mcy = monster.x + monster.w/2, monster.y + monster.h/2
        -- 兼容 target 可能是数据结构(data)或直接对象
        local t = target.data or target
        local tcx, tcy = t.x + (t.w or 32)/2, t.y + (t.h or 32)/2
        
        local dx = tcx - mcx
        local dy = tcy - mcy
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
        -- [修改] 移除 -w/2
        local ax = newX
        local ay = monster.y
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, monster.w, monster.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, monster.w, monster.h, tileX, tileY, tileSize, tileSize) then
                        if dx > 0 then
                            newX = tileX - monster.w
                        else
                            newX = tileX + tileSize
                        end
                        ax = newX
                    end
                end
            end
        end
        monster.x = newX
    end

    -- Y方向
    if dy ~= 0 then
        local newY = monster.y + dy
        -- [修改] 移除 -h/2
        local ax = monster.x
        local ay = newY
        local left, right, top, bottom = Core.tilesAroundAABB(ax, ay, monster.w, monster.h, tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Core.isSolidTile(tx, ty) then
                    local tileX = tx * tileSize
                    local tileY = ty * tileSize
                    if Core.aabbOverlap(ax, ay, monster.w, monster.h, tileX, tileY, tileSize, tileSize) then
                        if dy > 0 then
                            newY = tileY - monster.h
                        else
                            newY = tileY + tileSize
                        end
                        ay = newY
                    end
                end
            end
        end
        monster.y = newY
    end

    monster.vx, monster.vy = vx, vy
end

-- 查找出生点 (返回的也是左上角坐标)
function Core.findSpawnPoint(tileSize)
    local radius = 0
    while true do
        for ty = -radius, radius do
            for tx = -radius, radius do
                if not Core.isSolidTile(tx, ty) then
                    return tx * tileSize, ty * tileSize -- 返回格子左上角
                end
            end
        end
        radius = radius + 1
    end
end

return Core