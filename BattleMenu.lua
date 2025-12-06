local BattleMenu = {}

local Layout = require("layout")
local Player = require("player")
local UIGrid = require("UIGrid")
local ItemManager = require("ItemManager")
local MagicManager = require("MagicManager")
local Config = require("config")
-- 动态引用 Battle，防止死锁

-- === 配置 ===
local PANEL_H = 160
local LOG_PANEL_W = 240
local SLOT_SIZE = 40 
local GRID_COLS = 6
local GRID_ROWS = 2

-- 布局常量
-- 主面板宽度 = 总宽 - 日志区宽 - 间距
local MAIN_PANEL_W = Layout.virtualWidth - LOG_PANEL_W - 10
local POS_STATUS_X = 20    
local POS_CMD_X    = 20   
local POS_GRID_X   = 120   
local POS_EQUIP_X  = MAIN_PANEL_W - (40 * 3 + 20)
local EQUIP_GRID_MAP = {
    [1] = "head",       [2] = "body",       [3] = "legs",
    [4] = "main_hand",  [5] = nil,          [6] = "off_hand",
    [7] = "accessory1", [8] = "accessory3", [9] = "accessory2" 
}

-- === 状态 ===
BattleMenu.state = {
    phase = "idle",    
    turn = "player",   
    enemy = nil,
    enemyIndex = nil,
    log = {},
    timer = 0,
    shake = 0,
    onResolve = nil,
    isDefending = false,
    animResetTimer = 0,
    activeTab = "item",
    itemPage = 1,
    skillPage = 1
}

BattleMenu.cachedItems = {}   
BattleMenu.cachedSpells = {}  
BattleMenu.cachedEquips = {}  
BattleMenu.tooltip = nil
-- [新增] 简单的闪白 Shader 代码
local flashShaderCode = [[
    extern number intensity;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texcolor = Texel(texture, texture_coords);
        // 将原色与白色混合，intensity 控制混合程度 (0~1)
        return mix(texcolor, vec4(1,1,1,texcolor.a), intensity) * color;
    }
]]
local flashShader -- Shader 对象
-- === 初始化 ===
function BattleMenu.init(enemyPayload, enemyIndex, onResolve)
    BattleMenu.state.phase = "idle"
    BattleMenu.state.turn = "player"
    BattleMenu.state.log = {}
    BattleMenu.state.timer = 0
    BattleMenu.state.shake = 0
    BattleMenu.state.isDefending = false
    BattleMenu.state.animResetTimer = 0
    BattleMenu.state.activeTab = "item"
        -- [新增] 初始化 Shader
    if not flashShader then
        flashShader = love.graphics.newShader(flashShaderCode)
    end
    -- 初始化敌人
    BattleMenu.state.enemy = {
        name = enemyPayload.name,
        level = enemyPayload.level or 1,
        hp = enemyPayload.hp or 50,
        maxHp = enemyPayload.maxHp or 50,
        attack = enemyPayload.attack,
        isBoss = enemyPayload.isBoss,
        aiType = enemyPayload.aiType,
        escapeChance = (enemyPayload.isBoss and 0) or (enemyPayload.escapeChance or 0.5),
        
        -- 视觉数据
        texture = enemyPayload.texture,
        quads = enemyPayload.quads,       -- 如果是静态图，这里可能是 nil
        animConfig = enemyPayload.animConfig, -- 同上
        visualState = "idle", animFrame = 1, animTimer = 0,
        w = enemyPayload.w or 32, h = enemyPayload.h or 32,
        flashTimer = 0, 
    }
    
    BattleMenu.state.enemyIndex = enemyIndex
    BattleMenu.state.onResolve = onResolve
    
    BattleMenu.refreshLists()
    
    local h = Layout.virtualHeight
    local gridY = h - PANEL_H + 40 
    
    UIGrid.config("battle_grid", {
        cols = GRID_COLS, rows = GRID_ROWS,
        slotSize = SLOT_SIZE, margin = 5,
        startX = POS_GRID_X, startY = gridY
    })
    UIGrid.useConfig("battle_grid")
end

