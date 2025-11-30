local EntitySpawner = require("EntitySpawner")
local Core = require("core")

-- === 1. 定义状态机状态 ===
local STATES = {
    IDLE     = "idle",
    CHASE    = "chase",
    COOLDOWN = "cooldown"
}

-- 怪物模板
local monsterTypes = {
    {name="史莱姆", level=1, hp=50, color={0.6,0.6,1}, speed=30, range=100}, 
    {name="哥布林", level=2, hp=80, color={0,0.8,0.2}, speed=50, range=150},
    {name="蝙蝠",   level=3, hp=40, color={0,0.2,0.8}, speed=80, range=200}
}
-- BOSS 模板
local bossTemplate = {
    name = "魔王",
    level = 10,
    hp = 500,      -- 血量厚
    maxHp = 500,
    color = {0.8, 0, 0}, -- 深红色
    speed = 40,
    range = 300,   -- 警戒范围大
    isBoss = true, -- 标记为 BOSS
    attack = 30    -- 基础攻击力
}
-- 辅助函数：随机游荡逻辑
local function updateIdleMovement(monster, dt, Core)
    monster.stateTimer = monster.stateTimer - dt
    if monster.stateTimer <= 0 then
        monster.stateTimer = love.math.random(1, 3)
        if love.math.random() > 0.5 then
            monster.wanderDir = love.math.random() * math.pi * 2
        else
            monster.wanderDir = nil
        end
    end

    if monster.wanderDir then
        local dx = math.cos(monster.wanderDir) * monster.speed * 0.5 * dt
        local dy = math.sin(monster.wanderDir) * monster.speed * 0.5 * dt
        
        -- 简单防撞
        local tx = math.floor((monster.x + dx + 16)/32) -- +16取中心点
        local ty = math.floor((monster.y + dy + 16)/32)
        if not Core.isSolidTile(tx, ty) then
            monster.x = monster.x + dx
            monster.y = monster.y + dy
        else
            monster.wanderDir = monster.wanderDir + math.pi 
        end
    end
end

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
        state = STATES.IDLE,
        detectionRange = mType.range,
        cooldown = 0,
        cooldownDuration = 5.0,
        stateTimer = 0,
        wanderDir = nil
    }
end
-- === 配置怪物生成器 ===
local Monster = EntitySpawner.new({
    -- [关键修改 1] 扩大最大生成半径
    -- 假设 tileSize=32，30格 = 960像素。这保证了生成范围足够大，包裹住 noSpawnRange
    radius        = 30,

    -- [关键修改 2] 屏幕安全距离
    -- 假设屏幕宽800，一半是400。设为450保证在屏幕外生成。
    -- 现在的有效生成区域是：距离玩家 450像素 到 960像素 之间的圆环区域。
    noSpawnRange  = 450,
    
    -- [关键修改 3] 提高密度概率
    -- 新算法中尝试次数少，需要提高单次成功率。
    -- 0.1 * 10 = 1.0 (100%)。这意味着只要位置合法（不是墙，不在屏幕内），就一定会生成。
    density       = 0.12, 

    -- [关键修改 4] 加快尝试频率
    -- 每 0.1 秒尝试生成一次。之前是 1.0 秒太慢了。
    spawnInterval = 0.1,

    maxNearby     = 10,   -- 屏幕周围最大怪物数
    maxDistance   = 45,   -- 离多远删除 (要比 radius 大，防止刚生成就删除)

    isSolid = function(tx, ty)
        return Core.isSolidTile(tx, ty)
    end,

    spawnFunc = spawnMonster,

    updateFunc = function(monster, dt, player, tileSize, Core)
        local target = player.data or player
        if not target or not target.x or not target.y then return end

        local distSq = (monster.x - target.x)^2 + (monster.y - target.y)^2
        local dist = math.sqrt(distSq)

        if monster.state == STATES.COOLDOWN then
            monster.cooldown = monster.cooldown - dt
            if monster.cooldown <= 0 then
                monster.cooldown = 0
                monster.state = STATES.IDLE
            end

        elseif monster.state == STATES.CHASE then
            if dist > monster.detectionRange * 1.5 then
                monster.state = STATES.IDLE
                monster.stateTimer = 0
            else
                Core.updateMonsterMovement(monster, dt, tileSize, player) 
            end

        elseif monster.state == STATES.IDLE then
            if dist < monster.detectionRange then
                monster.state = STATES.CHASE
            else
                updateIdleMovement(monster, dt, Core)
            end
        end
        
        if monster.cooldown > 0 and monster.state ~= STATES.COOLDOWN then
            monster.state = STATES.COOLDOWN
        end
    end,

    drawFunc = function(monster, camX, camY)
        local x, y = monster.x - camX, monster.y - camY
        
        if monster.state == STATES.COOLDOWN then
            local t = love.timer.getTime()
            local alpha = (math.floor(t * 5) % 2 == 0) and 0.3 or 0.8
            love.graphics.setColor(monster.color[1], monster.color[2], monster.color[3], alpha)
        elseif monster.state == STATES.CHASE then
            love.graphics.setColor(1, 0, 0, 1)
        else
            love.graphics.setColor(monster.color)
        end

        love.graphics.rectangle("fill", x, y, monster.w, monster.h)
        
        love.graphics.setColor(1,1,1)
        love.graphics.print(monster.name, x, y - 20)
        
        if monster.state == STATES.CHASE then
            love.graphics.print("!", x + 10, y - 35)
        elseif monster.state == STATES.COOLDOWN then
            local timeLeft = string.format("%.1f", monster.cooldown)
            love.graphics.print(timeLeft, x + 5, y - 35)
        end
    end
})
function Monster.spawnBoss(x, y)
    local boss = {
        x = x, y = y,
        w = 64, h = 64, -- BOSS 体积大一点
        color = bossTemplate.color,
        name = bossTemplate.name,
        level = bossTemplate.level,
        hp = bossTemplate.maxHp,
        maxHp = bossTemplate.maxHp,
        speed = bossTemplate.speed,
        state = "idle",
        detectionRange = bossTemplate.range,
        attack = bossTemplate.attack,
        isBoss = true, -- 关键标记
        cooldown = 0,
        stateTimer = 0
    }
    table.insert(Monster.list, boss)
    return boss
end

return Monster