local EntitySpawner = require("EntitySpawner")
local Core = require("core")

-- 怪物模板
local monsterTypes = {
    {name="史莱姆", level=1, hp=200, color={1,0,0}, speed=1},
    {name="哥布林", level=2, hp=80,  color={0,1,0}, speed=1},
    {name="蝙蝠",   level=3, hp=60,  color={0,0,1}, speed=2}
}

-- 生成怪物对象
local function spawnMonster(tx, ty, tileSize)
    local mType = monsterTypes[love.math.random(#monsterTypes)]
    return {
        x = tx * tileSize,
        y = ty * tileSize,
        w = 32, h = 32,
        color = mType.color,
        name  = mType.name,
        level = mType.level,
        hp    = mType.hp,
        speed = mType.speed
    }
end

-- 配置怪物生成器
local Monster = EntitySpawner.new({
    spawnInterval = 1.0,
    noSpawnRange  = 600,
    density       = 0.01,
    radius        = 20,
    maxNearby     = 15,
    maxDistance   = 40,
    isSolid       = function(tx, ty, noiseScale, wallThreshold)
        return love.math.noise(tx * noiseScale, ty * noiseScale) < wallThreshold
    end,
    spawnFunc     = spawnMonster,
    updateFunc    = function(monster, dt, player, tileSize, noiseScale, wallThreshold)
        Core.updateMonsterMovement(monster, dt, tileSize, noiseScale, wallThreshold, player)
    end,
    drawFunc      = function(monster, camX, camY)
        love.graphics.setColor(monster.color)
        love.graphics.rectangle("fill", monster.x - camX, monster.y - camY, monster.w, monster.h)
        love.graphics.setColor(1,1,1)
        love.graphics.print(monster.name, monster.x - camX, monster.y - camY - 20)
    end
})

return Monster
