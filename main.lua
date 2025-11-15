-- main.lua
local Settings = require("settings")
local Player = require("player")

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

-- 键盘操作
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
            if choice == "开始游戏" then
                currentScene = "player"
                Player.load()
            elseif choice == "设置" then
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
            local bx, by, w, h = 250, 150 + i * 50, 200, 40
            if i == selectedIndex then
                love.graphics.setColor(0.2, 0.8, 1) -- 悬停高亮颜色（蓝色）
            else
                love.graphics.setColor(1, 1, 1) -- 默认白色
            end
            love.graphics.rectangle("line", bx, by, w, h)
            love.graphics.printf(item, bx, by + 10, w, "center")
        end
        love.graphics.setColor(1, 1, 1)
    elseif currentScene == "settings" then
        Settings.draw()
    elseif currentScene == "player" then
        Player.draw()
    end
end


-- 鼠标点击支持
function love.mousepressed(x, y, button)
    if currentScene == "menu" and button == 1 then
        for i, item in ipairs(menuItems) do
            local bx, by, w, h = 250, 150 + i * 50, 200, 40
            if x >= bx and x <= bx + w and y >= by and y <= by + h then
                selectedIndex = i
                local choice = menuItems[selectedIndex]
                if choice == "开始游戏" then
                    currentScene = "player"
                    Player.load()
                elseif choice == "设置" then
                    currentScene = "settings"
                elseif choice == "退出游戏" then
                    love.event.quit()
                end
            end
        end
    elseif currentScene == "settings" then
        local result = Settings.mousepressed(x, y, button)
        if result == "menu" then currentScene = "menu" end
    elseif currentScene == "player" then
        local result = Player.mousepressed(x, y, button)
        if result == "menu" then currentScene = "menu" end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if currentScene == "menu" then
        -- 菜单悬停检测
        for i, item in ipairs(menuItems) do
            local bx, by, w, h = 250, 150 + i * 50, 200, 40
            if x >= bx and x <= bx + w and y >= by and y <= by + h then
                selectedIndex = i
            end
        end
    elseif currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "settings" then
        Settings.mousemoved(x, y)
    end
end

