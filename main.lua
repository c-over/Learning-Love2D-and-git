local Settings = require("settings")

local font = love.graphics.newFont("simhei.ttf", 28)
love.graphics.setFont(font)

local currentScene = "menu"
local menuItems = {"开始游戏", "设置", "退出游戏"}
local selectedIndex = 1
local bgMusic

function love.load()
    bgMusic = love.audio.newSource("title.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
    Settings.init(bgMusic) -- 初始化设置界面并应用音量
end

function love.keypressed(key)
    if currentScene == "menu" then
        if key == "up" then
            selectedIndex = selectedIndex - 1
            if selectedIndex < 1 then selectedIndex = #menuItems end
        elseif key == "down" then
            selectedIndex = selectedIndex + 1
            if selectedIndex > #menuItems then selectedIndex = 1 end
        elseif key == "return" then
            local choice = menuItems[selectedIndex]
            if choice == "设置" then
                currentScene = "settings"
            elseif choice == "退出游戏" then
                love.event.quit()
            end
        end
    elseif currentScene == "settings" then
        currentScene = Settings.keypressed(key)
    end
end

function love.draw()
    if currentScene == "menu" then
        love.graphics.print("中文菜单 Demo", 200, 50)
        for i, item in ipairs(menuItems) do
            local y = 150 + i * 50
            if i == selectedIndex then
                love.graphics.setColor(1, 0, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.print(item, 250, y)
        end
        love.graphics.setColor(1, 1, 1)
    elseif currentScene == "settings" then
        Settings.draw()
    end
end
