local GameUI = {}

-- 引入依赖
local Player = require("player")
local Layout = require("layout")
local Config = require("config")
local InventoryUI = require("inventory_ui")

-- === UI 配置参数 ===
-- 1. 尺寸调整：更紧凑
local menuHeight = 80  -- [修改] 从 120 减小到 80
local statusMargin = 15
local statusBarW = 240 -- [修改] 稍微加宽，适配大字体
local statusBarH = 26  -- [修改] 加高，为了放得下 Fonts.medium

-- 2. 配色方案 (Flat UI 风格)
local COLORS = {
    hp      = {0.9, 0.3, 0.3, 1}, -- 鲜红
    mp      = {0.3, 0.5, 0.9, 1}, -- 亮蓝
    exp     = {0.4, 0.8, 0.4, 1}, -- 柔和绿
    bg_bar  = {0.2, 0.2, 0.2, 0.8}, -- 进度条深色底
    bg_menu = {0.1, 0.1, 0.15, 0.75}, -- [修改] 菜单背景恢复半透明
    btn_idle= {1, 1, 1, 0.2},     -- 按钮默认（半透明白框）
    btn_hov = {0.2, 0.8, 1, 0.6}, -- 按钮悬停（高亮蓝）
    text    = {1, 1, 1, 1},
    shadow  = {0, 0, 0, 0.8}      -- 文字阴影
}

GameUI.buttons = {}

-- === 初始化 ===
function GameUI.load()
    -- 重新计算按钮布局
    local menuTop = Layout.virtualHeight - menuHeight
    local btnW = 110
    local btnH = 40
    -- 垂直居中
    local btnY = menuTop + (menuHeight - btnH) / 2
    
    -- 水平居中排列
    local totalBtnW = btnW * 4
    local gap = 20
    local totalW = totalBtnW + gap * 3
    local startX = (Layout.virtualWidth - totalW) / 2
    
    GameUI.buttons = {
        {
            x = startX, y = btnY, w = btnW, h = btnH, 
            text = "状态",
            onClick = function() currentScene = "player" end
        },
        {
            x = startX + (btnW + gap), y = btnY, w = btnW, h = btnH, 
            text = "背包",
            onClick = function()
                InventoryUI.previousScene = currentScene
                currentScene = "inventory"
            end
        },
        {
            x = startX + (btnW + gap) * 2, y = btnY, w = btnW, h = btnH, 
            text = "保存",
            onClick = function() 
                Config.save()
                -- 这里可以加一个简单的浮动提示，暂略
                print(">>> 游戏已手动保存 <<<") 
            end
        },
        {
            x = startX + (btnW + gap) * 3, y = btnY, w = btnW, h = btnH, 
            text = "主菜单",
            onClick = function() 
                Config.save()
                currentScene = "title" 
            end
        }
    }
end