-- === 数据刷新 ===
function BattleMenu.refreshLists()
    local inventory = Config.data.inventory
    
    BattleMenu.cachedItems = {}
    for _, item in ipairs(inventory) do
        local def = ItemManager.get(item.id)
        if def and (def.usable or def.category == "weapon") and def.category ~= "equipment" then
            table.insert(BattleMenu.cachedItems, item)
        end
    end
    
    BattleMenu.cachedEquips = {}
    for _, item in ipairs(inventory) do
        local def = ItemManager.get(item.id)
        if def and (def.category == "equipment" or def.category == "weapon") then
            table.insert(BattleMenu.cachedEquips, item)
        end
    end
    
    BattleMenu.cachedSpells = {}
    local all = MagicManager.getPlayerSpells()
    for _, spell in ipairs(all) do
        if spell.type == "damage" or spell.type == "heal" or spell.type == "buff" then
            table.insert(BattleMenu.cachedSpells, spell)
        end
    end
end

function BattleMenu.addLog(msg)
    table.insert(BattleMenu.state.log, {text = msg, time = love.timer.getTime()})
end

function BattleMenu.triggerShake(amount)
    BattleMenu.state.shake = amount
end

local floatTexts = {}
function BattleMenu.addFloatText(text, target, color)
    local w, h = Layout.virtualWidth, Layout.virtualHeight
    local x, y
    if target == "player" then x, y = 100, h - 150
    elseif target == "enemy" then x, y = w/2, h/2 - 80
    else x, y = w/2, h/2 end 
    table.insert(floatTexts, {text=text, x=x, y=y, color=color, life=1.5, oy=0})
end

-- === 绘制辅助 ===
local function drawIconButton(x, y, id, count, isEquipped, mpCost)
    local sx, sy = Layout.toScreen(x, y)
    local _, ss = Layout.toScreen(0, SLOT_SIZE)
    
    local mx, my = love.mouse.getPosition()
    local vx, vy = Layout.toVirtual(mx, my)
    local isHover = vx >= x and vx <= x + SLOT_SIZE and vy >= y and vy <= y + SLOT_SIZE
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", sx, sy, ss, ss, 4)
    if isHover then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", sx, sy, ss, ss, 4)
    end
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", sx, sy, ss, ss, 4)
    
    love.graphics.setColor(1, 1, 1)
    local img, quad
    if mpCost then img, quad = MagicManager.getIcon(id)
    else img, quad = ItemManager.getIcon(id) end
    
    if img then
        local s = (ss * 0.8) / (quad and select(3, quad:getViewport()) or img:getWidth())
        if quad then love.graphics.draw(img, quad, sx+ss*0.1, sy+ss*0.1, 0, s, s)
        else love.graphics.draw(img, sx+ss*0.1, sy+ss*0.1, 0, s, s) end
    end
    
    if isEquipped then love.graphics.setColor(0,1,0); love.graphics.print("E", sx+2, sy+2) end
    if count and count > 1 then love.graphics.setColor(1,1,1); love.graphics.setFont(Fonts.small); love.graphics.print(count, sx+ss-15, sy+ss-15) end
    if mpCost then love.graphics.setColor(0.4,0.6,1); love.graphics.setFont(Fonts.small); love.graphics.print(mpCost, sx+2, sy+ss-14) end
    
    return isHover
end

