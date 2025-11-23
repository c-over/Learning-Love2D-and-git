local EntitySpawner = require("EntitySpawner")
local Core = require("core")

-- 怪物模板
local monsterTypes = {
    {name="史莱姆", level=1, hp=200, color={0.6,0.6,1}, speed=1},
    {name="哥布林", level=2, hp=80,  color={0,0.8,0.2}, speed=2},
    {name="蝙蝠",   level=3, hp=60,  color={0,0.2,0.8}, speed=5}
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
        speed = mType.speed,
        cooldown = 0,             -- 当前冷却剩余时间
        cooldownDuration = 5.0    -- 默认冷却时长，可按怪物类型调整
    }
end

-- 配置怪物生成器
local Monster = EntitySpawner.new({
    radius        = 20,   -- 玩家周围多少格(tile)范围内尝试生成怪物，半径为10表示21x21区域
    maxNearby     = 15,    -- 限制玩家附近同时存在的怪物数量，超过则不再生成
    noSpawnRange  = 600,   -- 玩家周围的安全区半径(像素)，在此范围内不会生成怪物
    density       = 0.01, -- 每个候选格子生成怪物的概率，值越大怪物越密集
    spawnInterval = 1.0,    -- 怪物生成的时间间隔(秒)，每隔2秒尝试一次生成
    maxDistance   = 40,   -- 怪物离玩家超过多少格(tile)时会被清理，避免远处怪物占用资源

    -- 使用 Core.isSolidTile 判定是否为不可进入的方块(树、石头、水等)，避免怪物生成在障碍物里
    isSolid = function(tx, ty)
        return Core.isSolidTile(tx, ty)
    end,

    -- 定义具体的怪物生成函数，负责创建怪物对象(位置、大小、属性等)
    spawnFunc = spawnMonster,

    updateFunc = function(monster, dt, player, tileSize, Core)
        if monster.cooldown and monster.cooldown > 0 then
            monster.cooldown = math.max(monster.cooldown - dt, 0)
        end
        Core.updateMonsterMovement(monster, dt, tileSize, player)
    end,
    drawFunc = function(monster, camX, camY)
        local isCooling = monster.cooldown and monster.cooldown > 0
        if isCooling then
            -- 闪烁：每 0.3 秒切换一次可见性
            local t = love.timer.getTime()
            local blink = math.floor(t * 3) % 2 == 0
            if blink then
                love.graphics.setColor(monster.color[1], monster.color[2], monster.color[3], 0.3) -- 半透明
            else
                love.graphics.setColor(monster.color[1], monster.color[2], monster.color[3], 1.0) -- 正常
            end
        else
            love.graphics.setColor(monster.color)
        end

        love.graphics.rectangle("fill", monster.x - camX, monster.y - camY, monster.w, monster.h)
        love.graphics.setColor(1,1,1)
        love.graphics.print(monster.name, monster.x - camX, monster.y - camY - 20)
    end
})

return Monster
