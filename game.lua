-- game.lua
local Game = {}
Game.keys = {}
local counter = 0
Game.justRespawned = false

local Core = require("core")
local Layout = require("layout")
local Debug = require("debug_utils")
local Player = require("player")
local Config = require("config")
local Monster = require("monster")
local Merchant = require("merchant")
local ShopUI = require("shop_ui")
local Pickup = require("pickup")
local Battle = require("battle")
local InventoryUI = require("inventory_ui")
local PlayerAnimation = require("PlayerAnimation")

-- 新模块
local Menu = require("Menu")
local StatusBar = require("StatusBar")
local Map = require("map")

local menuHeight = 120
local w, h = love.graphics.getWidth(), love.graphics.getHeight()
Game.menuButtons = Menu.createMenuButtons(Game, menuHeight, h)

function Game.load()
    Config.load() -- 必须先加载

    local spawnX, spawnY
    
    -- 现在 Config.data 可以被访问了，检查是否存在重生点
    if Config.data and Config.data.player and Config.data.player.respawnX then
        spawnX = Config.data.player.respawnX
        spawnY = Config.data.player.respawnY
        print("读取存档重生点:", spawnX, spawnY)
    else
        -- 没有存档或没设置过重生点，随机生成
        spawnX, spawnY = Core.findSpawnPoint(Game.tileSize)
        print("生成新随机出生点")
    end
    Game.tileSize = 32
    Game.noiseScale = 0.12
    Game.wallThreshold = 0.40
    Game.player = {
        x = spawnX,
        y = spawnY,
        w = 16, h = 20,
        speed = 240,
        gold = 100,
        anim = PlayerAnimation.load("assets/Character/Idle.png", "assets/Character/Walk.png", 32, 32)
    }
end

function Game.update(dt)
    counter = counter + dt
    local isMoving = Core.updatePlayerMovement(Game.player, dt, Game.tileSize)
    PlayerAnimation.update(Game.player.anim, dt, isMoving, {"down","up","right","left"})
    Monster.update(dt, Game.player, Game.tileSize, Core)
    Pickup.update(dt, Game.player, Game.tileSize, Core, coinSound)
    local i, monster = Monster.checkCollision(Game.player, Core.aabbOverlap)
    if i then
        Battle.enterBattle(i, monster)
    end

    local npc = Merchant.checkCollision(Game.player, aabbOverlap)
    if npc then
        Game.nearMerchant = npc
    else
        Game.nearMerchant = nil
    end
    
end

function Game.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local camX = Game.player.x - w/2
    local camY = Game.player.y - h/2

    -- 1. 最底层：地图
    Map.draw(Game, camX, camY)

    -- 2. 中间层：玩家
    -- (注意：这里需要加上我之前提到的 spriteOffset 修正，如果你还没加的话)
    local spriteOffset = (32 - Game.player.w) / 2 
    love.graphics.setColor(1, 1, 1)
    PlayerAnimation.draw(Game.player.anim,
        Game.player.x - spriteOffset - camX,
        Game.player.y - (32 - Game.player.h) - camY,
        isMoving)

    -- 3. 中间层：实体 (怪物、商人、掉落物)
    -- 这些必须在菜单之前绘制！
    Monster.draw(camX, camY)
    Merchant.draw(camX, camY)
    Pickup.draw(camX, camY)

    if debugMode then
        Debug.drawInfo(Game.player, counter)
        Debug.drawHitbox(Game.player, camX, camY)
    end

    if Game.nearMerchant then
        love.graphics.setColor(1,1,1)
        love.graphics.print("按 Z 键与 "..Game.nearMerchant.name.." 交谈", 200, 50)
    end

    -- 4. 最顶层：UI (菜单、状态栏)
    -- [修复] 将 Menu.draw 移到这里，确保它覆盖在所有游戏世界物体之上
    Menu.draw(Game.menuButtons, menuHeight, w, h)
    StatusBar.draw()
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
