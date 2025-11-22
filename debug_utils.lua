-- debug.lua
local Debug = {}
local Layout = require("layout")

-- 通用碰撞箱绘制
function Debug.drawHitbox(entity, camX, camY, r, g, b)
    -- 默认颜色：红色
    r, g, b = r or 1, g or 0, b or 0

    -- 计算左上角坐标（以中心点为基准）
    local ax = entity.x - entity.w / 2
    local ay = entity.y - entity.h / 2

    -- 半透明填充
    love.graphics.setColor(r, g, b, 0.3)
    love.graphics.rectangle("fill", ax - camX, ay - camY, entity.w, entity.h)

    -- 边框
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("line", ax - camX, ay - camY, entity.w, entity.h)

    -- 十字线标记中心点
    local cx = entity.x - camX
    local cy = entity.y - camY
    love.graphics.setColor(1, 1, 0, 1) -- 黄色十字线
    love.graphics.line(cx - 5, cy, cx + 5, cy) -- 横线
    love.graphics.line(cx, cy - 5, cx, cy + 5) -- 竖线

    -- 恢复默认颜色
    love.graphics.setColor(1, 1, 1, 1)
end

function Debug.drawHitboxes(entities, camX, camY, r, g, b)
    for _, e in ipairs(entities) do
        Debug.drawHitbox(e, camX, camY, r, g, b)
    end
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
    local posText = string.format("Player: (%.d, %.d)", player.x or 0, player.y or 0)

    love.graphics.print("游戏运行时间: " .. string.format("%.2f", counter), 200, 200)
    love.graphics.print(posText, w-300, 120)
    love.graphics.print(keysText, w-300, 140)
end

function Debug.openBag()
    InventoryButton = 
    {x = 250, y = 380, w = 200, h = 40, text = "背包(调试用)", onClick = function()
        currentScene = "inventory" 
    end}
    table.insert(Title.Buttons, InventoryButton)
end

return Debug
