local Core = require("core")

local Merchant = {}

Merchant.list = {
    {
        x = 64, y = 32, w = 32, h = 32,
        name = "商人",
        items = {
            {id=1, price=50}, -- 经验药水
            {id=2, price=120}, -- 大经验药水
            {id=3, price=200}  -- 生命药水
        }
    }
}

function Merchant.draw(camX, camY)
    for _, npc in ipairs(Merchant.list) do
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("fill", npc.x - camX, npc.y - camY, npc.w, npc.h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(npc.name, npc.x - camX, npc.y - camY - 20)
    end
end

function Merchant.checkCollision(player, aabbOverlap)
    for i, npc in ipairs(Merchant.list) do
        if Core.aabbOverlap(player.x, player.y, player.w, player.h,
                       npc.x, npc.y, npc.w, npc.h) then
            return npc
        end
    end
    return nil
end

return Merchant
