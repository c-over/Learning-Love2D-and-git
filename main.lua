local Title = require("title")
local Game = require("game")
local Layout = require("layout")
local Player = require("player")
local Settings = require("settings")
local Inventory = require("inventory")
local InventoryUI = require("inventory_ui")

function love.load()
    -- 全局初始化
    local font = love.graphics.newFont("assets/simhei.ttf", 28)
    love.graphics.setFont(font)

    love.window.setMode(Layout.virtualWidth, Layout.virtualHeight, {resizable = true})
    Layout.resize(love.graphics.getWidth(), love.graphics.getHeight()) 

    bgMusic = love.audio.newSource("assets/title.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
    Settings.init(bgMusic)

    debugMode = false  -- 初始关闭
    Inventory.load()
    Game.load()

    currentScene = "title"
    Title.load()
end

function love.update(dt)
    if currentScene == "title" then
        Title.update(dt)
    elseif currentScene == "game" then
        Game.update(dt)
    end
end

function love.draw()
    if currentScene == "title" then
        Title.draw()
    elseif currentScene == "game" then
        Game.draw()
    elseif currentScene == "settings" then
        Settings.draw()
    elseif currentScene == "player" then
        Player.load()
        Player.draw()
    elseif currentScene == "inventory" then
        InventoryUI.draw()
    end
end

function love.keypressed(key)
    if key == "f3" then
        debugMode = not debugMode  -- 按下 F3 切换调试模式
    end
    if currentScene == "title" then
        Title.keypressed(key)
    elseif currentScene == "game" then
        Game.keypressed(key)
    elseif currentScene == "settings" then
        Settings.keypressed(key)
    elseif currentScene == "inventory" then
        InventoryUI.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if currentScene == "title" then
        local result = Title.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "settings" then
        local result = Settings.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "player" then
        local result = Player.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "inventory" then
        local result = InventoryUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if currentScene == "title" then
        selectedIndex = Title.mousemoved(x, y, buttons)
    elseif currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "settings" then
        Settings.mousemoved(x, y)
    elseif currentScene == "inventory" then
        InventoryUI.mousemoved(x, y)
    end
end