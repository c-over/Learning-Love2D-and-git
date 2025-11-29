-- title.lua
local Layout = require("layout")
local Settings = require("settings")
local InventoryUI = require("inventory_ui")

local Title = {}

local selectedIndex = nil
local background = nil
local lastDebugModeState = nil 

-- === 1. 按钮配置数据 ===
local BASE_BUTTONS = {
    {text = "开始游戏", onClick = function() currentScene = "game" end},
    {text = "设置",    onClick = function() currentScene = "settings" end},
    {text = "退出游戏", onClick = function() love.event.quit() end}
}

local DEBUG_BUTTON = {
    text = "背包(调试用)", 
    onClick = function()
        InventoryUI.previousScene = currentScene
        currentScene = "inventory"
    end
}

Title.buttons = {}

-- === 2. 核心：动态计算按钮坐标 ===
-- 根据当前屏幕宽度，计算按钮在虚拟坐标系中的 X 值，使其在屏幕上视觉居中
local function updateButtonPositions()
    local screenW = love.graphics.getWidth()
    -- 获取当前的水平缩放比例 (屏幕宽 / 虚拟宽)
    local scaleX = screenW / Layout.virtualWidth
    
    for _, btn in ipairs(Title.buttons) do
        -- 目标屏幕 X 坐标 = (屏幕宽 - 按钮宽) / 2
        local targetScreenX = (screenW - btn.w) / 2
        
        -- 逆向转换回虚拟 X 坐标 = 目标屏幕 X / 缩放比例
        btn.x = targetScreenX / scaleX
    end
end

-- === 3. 刷新列表 ===
local function refreshButtonList()
    Title.buttons = {}
    
    -- 基础Y轴布局
    local startY = 200
    local gapY = 60
    local width = 200
    local height = 40

    -- 生成按钮对象 (X坐标暂时填0，稍后由 updateButtonPositions 统一计算)
    for i, btnData in ipairs(BASE_BUTTONS) do
        table.insert(Title.buttons, {
            x = 0, -- 占位
            y = startY + (i-1) * gapY,
            w = width,
            h = height,
            text = btnData.text,
            onClick = btnData.onClick
        })
    end

    if debugMode then
        table.insert(Title.buttons, {
            x = 0,
            y = startY + (#BASE_BUTTONS) * gapY,
            w = width,
            h = height,
            text = DEBUG_BUTTON.text,
            onClick = DEBUG_BUTTON.onClick
        })
    end
    
    -- 立即计算一次位置
    updateButtonPositions()
    
    lastDebugModeState = debugMode
end

function Title.load()
    currentScene = "title"
    refreshButtonList()

    if not background then
        if love.filesystem.getInfo("assets/background.png") then
            background = love.graphics.newImage("assets/background.png")
        end
    end
end

function Title.update(dt)
    -- 1. 监听 debugMode 变化
    if debugMode ~= lastDebugModeState then
        refreshButtonList()
    end
    
    -- 2. 实时更新按钮位置 (处理窗口大小改变)
    -- Layout.draw 依赖于 btn.x，我们需要每一帧确保 btn.x 是针对当前窗口宽度的正确值
    updateButtonPositions()
end

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
        elseif key == "return" or key == "space" then
            if selectedIndex and Title.buttons[selectedIndex] and Title.buttons[selectedIndex].onClick then
                Title.buttons[selectedIndex].onClick()
            end
        elseif key == "f1" then
            debugMode = not debugMode
        end
    elseif currentScene == "settings" then
        if Settings.keypressed then currentScene = Settings.keypressed(key) end
    end
end

function Title.draw()
    -- 1. 绘制背景图 (保持居中缩放)
    if background then
        local w, h = love.graphics.getDimensions()
        local iw, ih = background:getWidth(), background:getHeight()
        local scale = math.max(w / iw, h / ih)
        local dx = (w - iw * scale) / 2
        local dy = (h - ih * scale) / 2
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(background, dx, dy, 0, scale, scale)
    else
        love.graphics.clear(0.1, 0.1, 0.2)
    end
    
    if currentScene == "title" then
        -- 2. 绘制按钮背景 (橙色半透明)
        -- 直接使用 btn.x 和 Layout.toScreen，因为我们已经在 update 中修正了 btn.x
        love.graphics.setColor(1, 0.7, 0, 0.3)
        for _, btn in ipairs(Title.buttons) do
            local bx, by = btn.x, btn.y
            -- 使用 Layout 转换，确保与文字对齐
            if Layout.toScreen then bx, by = Layout.toScreen(btn.x, btn.y) end
            love.graphics.rectangle("fill", bx, by, btn.w, btn.h)
        end

        -- 3. 绘制文字和边框 (调用 Layout.draw)
        Layout.draw("无限2D世界 Demo", {}, Title.buttons, selectedIndex)

        -- 4. 版本号
        local version = "v0.1"
        local font = love.graphics.getFont()
        local x = love.graphics.getWidth() - font:getWidth(version) - 10
        local y = love.graphics.getHeight() - font:getHeight() - 5
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(version, x, y)
        love.graphics.setColor(1, 1, 1)
    end    
end

function Title.mousepressed(x, y, button)
    -- Layout.mousepressed 会将鼠标坐标转回虚拟坐标
    -- 因为我们反向计算了 btn.x，所以这里的碰撞检测也是准确的
    local result = Layout.mousepressed(x, y, button, Title.buttons)
    if type(result) == "number" then
        selectedIndex = result
    end
end

function Title.mousemoved(x, y, dx, dy, istouch)
    selectedIndex = Layout.mousemoved(x, y, Title.buttons)
end

return Title