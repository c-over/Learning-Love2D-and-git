-- main.lua
local Settings = require("settings")
local Player = require("player")
local InventoryUI = require("inventory_ui")
local Inventory = require("inventory")
local Layout = require("layout")

local font = love.graphics.newFont("assets/simhei.ttf", 28)
love.graphics.setFont(font)

local currentScene = "menu"
local selectedIndex = nil
local bgMusic

-- 菜单按钮表
local buttons = {
    {x = 250, y = 200, w = 200, h = 40, text = "开始游戏", onClick = function()
        currentScene = "player"
        Player.load()
    end},
    {x = 250, y = 260, w = 200, h = 40, text = "设置", onClick = function()
        currentScene = "settings"
    end},
    {x = 250, y = 320, w = 200, h = 40, text = "背包", onClick = function()
        currentScene = "inventory"
    end},
    {x = 250, y = 380, w = 200, h = 40, text = "退出游戏", onClick = function()
        love.event.quit()
    end}
}

function love.load()
    bgMusic = love.audio.newSource("assets/title.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
    Settings.init(bgMusic)

    love.window.setMode(Layout.virtualWidth, Layout.virtualHeight, {resizable = true})
    Layout.resize(love.graphics.getWidth(), love.graphics.getHeight()) 
    Inventory.load()
end

function love.resize(w, h)
    Layout.resize(w, h)
end

-- 键盘操作
function love.keypressed(key)
    if currentScene == "menu" then
        if key == "up" then
            if selectedIndex == nil then selectedIndex = 1
            else
                selectedIndex = selectedIndex - 1
                if selectedIndex < 1 then selectedIndex = #buttons end
            end
        elseif key == "down" then
            if selectedIndex == nil then selectedIndex = 1
            else
                selectedIndex = selectedIndex + 1
                if selectedIndex > #buttons then selectedIndex = 1 end
            end
        elseif key == "return" then
            if selectedIndex and buttons[selectedIndex].onClick then
                buttons[selectedIndex].onClick()
            end
        end
    elseif currentScene == "settings" then
        currentScene = Settings.keypressed(key)
    end
end

function love.draw()
    if currentScene == "menu" then
        Layout.draw("中文菜单 Demo", {}, buttons, selectedIndex)
    elseif currentScene == "settings" then
        Settings.draw()
    elseif currentScene == "player" then
        Player.draw()
    elseif currentScene == "inventory" then
        InventoryUI.draw()
    end
end

function love.mousepressed(x, y, button)
    if currentScene == "menu" then
        local result = Layout.mousepressed(x, y, button, buttons)
        if type(result) == "number" then
            selectedIndex = result
        end
    elseif currentScene == "settings" then
        local result = Settings.mousepressed(x, y, button)
        if result == "menu" then currentScene = "menu" end
    elseif currentScene == "player" then
        local result = Player.mousepressed(x, y, button)
        if result == "menu" then currentScene = "menu" end
    elseif currentScene == "inventory" then
        local result = InventoryUI.mousepressed(x, y, button)
        if result == "menu" then currentScene = "menu" end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if currentScene == "menu" then
        selectedIndex = Layout.mousemoved(x, y, buttons)
    elseif currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "settings" then
        Settings.mousemoved(x, y)
    elseif currentScene == "inventory" then
        InventoryUI.mousemoved(x, y)
    end
end
