local Debug = {}
local Layout = require("layout")
local Player = require("player")
local Config = require("config")
local StoryManager = require("StoryManager")

-- === 状态管理 ===
Debug.showUI = true
Debug.showHitboxes = true
Debug.activeTab = 1 -- 1: 常规, 2: 剧情/变量
Debug.logs = {}
Debug.maxLogs = 20 -- 增加日志上限，防止信息被刷掉

-- === 常规调试按钮 ===
Debug.generalButtons = {
    { text = "HP 回满", func = function() if Player.data then Player.data.hp = Player.data.maxHp; Debug.log("HP已恢复") end end },
    { text = "MP 回满", func = function() if Player.data then Player.data.mp = Player.data.maxMp; Debug.log("MP已恢复") end end },
    { text = "金币 +1k", func = function() if Player.data then Player.addGold(1000); Debug.log("获得1000金币") end end },
    { text = "升级", func = function() if Player then Player.addLevel(1); Debug.log("已经升级，当前等级:"..Player.data.level)end end },
    { text = "速度 x2", func = function() if Player.data then Player.data.speed = 480; Debug.log("速度设为480") end end },
    { text = "速度重置", func = function() if Player.data then Player.data.speed = 240; Debug.log("速度重置") end end },

    { text = "传送 BOSS", func = function() 
        local Monster = require("monster")
        for _, m in ipairs(Monster.list) do
            if m.isBoss then 
                Player.data.x = m.x
                Player.data.y = m.y + 150 -- 传送到下方一点
                Debug.log(string.format("传送至: %.0f, %.0f", m.x, m.y))
                return 
            end
        end
        Debug.log(">> 错误: 当前地图未找到 BOSS 实体")
    end},
    { text = "强制保存", func = function() Config.save(); Debug.log("存档已保存") end },
}

-- === 核心：日志系统 (支持换行) ===
function Debug.log(msg)
    local time = os.date("%H:%M:%S")
    -- 插入到最前面
    table.insert(Debug.logs, 1, {time = time, text = tostring(msg)})
    -- 限制数量
    if #Debug.logs > Debug.maxLogs then table.remove(Debug.logs) end
    -- 同时打印到控制台，防丢失
    print("[Debug " .. time .. "] " .. tostring(msg))
end

-- === 绘制辅助 ===
function Debug.drawEntityHitbox(entity, camX, camY)
    if not Debug.showHitboxes or not entity then return end
    local x, y = entity.x - camX, entity.y - camY
    local w, h = entity.w or 32, entity.h or 32
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

function Debug.drawMapGrid(camX, camY, tileSize, screenW, screenH)
    if not Debug.showHitboxes then return end
    local Core = require("core")
    local startCol = math.floor(camX / tileSize)
    local endCol   = math.floor((camX + screenW) / tileSize) + 1
    local startRow = math.floor(camY / tileSize)
    local endRow   = math.floor((camY + screenH) / tileSize) + 1
    love.graphics.setColor(1, 0, 0, 0.3)
    for r = startRow, endRow do
        for c = startCol, endCol do
            -- 获取精确碰撞盒
            local Map = require("map")
            local box = Map.getTileCollision(Map.getTile(c, r), c, r)
            if box then
                love.graphics.rectangle("fill", c*tileSize+box.x-camX, r*tileSize+box.y-camY, box.w, box.h)
                love.graphics.setColor(1, 0, 0, 0.8)
                love.graphics.rectangle("line", c*tileSize+box.x-camX, r*tileSize+box.y-camY, box.w, box.h)
                love.graphics.setColor(1, 0, 0, 0.3)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- === 绘制 UI 面板 ===
