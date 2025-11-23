-- Menu.lua
local Layout = require("Layout")
local Config = require("config")
local InventoryUI = require("inventory_ui")

local Menu = {}

function Menu.createMenuButtons(Game, menuHeight, h)
    local menuTop = h - menuHeight
    return {
        {
            x = 100, y = menuTop + (menuHeight - 40) / 2,
            w = 120, h = 40, text = "玩家信息",
            onClick = function() currentScene = "player" end
        },
        {
            x = 250, y = menuTop + (menuHeight - 40) / 2,
            w = 120, h = 40, text = "背包",
            onClick = function()
                InventoryUI.previousScene = currentScene
                currentScene = "inventory"
            end
        },
        {
            x = 400, y = menuTop + (menuHeight - 40) / 2,
            w = 120, h = 40, text = "返回标题",
            onClick = function() currentScene = "title" end
        },
        {
            x = 550, y = menuTop + (menuHeight - 40) / 2,
            w = 180, h = 40, text = "设置重生点",
            onClick = function() Config.setRespawn(Game.player.x, Game.player.y) end
        }
    }
end

function Menu.draw(menuButtons, menuHeight, w, h)
    local offsetY = h - menuHeight - Layout.virtualHeight
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", 0, h - menuHeight, w, menuHeight)

    local infoLines = {""}
    local hoveredIndex = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), menuButtons or {})
    Layout.draw("", infoLines, menuButtons, hoveredIndex, offsetY)
end

return Menu
