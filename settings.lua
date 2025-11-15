-- settings.lua
local Settings = {}
local Config = require("config")

local options = {"音量", "语言", "返回菜单"}
local selected = 1
local volume = 100
local language = "中文"
local bgMusicRef

function Settings.init(music)
    -- 加载存档
    Config.load()
    local data = Config.get()

    -- 从存档恢复音量和语言
    volume = data.settings.volume or 100
    language = data.settings.language or "中文"

    -- 应用音量到音乐
    if music then
        bgMusicRef = music
        bgMusicRef:setVolume(volume / 100)
    end
end

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
            bgMusicRef:setVolume(volume / 100) -- 真正应用到音乐
        end
    elseif options[selected] == "语言" and (key == "left" or key == "right") then
        language = (language == "中文") and "English" or "中文"
        Config.setLanguage(language)
    elseif key == "return" and options[selected] == "返回菜单" then
        return "menu"
    end
    return "settings"
end

function Settings.draw()
    love.graphics.print("设置界面", 220, 50)

    for i, opt in ipairs(options) do
        local y = 120 + i * 40
        local display = opt
        if opt == "音量" then
            display = opt .. "：" .. volume .. "%"
        elseif opt == "语言" then
            display = opt .. "：" .. language
        end

        if i == selected then
            love.graphics.setColor(0, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.print(display, 240, y)
    end

    love.graphics.setColor(1, 1, 1)
end

return Settings
