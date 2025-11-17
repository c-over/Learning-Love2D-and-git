-- game.lua
local Game = {}
Game.keys = {}
local counter = 0
Game.justRespawned = false

local Layout = require("Layout")
local Player = require("player")
local Config = require("config")
local Battle = require("battle")
local InventoryUI = require("inventory_ui")

 -- 菜单栏按钮
local menuHeight = 120
local w, h = love.graphics.getWidth(), love.graphics.getHeight()
local menuTop = h - menuHeight

Game.menuButtons = {
    {
        x = 100, 
        y = menuTop + (menuHeight - 40) / 2,  -- 按钮高度40，居中
        w = 120, h = 40,
        text = "玩家信息",
         onClick = function() currentScene = "player" end
    },
    {
        x = 250, 
        y = menuTop + (menuHeight - 40) / 2,
        w = 120, h = 40,
        text = "背包",
        onClick = function() currentScene = "inventory" end
    },
    {
        x = 400, 
        y = menuTop + (menuHeight - 40) / 2,
        w = 120, h = 40,
        text = "返回标题",
        onClick = function() currentScene = "title" end
    },
    {
        x = 550, 
        y = menuTop + (menuHeight - 40) / 2,
        w = 180, h = 40,
        text = "设置重生点",
        onClick = function() Config.setRespawn(Game.player.x, Game.player.y) end
    }
}

Game.monsters = {
    {x = 200, y = 200, w = 32, h = 32, color = {1, 0, 0}, name = "史莱姆", level = 1, hp = 200},
    {x = 400, y = 300, w = 32, h = 32, color = {0, 1, 0}, name = "哥布林", level = 2, hp = 80},
    {x = 600, y = 250, w = 32, h = 32, color = {0, 0, 1}, name = "蝙蝠", level = 3, hp = 60}
    }

-- 进入战斗
local function enterBattle(i, monster)
    if Player.data.hp > 0 then 
        Battle.start(
            { name = monster.name, level = monster.level, hp = monster.hp },
            i,
            function(outcome, enemyIndex)
                if outcome.result == "win" then
                    -- 删除该怪物，避免死循环
                    table.remove(Game.monsters, enemyIndex)
                    -- 奖励逻辑可在此实现（比如增加等级或给物品）
                    Player.addLevel(1)
                elseif outcome.result == "lose" then
                    -- 失败处理（回到标题或惩罚）
                    currentScene = "title"
                return
                end
                -- 回到游戏场景
                currentScene = "game"
            end
        )
    else 
        print("你需要治疗")
    end
end

function Game.load()
    Config.load()
    Game.tileSize = 32
    -- 玩家像素坐标（屏幕中心）
    -- 统一噪声参数
    Game.noiseScale = 0.12
    Game.wallThreshold = 0.40

    -- 玩家（世界坐标，像素）
    local rx, ry = Config.getRespawn()
    Game.player = {
        x = rx or 0,
        y = ry or 0,
        w = 30, h = 30,
        speed = 240
    }
    -- 其他初始化逻辑...
    Player.load({x = Game.player.x, y = Game.player.y})

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
    InventoryUI.load()

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

    -- 碰到怪物时触发
    for i, monster in ipairs(Game.monsters) do
        if math.abs(Game.player.x - monster.x) < monster.w and
            math.abs(Game.player.y - monster.y) < monster.h then
            enterBattle(i, monster)
            break
        end
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
        -- 调试内容：绘制计数器
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
        local posText = string.format("Player: (%.d, %.d)", Game.player.x, Game.player.y)

        -- 在右上角绘制，保证在屏幕内
        love.graphics.print(posText, w-250, 20)
        love.graphics.print(keysText, w-250, 40)
    end

    local offsetY = h - menuHeight - Layout.virtualHeight  -- 把虚拟坐标整体下移

    -- 绘制菜单栏背景（底部遮挡地图）
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", 0, h - menuHeight, w, menuHeight)

    -- 在菜单栏区域调用 Layout.draw
    local infoLines = {""}
    local hoveredIndex = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), Game.menuButtons or {})
    Layout.draw("", infoLines, Game.menuButtons, hoveredIndex,offsetY)

    -- 绘制怪物
    for _, monster in ipairs(Game.monsters) do
        love.graphics.setColor(monster.color)
        love.graphics.rectangle("fill", monster.x - camX, monster.y - camY, monster.w, monster.h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(monster.name, monster.x - camX, monster.y - camY - 20)
    end
end

function Game.keypressed(key)
    if key == "escape" then
        currentScene = "title"
    end
end

function Game.mousemoved(x, y)
    if currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "inventory" then
        InventoryUI.mousemoved(x, y)
    end
end

function Game.mousepressed(x, y, button)
    if currentScene == "player" then
        local result = Player.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "inventory" then
        local result = InventoryUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    else
        Layout.mousepressed(x, y, button, Game.menuButtons)
    end
end


return Game