-- === 绘制状态栏 ===
local function drawStatusBar()
    -- 1. 整体容器背景 (让数值在任何地图上都清晰可见)
    local vX = Layout.virtualWidth - statusBarW - statusMargin
    local vY = statusMargin
    -- 容器高度：3个条 + 间距 + 内边距
    local totalH = statusBarH * 3 + 10 * 2 + 10 
    
    local sX, sY = Layout.toScreen(vX, vY)
    local sW, sH = Layout.toScreen(statusBarW, statusBarH)
    local sContainerH = select(2, Layout.toScreen(0, totalH))
    local _, sGap = Layout.toScreen(0, 8) -- 间距
    local _, sPad = Layout.toScreen(0, 5) -- 内边距

    -- 绘制半透明底板 (圆角)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", sX - sPad, sY - sPad, sW + sPad*2, sContainerH, 10, 10)

    -- 辅助：绘制单条
    local function drawBar(label, cur, max, color, index)
        local drawY = sY + (index - 1) * (sH + sGap)
        
        -- 条背景
        love.graphics.setColor(COLORS.bg_bar)
        love.graphics.rectangle("fill", sX, drawY, sW, sH, 6, 6) -- 圆角
        
        -- 进度填充
        local ratio = math.max(0, math.min(cur / max, 1))
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", sX, drawY, sW * ratio, sH, 6, 6)
        
        -- 装饰线 (增加一点质感)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", sX, drawY, sW * ratio, sH * 0.4, 6, 6)

        -- 文字绘制
        -- [修改] 使用 medium 字体让血条数字变大
        local font = Fonts.medium or love.graphics.getFont()
        love.graphics.setFont(font)
        
        local text = string.format("%d / %d", math.floor(cur), math.floor(max))
        -- 经验条只显示百分比，显得不那么拥挤
        if label == "EXP" then 
            text = string.format("%.1f%%", (cur/max)*100) 
        end
        
        -- 文字阴影 (Shadow) - 保证可读性
        local tx = sX + 10
        local ty = drawY + (sH - font:getHeight())/2 - 2 -- 微调居中
        
        love.graphics.setColor(COLORS.shadow)
        love.graphics.print(label, tx + 1, ty + 1)
        love.graphics.printf(text, sX, ty + 1, sW - 10, "right")

        -- 文字本体
        love.graphics.setColor(COLORS.text)
        love.graphics.print(label, tx, ty)
        love.graphics.printf(text, sX, ty, sW - 10, "right")
    end

    drawBar("HP", Player.data.hp, Player.data.maxHp, COLORS.hp, 1)
    drawBar("MP", Player.data.mp, Player.data.maxMp, COLORS.mp, 2)
    
    local nextLevelExp = Player.data.level * 100
    drawBar("EXP", Player.data.exp, nextLevelExp, COLORS.exp, 3)
    
    -- 恢复默认
    love.graphics.setColor(1, 1, 1)
end

-- === 绘制底部菜单 ===
local function drawMenu()
    -- 1. 绘制半透明背景
    local vBgY = Layout.virtualHeight - menuHeight
    local bx, by = Layout.toScreen(0, vBgY)
    local bw, bh = Layout.toScreen(Layout.virtualWidth, menuHeight)

    -- [修改] 使用半透明颜色
    love.graphics.setColor(COLORS.bg_menu)
    love.graphics.rectangle("fill", bx, by, bw, bh)
    
    -- 顶部装饰亮线
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.line(bx, by, bx + bw, by)

    -- 2. 绘制按钮
    local font = Fonts.medium or love.graphics.getFont()
    love.graphics.setFont(font)
    
    local hoveredIndex = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), GameUI.buttons)

    for i, btn in ipairs(GameUI.buttons) do
        local btnX, btnY = Layout.toScreen(btn.x, btn.y)
        local btnW, btnH = Layout.toScreen(btn.w, btn.h)
        local radius = 8 -- 圆角半径
        
        if i == hoveredIndex then
            -- 悬停：填充高亮色
            love.graphics.setColor(COLORS.btn_hov)
            love.graphics.rectangle("fill", btnX, btnY + 2, btnW, btnH, radius, radius) -- 稍微下沉一点产生按压感
        else
            -- 默认：半透明填充 + 边框
            love.graphics.setColor(COLORS.btn_idle)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, radius, radius)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH, radius, radius)
        end
        
        -- 按钮文字
        love.graphics.setColor(COLORS.text)
        local textY = btnY + (btnH - font:getHeight()) / 2
        if i == hoveredIndex then textY = textY + 2 end -- 文字跟随下沉
        
        love.graphics.printf(btn.text, btnX, textY, btnW, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

-- === 主绘制函数 ===
function GameUI.draw()
    drawStatusBar()
    drawMenu()
end

-- === 输入处理 (不变) ===
function GameUI.mousepressed(x, y, button)
    if button == 1 then
        local index = Layout.mousepressed(x, y, button, GameUI.buttons)
        if index and GameUI.buttons[index].onClick then
            GameUI.buttons[index].onClick()
            return true
        end
    end
    return false
end

return GameUI