-- game.lua
local Game = {}
Game.keys = {}
local counter = 0
Game.justRespawned = false

local Core = require("core")
local Debug = require("debug_utils")
local Layout = require("Layout")
local Player = require("player")
local Config = require("config")
local Battle = require("battle")
local Monster = require("monster")
local InventoryUI = require("inventory_ui")
local PlayerAnimation = require("PlayerAnimation")

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
    Monster.load()
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
    w = 32, h = 32, --玩家碰撞箱大小
    speed = 240,
    anim = PlayerAnimation.load("assets/Character/Idle.png", "assets/Character/Walk.png", 32, 32)
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
    InventoryUI.load()

end

function Game.update(dt)
    counter = counter + dt   -- 每帧累加
    local isMoving = Core.updatePlayerMovement(Game.player, dt, Game.tileSize, Game.noiseScale, Game.wallThreshold)
    PlayerAnimation.update(Game.player.anim, dt, isMoving,{"down","up","right","left"})

    -- 怪物移动（追踪玩家）
    Monster.update(dt, Game.player, Game.tileSize, Game.noiseScale, Game.wallThreshold,Core)

    -- 碰到怪物时触发
    local i, monster = Monster.checkCollision(Game.player, Core.aabbOverlap)
    if i then
        enterBattle(i, monster)
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
            local tileSolid = Core.isSolidTile(gx, gy, Game.noiseScale, Game.wallThreshold)

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

    love.graphics.setColor(1, 1, 1)
    PlayerAnimation.draw(Game.player.anim, Game.player.x - camX, Game.player.y - camY, isMoving)

    if debugMode then
        Debug.drawInfo(Game.player, counter)
        Debug.drawPlayerHitbox(Game.player, camX, camY)
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
    Monster.draw(camX, camY)
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
