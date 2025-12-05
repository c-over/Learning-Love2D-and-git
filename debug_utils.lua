local Debug = {}
-- 动态引用，防止循环依赖
local Player = nil 
local Inventory = nil
local Config = nil
local Core = nil

-- 调试日志缓存
Debug.logs = {}
Debug.maxLogs = 8
-- 调试开关
Debug.showHitboxes = true
Debug.showUI = true

-- === 1. 调试按钮配置 ===
Debug.buttons = {
    { text = "HP 回满", func = function() if Player then Player.data.hp = Player.data.maxHp end end },
    { text = "MP 回满", func = function() if Player then Player.data.mp = Player.data.maxMp end end },
    { text = "金币 +1k", func = function() if Player then Player.addGold(1000) end end },
    { text = "升级", func = function() if Player then Player.addLevel(1) end end },
    { text = "速度 x2", func = function() if Player then Player.data.speed = (Player.data.speed or 240) * 2 Debug.log("速度翻倍") end end },
    { text = "速度重置", func = function() if Player then Player.data.speed = 240 Debug.log("速度重置") end end },
    { text = "强制保存", func = function() if Config then Config.save() Debug.log("已保存") end end },
    { text = "清空日志", func = function() Debug.logs = {} end },
    { text = "切换背包", func = function() 
        if currentScene == "inventory" then currentScene = "game" else currentScene = "inventory" end 
    end },
    {text = "传送至桥梁",func = Debug.teleportToBridge}
}

local function ensureModules()
    if not Player then Player = require("player") end
    if not Inventory then Inventory = require("inventory") end
    if not Config then Config = require("config") end
    if not Core then Core = require("core") end
end

function Debug.log(msg)
    local time = os.date("%H:%M:%S")
    table.insert(Debug.logs, 1, string.format("[%s] %s", time, tostring(msg)))
    if #Debug.logs > Debug.maxLogs then table.remove(Debug.logs) end
    print("[Debug] " .. tostring(msg))
end

-- === 2. 绘制实体碰撞箱 (动态物体：人、怪) ===
function Debug.drawEntityHitbox(entity, camX, camY)
    if not Debug.showHitboxes or not entity then return end
    
    -- 转换为屏幕坐标
    local x = entity.x - camX
    local y = entity.y - camY
    local w = entity.w or 32
    local h = entity.h or 32

    -- 绘制绿色边框 (表示实体边界)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- 绘制锚点 (左上角)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.circle("fill", x, y, 2)
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- === 绘制地图阻挡格 (静态物体：树、墙) ===
function Debug.drawMapGrid(camX, camY, tileSize, screenW, screenH)
    local Map = require("map")
    if not Debug.showHitboxes then return end
    ensureModules() -- 确保 Map 模块已加载

    local startCol = math.floor(camX / tileSize)
    local endCol   = math.floor((camX + screenW) / tileSize) + 1
    local startRow = math.floor(camY / tileSize)
    local endRow   = math.floor((camY + screenH) / tileSize) + 1

    love.graphics.setColor(1, 0, 0, 0.4) -- 红色半透明

    for r = startRow, endRow do
        for c = startCol, endCol do
            local tile = Map.getTile(c, r)
            
            -- [修改] 不再简单的 isSolid，而是获取具体碰撞盒
            local box = Map.getTileCollision(tile, c, r)
            
            if box then
                -- box 是相对于格子左上角的偏移 {x, y, w, h}
                local worldX = c * tileSize + box.x
                local worldY = r * tileSize + box.y
                
                local drawX = worldX - camX
                local drawY = worldY - camY
                
                -- 绘制具体的阻挡区域
                love.graphics.rectangle("fill", drawX, drawY, box.w, box.h)
                
                -- 边框
                love.graphics.setColor(1, 0, 0, 0.9)
                love.graphics.rectangle("line", drawX, drawY, box.w, box.h)
                love.graphics.setColor(1, 0, 0, 0.4)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end
