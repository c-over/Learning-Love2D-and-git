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
local Merchant = require("merchant")
local ShopUI = require("shop_ui")
local Pickup = require("pickup")
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
        onClick = function() 
            InventoryUI.previousScene = currentScene
            currentScene = "inventory" end
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
                    table.remove(Monster.list, enemyIndex)
                    -- 奖励逻辑：提供经验而不是直接升级
                    local expReward = monster.level * 50  -- 简单经验公式，可调整
                    Player.gainExp(expReward)
                    print("获得经验：" .. expReward)
                    
                elseif outcome.result == "lose" then
                    -- 失败处理：重置血量，避免负值
                    Player.data.hp = Player.data.maxHp
                    print("你被击败了，血量已重置为满值")
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
    w = 16, h = 20, --玩家碰撞箱大小
    speed = 240,
    gold = 100, 
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
                    -- 设置为格子中心
                    Game.player.x = gx * Game.tileSize + Game.tileSize/2
                    Game.player.y = gy * Game.tileSize + Game.tileSize/2
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

    -- 检查是否靠近商人
    local npc = Merchant.checkCollision(Game.player, aabbOverlap)
    if npc then
        Game.nearMerchant = npc
    else
        Game.nearMerchant = nil
    end

    --检测奖励
    Pickup.update(dt, Game.player, Game.tileSize, Game.noiseScale, Game.wallThreshold, coinSound)
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

    -- 摄像机以中心点居中
    local camX = Game.player.x - w/2
    local camY = Game.player.y - h/2

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
    -- 绘制玩家（中心点 → 左上角）
    PlayerAnimation.draw(Game.player.anim,
        Game.player.x - 16 - camX,
        Game.player.y - 16 - camY,
        isMoving)

    if debugMode then
        Debug.drawInfo(Game.player, counter)
        Debug.drawHitbox(Game.player, camX, camY)
    end

    local offsetY = h - menuHeight - Layout.virtualHeight  -- 把虚拟坐标整体下移

    -- 绘制菜单栏背景（底部遮挡地图）
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", 0, h - menuHeight, w, menuHeight)

    -- 在菜单栏区域调用 Layout.draw
    local infoLines = {""}
    local hoveredIndex = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), Game.menuButtons or {})
    Layout.draw("", infoLines, Game.menuButtons, hoveredIndex,offsetY)

    Monster.draw(camX, camY)    -- 绘制怪物
    Merchant.draw(camX, camY)   -- 绘制商人
    -- 如果靠近商人，显示提示
    if Game.nearMerchant then
        love.graphics.setColor(1,1,1)
        love.graphics.print("按 Z 键与 "..Game.nearMerchant.name.." 交谈", 200, 50)
    end
    Pickup.draw(camX, camY)

    -- 绘制玩家状态条
    Game.drawStatusBar()
end

-- 绘制血量和魔力条
function Game.drawStatusBar()
    local margin = 20
    local barWidth = 200
    local barHeight = 20
    local x = love.graphics.getWidth() - barWidth - margin
    local y = margin

    -- 血量条背景
    love.graphics.setColor(0.3, 0.3, 0.3) -- 灰色背景
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)

    -- 血量条填充
    local hpRatio = Player.data.hp / Player.data.maxHp
    love.graphics.setColor(1, 0, 0) -- 红色血量
    love.graphics.rectangle("fill", x, y, barWidth * hpRatio, barHeight)

    -- 血量文字
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. Player.data.hp .. "/" .. Player.data.maxHp, x, y)

    -- 魔力条背景
    local mpY = y + barHeight + 5
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, mpY, barWidth, barHeight)

    -- 魔力条填充
    local mpRatio = Player.data.mp / Player.data.maxMp
    love.graphics.setColor(0, 0, 1) -- 蓝色魔力
    love.graphics.rectangle("fill", x, mpY, barWidth * mpRatio, barHeight)

    -- 魔力文字
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("MP: " .. Player.data.mp .. "/" .. Player.data.maxMp, x, mpY)

    -- 经验值条
    local expY = mpY + barHeight + 5
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, expY, barWidth, barHeight)
    local expRatio = Player.data.exp / (Player.data.level * 100)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", x, expY, barWidth * expRatio, barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("EXP: " .. Player.data.exp .. "/" .. (Player.data.level * 100), x, expY)
end

function Game.keypressed(key)
    if key == "z" and Game.nearMerchant then
        ShopUI.open(Game.nearMerchant)
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
