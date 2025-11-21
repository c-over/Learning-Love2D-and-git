local Core = require("core")
local Player = require("player")

local Pickup = {}
Pickup.list = {}
Pickup.floatTexts = {}

-- 光点模板
local pickupTypes = {
    {reward=10, color={1,1,0}},   -- 金币
    {reward=20, color={1,0.5,0}}, -- 更多金币
}

-- 生成计时器
local spawnTimer = 0
local spawnInterval = 2.0 -- 每隔 2 秒尝试生成一次
local noSpawnRange = 200  -- 玩家周围禁止生成范围

-- 随机生成光点
local function spawnPickup(tx, ty, tileSize)
    local pType = pickupTypes[love.math.random(#pickupTypes)]
    return {
        x = tx * tileSize,
        y = ty * tileSize,
        w = 16, h = 16,
        blink = 0,
        reward = pType.reward,
        color = pType.color
    }
end

function Pickup.generateAroundPlayer(player, tileSize, noiseScale, wallThreshold, density, radius, maxNearby)
    local px = math.floor(player.x / tileSize)
    local py = math.floor(player.y / tileSize)

    -- 限制周围光点数量
    local nearbyCount = 0
    for _, p in ipairs(Pickup.list) do
        local dx = math.floor(p.x / tileSize) - px
        local dy = math.floor(p.y / tileSize) - py
        if dx*dx + dy*dy <= radius*radius then
            nearbyCount = nearbyCount + 1
        end
    end
    if nearbyCount >= maxNearby then return end

    -- 按概率生成
    for ty = py - radius, py + radius do
        for tx = px - radius, px + radius do
            local dx = tx - px
            local dy = ty - py
            if math.abs(dx * tileSize) > noSpawnRange or math.abs(dy * tileSize) > noSpawnRange then
                if love.math.random() < density then
                    if not Core.isSolidTile(tx, ty, noiseScale, wallThreshold) then
                        local exists = false
                        for _, p in ipairs(Pickup.list) do
                            if math.floor(p.x / tileSize) == tx and math.floor(p.y / tileSize) == ty then
                                exists = true
                                break
                            end
                        end
                        if not exists then
                            table.insert(Pickup.list, spawnPickup(tx, ty, tileSize))
                        end
                    end
                end
            end
        end
    end
end

function Pickup.update(dt, player, tileSize, noiseScale, wallThreshold, coinSound)
    -- 控制生成频率
    spawnTimer = spawnTimer + dt
    if spawnTimer >= spawnInterval then
        spawnTimer = 0
        Pickup.generateAroundPlayer(player, tileSize, noiseScale, wallThreshold, 0.02, 15, 10)
    end

    -- 更新闪烁
    for _, p in ipairs(Pickup.list) do
        p.blink = p.blink + dt * 5
    end

    -- 碰撞检测：玩家碰到金币直接加钱并删除
    for i = #Pickup.list, 1, -1 do
        local p = Pickup.list[i]
        local px = player.x - player.w/2
        local py = player.y - player.h/2
        if Core.aabbOverlap(px, py, player.w, player.h,
                            p.x, p.y, p.w, p.h) then
            if coinSound then
                coinSound:stop()   -- 防止叠音
                coinSound:play()   -- 播放音效
            end
            -- 添加浮动文字提示
            table.insert(Pickup.floatTexts, {
                text = "+"..p.reward.." Gold",
                x = player.x,
                y = player.y - player.h, -- 玩家头顶
                timer = 0,
                duration = 1.0
            })
            Player.data.gold = Player.data.gold + p.reward
            Player.save()  -- 调用保存函数
            table.remove(Pickup.list, i)
        end
    end

    --更新浮动文字
    for i = #Pickup.floatTexts, 1, -1 do
        local ft = Pickup.floatTexts[i]
        ft.timer = ft.timer + dt
        if ft.timer > ft.duration then
            table.remove(Pickup.floatTexts, i)
        end
    end


    -- 清理远离玩家的光点
    local maxDistance = 30 * tileSize
    local px, py = player.x, player.y
    for i = #Pickup.list, 1, -1 do
        local p = Pickup.list[i]
        local dx = p.x - px
        local dy = p.y - py
        if dx*dx + dy*dy > maxDistance*maxDistance then
            table.remove(Pickup.list, i)
        end
    end
end

function Pickup.draw(camX, camY)
    for _, p in ipairs(Pickup.list) do
        local alpha = (math.sin(p.blink) * 0.5 + 0.5)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.line(p.x - camX - 8, p.y - camY, p.x - camX + 8, p.y - camY)
        love.graphics.line(p.x - camX, p.y - camY - 8, p.x - camX, p.y - camY + 8)
    end
    love.graphics.setColor(1,1,1,1)
    --绘制浮动文字
    for _, ft in ipairs(Pickup.floatTexts) do
        local alpha = 1 - (ft.timer / ft.duration)
        local offsetY = -20 * (ft.timer / ft.duration) -- 向上漂浮
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(ft.text, ft.x - camX, ft.y - camY + offsetY)
    end
    love.graphics.setColor(1,1,1,1)

end

return Pickup
