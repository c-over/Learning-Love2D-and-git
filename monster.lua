local Monster = {}

Monster.list = {}

-- 怪物模板
local monsterTypes = {
    {name="史莱姆", level=1, hp=200, color={1,0,0}, speed=1},
    {name="哥布林", level=2, hp=80,  color={0,1,0}, speed=1},
    {name="蝙蝠",   level=3, hp=60,  color={0,0,1}, speed=2}
}

function Monster.load()
    Monster.list = {}
end

-- 根据噪声判断是否是墙
local function isSolid(tx, ty, noiseScale, wallThreshold)
    local n = love.math.noise(tx * noiseScale, ty * noiseScale)
    return n < wallThreshold
end

-- 随机生成怪物在某个 tile 上
local function spawnMonster(tx, ty, tileSize)
    local mType = monsterTypes[love.math.random(#monsterTypes)]
    return {
        x = tx * tileSize,
        y = ty * tileSize,
        w = 32, h = 32,
        color = mType.color,
        name = mType.name,
        level = mType.level,
        hp = mType.hp,
        speed = mType.speed
    }
end

-- 生成计时器
local spawnTimer = 0
local spawnInterval = 1.0 -- 每隔 1 秒尝试生成一次
-- 禁止生成范围（相对玩家坐标）
local noSpawnRange = 600

function Monster.generateAroundPlayer(player, tileSize, noiseScale, wallThreshold, density, radius, maxNearby)
    local px = math.floor(player.x / tileSize)
    local py = math.floor(player.y / tileSize)

    -- 统计周围怪物数量
    local nearbyCount = 0
    for _, m in ipairs(Monster.list) do
        local dx = math.floor(m.x / tileSize) - px
        local dy = math.floor(m.y / tileSize) - py
        if dx*dx + dy*dy <= radius*radius then
            nearbyCount = nearbyCount + 1
        end
    end
    if nearbyCount >= maxNearby then return end

    -- 按概率生成怪物
    for ty = py - radius, py + radius do
        for tx = px - radius, px + radius do
            -- 检查是否在禁止生成范围内
            local dx = tx - px
            local dy = ty - py
            if math.abs(dx * tileSize) > noSpawnRange or math.abs(dy * tileSize) > noSpawnRange then
                if love.math.random() < density then
                    if not isSolid(tx, ty, noiseScale, wallThreshold) then
                        local exists = false
                        for _, m in ipairs(Monster.list) do
                            if math.floor(m.x / tileSize) == tx and math.floor(m.y / tileSize) == ty then
                                exists = true
                                break
                            end
                        end
                        if not exists then
                            table.insert(Monster.list, spawnMonster(tx, ty, tileSize))
                        end
                    end
                end
            end
        end
    end
end


function Monster.update(dt, player, tileSize, noiseScale, wallThreshold, Core)
    -- 控制生成频率
    spawnTimer = spawnTimer + dt
    if spawnTimer >= spawnInterval then
        spawnTimer = 0
        Monster.generateAroundPlayer(player, tileSize, noiseScale, wallThreshold, 0.01, 20, 15)
    end

    -- 更新怪物移动
    for _, monster in ipairs(Monster.list) do
        Core.updateMonsterMovement(monster, dt, tileSize, noiseScale, wallThreshold, player)
    end

    -- 清理远离玩家的怪物
    local maxDistance = 40 * tileSize
    local px, py = player.x, player.y
    for i = #Monster.list, 1, -1 do
        local m = Monster.list[i]
        local dx = m.x - px
        local dy = m.y - py
        if dx*dx + dy*dy > maxDistance*maxDistance then
            table.remove(Monster.list, i)
        end
    end
end
function Monster.draw(camX, camY)
    for _, monster in ipairs(Monster.list) do
        love.graphics.setColor(monster.color)
        love.graphics.rectangle("fill", monster.x - camX, monster.y - camY, monster.w, monster.h)
        love.graphics.setColor(1,1,1)
        love.graphics.print(monster.name, monster.x - camX, monster.y - camY - 20)
    end
end

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
