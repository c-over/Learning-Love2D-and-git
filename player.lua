local Config = require("config")
local Layout = require("layout")
local Player = {}

local data = {}
local buttons = {}
local selectedIndex = nil -- 用来记录悬停的按钮

function Player.load()
    -- 从存档读取数据
    Config.load()
    local save = Config.get()

    -- 假设 save.json 里有 player 字段
    data.name = save.player.name or "未命名"
    data.level = save.player.level or 1
    data.hp    = save.player.hp or 100

    -- 定义按钮（只定义一次，绘制和交互都用这个表）
    buttons = {
        {
            x = 200, y = 300, w = 200, h = 50,
            text = "提升等级",
            onClick = function()
                data.level = data.level + 1
                data.hp = data.hp + 100
                -- 保存数据
                Config.updatePlayer({name = data.name, level = data.level, hp = data.hp})
            end
        },
        {
            x = 200, y = 370, w = 200, h = 50,
            text = "返回菜单",
            onClick = function()
                -- 保存数据
                Config.updatePlayer({name = data.name, level = data.level, hp = data.hp})
                return "menu"
            end
        }
    }
end

function Player.draw()
    local infoLines = {
        "名字: " .. data.name,
        "等级: " .. data.level,
        "血量: " .. data.hp
    }
    Layout.draw("玩家信息", infoLines, buttons, selectedIndex)
end

function Player.mousepressed(x, y, button)
    local result = Layout.mousepressed(x, y, button, buttons)
    if result == "menu" then
        return "menu"
    end
    return "game"
end

function Player.mousemoved(x, y)
    selectedIndex = Layout.mousemoved(x, y, buttons)
end

return Player
