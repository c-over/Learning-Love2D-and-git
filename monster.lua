local EntitySpawner = require("EntitySpawner")
local Core = require("core")

-- === 1. 资源加载 ===
local monsterTextures = {
    slime = love.graphics.newImage("assets/monsters/slime.png")
}
-- === 定义状态机状态 ===
local STATES = {
    IDLE     = "idle",     -- 游荡/发呆
    CHASE    = "chase",    -- 追逐玩家
    COOLDOWN = "cooldown"  -- 战后冷却（无敌且不移动）
}
-- 辅助函数：生成 Quads
local function createQuads(image, cols, rows)
    local quads = {}
    local iw, ih = image:getDimensions()
    local w = iw / cols
    local h = ih / rows
    for i = 0, cols * rows - 1 do
        table.insert(quads, love.graphics.newQuad(
            (i % cols) * w, math.floor(i / cols) * h,
            w, h, iw, ih
        ))
    end
    return quads, w, h
end

-- 史莱姆只有1行8列
local slimeQuads, slimeW, slimeH = createQuads(monsterTextures.slime, 8, 1)

-- 定义动画帧配置 (索引从1开始)
local ANIMS = {
    slime = {
        idle   = {1, 2},       -- 待机
        walk   = {3, 4, 5},    -- 行走/攻击
        attack = {3, 4, 5},    -- 攻击
        hurt   = {6, 7},       -- 受伤
        die    = {8}           -- 死亡
    }
}

