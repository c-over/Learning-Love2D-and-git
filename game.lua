-- game.lua
local Game = {}
Game.keys = {}
local counter = 0

function Game.load()
    Game.tileSize = 32
    -- 玩家像素坐标（屏幕中心）
    -- 统一噪声参数
    Game.noiseScale = 0.12
    Game.wallThreshold = 0.40

    -- 玩家（世界坐标，像素）
    Game.player = {
        x = 0, y = 0,        -- 世界坐标（像素）
        w = 30, h = 30,      -- 玩家碰撞盒（略小于 tileSize，避免边界卡死）
        speed = 240
    }

    -- 保证出生在草地：从原点开始向外扩展找草地
    local gx, gy = 0, 0
    local function isSolid(tx, ty)
        local n = love.math.noise(tx * Game.noiseScale, ty * Game.noiseScale)
        return n < Game.wallThreshold
    end
    local radius = 0
    while true do
        -- 环形搜索
        for ty = -radius, radius do
            for tx = -radius, radius do
                if not isSolid(tx, ty) then
                    gx, gy = tx, ty
                    Game.player.x = gx * Game.tileSize + (Game.tileSize - Game.player.w) / 2
                    Game.player.y = gy * Game.tileSize + (Game.tileSize - Game.player.h) / 2
                    return
                end
            end
        end
        radius = radius + 1
    end
end

-- 地图判定：格子是否为墙
function Game.isSolidTile(tx, ty)
    local n = love.math.noise(tx * Game.noiseScale, ty * Game.noiseScale)
    return n < Game.wallThreshold
end

-- 取玩家附近需要检测的瓷砖集合
local function tilesAroundAABB(ax, ay, aw, ah, tileSize)
    local left   = math.floor(ax / tileSize)
    local right  = math.floor((ax + aw - 1) / tileSize)
    local top    = math.floor(ay / tileSize)
    local bottom = math.floor((ay + ah - 1) / tileSize)
    return left, right, top, bottom
end

-- 与瓷砖矩形碰撞（AABB vs tile rect），返回是否相交
local function aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Game.update(dt)
    counter = counter + dt   -- 每帧累加
    local p = Game.player
    local vx, vy = 0, 0

    if love.keyboard.isDown("left")  or love.keyboard.isDown("a") then vx = vx - 1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then vx = vx + 1 end
    if love.keyboard.isDown("up")    or love.keyboard.isDown("w") then vy = vy - 1 end
    if love.keyboard.isDown("down")  or love.keyboard.isDown("s") then vy = vy + 1 end

    -- 归一化（避免斜向更快）
    if vx ~= 0 or vy ~= 0 then
        local len = math.sqrt(vx*vx + vy*vy)
        vx, vy = vx/len, vy/len
    end

    local dx = vx * p.speed * dt
    local dy = vy * p.speed * dt

    -- 先移动 X，碰到墙则贴边停止
    if dx ~= 0 then
        local newX = p.x + dx
        local left, right, top, bottom = tilesAroundAABB(newX, p.y, p.w, p.h, Game.tileSize)
        local collided = false
        for ty = top, bottom do
            for tx = left, right do
                if Game.isSolidTile(tx, ty) then
                    local tileX = tx * Game.tileSize
                    local tileY = ty * Game.tileSize
                    if aabbOverlap(newX, p.y, p.w, p.h, tileX, tileY, Game.tileSize, Game.tileSize) then
                        collided = true
                        if dx > 0 then -- 往右撞
                            newX = tileX - p.w
                        else          -- 往左撞
                            newX = tileX + Game.tileSize
                        end
                    end
                end
            end
        end
        p.x = newX
    end

    -- 再移动 Y，同理
    if dy ~= 0 then
        local newY = p.y + dy
        local left, right, top, bottom = tilesAroundAABB(p.x, newY, p.w, p.h, Game.tileSize)
        for ty = top, bottom do
            for tx = left, right do
                if Game.isSolidTile(tx, ty) then
                    local tileX = tx * Game.tileSize
                    local tileY = ty * Game.tileSize
                    if aabbOverlap(p.x, newY, p.w, p.h, tileX, tileY, Game.tileSize, Game.tileSize) then
                        if dy > 0 then -- 往下撞
                            newY = tileY - p.h
                        else          -- 往上撞
                            newY = tileY + Game.tileSize
                        end
                    end
                end
            end
        end
        p.y = newY
    end
end

-- 根据噪声生成地形：0=草地, 1=墙
function Game.getTile(x, y)
    local n = love.math.noise(x * 0.1, y * 0.1)
    if n < 0.4 then
        return 1  -- 墙
    else
        return 0  -- 草地
    end
end

function Game.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local tilesX = math.floor(w / Game.tileSize)
    local tilesY = math.floor(h / Game.tileSize)

    -- 摄像机：把玩家放屏幕中心
    local camX = Game.player.x + Game.player.w/2 - w/2
    local camY = Game.player.y + Game.player.h/2 - h/2

    -- 屏幕左上角对应的世界格子
    local startGX = math.floor(camX / Game.tileSize)
    local startGY = math.floor(camY / Game.tileSize)

    love.graphics.setColor(1,1,1)
    for j = 0, tilesY do
        for i = 0, tilesX do
            local gx = startGX + i
            local gy = startGY + j
            local tileSolid = Game.isSolidTile(gx, gy)

            if tileSolid then
                love.graphics.setColor(0.45, 0.45, 0.45) -- 墙
            else
                love.graphics.setColor(0.3, 0.8, 0.3)    -- 草地
            end

            local drawX = gx * Game.tileSize - camX
            local drawY = gy * Game.tileSize - camY
            love.graphics.rectangle("fill", drawX, drawY, Game.tileSize, Game.tileSize)
        end
    end

    -- 玩家（用世界坐标减摄像机偏移绘制）
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", Game.player.x - camX, Game.player.y - camY, Game.player.w, Game.player.h)

    if debugMode then
        -- 绘制计数器
        love.graphics.print("游戏运行时间: " .. string.format("%.2f", counter), 200, 200)
    
        -- 绘制调试信息（右上角）
        love.graphics.setColor(1,1,1)
        local w = love.graphics.getWidth()
        local pressedKeys = {}
        if love.keyboard.isDown("up") then table.insert(pressedKeys, "UP") end
        if love.keyboard.isDown("down") then table.insert(pressedKeys, "DOWN") end
        if love.keyboard.isDown("left") then table.insert(pressedKeys, "LEFT") end
        if love.keyboard.isDown("right") then table.insert(pressedKeys, "RIGHT") end

        local keysText = "Keys: " .. table.concat(pressedKeys, ", ")
        local posText = string.format("Player: (%.1f, %.1f)", Game.player.x, Game.player.y)

        -- 在右上角绘制，保证在屏幕内
        love.graphics.print(posText, w-250, 20)
        love.graphics.print(keysText, w-250, 40)
    end
end

function Game.keypressed(key)
    if key == "escape" then
        currentScene = "title"
    end
end

return Game