-- 寻找并传送到最近的桥
function Debug.teleportToBridge()
    local Map = require("map")
    local Player = require("player")
    local Game = require("game")
    
    local searchRadius = 200 -- 搜索半径 (格)
    local playerGx = math.floor(Player.data.x / Game.tileSize)
    local playerGy = math.floor(Player.data.y / Game.tileSize)
    
    print("开始搜索桥梁...")
    
    -- 我们知道桥只生成在 % 50 的线上，所以只扫描这些线，极大提高搜索效率
    for r = 0, searchRadius do
        -- 螺旋或者简单遍历，这里用简单遍历
        for gx = playerGx - r, playerGx + r do
            for gy = playerGy - r, playerGy + r do
                
                -- 只检查可能生成桥的坐标轴
                if gx % 50 == 0 or gy % 50 == 0 then
                    local tile = Map.getTile(gx, gy)
                    
                    -- 如果发现了桥梁路面
                    if tile and string.find(tile, "bridge") then
                        print(string.format("找到桥梁！坐标: %d, %d (Tile: %s)", gx, gy, tile))
                        
                        -- 传送玩家 (稍微偏移一点防止卡在护栏里)
                        Player.data.x = gx * Game.tileSize
                        Player.data.y = gy * Game.tileSize
                        return
                    end
                end
            end
        end
    end
    print("范围内未找到桥梁，请尝试跑远点再试，或者检查生成逻辑。")
end
-- === 3. UI 绘制 (布局重构) ===
function Debug.drawInfo(player, counter)
    if not Debug.showUI then return end
    ensureModules()

    local w, h = love.graphics.getDimensions()
    
    -- A. 左上角：基础信息面板 (固定位置)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 5, 5, 240, 140) -- 加大一点背景
    
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.print(string.format("Memory: %.2f MB", collectgarbage("count")/1024), 10, 30)
    -- [新增] 显示当前场景
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Scene: " .. tostring(currentScene), 10, 50)
    love.graphics.setColor(0, 1, 0)
    
    if player then
        love.graphics.print(string.format("Pos: (%.1f, %.1f)", player.x, player.y), 10, 80)
        -- 计算格子坐标
        local gx, gy = math.floor(player.x/32), math.floor(player.y/32)
        love.graphics.print(string.format("Grid: [%d, %d]", gx, gy), 10, 100)
    end

    -- B. 右侧：功能按钮栏 (动态贴边)
    local btnW, btnH = 100, 30
    local margin = 10
    local startX = w - btnW - margin -- 靠右对齐
    local startY = 50 -- 顶部留一点空隙
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("--- Debug Menu ---", startX - 10, startY - 20)
    
    for i, btn in ipairs(Debug.buttons) do
        local by = startY + (i-1) * (btnH + 5)
        
        -- 记录 rect 用于点击检测
        btn.rect = {x=startX, y=by, w=btnW, h=btnH}
        
        -- 悬停效果
        local mx, my = love.mouse.getPosition()
        if mx >= startX and mx <= startX+btnW and my >= by and my <= by+btnH then
            love.graphics.setColor(0.3, 0.7, 0.3, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        end
        
        love.graphics.rectangle("fill", startX, by, btnW, btnH)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", startX, by, btnW, btnH)
        
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local tw = font:getWidth(btn.text)
        love.graphics.print(btn.text, startX + (btnW-tw)/2, by + 8)
    end

    -- C. 右下角：日志控制台 (动态贴底)
    local logW = 350
    local logH = (#Debug.logs * 15) + 10
    local logX = w - logW - 10
    -- 放在按钮下方，或者贴底，这里选择贴底，避开上方按钮
    local logY = h - logH - 10
    
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", logX, logY, logW, logH)
    
    for i, msg in ipairs(Debug.logs) do
        love.graphics.setColor(1, 1, 1, 1 - (i-1)*0.1)
        love.graphics.print(msg, logX + 5, logY + (i-1)*15 + 5)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Debug.mousepressed(x, y, button)
    if not Debug.showUI or button ~= 1 then return false end
    for _, btn in ipairs(Debug.buttons) do
        if btn.rect and x >= btn.rect.x and x <= btn.rect.x + btn.rect.w and
           y >= btn.rect.y and y <= btn.rect.y + btn.rect.h then
            if btn.func then btn.func() end
            return true
        end
    end
    return false
end

return Debug