-- settings.lua
local Settings = {}
local Config = require("config")

local options = {"音量", "语言", "返回菜单"}
local selected = 1
local volume = 100
local language = "中文"
local bgMusicRef
local selectedIndex = nil -- 用来记录悬停的按钮

function Settings.init(music)
    Config.load()
    local data = Config.get()
    volume = data.settings.volume or 100
    language = data.settings.language or "中文"

    if music then
        bgMusicRef = music
        bgMusicRef:setVolume(volume / 100)
    end

    -- 定义按钮
    buttons = {
        {
            x = 240, y = 160, w = 200, h = 40,
            getText = function() return "音量：" .. volume .. "%" end,
            onClick = function()
                volume = math.min(100, volume + 10)
                Config.setVolume(volume)
                if bgMusicRef then
                    bgMusicRef:setVolume(volume / 100)
                end
            end
        },
        {
            x = 240, y = 210, w = 200, h = 40,
            getText = function() return "语言：" .. language end,
            onClick = function()
                language = (language == "中文") and "English" or "中文"
                Config.setLanguage(language)
            end
        },
        {
            x = 240, y = 260, w = 200, h = 40,
            getText = function() return "返回菜单" end,
            onClick = function()
                return "menu"
            end
        }
    }
end

-- 键盘操作
function Settings.keypressed(key)
    if key == "up" then
        selected = selected - 1
        if selected < 1 then selected = #options end
    elseif key == "down" then
        selected = selected + 1
        if selected > #options then selected = 1 end
    end

    if options[selected] == "音量" then
        if key == "left" then
            volume = math.max(0, volume - 10)
        elseif key == "right" then
            volume = math.min(100, volume + 10)
        end
        Config.setVolume(volume)
        if bgMusicRef then
            bgMusicRef:setVolume(volume / 100)
        end
    elseif options[selected] == "语言" and (key == "left" or key == "right") then
        language = (language == "中文") and "English" or "中文"
        Config.setLanguage(language)
    elseif key == "return" and options[selected] == "返回菜单" then
        return "menu"
    end
    return "settings"
end

-- 鼠标点击
function Settings.mousepressed(x, y, button)
    if button ~= 1 then return "settings" end
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            local result = btn.onClick()
            if result == "menu" then
                return "menu"
            end
        end
    end
    return "settings"
end

-- 绘制
function Settings.draw()
    love.graphics.print("设置界面", 220, 100)

    for i, btn in ipairs(buttons) do
        local text = btn.getText()
        if selectedIndex == i then
            love.graphics.setColor(0.2, 0.8, 1)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        love.graphics.printf(text, btn.x, btn.y + 10, btn.w, "center")
    end

    love.graphics.setColor(1, 1, 1)
end
-- 鼠标移动检测
function Settings.mousemoved(x, y)
    selectedIndex = nil
    for i, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            selectedIndex = i
        end
    end
end
return Settings