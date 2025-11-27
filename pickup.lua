local EntitySpawner = require("EntitySpawner")
local Core   = require("core")
local Player = require("player")

-- === 1. 资源加载与设置 ===
-- 假设图标大小为 64x64 (常用 RPG 素材大小)，如果是 16x16 请改为 16
local ICON_SIZE = 64 
local iconSheet = love.graphics.newImage("assets/icon.png")
iconSheet:setFilter("nearest", "nearest") -- 保持像素风格清晰

-- 辅助函数：根据索引获取图标的 Quad (切片)
local function getIconQuad(index)
    local cols = math.floor(iconSheet:getWidth() / ICON_SIZE)
    local col = index % cols
    local row = math.floor(index / cols)
    return love.graphics.newQuad(col * ICON_SIZE, row * ICON_SIZE, ICON_SIZE, ICON_SIZE, iconSheet:getDimensions())
end

-- === 2. 配置模板 ===
-- === 配置模板 ===
local pickupTypes = {
    -- 普通金币：奖励10，白色原色，图标索引 131
    {reward=10, color={1, 1, 1},       iconIndex=130}, 
    
    -- 大金币：奖励20，偏红，图标索引 132 (请根据实际素材修改此数字)
    {reward=20, color={1, 0.8, 0.8},   iconIndex=128}, 
}
local floatTexts = {}

-- 生成光点对象
local function spawnPickup(tx, ty, tileSize)
    local pType = pickupTypes[love.math.random(#pickupTypes)]
    
    -- 根据配置的 iconIndex 获取对应的 Quad
    local specificQuad = getIconQuad(pType.iconIndex)

    return {
        x = tx * tileSize + tileSize/2,
        y = ty * tileSize + tileSize/2,
        w = 16, h = 16,
        blink = 0,
        reward = pType.reward,
        color  = pType.color,
        quad   = specificQuad -- <--- 保存这个金币专属的图片切片
    }
end

-- === 3. 生成器配置 ===
local Pickup = EntitySpawner.new({
    spawnInterval = 2.0,
    noSpawnRange  = 200,
    density       = 0.02,
    radius        = 15,
    maxNearby     = 10,
    maxDistance   = 30,
    isSolid       = function(tx, ty) return Core.isSolidTile(tx, ty) end,
    spawnFunc     = spawnPickup,

    updateFunc = function(pickup, dt, player, tileSize, Core, coinSound)
        -- 动画计时器更新
        pickup.blink = pickup.blink + dt * 4

        -- === 修复核心开始 ===
        -- 安全获取玩家坐标对象
        -- 如果 player.data 存在，说明传入的是模块，用 .data；否则直接用 player
        local target = player.data or player

        -- 如果 target 为空或没有坐标，直接跳过检测
        if not target or not target.x or not target.y then 
            return false 
        end
        
        local px, py = target.x, target.y
        -- === 修复核心结束 ===

        -- 计算距离拾取
        local dx = px - pickup.x
        local dy = py - pickup.y
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < 24 then -- 拾取半径
            if coinSound then
                coinSound:stop()
                coinSound:play()
            end
            
            -- 添加浮动文字
            table.insert(floatTexts, {
                text     = "+"..pickup.reward.." G",
                x        = pickup.x,
                y        = pickup.y - 10,
                timer    = 0,
                duration = 0.8
            })
            
            -- 增加金币 (这里需要确保 Player 模块被正确 require 并且有数据)
            -- 尽量使用全局 require 的 Player 来修改数据，而不是依赖传入的参数
            if Player.data then
                Player.data.gold = (Player.data.gold or 0) + pickup.reward
            end
            
            return true  -- 返回 true 表示需要删除
        end
        return false
    end,

    -- === 4. 绘制图标 ===
    drawFunc = function(pickup, camX, camY)
        -- 动画计算
        local alpha = (math.sin(pickup.blink) * 0.3 + 0.7)
        local bobOffset = math.sin(pickup.blink) * 3

        love.graphics.setColor(pickup.color[1], pickup.color[2], pickup.color[3], alpha)
        
        local scale = 0.5 
        
        love.graphics.draw(
            iconSheet, 
            pickup.quad,     -- <--- 修改这里：使用实例自带的 quad
            pickup.x - camX, 
            pickup.y - camY + bobOffset, 
            0, 
            scale, scale, 
            ICON_SIZE/2, ICON_SIZE/2
        )
        
        love.graphics.setColor(1,1,1,1)
    end
})

-- 扩展 update (保持原有逻辑不变)
local oldUpdate = Pickup.update
function Pickup.update(dt, player, tileSize, Core, coinSound)
    oldUpdate(dt, player, tileSize, Core)

    -- 这里你原来的逻辑是手动调用 updateFunc 来删除物体
    -- 注意：通常 EntitySpawner.update 内部会自动调用 updateFunc。
    -- 如果你的 EntitySpawner 没有自动处理返回值删除，保留下面这段是对的。
    for i = #Pickup.list, 1, -1 do
        local p = Pickup.list[i]
        -- 确保传入 player.data 或者 player 保持一致
        if Pickup.config.updateFunc(p, dt, player, tileSize, Core, coinSound) then
            table.remove(Pickup.list, i)
        end
    end

    -- 更新浮动文字动画
    for i = #floatTexts, 1, -1 do
        local ft = floatTexts[i]
        ft.timer = ft.timer + dt
        ft.y = ft.y - dt * 20 -- 向上飘动
        if ft.timer > ft.duration then
            table.remove(floatTexts, i)
        end
    end
end

-- 扩展 draw (保持原有逻辑不变，增加字体优化)
local oldDraw = Pickup.draw
function Pickup.draw(camX, camY)
    oldDraw(camX, camY)

    -- 绘制浮动文字动画
    for _, ft in ipairs(floatTexts) do
        local progress = ft.timer / ft.duration
        local alpha = 1 - progress
        
        -- 文字带黑边，更清晰
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.print(ft.text, ft.x - camX + 1, ft.y - camY + 1)
        
        love.graphics.setColor(1, 1, 0, alpha) -- 金色文字
        love.graphics.print(ft.text, ft.x - camX, ft.y - camY)
    end
    love.graphics.setColor(1,1,1,1)
end

return Pickup