-- === 2. 怪物模板配置 ===
local monsterTypes = {
    {
        key="slime", name="史莱姆", level=1, hp=50, 
        speed=30, range=100, 
        -- 视觉配置
        texture=monsterTextures.slime, 
        quads=slimeQuads, 
        animData=ANIMS.slime,
        w=slimeW, h=slimeH,
        offsetY = -10, -- 贴图修正（脚底对齐）
        escapeChance = 0.8
    }, 
    {name="哥布林", level=2, hp=80, color={0,0.8,0.2}, speed=50, range=150, escapeChance = 0.5},
    {name="蝙蝠",   level=3, hp=40, color={0,0.2,0.8}, speed=80, range=200, escapeChance = 0.3}
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
    attack = 30,    -- 基础攻击力
    escapeChance = 0
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
    
    -- 基础属性
    local monster = {
        x = tx * tileSize,
        y = ty * tileSize,
        -- 如果有贴图，使用贴图宽高，否则默认32
        w = mType.w or 32, 
        h = mType.h or 32,
        color = mType.color,
        name  = mType.name,
        level = mType.level,
        hp    = mType.hp,
        maxHp = mType.hp,
        speed = mType.speed,
        state = "idle",
        detectionRange = mType.range,
        cooldown = 0,
        cooldownDuration = 5.0,
        stateTimer = 0,
        wanderDir = nil,
        
        -- [新增] 动画状态
        texture = mType.texture,
        quads = mType.quads,
        animConfig = mType.animData,
        animFrame = 1,
        animTimer = 0,
        visualState = "idle", -- 当前播放的动画名
        offsetY = mType.offsetY or 0
    }
    
    -- 如果是BOSS，从这里扩展属性... (略)
    return monster
end

-- === 3. 配置生成器 ===
local Monster = EntitySpawner.new({
    radius = 30, noSpawnRange = 450, density = 0.12, spawnInterval = 0.1, maxNearby = 10, maxDistance = 45,
    isSolid = function(tx, ty) return Core.isSolidTile(tx, ty) end,
    spawnFunc = spawnMonster,

    updateFunc = function(monster, dt, player, tileSize, Core)
        local target = player.data or player

        -- [安全] 防止 target 为空导致报错 (例如游戏刚开始 player 还没初始化)
        if not target or not target.x or not target.y then 
            return 
        end

        -- 计算与玩家的距离 (使用 target 而不是 player.data)
        local distSq = (monster.x - target.x)^2 + (monster.y - target.y)^2
        local dist = math.sqrt(distSq)
        local isMoving = false
        -- 状态机逻辑
        if monster.state == STATES.COOLDOWN then
            -- ... (保持原有逻辑不变)
            monster.cooldown = monster.cooldown - dt
            if monster.cooldown <= 0 then
                monster.cooldown = 0
                monster.state = STATES.IDLE
                print(monster.name .. " 恢复了行动！")
            end

        elseif monster.state == STATES.CHASE then
            -- [追逐状态]
            if dist > monster.detectionRange * 1.5 then
                monster.state = STATES.IDLE
                monster.stateTimer = 0
            else
                -- 这里的 Core.updateMonsterMovement 内部可能也需要 target
                -- 建议检查 core.lua 或者直接传 target
                Core.updateMonsterMovement(monster, dt, tileSize, player) 
            end

        elseif monster.state == STATES.IDLE then
            -- [闲逛状态]
            if dist < monster.detectionRange then
                monster.state = STATES.CHASE
            else
                updateIdleMovement(monster, dt, Core)
            end
        end
        
        if monster.cooldown > 0 and monster.state ~= STATES.COOLDOWN then
            monster.state = STATES.COOLDOWN
        end

        if monster.state == "cooldown" then
            monster.cooldown = monster.cooldown - dt
            if monster.cooldown <= 0 then monster.state = "idle" end
        elseif monster.state == "chase" then
            if dist > monster.detectionRange * 1.5 then
                monster.state = "idle"
            else
                Core.updateMonsterMovement(monster, dt, tileSize, player)
                isMoving = true
            end
        elseif monster.state == "idle" then
            if dist < monster.detectionRange then
                monster.state = "chase"
            else
                updateIdleMovement(monster, dt, Core)
                -- 简单判断是否有速度
                if monster.wanderDir then isMoving = true end
            end
        end
        
        -- [新增] 更新动画帧
        if monster.texture then
            local animKey = isMoving and "walk" or "idle"
            
            -- 状态切换时重置帧
            if monster.visualState ~= animKey then
                monster.visualState = animKey
                monster.animFrame = 1
                monster.animTimer = 0
            end
            
            -- 播放动画
            local frames = monster.animConfig[animKey]
            monster.animTimer = monster.animTimer + dt
            if monster.animTimer > 0.2 then -- 0.2秒一帧
                monster.animTimer = 0
                monster.animFrame = monster.animFrame + 1
                if monster.animFrame > #frames then monster.animFrame = 1 end
            end
        end
    end,

    drawFunc = function(monster, camX, camY)
        local x = monster.x - camX
        local y = monster.y - camY
        
        -- 有贴图画贴图
        if monster.texture and monster.quads then
            love.graphics.setColor(1, 1, 1)
            -- 冷却变半透明
            if monster.state == "cooldown" then 
                love.graphics.setColor(1, 1, 1, 0.5) 
            end
            
            local frames = monster.animConfig[monster.visualState]
            local frameIdx = frames[monster.animFrame] or 1
            local quad = monster.quads[frameIdx]
            
            -- 绘制 (水平翻转逻辑可选：根据 vx > 0 或 < 0)
            -- 这里简化直接画
            love.graphics.draw(monster.texture, quad, x, y + monster.offsetY)
            
        else
            -- 没贴图画方块 (兼容哥布林/蝙蝠)
            if monster.state == "chase" then love.graphics.setColor(1, 0, 0)
            elseif monster.state == "cooldown" then love.graphics.setColor(monster.color[1], monster.color[2], monster.color[3], 0.3)
            else love.graphics.setColor(monster.color) end
            love.graphics.rectangle("fill", x, y, monster.w, monster.h)
        end
        
        -- 名字
        love.graphics.setColor(1,1,1)
        love.graphics.print(monster.name, x, y - 20)
        if monster.state == "chase" then love.graphics.print("!", x + 10, y - 35) end
    end
})

-- (保留 spawnBoss 接口)
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