-- settings.lua
local Layout = require("layout")
local Config = require("config")
local Settings = {}

local buttons = {}
local selectedIndex = nil
local bgMusic
local volume = 100
local language = "zh" -- 默认内部代码: zh, en

-- UI 风格配置
local COLORS = {
    bg      = {0.1, 0.1, 0.15, 0.95},
    btn_idle= {1, 1, 1, 0.1},
    btn_hov = {0.2, 0.8, 1, 0.6},
    text    = {1, 1, 1, 1},
    shadow  = {0, 0, 0, 0.8},
    title   = {1, 0.8, 0.2, 1}
}

function Settings.init(music)
    bgMusic = music
    Config.load()
    local data = Config.get()
    
    -- 读取设置
    volume = data.settings.volume or 100
    language = data.settings.language or "zh" -- 确保有默认值
    
    -- [修复 Bug 1] 初始化时立即应用音量
    if bgMusic then bgMusic:setVolume(volume / 100) end

    -- 定义按钮 (虚拟坐标)
    local btnW, btnH = 200, 45
    local startX = (Layout.virtualWidth - btnW) / 2
    local startY = 240
    local gap = 60

    buttons = {
        -- 音量控制
        {
            text = "音量 +", x = startX + 110, y = startY, w = 80, h = btnH,
            onClick = function()
                volume = math.min(100, volume + 10)
                if bgMusic then bgMusic:setVolume(volume / 100) end
                Config.updateSettings("volume", volume)
            end
        },
        {
            text = "音量 -", x = startX - 10, y = startY, w = 80, h = btnH,
            onClick = function()
                volume = math.max(0, volume - 10)
                if bgMusic then bgMusic:setVolume(volume / 100) end
                Config.updateSettings("volume", volume)
            end
        },
        -- 语言切换
        {
            text = "切换语言 / Language", x = startX, y = startY + gap, w = btnW, h = btnH,
            onClick = function()
                -- [修复 Bug 2] 使用标准代码切换
                if language == "zh" then language = "en"
                else language = "zh" end
                Config.updateSettings("language", language)
            end
        },
        -- 返回
        {
            text = "返回标题", x = startX, y = startY + gap * 2.5, w = btnW, h = btnH,
            onClick = function()
                -- 保存配置并返回
                Config.save()
                return "title" -- 返回给 main.lua 用于切换场景
            end
        }
    }
end

function Settings.draw()
    local w, h = love.graphics.getDimensions()
    
    -- 1. 绘制背景 (全屏半透明遮罩)
    love.graphics.setColor(COLORS.bg)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- 2. 绘制标题
    local vTitleX, vTitleY = Layout.virtualWidth / 2, 100
    local sTitleX, sTitleY = Layout.toScreen(vTitleX, vTitleY)
    
    love.graphics.setFont(Fonts.title)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("设置 / Settings", 0, sTitleY, w, "center")
    
    -- 3. 绘制信息文本 (音量和当前语言)
    local vInfoY = 180
    local _, sInfoY = Layout.toScreen(0, vInfoY)
    
    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(1, 1, 1)
    
    -- 音量显示
    local volText = string.format("当前音量: %d%%", volume)
    love.graphics.printf(volText, 0, sInfoY, w, "center")
    
    -- 语言显示
    local langName = (language == "zh") and "中文" or "English"
    local _, sLangY = Layout.toScreen(0, 315) -- 在切换按钮上方一点
    -- 这里的 Y 坐标根据按钮布局微调
    
    -- 4. 绘制按钮
    local fontBtn = Fonts.normal
    love.graphics.setFont(fontBtn)
    
    for i, btn in ipairs(buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local bw, bh = Layout.toScreen(btn.w, btn.h)
        
        -- 悬停效果
        if i == selectedIndex then
            love.graphics.setColor(COLORS.btn_hov)
            -- 悬停时轻微放大或偏移
            love.graphics.rectangle("fill", bx, by + 2, bw, bh, 8, 8)
        else
            love.graphics.setColor(COLORS.btn_idle)
            love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
        end
        
        -- 按钮文字
        love.graphics.setColor(COLORS.text)
        local th = fontBtn:getHeight()
        love.graphics.printf(btn.text, bx, by + (bh - th) / 2, bw, "center")
    end
    
    -- 显示当前语言状态
    local _, sLangTextY = Layout.toScreen(0, 300 + 45 + 10) -- 按钮下方
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Current: " .. langName, 0, sLangTextY, w, "center")
end

function Settings.mousemoved(x, y)
    selectedIndex = Layout.mousemoved(x, y, buttons)
end

function Settings.mousepressed(x, y, button)
    -- Layout.mousepressed 会执行 onClick 并返回其返回值
    return Layout.mousepressed(x, y, button, buttons)
end

function Settings.keypressed(key)
    if key == "escape" then
        return "title"
    end
end

return Settings