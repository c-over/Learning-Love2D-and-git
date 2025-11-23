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
local Map = require("Map")

local menuHeight = 120
local w, h = love.graphics.getWidth(), love.graphics.getHeight()
Game.menuButtons = Menu.createMenuButtons(Game, menuHeight, h)

function Game.load()
    Config.load()
    Game.tileSize = 32
    Game.noiseScale = 0.12
    Game.wallThreshold = 0.40
    local spawnX, spawnY = Core.findSpawnPoint(Game.tileSize)
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

    -- 使用 Map 模块绘制地图
    Map.draw(Game, camX, camY)

    love.graphics.setColor(1, 1, 1)
    PlayerAnimation.draw(Game.player.anim,
        Game.player.x - 16 - camX,
        Game.player.y - 16 - camY,
        isMoving)

    if debugMode then
        Debug.drawInfo(Game.player, counter)
        Debug.drawHitbox(Game.player, camX, camY)
    end

    Menu.draw(Game.menuButtons, menuHeight, w, h)
    Monster.draw(camX, camY)
    Merchant.draw(camX, camY)
    if Game.nearMerchant then
        love.graphics.setColor(1,1,1)
        love.graphics.print("按 Z 键与 "..Game.nearMerchant.name.." 交谈", 200, 50)
    end
    Pickup.draw(camX, camY)

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
