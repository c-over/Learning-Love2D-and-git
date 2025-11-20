-- monster.lua
local Monster = {}

-- 怪物列表
Monster.list = {}

-- 初始化怪物
function Monster.load()
    Monster.list = {
        {x = 200, y = 200, w = 32, h = 32, color = {1, 0, 0}, name = "史莱姆", level = 1, hp = 200,speed = 1},
        {x = 400, y = 300, w = 32, h = 32, color = {0, 1, 0}, name = "哥布林", level = 2, hp = 80,speed = 1},
        {x = 600, y = 250, w = 32, h = 32, color = {0, 0, 1}, name = "蝙蝠", level = 3, hp = 60,speed = 1}
    }
end

function Monster.update(dt, player, tileSize, noiseScale, wallThreshold,Core)
    for _, monster in ipairs(Monster.list) do
        Core.updateMonsterMovement(monster, dt, tileSize, noiseScale, wallThreshold, player)
    end
end

-- 绘制怪物
function Monster.draw(camX, camY)
    for _, monster in ipairs(Monster.list) do
        love.graphics.setColor(monster.color)
        love.graphics.rectangle("fill", monster.x - camX, monster.y - camY, monster.w, monster.h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(monster.name, monster.x - camX, monster.y - camY - 20)
    end
end

-- 检测玩家是否碰到怪物（AABB）
function Monster.checkCollision(player, aabbOverlap)
    for i, monster in ipairs(Monster.list) do
        local px = player.x - player.w/2
        local py = player.y - player.h/2
        if aabbOverlap(px, py, player.w, player.h,
                       monster.x, monster.y, monster.w, monster.h) then
            return i, monster
        end
    end
    return nil, nil
end

return Monster
