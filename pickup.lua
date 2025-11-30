local EntitySpawner = require("EntitySpawner")
local ItemManager = require("ItemManager")
local Player = require("player")
local Inventory = require("inventory")
local GameUI = require("game_ui") -- [修改] 引用 GameUI 来显示飘字

-- 1. 定义掉落物类型
local definitions = {
    coin = {
        id = 5,
        color = {1, 1, 0},
        -- 特殊逻辑：直接加钱
        onPickup = function(amount)
            Player.addGold(amount)
            return "金币 +" .. amount, {1, 0.9, 0.2} 
        end
    },
    wood = {
        id = 12,
        color = {1, 1, 1},
        category = "material"
    },
    -- 可以在这里加 stone, potion 等
}

-- 默认拾取逻辑
local function defaultOnPickup(def, count)
    Inventory:addItem(def.id, count, def.category or "material")
    local itemDef = ItemManager.get(def.id)
    local name = itemDef and itemDef.name or "未知物品"
    return name .. " +" .. count, {1, 1, 1}
end

-- 2. 创建 Spawner
local Pickup = EntitySpawner.new({
    radius = 0, noSpawnRange = 0, density = 0, spawnInterval = 9999, maxNearby = 100, maxDistance = 2000,
    spawnFunc = function() end,

    -- === 更新逻辑 ===
    updateFunc = function(item, dt, player, tileSize, Core)
        -- A. 物理运动 (爆裂散开效果)
        item.x = item.x + item.vx * dt
        item.y = item.y + item.vy * dt
        
        -- 摩擦力：让物品慢慢停下来
        item.vx = item.vx * 0.92 
        item.vy = item.vy * 0.92
        
        -- B. 动画计时
        item.life = item.life - dt
        item.animTimer = item.animTimer + dt * 5 -- 浮动速度

        -- C. 拾取检测 (磁吸效果可选，这里用简单的距离)
        -- 检测脚底位置
        local dx = item.x - player.x
        local dy = item.y - (player.y + 16) 
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < 32 and item.life < 29.5 then -- 刚生成 0.5 秒内捡不起来，防止瞬间捡起没动画
            local def = definitions[item.typeKey]
            local text, color
            
            if def.onPickup then
                text, color = def.onPickup(item.count)
            else
                text, color = defaultOnPickup(def, item.count)
            end
            
            -- [修改] 调用 GameUI 显示飘字
            GameUI.addFloatText(text, item.x, item.y - 30, color)
            
            -- 播放音效 (如果有)
            if coinSound then coinSound:stop(); coinSound:play() end
            
            -- 标记移除
            item.life = -1 
        end
    end,

    -- === 绘制逻辑 (美化版) ===
    drawFunc = function(item, camX, camY)
        local def = definitions[item.typeKey]
        
        -- 1. 计算透明度 (消失前闪烁)
        local alpha = 1
        if item.life < 3 then
            alpha = (math.sin(item.animTimer * 5) + 1) / 2
        end
        
        -- 2. 浮动动画 (上下漂浮)
        local bobOffset = math.sin(item.animTimer) * 4
        
        -- 屏幕坐标
        local sx = item.x - camX
        local sy = item.y - camY
        
        -- [新增] 绘制阴影 (让物体看起来悬浮)
        love.graphics.setColor(0, 0, 0, 0.3 * alpha)
        love.graphics.ellipse("fill", sx, sy + 6, 8, 4) -- 椭圆阴影

        -- [优化] 绘制图标
        love.graphics.setColor(1, 1, 1, alpha)
        
        if item.quad then
            local _, _, w, h = item.quad:getViewport()
            local scale = 0.6
            -- 关键：设置 Origin (w/2, h/2) 让图片居中绘制
            love.graphics.draw(ItemManager.getIcon(def.id), item.quad, 
                sx, sy + bobOffset - 10, -- y轴上移一点，不要贴地
                0, scale, scale, w/2, h/2)
        else
            -- 兜底圆点
            love.graphics.setColor(def.color)
            love.graphics.circle("fill", sx, sy + bobOffset - 10, 5)
        end
        
        -- 数量标记
        if item.count > 1 then
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.print(item.count, sx + 6, sy - 20)
        end
        
        love.graphics.setColor(1, 1, 1)
    end
})

-- === 生成接口 ===
function Pickup.create(x, y, typeKey, count)
    local def = definitions[typeKey]
    if not def then return end
    
    local _, quad = ItemManager.getIcon(def.id)
    
    table.insert(Pickup.list, {
        x = x, y = y,
        -- [优化] 增大初始速度，让物品炸得更开
        vx = love.math.random(-150, 150), 
        vy = love.math.random(-150, 150),
        
        typeKey = typeKey,
        count = count or 1,
        quad = quad,
        
        life = 30,
        animTimer = love.math.random(0, 100) -- 随机起始相位，让不同物品浮动不同步
    })
end

return Pickup