-- 通用条形绘制函数
-- type: "hp" 或 "mp"
-- isFixed: boolean, 如果为 true 则使用固定宽度(用于玩家UI)，false 则动态计算宽度(用于BOSS)
local function drawDynamicBar(entity, x, y, type, isFixed)
    local cur, max
    local color
    
    -- 1. 根据类型获取数值和颜色
    if type == "mp" then
        cur = entity.mp or 0
        max = entity.maxMp or 1
        color = {0.2, 0.4, 0.9} -- 蓝色
    else
        -- 默认为 hp
        cur = entity.hp or 0
        max = entity.maxHp or 1
        color = {0.9, 0.2, 0.2} -- 红色
    end
    
    -- 2. 计算宽度
    local barW
    if isFixed then
        barW = 200 -- 玩家状态栏固定宽度
    else
        -- 怪物/BOSS 动态宽度
        local widthScale = 1.5 
        local minW, maxW = 80, Layout.virtualWidth - 100
        barW = math.max(minW, math.min(max * widthScale, maxW))
    end
    
    local barH = 16 -- 条的高度
    
    -- 3. 居中逻辑 (如果不是固定宽度，通常意味着是怪物，需要屏幕居中)
    if not isFixed then 
        x = (Layout.virtualWidth - barW) / 2 
    end

    -- 4. 绘制条形
    -- 背景
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, barW, barH)
    
    -- 前景 (进度)
    love.graphics.setColor(unpack(color))
    local ratio = math.max(0, math.min(cur / max, 1))
    love.graphics.rectangle("fill", x, y, barW * ratio, barH)
    
    -- 边框
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, barW, barH)
    
    -- 5. 绘制文字 (位于下方)
    local text = ""
    if isFixed then
        -- 玩家/UI: 只显示数值 "100/100"
        if type == "hp" then
            text = string.format("HP: %d/%d", entity.hp, entity.maxHp)
        else
            text = string.format("MP: %d/%d", entity.mp, entity.maxMp)
        end
    else
        -- 怪物: 显示 "名字 Lv.X: 数值" (MP通常怪物不显示，或者只显示数值)
        if type == "hp" then
            text = string.format("%s Lv.%d: %d", entity.name, entity.level, math.floor(cur))
        else
            text = string.format("MP: %d", math.floor(cur))
        end
    end
    
    love.graphics.setFont(Fonts.small or love.graphics.getFont())
    
    -- 文字居中逻辑 (创建一个足够宽的文本框，中心对齐血条中心)
    local textLayoutW = 600
    local textX = x + (barW - textLayoutW) / 2
    
    -- 阴影
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(text, textX + 1, y + barH + 5 + 1, textLayoutW, "center")
    
    -- 本体
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, textX, y + barH + 5, textLayoutW, "center")
end

