-- StatusBar.lua
local Player = require("player")

local StatusBar = {}

function StatusBar.draw()
    local margin = 20
    local barWidth = 200
    local barHeight = 20
    local x = love.graphics.getWidth() - barWidth - margin
    local y = margin

    -- HP
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    local hpRatio = Player.data.hp / Player.data.maxHp
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", x, y, barWidth * hpRatio, barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. Player.data.hp .. "/" .. Player.data.maxHp, x, y)

    -- MP
    local mpY = y + barHeight + 5
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, mpY, barWidth, barHeight)
    local mpRatio = Player.data.mp / Player.data.maxMp
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", x, mpY, barWidth * mpRatio, barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("MP: " .. Player.data.mp .. "/" .. Player.data.maxMp, x, mpY)

    -- EXP
    local expY = mpY + barHeight + 5
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, expY, barWidth, barHeight)
    local expRatio = Player.data.exp / (Player.data.level * 100)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", x, expY, barWidth * expRatio, barHeight)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("EXP: " .. Player.data.exp .. "/" .. (Player.data.level * 100), x, expY)
end

return StatusBar
