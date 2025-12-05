local Core = require("core")

local Merchant = {}

Merchant.list = {
    {
        x = 64, y = 32, w = 32, h = 32,
        name = "商人",
        items = {
            {id=1, price=50}, -- 生命药水
            {id=2, price=120}, -- 魔力药水
            {id=3, price=200},  -- 经验药水
            -- === 有限耗材 (库存 > 1) ===
            {id=4, price=300, stock=5}, -- 锚：只有5个

            -- === 唯一装备 (库存 = 1) ===
            {id=6, price=100, stock=1}, -- 铁头盔
            {id=7, price=200, stock=1}, -- 铁胸甲
            {id=8, price=150, stock=1}, -- 铁护腿
            {id=10, price=10, stock=1}, --攻击戒指
            {id=11, price=10, stock=1}, --守护戒指
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

function Merchant.checkCollision(player, _) -- 第二个参数不再需要 aabbOverlap
    for i, npc in ipairs(Merchant.list) do
        -- 判定距离 < 50 像素即可交互
        if npc.x and Core.getDistance(player, npc) < 60 then
            return npc
        end
    end
    return nil
end

return Merchant
