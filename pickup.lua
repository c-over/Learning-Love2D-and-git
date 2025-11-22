local EntitySpawner = require("EntitySpawner")
local Core   = require("core")
local Player = require("player")

-- 光点模板
local pickupTypes = {
    {reward=10, color={1,1,0}},   -- 金币
    {reward=20, color={1,0.5,0}}, -- 更多金币
}

-- 浮动文字列表
local floatTexts = {}

-- 生成光点对象
local function spawnPickup(tx, ty, tileSize)
    local pType = pickupTypes[love.math.random(#pickupTypes)]
    return {
        x = tx * tileSize,
        y = ty * tileSize,
        w = 16, h = 16,
        blink = 0,
        reward = pType.reward,
        color  = pType.color
    }
end

-- 配置光点生成器
local Pickup = EntitySpawner.new({
    spawnInterval = 2.0,
    noSpawnRange  = 200,
    density       = 0.02,
    radius        = 15,
    maxNearby     = 10,
    maxDistance   = 30,
    isSolid       = Core.isSolidTile,
    spawnFunc     = spawnPickup,
    updateFunc    = function(pickup, dt, player, tileSize, noiseScale, wallThreshold, coinSound)
        -- 闪烁动画
        pickup.blink = pickup.blink + dt * 5

        -- 碰撞检测：玩家拾取金币
        local px, py = player.x - player.w/2, player.y - player.h/2
        if Core.aabbOverlap(px, py, player.w, player.h, pickup.x, pickup.y, pickup.w, pickup.h) then
            if coinSound then
                coinSound:stop()
                coinSound:play()
            end
            -- 添加浮动文字
            table.insert(floatTexts, {
                text     = "+"..pickup.reward.." Gold",
                x        = player.x,
                y        = player.y - player.h,
                timer    = 0,
                duration = 1.0
            })
            -- 增加金币并保存
            Player.data.gold = Player.data.gold + pickup.reward
            Player.save()
            -- 从列表中移除该金币
            return true  -- 返回 true 表示需要删除
        end
        return false
    end,
    drawFunc      = function(pickup, camX, camY)
        local alpha = (math.sin(pickup.blink) * 0.5 + 0.5)
        love.graphics.setColor(pickup.color[1], pickup.color[2], pickup.color[3], alpha)
        love.graphics.line(pickup.x - camX - 8, pickup.y - camY, pickup.x - camX + 8, pickup.y - camY)
        love.graphics.line(pickup.x - camX, pickup.y - camY - 8, pickup.x - camX, pickup.y - camY + 8)
    end
})

-- 扩展 update：处理浮动文字和金币删除
local oldUpdate = Pickup.update
function Pickup.update(dt, player, tileSize, noiseScale, wallThreshold, coinSound)
    oldUpdate(dt, player, tileSize, noiseScale, wallThreshold, coinSound)

    -- 删除已拾取的金币
    for i = #Pickup.list, 1, -1 do
        local p = Pickup.list[i]
        if Pickup.config.updateFunc(p, dt, player, tileSize, noiseScale, wallThreshold, coinSound) then
            table.remove(Pickup.list, i)
        end
    end

    -- 更新浮动文字动画
    for i = #floatTexts, 1, -1 do
        local ft = floatTexts[i]
        ft.timer = ft.timer + dt
        if ft.timer > ft.duration then
            table.remove(floatTexts, i)
        end
    end
end

-- 扩展 draw：绘制浮动文字
local oldDraw = Pickup.draw
function Pickup.draw(camX, camY)
    oldDraw(camX, camY)

    -- 绘制浮动文字动画
    for _, ft in ipairs(floatTexts) do
        local alpha   = 1 - (ft.timer / ft.duration)
        local offsetY = -20 * (ft.timer / ft.duration) -- 向上漂浮
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(ft.text, ft.x - camX, ft.y - camY + offsetY)
    end
    love.graphics.setColor(1,1,1,1)
end

return Pickup