function Debug.drawInfo(player, timer)
    if not Debug.showUI then return end
    local w, h = love.graphics.getDimensions()
    
    -- 1. 左侧监控 (保持不变)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 5, 5, 260, 120)
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(Fonts.normal or love.graphics.getFont())
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    if player then
        love.graphics.print(string.format("Pos: %.0f, %.0f", player.x, player.y), 10, 30)
        local gx, gy = math.floor(player.x/32), math.floor(player.y/32)
        love.graphics.print(string.format("Grid: [%d, %d]", gx, gy), 10, 50)
        -- 显示是否有 BOSS
        local Monster = require("monster")
        local hasBoss = false
        for _, m in ipairs(Monster.list) do if m.isBoss then hasBoss = true break end end
        love.graphics.setColor(hasBoss and {1,0,0} or {0.5,0.5,0.5})
        love.graphics.print("Boss Exist: " .. tostring(hasBoss), 10, 70)
    end

    -- 2. 右侧控制台背景
    local panelW, panelH = 320, 550
    local panelX = w - panelW - 10
    local panelY = 50
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
    
    -- Tabs
    local tabs = {"功能", "变量"}
    local tabW = panelW / 2
    for i, t in ipairs(tabs) do
        local tx = panelX + (i-1)*tabW
        love.graphics.setColor(Debug.activeTab == i and {0.3,0.3,0.3} or {0.15,0.15,0.15})
        love.graphics.rectangle("fill", tx, panelY, tabW, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(t, tx, panelY + 5, tabW, "center")
    end

    local contentY = panelY + 40
    
    -- TAB 1: 常规功能
    if Debug.activeTab == 1 then
        local btnW, btnH = 140, 30
        local gap = 10
        for i, btn in ipairs(Debug.generalButtons) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local bx = panelX + 10 + col * (btnW + gap)
            local by = contentY + row * (btnH + gap)
            btn.rect = {x=bx, y=by, w=btnW, h=btnH}
            
            local mx, my = love.mouse.getPosition()
            local isHover = mx >= bx and mx <= bx+btnW and my >= by and my <= by+btnH
            love.graphics.setColor(isHover and {0.4,0.4,0.4} or {0.25,0.25,0.25})
            love.graphics.rectangle("fill", bx, by, btnW, btnH)
            love.graphics.setColor(1,1,1)
            love.graphics.printf(btn.text, bx, by+5, btnW, "center")
        end
        
        -- === [核心升级] 日志控制台 (支持自动换行) ===
        local logY = contentY + 200
        local logH = panelH - 250
        
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", panelX+5, logY, panelW-10, logH)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("--- 系统日志 ---", panelX+10, logY - 20)
        
        love.graphics.setScissor(panelX+5, logY, panelW-10, logH)
        
        local currentY = logY + 5
        local font = love.graphics.getFont()
        local wrapWidth = panelW - 20
        
        for i, logEntry in ipairs(Debug.logs) do
            love.graphics.setColor(1, 1, 1, 1 - (i-1)*0.05) -- 越旧越透明
            
            -- 拼接时间与文本
            local fullText = string.format("[%s] %s", logEntry.time, logEntry.text)
            
            -- [关键] 获取自动换行后的高度和行数
            local width, wrappedText = font:getWrap(fullText, wrapWidth)
            
            -- 逐行打印
            for _, line in ipairs(wrappedText) do
                love.graphics.print(line, panelX + 10, currentY)
                currentY = currentY + 18 -- 行高
            end
            
            currentY = currentY + 5 -- 段落间距
            
            if currentY > logY + logH then break end
        end
        love.graphics.setScissor()
        
    -- TAB 2: 剧情变量
    elseif Debug.activeTab == 2 then
        local progress = (Player.data and Player.data.progress) or {}
        local i = 0
        for k, v in pairs(progress) do
            local rowY = contentY + i * 30
            love.graphics.setColor(0.4, 0.8, 1)
            love.graphics.print(k, panelX + 10, rowY)
            love.graphics.setColor(1, 1, 0)
            love.graphics.print(tostring(v), panelX + 180, rowY)
            
            -- +/- 按钮
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", panelX+220, rowY, 20, 20)
            love.graphics.rectangle("fill", panelX+250, rowY, 20, 20)
            love.graphics.setColor(0,1,0); love.graphics.print("+", panelX+226, rowY)
            love.graphics.setColor(1,0,0); love.graphics.print("-", panelX+256, rowY)
            i = i + 1
        end
        if i == 0 then
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.printf("暂无变量，请找商人接任务", panelX, contentY+50, panelW, "center")
        end
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- === 3. 交互逻辑 (详细追踪) ===
function Debug.mousepressed(x, y, button)
    if not Debug.showUI or button ~= 1 then return false end
    
    local w = love.graphics.getDimensions()
    local panelW, panelH = 320, 550
    local panelX = w - panelW - 10
    local panelY = 50
    
    -- 1. 切换 Tab
    if y >= panelY and y <= panelY + 30 then
        if x >= panelX and x <= panelX + panelW/2 then Debug.activeTab = 1 return true end
        if x >= panelX + panelW/2 and x <= panelX + panelW then Debug.activeTab = 2 return true end
    end
    
    -- 2. 内容点击
    if Debug.activeTab == 1 then
        for _, btn in ipairs(Debug.generalButtons) do
            if btn.rect and x >= btn.rect.x and x <= btn.rect.x + btn.rect.w and
               y >= btn.rect.y and y <= btn.rect.y + btn.rect.h then
                btn.func()
                return true
            end
        end
        
    elseif Debug.activeTab == 2 then
        local contentY = panelY + 40
        local progress = Player.data.progress or {}
        local i = 0
        
        for k, v in pairs(progress) do
            local rowY = contentY + i * 30
            
            -- 点击 [+]
            if x >= panelX + 220 and x <= panelX + 240 and y >= rowY and y <= rowY + 20 then
                StoryManager.addVar(k, 1)
                local newVal = StoryManager.getVar(k)
                Debug.log(string.format("变量 %s 变更为: %d", k, newVal))
                
                -- [BOSS 生成逻辑]
                if k == "boss_quest_step" and newVal == 1 then
                    Debug.log(">>> 触发 BOSS 生成流程")
                    
                    -- 1. 检查是否存在
                    local Monster = require("monster")
                    local bossExists = false
                    for _, m in ipairs(Monster.list) do 
                        if m.isBoss then bossExists = true break end 
                    end
                    
                    if bossExists then
                        Debug.log("警告: BOSS 已存在，跳过生成")
                    else
                        -- 2. 执行生成
                        local targetX, targetY = 0, -3200 -- 100格远
                        Debug.log(string.format("尝试在 (%d, %d) 生成...", targetX, targetY))
                        
                        -- 3. 调用生成函数
                        local boss = Monster.spawnBoss(targetX, targetY)
                        
                        if boss then
                            Debug.log(string.format("成功! 实际坐标: %.0f, %.0f", boss.x, boss.y))
                            Player.data.questStatus = "active"
                            Player.addOrUpdateQuest("kill_boss", "讨伐魔王 (Debug)", "前往北方...")
                        else
                            Debug.log("失败: spawnBoss 返回 nil")
                        end
                    end
                end
                return true
            end
            
            -- 点击 [-]
            if x >= panelX + 250 and x <= panelX + 270 and y >= rowY and y <= rowY + 20 then
                StoryManager.addVar(k, -1)
                Debug.log(k .. " -1")
                return true
            end
            i = i + 1
        end
    end
    
    -- 吞噬点击
    if x >= panelX and x <= panelX + panelW and y >= panelY and y <= panelY + panelH then return true end
    return false
end

return Debug