-- === 主绘制 ===
function BattleMenu.draw()
    local realW, realH = love.graphics.getDimensions()
    
    -- 1. 场景遮罩
    love.graphics.setColor(0, 0, 0, 0.7) 
    love.graphics.rectangle("fill", 0, 0, realW, realH)

    local w, h = Layout.virtualWidth, Layout.virtualHeight
    
    -- 使用局部变量锁定震动状态，确保 push/pop 绝对配对
    local isShaking = BattleMenu.state.shake > 0
    
    -- 2. 绘制场景层 (怪物 + 震动)
    if isShaking then
        local dx = math.random(-BattleMenu.state.shake, BattleMenu.state.shake)
        local dy = math.random(-BattleMenu.state.shake, BattleMenu.state.shake)
        love.graphics.push()
        love.graphics.translate(dx, dy)
    end

    local enemy = BattleMenu.state.enemy
    if enemy then
        -- 计算游戏区域高度 (屏幕高 - 面板高)
        local gameH = h - PANEL_H
        -- 在游戏区域正中心绘制
        local cx, cy = w/2, gameH/2
        love.graphics.setColor(1,1,1)
        -- 应用闪白特效
        if enemy.flashTimer > 0 then
            love.graphics.setShader(flashShader)
            -- 根据时间计算强度，产生一闪一闪的效果，或者持续高亮
            flashShader:send("intensity", 0.8) 
        end
        
        love.graphics.setColor(1,1,1)
        -- 怪物绘制三级判定
        if enemy.texture then
            -- 1. 优先检查是否有动画帧配置 (Quads)
            if enemy.quads and enemy.animConfig then
                local frames = enemy.animConfig[enemy.visualState] or {1}
                local frameIdx = frames[enemy.animFrame] or 1
                local q = enemy.quads[frameIdx]
                if q then
                    local _,_,qw,qh = q:getViewport()
                    love.graphics.draw(enemy.texture, q, cx, cy, 0, 3, 3, qw/2, qh/2)
                else
                    -- 动画配置出错，画原图
                    love.graphics.draw(enemy.texture, cx, cy, 0, 3, 3, enemy.texture:getWidth()/2, enemy.texture:getHeight()/2)
                end
            else
                -- 2. 静态贴图 (无动画)
                local iw, ih = enemy.texture:getDimensions()
                love.graphics.draw(enemy.texture, cx, cy, 0, 3, 3, iw/2, ih/2)
            end
        else
            -- 3. 无贴图兜底 (红方块)
            love.graphics.setColor(1,0,0)
            love.graphics.rectangle("fill", cx-32, cy-32, 64, 64)
        end
        love.graphics.setShader()
        
        -- 绘制怪物血条 (跟随震动)
        drawDynamicBar(enemy, 0, cy + 80, "hp", false)
    end

    if isShaking then
        love.graphics.pop()
    end

    -- 3. 绘制 UI 面板 (不震动)
    local panelY = h - PANEL_H
    local sx, sy = Layout.toScreen(0, panelY)
    local sw, sh = Layout.toScreen(w, PANEL_H)
    love.graphics.setColor(0.1, 0.1, 0.12, 0.95)
    love.graphics.rectangle("fill", sx, sy, sw, sh)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.line(sx, sy, sx+sw, sy)
    
    -- A. 玩家状态
    local pX = 20
    local pY = panelY + 30
    -- 绘制状态条
    drawDynamicBar(Player.data, pX, pY, "hp", true)
    drawDynamicBar(Player.data, pX, pY+45, "mp", true)

    -- B. 指令按钮
    local cmdX = POS_CMD_X
    local cmdY = panelY + 25
    local btnW, btnH = 80, 35
    local gap = 10
    local cmds = {{t="攻击"}, {t="防御"}, {t="逃跑"}}
    local mx, my = love.mouse.getPosition()
    local vx, vy = Layout.toVirtual(mx, my)
    
    for i, c in ipairs(cmds) do
        local by = cmdY + (i-1)*(btnH+gap)
        local bsx, bsy = Layout.toScreen(cmdX, by)
        local bsw, bsh = Layout.toScreen(btnW, btnH)
        local isHover = vx>=cmdX and vx<=cmdX+btnW and vy>=by and vy<=by+btnH
        love.graphics.setColor(isHover and {0.3,0.3,0.3} or {0.2,0.2,0.2})
        love.graphics.rectangle("fill", bsx, bsy, bsw, bsh, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bsx, bsy, bsw, bsh, 4)
        love.graphics.printf(c.t, bsx, bsy+(bsh-16)/2, bsw, "center")
    end
    
    -- C. Grid
    UIGrid.useConfig("battle_grid")
    local list = {}
    if BattleMenu.state.activeTab == "item" then list = BattleMenu.cachedItems
    elseif BattleMenu.state.activeTab == "skill" then list = BattleMenu.cachedSpells
    elseif BattleMenu.state.activeTab == "equip" then list = BattleMenu.cachedEquips end
    
    BattleMenu.tooltip = nil
    
    local tabX = POS_GRID_X
    local tabY = panelY + 10
    local tabW = 50
    local tabs = { {k="item",t="物品"}, {k="skill",t="魔法"}, {k="equip",t="装备"} }
    for i, t in ipairs(tabs) do
        local tx = tabX + (i-1)*(tabW+10)
        local tsx, tsy = Layout.toScreen(tx, tabY)
        local tsw, tsh = Layout.toScreen(tabW, 20)
        if BattleMenu.state.activeTab == t.k then love.graphics.setColor(0.2,0.6,1) else love.graphics.setColor(0.3,0.3,0.3) end
        love.graphics.rectangle("fill", tsx, tsy, tsw, tsh, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(t.t, tsx, tsy+3, tsw, "center")
    end
    
    local function render(idx, x, y, w, h, state)
        local item = list[idx]
        if not item then return end
        if state.hovered then
            love.graphics.setColor(1,1,1,0.2); love.graphics.rectangle("fill", x, y, w, h)
            if BattleMenu.state.activeTab == "skill" then BattleMenu.tooltip = item
            else BattleMenu.tooltip = ItemManager.get(item.id) end
        end
        love.graphics.setColor(0.4,0.4,0.4); love.graphics.rectangle("line", x, y, w, h)
        local id = item.id
        local count = item.count
        local isEq = item.equipSlot
        local mp = item.mp
        local img, quad 
        if BattleMenu.state.activeTab == "skill" then img, quad = MagicManager.getIcon(id)
        else img, quad = ItemManager.getIcon(id) end
        love.graphics.setColor(1,1,1)
        if img then
            local s = (w*0.8) / (quad and select(3,quad:getViewport()) or img:getWidth())
            if quad then love.graphics.draw(img, quad, x+w*0.1, y+h*0.1, 0, s, s)
            else love.graphics.draw(img, x+w*0.1, y+h*0.1, 0, s, s) end
        end
        if count and count > 1 then love.graphics.print(count, x+w-15, y+h-15) end
        if mp then love.graphics.setColor(0.4,0.6,1); love.graphics.print(mp, x+2, y+h-14) end
        if isEq then love.graphics.setColor(0,1,0); love.graphics.print("E", x+2, y+2) end
    end
    UIGrid.drawAll(render, list, UIGrid.hoveredSlotIndex)
    UIGrid.drawScrollbar(#list)

    -- D. 右侧装备 (3x3 网格)
    local eqY = panelY + 25
    love.graphics.setColor(1,1,0.6)
    love.graphics.print("装备", Layout.toScreen(POS_EQUIP_X, eqY-20))
    
    local eqSize = SLOT_SIZE
    local eqGap = 5
    
    for i = 1, 9 do
        -- 计算行列 (0-2)
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local dx = POS_EQUIP_X + col * (eqSize + eqGap)
        local dy = eqY + row * (eqSize + eqGap)
        
        local slotKey = EQUIP_GRID_MAP[i]
        local def = slotKey and Player.data.equipment[slotKey] or nil
        
        if def then
            -- 有装备，画图标
            if drawIconButton(dx, dy, def.id, nil, true, nil) then 
                BattleMenu.tooltip = def 
            end
        else
            -- 空格子
            local sx, sy = Layout.toScreen(dx, dy)
            local _, ss = Layout.toScreen(0, eqSize)
            love.graphics.setColor(1,1,1,0.1)
            love.graphics.rectangle("line", sx, sy, ss, ss, 4)
        end
    end

    --F、绘制日志面板
    local logX = MAIN_PANEL_W + 5
    local logY = h - PANEL_H
    local slx, sly = Layout.toScreen(logX, logY)
    local slw, slh = Layout.toScreen(LOG_PANEL_W, PANEL_H)
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", slx, sly, slw, slh)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("line", slx, sly, slw, slh)
    
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.setFont(Fonts.medium)
    love.graphics.print("战斗记录", Layout.toScreen(logX + 10, logY + 10))
    
    -- 绘制日志内容
    local logContentY = logY + 35
    local _, sLineH = Layout.toScreen(0, 20)
    
    -- 裁剪以防溢出
    love.graphics.setScissor(slx, sly + 30, slw, slh - 35)
    
    -- 倒序显示最近的 6 条
    local count = 0
    for i = #BattleMenu.state.log, 1, -1 do
        if count >= 6 then break end
        local entry = BattleMenu.state.log[i]
        
        -- 根据时间计算透明度 (可选，这里为了清晰始终显示)
        love.graphics.setColor(1, 1, 1)
        if string.find(entry.text, "伤害") then love.graphics.setColor(1,0.6,0.6) end
        if string.find(entry.text, "恢复") then love.graphics.setColor(0.6,1,0.6) end
        
        local drawY = logContentY + count * 20
        love.graphics.setFont(Fonts.small)
        love.graphics.print(">"..entry.text, Layout.toScreen(logX + 10, drawY))
        
        count = count + 1
    end
    love.graphics.setScissor()

    -- Tooltip
    if BattleMenu.tooltip then
        local def = BattleMenu.tooltip
        local text = (def.name or "???") .. "\n" .. (def.description or "")
        UIGrid.drawTooltip(text)
    end
    
    -- G. 飘字
    love.graphics.setFont(Fonts.large)
    for i = #floatTexts, 1, -1 do
        local f = floatTexts[i]
        f.life = f.life - love.timer.getDelta()
        f.oy = f.oy - love.timer.getDelta() * 40
        if f.life <= 0 then table.remove(floatTexts, i) else
            local fsx, fsy = Layout.toScreen(f.x, f.y + f.oy)
            love.graphics.setColor(f.color[1], f.color[2], f.color[3], f.life)
            love.graphics.print(f.text, fsx, fsy)
        end
    end
    love.graphics.setColor(1,1,1)
end

-- === 交互 ===
function BattleMenu.mousepressed(x, y, button)
    if button ~= 1 then return end
    local Battle = require("battle") 
    if BattleMenu.state.turn ~= "player" or BattleMenu.state.phase ~= "idle" then return end
    
    local vx, vy = Layout.toVirtual(x, y)
    local panelY = Layout.virtualHeight - PANEL_H
    
    -- 1. 指令按钮
    local cmdY = panelY + 25
    local btnW, btnH, gap = 80, 35, 10
    if vx>=POS_CMD_X and vx<=POS_CMD_X+btnW and vy>panelY then
        if vy < cmdY+btnH+gap then Battle.playerAttackAction()
        elseif vy < cmdY+(btnH+gap)*2 then Battle.playerDefendAction()
        else Battle.playerEscapeAction() end
        return
    end
    
    -- 2. Tab 切换
    local tabY = panelY + 10
    if vy >= tabY and vy <= tabY + 25 then
        if vx >= POS_GRID_X and vx <= POS_GRID_X + 60 then BattleMenu.state.activeTab="item"; UIGrid.scrollOffset=0 return end
        if vx >= POS_GRID_X + 70 and vx <= POS_GRID_X + 130 then BattleMenu.state.activeTab="skill"; UIGrid.scrollOffset=0 return end
        if vx >= POS_GRID_X + 140 and vx <= POS_GRID_X + 200 then BattleMenu.state.activeTab="equip"; UIGrid.scrollOffset=0 return end
    end
    
    -- 3. Grid 交互
    local list = {}
    if BattleMenu.state.activeTab == "item" then list = BattleMenu.cachedItems
    elseif BattleMenu.state.activeTab == "skill" then list = BattleMenu.cachedSpells
    elseif BattleMenu.state.activeTab == "equip" then list = BattleMenu.cachedEquips end
    
    if UIGrid.checkScrollbarPress(vx, vy, #list) then return end
    local idx = UIGrid.getIndexAtPosition(vx, vy)
    if idx then
        local realIdx = math.floor(UIGrid.scrollOffset) + idx
        local target = list[realIdx]
        if target then
             if BattleMenu.state.activeTab == "item" then
                 Battle.onBattleMenuAction("item", target)
             elseif BattleMenu.state.activeTab == "equip" then
                 Battle.onBattleMenuAction("equip", target)
             elseif BattleMenu.state.activeTab == "skill" then
                 Battle.onBattleMenuAction("skill", target)
             end
             BattleMenu.refreshLists()
        end
        return
    end
    
    -- [修改] 4. 装备栏交互 (3x3 网格点击)
    local eqY = panelY + 25
    local eqSize = SLOT_SIZE
    local eqGap = 5
    local totalEqW = 3 * (eqSize + eqGap)
    local totalEqH = 3 * (eqSize + eqGap)
    
    if vx >= POS_EQUIP_X and vx <= POS_EQUIP_X + totalEqW and
       vy >= eqY and vy <= eqY + totalEqH then
       
        -- 计算点击了第几个格子
        local col = math.floor((vx - POS_EQUIP_X) / (eqSize + eqGap))
        local row = math.floor((vy - eqY) / (eqSize + eqGap))
        
        if col >= 0 and col < 3 and row >= 0 and row < 3 then
            local index = row * 3 + col + 1
            local slotKey = EQUIP_GRID_MAP[index]
            
            -- 如果该槽位有东西，执行卸下
            if slotKey then
                -- 需要去 inventory 找对应的 item 对象以便调用 unequip
                -- (Player.data.equipment 存的是 def，无法直接用于 unequipItem 函数)
                for _, item in ipairs(Config.data.inventory) do
                    if item.equipSlot == slotKey then
                        Battle.onBattleMenuAction("equip", item)
                        BattleMenu.refreshLists()
                        break
                    end
                end
            end
        end
    end
end

function BattleMenu.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)
    if UIGrid.scrollbar.isDragging then
        local list = {}
        if BattleMenu.state.activeTab == "item" then list = BattleMenu.cachedItems
        elseif BattleMenu.state.activeTab == "skill" then list = BattleMenu.cachedSpells
        elseif BattleMenu.state.activeTab == "equip" then list = BattleMenu.cachedEquips end
        UIGrid.updateScrollbarDrag(vx, vy, #list)
    else
        UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    end
end

function BattleMenu.wheelmoved(x, y)
    local list = {}
    if BattleMenu.state.activeTab == "item" then list = BattleMenu.cachedItems
    elseif BattleMenu.state.activeTab == "skill" then list = BattleMenu.cachedSpells
    elseif BattleMenu.state.activeTab == "equip" then list = BattleMenu.cachedEquips end
    UIGrid.scroll(-y, #list)
end

return BattleMenu