local Title = require("title")
local Game = require("game")
local Layout = require("layout")
local Player = require("player")
local Battle = require("battle")
local ShopUI = require("shop_ui")
local Settings = require("settings")
local Inventory = require("inventory")
local IconBrowser = require("IconBrowser")
local InventoryUI = require("inventory_ui")

function love.load()
    -- 全局初始化
    local font = love.graphics.newFont("assets/simhei.ttf", 28)
    love.graphics.setFont(font)
    IconBrowser.load("assets/icon.png") -- 加载图标素材

    love.window.setMode(Layout.virtualWidth, Layout.virtualHeight, {resizable = true})
    Layout.resize(love.graphics.getWidth(), love.graphics.getHeight()) 

    coinSound = love.audio.newSource("assets/sounds/coin.wav", "static")
    bgMusic = love.audio.newSource("assets/sounds/title.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
    Settings.init(bgMusic)

    debugMode = false  -- 初始关闭
    Player.load()   -- 从存档读取数据
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
    elseif currentScene == "battle" then
        Battle.update(dt)
    elseif currentScene == "icon_browser" then
        IconBrowser.update(dt)
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
        Player.draw()
    elseif currentScene == "inventory" then
        InventoryUI.draw()
    elseif currentScene == "icon_browser" then
        IconBrowser.draw(currentScene, "icon_browser")
    elseif currentScene == "battle" then
        Battle.draw()
    elseif currentScene == "shop" then
        ShopUI.draw()
    end
    if debugMode then
        love.graphics.setColor(1, 0, 0.5, 0.8)
        love.graphics.print("当前场景: " .. currentScene, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
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
    elseif currentScene == "icon_browser" and key == "escape" then
        currentScene = InventoryUI.previousScene or "inventory"
    elseif currentScene == "battle" then
        Battle.keypressed(key)
    elseif currentScene == "shop" then
        ShopUI.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if currentScene == "title" then
        local result = Title.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "game" then
        local result = Game.mousepressed(x, y, button)
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
    elseif currentScene == "battle" then
        local result = Battle.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "shop" then
        local result = ShopUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if currentScene == "title" then
        Title.mousemoved(x,y)
    elseif currentScene == "game" then
        Game.mousemoved(x,y)
    elseif currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "battle" then
        Battle.mousemoved(x, y)
    elseif currentScene == "settings" then
        Settings.mousemoved(x, y)
    elseif currentScene == "inventory" then
        InventoryUI.mousemoved(x, y)
    elseif currentScene == "icon_browser" then
        IconBrowser.mousemoved(x, y)
    elseif currentScene == "shop" then
        ShopUI.mousemoved(x, y)
    end
end

function love.mousereleased(x, y, button)
    -- 转发给 InventoryUI
    if currentScene == "inventory" then
        InventoryUI.mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
    if currentScene == "icon_browser" then
        IconBrowser.wheelmoved(x, y)
    end
end