-- debug.lua
local Debug = {}
local Layout = require("layout")

-- 绘制玩家碰撞箱
function Debug.drawPlayerHitbox(player, camX, camY)

    -- 半透明填充
    love.graphics.setColor(1, 0, 0, 0.3)
    love.graphics.rectangle("fill", player.x-camX, player.y-camY, player.w, player.h)

    -- 边框
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("line", player.x-camX,player.y-camY, player.w, player.h)

    -- 恢复默认颜色
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制调试信息（按键、坐标等）
function Debug.drawInfo(player, counter)
    local w = love.graphics.getWidth()
    local pressedKeys = {}
    if love.keyboard.isDown("up") then table.insert(pressedKeys, "UP") end
    if love.keyboard.isDown("down") then table.insert(pressedKeys, "DOWN") end
    if love.keyboard.isDown("left") then table.insert(pressedKeys, "LEFT") end
    if love.keyboard.isDown("right") then table.insert(pressedKeys, "RIGHT") end

    local keysText = "Keys: " .. table.concat(pressedKeys, ", ")
    local posText = string.format("Player: (%.d, %.d)", player.x, player.y)

    love.graphics.print("游戏运行时间: " .. string.format("%.2f", counter), 200, 200)
    love.graphics.print(posText, w-250, 20)
    love.graphics.print(keysText, w-250, 40)
end

function Debug.openBag()
    InventoryButton = 
    {x = 250, y = 380, w = 200, h = 40, text = "背包(调试用)", onClick = function()
        currentScene = "inventory" 
    end}
    table.insert(Title.Buttons, InventoryButton)
end

return Debug
