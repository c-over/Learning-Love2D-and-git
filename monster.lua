local EntitySpawner = require("EntitySpawner")
local Core = require("core")

-- === 1. 资源加载 ===
local monsterTextures = {
    -- 请确保路径存在，如果改名了请同步修改这里
    slime = love.graphics.newImage("assets/monsters/slime.png")
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

-- 定义动画帧配置
local ANIMS = {
    slime = {
        idle   = {1, 2},       
        walk   = {3, 4, 5},    
        attack = {3, 4, 5},    
        hurt   = {6, 7},       
        die    = {8}           
    }
}

-- === 2. 怪物模板配置 ===
local monsterTypes = {
    {
        key="slime", name="史莱姆", level=1, hp=50, 
        speed=30, range=100, 
        texture=monsterTextures.slime, 
        quads=slimeQuads, 
        animData=ANIMS.slime,
        w=slimeW, h=slimeH,
        offsetY = -10,
        escapeChance = 0.8
    }, 
    {
        name="哥布林", level=2, hp=80, color={0,0.8,0.2}, speed=50, range=150,
        escapeChance = 0.5
    },
    {
        name="蝙蝠",   level=3, hp=40, color={0,0.2,0.8}, speed=80, range=200,
        escapeChance = 0.3, aiType = "bat"
    }
}

-- BOSS 模板
local bossTemplate = {
    name = "魔王",
    level = 10,
    hp = 500,
    maxHp = 500,
    color = {0.8, 0, 0},
    speed = 40,
    range = 300,
    isBoss = true,
    attack = 30,
    aiType = "demon_king", -- AI 类型
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
        
        local tx = math.floor((monster.x + dx + 16)/32)
        local ty = math.floor((monster.y + dy + 16)/32)
        if not Core.isSolidTile(tx, ty) then
            monster.x = monster.x + dx
            monster.y = monster.y + dy
        else
            monster.wanderDir = monster.wanderDir + math.pi 
        end
    end
end

-- 生成普通怪物对象
local function spawnMonster(tx, ty, tileSize)
    local mType = monsterTypes[love.math.random(#monsterTypes)]
    
    local monster = {
        x = tx * tileSize,
        y = ty * tileSize,
        w = mType.w or 32, 
        h = mType.h or 32,
        color = mType.color,
        name  = mType.name,
        level = mType.level,
        hp    = mType.hp,
        maxHp = mType.hp, -- 确保有 maxHp
        speed = mType.speed,
        state = "idle",
        detectionRange = mType.range,
        cooldown = 0,
        cooldownDuration = 5.0,
        stateTimer = 0,
        wanderDir = nil,
        
        -- 动画与AI状态
        texture = mType.texture,
        quads = mType.quads,
        animConfig = mType.animData,
        animFrame = 1,
        animTimer = 0,
        visualState = "idle", 
        offsetY = mType.offsetY or 0,
        
        escapeChance = mType.escapeChance,
        aiType = mType.aiType or "default"
    }
    
    -- 读取死亡次数增加难度
    if package.loaded["player"] then
        local Player = require("player")
        local deathCount = Player.data.deathCount or 0
        local scale = 1 + (deathCount * 0.1)
        monster.hp = math.floor(monster.hp * scale)
        monster.maxHp = math.floor(monster.maxHp * scale)
    end
    
    return monster
end

-- === 3. 配置生成器 ===
local Monster = EntitySpawner.new({
    radius = 30, noSpawnRange = 450, density = 0.12, spawnInterval = 0.1, maxNearby = 10, maxDistance = 45,
    isSolid = function(tx, ty) return Core.isSolidTile(tx, ty) end,
    spawnFunc = spawnMonster,

    updateFunc = function(monster, dt, player, tileSize, Core)
        local target = player.data or player
        local distSq = (monster.x - target.x)^2 + (monster.y - target.y)^2
        local dist = math.sqrt(distSq)

        local isMoving = false
        -- [修改] 索敌逻辑：如果玩家隐身，怪物变成瞎子 (检测范围归0或极小)
        local effectiveRange = monster.detectionRange
        if require("player").hasBuff("invisible") then
            effectiveRange = 0 -- 或者 32 (必须贴脸才会被发现)
        end

        if monster.state == "cooldown" then
            monster.cooldown = monster.cooldown - dt
            if monster.cooldown <= 0 then monster.state = "idle" end
        elseif monster.state == "chase" then
            if dist > effectiveRange * 1.5 then
                monster.state = "idle"
            else
                Core.updateMonsterMovement(monster, dt, tileSize, player)
                isMoving = true
            end
        elseif monster.state == "idle" then
            if dist < effectiveRange then
                monster.state = "chase"
            else
                updateIdleMovement(monster, dt, Core)
                if monster.wanderDir then isMoving = true end
            end
        end
        
        -- 更新动画帧
        if monster.texture then
            local animKey = isMoving and "walk" or "idle"
            
            if monster.visualState ~= animKey then
                monster.visualState = animKey
                monster.animFrame = 1
                monster.animTimer = 0
            end
            
            local frames = monster.animConfig[animKey]
            monster.animTimer = monster.animTimer + dt
            if monster.animTimer > 0.2 then 
                monster.animTimer = 0
                monster.animFrame = monster.animFrame + 1
                if monster.animFrame > #frames then monster.animFrame = 1 end
            end
        end
    end,

    drawFunc = function(monster, camX, camY)
        local x = monster.x - camX
        local y = monster.y - camY
        
        if monster.texture and monster.quads then
            love.graphics.setColor(1, 1, 1)
            if monster.state == "cooldown" then love.graphics.setColor(1, 1, 1, 0.5) end
            
            local frames = monster.animConfig[monster.visualState]
            local frameIdx = frames[monster.animFrame] or 1
            local quad = monster.quads[frameIdx]
            
            love.graphics.draw(monster.texture, quad, x, y + monster.offsetY)
        else
            if monster.state == "chase" then love.graphics.setColor(1, 0, 0)
            elseif monster.state == "cooldown" then love.graphics.setColor(monster.color[1], monster.color[2], monster.color[3], 0.3)
            else love.graphics.setColor(monster.color) end
            love.graphics.rectangle("fill", x, y, monster.w, monster.h)
        end
        
        love.graphics.setColor(1,1,1)
        love.graphics.print(monster.name, x, y - 20)
        if monster.state == "chase" then love.graphics.print("!", x + 10, y - 35) end
    end
})

-- 暴露给外部手动生成 BOSS 的接口
function Monster.spawnBoss(targetX, targetY)
    -- 使用 Core 寻找最近的合法落脚点
    -- 搜索半径设为 100 格 (3200像素)，确保能找到陆地
    local safeX, safeY = Core.findSpawnPoint(targetX, targetY, 100)
    
    local boss = {
        x = safeX, 
        y = safeY,
        w = 64, h = 64,
        color = bossTemplate.color,
        name = bossTemplate.name,
        level = bossTemplate.level,
        hp = bossTemplate.maxHp,
        maxHp = bossTemplate.maxHp,
        speed = bossTemplate.speed,
        state = "idle",
        detectionRange = bossTemplate.range,
        attack = bossTemplate.attack,
        isBoss = true,
        escapeChance = 0,
        aiType = bossTemplate.aiType,
        
        stateTimer = 0,
        wanderDir = nil,
    }
    
    -- 难度动态调整
    if package.loaded["player"] then
        local Player = require("player")
        local deathCount = Player.data.deathCount or 0
        local scale = 1 + (deathCount * 0.1)
        boss.hp = math.floor(boss.hp * scale)
        boss.maxHp = math.floor(boss.maxHp * scale)
    end
    
    table.insert(Monster.list, boss)
    print("BOSS 生成于: " .. safeX .. ", " .. safeY .. " (目标: " .. targetX .. "," .. targetY .. ")")
    return boss
end

return Monster