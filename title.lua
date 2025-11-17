-- title.lua
local Layout = require("layout")
local Settings = require("settings")
local Title = {}

local selectedIndex = nil
local bgMusic

-- 菜单按钮表
Title.buttons = {
    {x = 250, y = 200, w = 200, h = 40, text = "开始游戏", onClick = function()
        currentScene = "game"
    end},
    {x = 250, y = 260, w = 200, h = 40, text = "设置", onClick = function()
        currentScene = "settings"
    end},
    {x = 250, y = 320, w = 200, h = 40, text = "退出游戏", onClick = function()
        love.event.quit()
    end},
    {x = 250, y = 380, w = 200, h = 40, text = "背包(调试用)", onClick = function()
        currentScene = "inventory"
    end}
}
-- -- 只有在 debugMode = true 时才添加额外按钮
-- if debugMode == true then
--     table.insert(Title.Buttons, 
--         {x = 250, y = 380, w = 200, h = 40, text = "背包(调试用)", onClick = function()
--         currentScene = "inventory"
--         end})
--     end

function Title.load()
    currentScene = "title"
end

function love.resize(w, h)
    Layout.resize(w, h)
end

function Title.update(dt) end

-- 键盘操作
function Title.keypressed(key)
    if currentScene == "title" then
        if key == "up" then
            if selectedIndex == nil then selectedIndex = 1
            else
                selectedIndex = selectedIndex - 1
                if selectedIndex < 1 then selectedIndex = #Title.buttons end
            end
        elseif key == "down" then
            if selectedIndex == nil then selectedIndex = 1
            else
                selectedIndex = selectedIndex + 1
                if selectedIndex > #Title.buttons then selectedIndex = 1 end
            end
        elseif key == "return" then
            if selectedIndex and Title.buttons[selectedIndex].onClick then
                Title.buttons[selectedIndex].onClick()
            end
        end
    elseif currentScene == "settings" then
        currentScene = Settings.keypressed(key)
    end
end

function Title.draw()
    if currentScene == "title" then
        Layout.draw("标题菜单 Demo", {}, Title.buttons, selectedIndex)

        -- 绘制版本号（右下角小字）
        local version = "v0.0.6"  -- 这里写当前版本号
        local font = love.graphics.getFont()
        local textW = font:getWidth(version)
        local textH = font:getHeight()

        local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
        local x = screenW - textW - 10   -- 距离右边 10 像素
        local y = screenH - textH - 5    -- 距离底部 5 像素

        love.graphics.setColor(0.7, 0.7, 0.7)  -- 灰色小字
        love.graphics.print(version, x, y)
        love.graphics.setColor(1, 1, 1)        -- 恢复颜色
    end
end

function Title.mousepressed(x, y, button)
    local result = Layout.mousepressed(x, y, button, Title.buttons)
    if type(result) == "number" then
        selectedIndex = result
    end
end

function Title.mousemoved(x, y, dx, dy, istouch)
    selectedIndex = Layout.mousemoved(x, y, Title.buttons)
end

return Title