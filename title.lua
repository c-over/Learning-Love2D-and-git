-- title.lua
local Layout = require("layout")
local Settings = require("settings")
local Title = {}

local selectedIndex = nil
local background = nil
local lastDebugModeState = nil 

-- 样式配置
local COLORS = {
    btn_idle = {0, 0, 0, 0.6},        -- 深色半透明底
    btn_hov  = {0.9, 0.6, 0.2, 0.9},  -- 橙色高亮 (符合主菜单活力感)
    text     = {1, 1, 1, 1},
    shadow   = {0, 0, 0, 0.5}
}

Title.buttons = {}

-- 刷新按钮列表 (虚拟坐标)
local function refreshButtonList()
    Title.buttons = {}
    
    local btnW, btnH = 220, 50
    local startX = (Layout.virtualWidth - btnW) / 2
    local startY = 300 -- 标题下移
    local gap = 65

    -- 1. 开始游戏
    table.insert(Title.buttons, {
        x = startX, y = startY, w = btnW, h = btnH,
        text = "开始游戏",
        onClick = function() currentScene = "game" end
    })

    -- 2. 设置
    table.insert(Title.buttons, {
        x = startX, y = startY + gap, w = btnW, h = btnH,
        text = "系统设置",
        onClick = function() 
            currentScene = "settings" 
            Settings.init(bgMusic) -- 重新读取配置
        end
    })

    -- 3. 退出
    table.insert(Title.buttons, {
        x = startX, y = startY + gap * 2, w = btnW, h = btnH,
        text = "退出游戏",
        onClick = function() love.event.quit() end
    })

    -- Debug 按钮
    if debugMode then
        table.insert(Title.buttons, {
            x = startX, y = startY + gap * 3, w = btnW, h = btnH,
            -- [修改] 按钮文字和回调
            text = "素材/资产查看器",
            onClick = function()
                local AssetViewer = require("AssetViewer")
                AssetViewer.load() -- 加载资源
                currentScene = "asset_viewer"
            end
        })
    end
    
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
    if debugMode ~= lastDebugModeState then
        refreshButtonList()
    end
end

function Title.draw()
    local w, h = love.graphics.getDimensions()

    -- 1. 绘制背景图 (保持居中缩放)
    if background then
        local iw, ih = background:getWidth(), background:getHeight()
        local scale = math.max(w / iw, h / ih)
        local dx = (w - iw * scale) / 2
        local dy = (h - ih * scale) / 2
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(background, dx, dy, 0, scale, scale)
    else
        -- 兜底渐变色 (如果没有图片)
        love.graphics.setColor(0.1, 0.1, 0.2)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    
    if currentScene == "title" then
        -- 2. 绘制大标题
        local vTitleX, vTitleY = Layout.virtualWidth / 2, 150
        local sTitleX, sTitleY = Layout.toScreen(vTitleX, vTitleY)
        
        love.graphics.setFont(Fonts.title)
        local titleText = "无限2D世界 Demo"
        
        -- 标题阴影
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.printf(titleText, 4, sTitleY + 4, w, "center")
        
        -- 标题本体
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(titleText, 0, sTitleY, w, "center")

        -- 3. 绘制按钮
        love.graphics.setFont(Fonts.medium)
        local fontH = Fonts.medium:getHeight()

        for i, btn in ipairs(Title.buttons) do
            local bx, by = Layout.toScreen(btn.x, btn.y)
            local bw, bh = Layout.toScreen(btn.w, btn.h)
            
            if i == selectedIndex then
                love.graphics.setColor(COLORS.btn_hov)
                love.graphics.rectangle("fill", bx, by + 2, bw, bh, 10, 10) -- 高亮下沉
            else
                love.graphics.setColor(COLORS.btn_idle)
                love.graphics.rectangle("fill", bx, by, bw, bh, 10, 10)
                love.graphics.setColor(1, 1, 1, 0.2)
                love.graphics.rectangle("line", bx, by, bw, bh, 10, 10)
            end
            
            love.graphics.setColor(COLORS.text)
            love.graphics.printf(btn.text, bx, by + (bh - fontH) / 2, bw, "center")
        end

        -- 4. 版本号
        local version = "v0.1.4"
        love.graphics.setFont(Fonts.small)
        love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
        love.graphics.print(version, w - 150, h - 30)
    end    
end

function Title.keypressed(key)
    -- 简单的键盘导航逻辑
    if key == "up" then
        if not selectedIndex then selectedIndex = 1 
        else selectedIndex = selectedIndex - 1 end
        if selectedIndex < 1 then selectedIndex = #Title.buttons end
    elseif key == "down" then
        if not selectedIndex then selectedIndex = 1 
        else selectedIndex = selectedIndex + 1 end
        if selectedIndex > #Title.buttons then selectedIndex = 1 end
    elseif key == "return" or key == "space" then
        if selectedIndex and Title.buttons[selectedIndex] then
            Title.buttons[selectedIndex].onClick()
        end
    elseif key == "f3" then
        -- main.lua 处理了 f3，这里主要是为了防止冲突或者添加额外的 title debug 操作
    end
end

function Title.mousemoved(x, y)
    selectedIndex = Layout.mousemoved(x, y, Title.buttons)
end

function Title.mousepressed(x, y, button)
    if button == 1 then
        local result = Layout.mousepressed(x, y, button, Title.buttons)
        -- 如果按钮返回了场景名，可能需要传递出去，但在 main.lua 架构里
        -- 主要是靠修改全局 currentScene 变量
    end
end

return Title