--settings.lua
local Layout = require("layout")
local Config = require("config")
local Settings = {}

local buttons = {}
local selectedIndex = nil
local bgMusic
local volume = 100
local language = "中文"

function Settings.init(music)
    bgMusic = music
    Config.load()
    local data = Config.get()
    volume = data.settings.volume or 100
    language = data.settings.language or "中文"

    buttons = {
        {text = "音量 +", x = 250, y = 250, w = 200, h = 40,
         onClick = function()
            volume = math.min(100, volume + 10)
            bgMusic:setVolume(volume / 100)
            Config.setVolume(volume)
         end},
        {text = "音量 -", x = 250, y = 310, w = 200, h = 40,
         onClick = function()
            volume = math.max(0, volume - 10)
            bgMusic:setVolume(volume / 100)
            Config.setVolume(volume)
         end},
        {text = "切换语言", x = 250, y = 370, w = 200, h = 40,
         onClick = function()
            if language == "中文" then
                language = "English"
            else
                language = "中文"
            end
            Config.setLanguage(language)
         end},
        {text = "返回菜单", x = 250, y = 430, w = 200, h = 40,
         onClick = function()
            return "menu"
         end}
    }
end

function Settings.draw()
    local infoLines = {
        "音量：" .. volume .. "%",
        "语言：" .. language
    }
    Layout.draw("设置界面", infoLines, buttons, selectedIndex)
end

function Settings.mousemoved(x, y)
    selectedIndex = Layout.mousemoved(x, y, buttons)
    return selectedIndex
end

function Settings.mousepressed(x, y, button)
    return Layout.mousepressed(x, y, button, buttons)
end

return Settings
