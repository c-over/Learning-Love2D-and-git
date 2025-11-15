-- player.lua
local Config = require("config")
local Player = {}

local data = {}
local button = {}
local selectedIndex = nil -- 用来记录悬停的按钮

function Player.load()
    -- 从存档读取数据
    Config.load()
    local save = Config.get()

    -- 假设 save.json 里有 player 字段
    data.name = save.player.name or "未命名"
    data.level = save.player.level or 1
    data.hp    = save.player.hp or 100

    -- 定义按钮
    buttons = {
        {
            x = 200, y = 300, w = 200, h = 50,
            text = "提升等级",
            onClick = function()
                data.level = data.level + 1
                data.hp = data.hp + 100
                -- 保存数据
                Config.updatePlayer({name = data.name,level = data.level,hp = data.hp})
            end
        },
        {
            x = 200, y = 370, w = 200, h = 50,
            text = "返回菜单",
            onClick = function()
                -- 保存数据
                Config.updatePlayer({name = data.name,level = data.level,hp = data.hp})
                return "menu"
            end
        }
    }
end

function Player.draw()
    Player.load()
    love.graphics.print("玩家信息", 200, 100)
    love.graphics.print("名字: " .. data.name, 200, 140)
    love.graphics.print("等级: " .. data.level, 200, 180)
    love.graphics.print("血量: " .. data.hp, 200, 220)
     -- 绘制按钮
    for i, btn in ipairs(buttons) do
        if selectedIndex == i then
            love.graphics.setColor(0.2, 0.8, 1) -- 悬停高亮
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        love.graphics.printf(btn.text, btn.x, btn.y + 15, btn.w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function Player.mousepressed(x, y, button)
    if button ~= 1 then return "game" end
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            local result = btn.onClick()
            if result == "menu" then
                return "menu"
            end
        end
    end
    return "game"
end
-- 鼠标移动检测
function Player.mousemoved(x, y)
    selectedIndex = nil
    for i, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            selectedIndex = i
        end
    end
end

return Player
