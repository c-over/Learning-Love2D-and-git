local Player = {}
local Layout = require("layout")
local Config = require("config")
local ItemManager = require("ItemManager")

-- UI 状态
Player.data = {}
Player.activeTab = 1
Player.hoveredTabIndex = nil
Player.hoveredButtonIndex = nil

-- === 1. 配置 ===
local tabs = {"状态", "装备", "任务"}

-- 装备槽定义
local equipmentSlots = {
    {key = "head",       name = "头部",   col = 1},
    {key = "body",       name = "身体",   col = 1},
    {key = "legs",       name = "腿部",   col = 1},
    {key = "accessory1", name = "饰品 I", col = 1, type = "accessory"},
    {key = "main_hand",  name = "主手",   col = 2},
    {key = "off_hand",   name = "副手",   col = 2},
    {key = "accessory2", name = "饰品 II",col = 2, type = "accessory"},
    {key = "accessory3", name = "饰品 III",col = 2,type = "accessory"},
}

local COLORS = {
    bg          = {0.1, 0.1, 0.15, 0.95},
    panel       = {0.18, 0.18, 0.22, 1},
    border      = {0.6, 0.5, 0.3, 1},
    text        = {1, 1, 1, 1},
    label       = {0.7, 0.7, 0.7, 1},
    tab_active  = {0.2, 0.6, 1, 1},
    tab_inactive= {0.3, 0.3, 0.35, 1},
    bar_bg      = {0.1, 0.1, 0.1, 1},
    hp          = {0.8, 0.2, 0.2, 1},
    mp          = {0.2, 0.4, 0.9, 1},
    exp         = {0.8, 0.8, 0.2, 1}
}

Player.buttons = {
    {
        x = 650, y = 520, w = 120, h = 40,
        text = "返回游戏",
        onClick = function() 
            Player.save() 
            currentScene = "game" 
        end
    }
}

-- === 2. 数据管理 ===

local function initDefaults()
    Player.data.name   = Player.data.name or "未命名"
    Player.data.level  = Player.data.level or 1
    Player.data.hp     = Player.data.hp or 100
    Player.data.maxHp  = Player.data.maxHp or 100
    Player.data.mp     = Player.data.mp or 50
    Player.data.maxMp  = Player.data.maxMp or 50
    Player.data.exp    = Player.data.exp or 0
    Player.data.attack = Player.data.attack or 10
    Player.data.defense= Player.data.defense or 5
    Player.data.speed  = Player.data.speed or 240
    Player.data.gold   = Player.data.gold or 100
    Player.data.equipment = Player.data.equipment or {}
    Player.data.quests = Player.data.quests or {}
end

function Player.save()
    Config.updatePlayer(Player.data)
end

function Player.load()
    Config.load()
    local saveData = Config.get()
    Player.data = saveData.player or {}
    initDefaults()
end

-- === 3. 核心逻辑 ===

function Player.recalcStats()
    local totalDef = 5  -- 基础防御
    local totalAtk = 10 -- 基础攻击
    
    Player.data.equipment = {} 
    
    local inventory = require("config").data.inventory
    if inventory then
        for _, item in ipairs(inventory) do
            if item.equipSlot then
                local def = ItemManager.get(item.id)
                if def then
                    if def.defense then totalDef = totalDef + def.defense end
                    if def.attack then totalAtk = totalAtk + def.attack end
                    
                    local visualEntry = { id = item.id }
                    setmetatable(visualEntry, { __index = def })
                    Player.data.equipment[item.equipSlot] = visualEntry
                end
            end
        end
    end
    
    Player.data.defense = totalDef
    Player.data.attack = totalAtk
end

function Player.equipItem(targetItem)
    local def = ItemManager.get(targetItem.id)
    if not def or not def.slot then return end

    local targetSlot = def.slot
    local finalSlot = nil
    local inventory = require("config").data.inventory

    if targetSlot == "accessory" then
        local slots = {"accessory1", "accessory2", "accessory3"}
        for _, s in ipairs(slots) do
            local isOccupied = false
            for _, item in ipairs(inventory) do
                if item.equipSlot == s then isOccupied = true break end
            end
            if not isOccupied then finalSlot = s break end
        end
        if not finalSlot then finalSlot = "accessory1" end
    else
        finalSlot = targetSlot
    end

    for _, item in ipairs(inventory) do
        if item.equipSlot == finalSlot then item.equipSlot = nil end
    end

    targetItem.equipSlot = finalSlot
    Player.recalcStats()
end

function Player.unequipItem(targetItem)
    targetItem.equipSlot = nil
    Player.recalcStats()
end

-- 基础属性接口
function Player.takeDamage(amount)
    initDefaults()
    local def = Player.data.defense or 0
    local actualDmg = math.max(amount - def, 1)
    Player.data.hp = math.max(Player.data.hp - actualDmg, 0)
    Player.save()
end
function Player.addHP(v) initDefaults(); Player.data.hp = math.min(Player.data.hp + (v or 10), Player.data.maxHp); Player.save() end
function Player.addMP(v) initDefaults(); Player.data.mp = math.min(Player.data.mp + (v or 10), Player.data.maxMp); Player.save() end
function Player.addGold(v) initDefaults(); Player.data.gold = Player.data.gold + (v or 10); Player.save() end
function Player.gainExp(v) 
    initDefaults()
    Player.data.exp = Player.data.exp + (v or 10)
    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.addLevel(1)
    end
    Player.save() 
end
function Player.addLevel(v) 
    initDefaults()
    local inc = v or 1
    Player.data.level = Player.data.level + inc
    Player.data.maxHp = Player.data.maxHp + 100 * inc
    Player.data.maxMp = Player.data.maxMp + 20 * inc
    Player.data.hp = Player.data.maxHp
    Player.data.mp = Player.data.maxMp
    Player.data.attack = Player.data.attack + 5 * inc
    Player.data.defense= Player.data.defense + 3 * inc
    Player.save()
end
function Player.useMana(cost)
    initDefaults()
    if Player.data.mp >= cost then
        Player.data.mp = Player.data.mp - cost
        Player.save()
        return true
    else
        return false
    end
end

-- === 4. 绘制 ===

function Player.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local fontLarge = Fonts.large or love.graphics.getFont()
    local fontNormal = Fonts.normal or love.graphics.getFont()

    local vWinX, vWinY = 80, 80
    local vWinW, vWinH = Layout.virtualWidth - 160, Layout.virtualHeight - 160
    
    local sWinX, sWinY = Layout.toScreen(vWinX, vWinY)
    local sWinW, sWinH = Layout.toScreen(vWinW, vWinH)

    love.graphics.setColor(COLORS.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", sWinX, sWinY, sWinW, sWinH, 10, 10)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", sWinX, sWinY, sWinW, sWinH, 10, 10)
    love.graphics.setLineWidth(1)

    -- 标签页
    local vTabW, vTabH = 100, 35
    local vTabStartX = vWinX + 20
    for i, tab in ipairs(tabs) do
        local vTx = vTabStartX + (i-1)*(vTabW+5)
        local vTy = vWinY + 15
        
        local sTx, sTy = Layout.toScreen(vTx, vTy)
        local sTw, sTh = Layout.toScreen(vTabW, vTabH)
        
        if Player.activeTab == i then
            love.graphics.setColor(COLORS.tab_active)
        elseif Player.hoveredTabIndex == i then
            love.graphics.setColor(COLORS.tab_active[1], COLORS.tab_active[2], COLORS.tab_active[3], 0.7)
        else
            love.graphics.setColor(COLORS.tab_inactive)
        end
        love.graphics.rectangle("fill", sTx, sTy, sTw, sTh, 5, 5)
        love.graphics.setColor(COLORS.text)
        love.graphics.setFont(fontNormal)
        local _, textOffset = Layout.toScreen(0, (vTabH - fontNormal:getHeight())/2)
        love.graphics.printf(tab, sTx, sTy + textOffset, sTw, "center")
    end
    
    local _, sLineY = Layout.toScreen(0, vWinY + 60)
    love.graphics.setColor(COLORS.border)
    love.graphics.line(sWinX, sLineY, sWinX + sWinW, sLineY)

    local vContentX = vWinX + 40
    local vContentY = vWinY + 80

    -- [状态]
    if Player.activeTab == 1 then
        local sCX, sCY = Layout.toScreen(vContentX, vContentY)
        love.graphics.setColor(COLORS.text)
        love.graphics.setFont(fontLarge)
        love.graphics.print(Player.data.name or "Hero", sCX, sCY)
        
        local sLevelX, sLevelY = Layout.toScreen(vContentX, vContentY + 30)
        love.graphics.setFont(fontNormal)
        love.graphics.setColor(COLORS.label)
        love.graphics.print("等级 " .. (Player.data.level or 1), sLevelX, sLevelY)

        local vStatX = vContentX + 250
        local vStatY = vContentY
        local lineHeight = 30
        local function drawStat(label, value, idx, color)
            local sx, sy = Layout.toScreen(vStatX, vStatY + idx * lineHeight)
            love.graphics.setColor(color or COLORS.text)
            love.graphics.print(label .. ": " .. value, sx, sy)
        end
        drawStat("攻击力", Player.data.attack or 0, 0)
        drawStat("防御力", Player.data.defense or 0, 1)
        drawStat("速  度", Player.data.speed or 0, 2)
        drawStat("金  币", Player.data.gold or 0, 3, {1, 0.9, 0.2, 1})

        local vBarY = vContentY + 150
        local vBarW = vWinW - 80
        local barGap = 50
        local function drawBar(label, cur, max, idx, color)
            local vy = vBarY + idx * barGap
            local sx, sy = Layout.toScreen(vContentX, vy)
            local sw, sh = Layout.toScreen(vBarW, 20)
            local _, textOff = Layout.toScreen(0, 20)
            love.graphics.setColor(COLORS.label)
            love.graphics.print(label, sx, sy - textOff)
            love.graphics.setColor(COLORS.bar_bg)
            love.graphics.rectangle("fill", sx, sy, sw, sh, 4, 4)
            local ratio = math.min(math.max(cur / max, 0), 1)
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", sx, sy, sw * ratio, sh, 4, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(math.floor(cur).."/"..math.floor(max), sx, sy + 2, sw, "center")
        end
        drawBar("生命值", Player.data.hp, Player.data.maxHp, 0, COLORS.hp)
        drawBar("法力值", Player.data.mp, Player.data.maxMp, 1, COLORS.mp)
        drawBar("经验值", Player.data.exp, Player.data.level * 100, 2, COLORS.exp)

    -- [装备]
    elseif Player.activeTab == 2 then
        local vSlotW, vSlotH = 170, 60
        local vIconSize = 48
        local col1X = vContentX
        local col2X = vContentX + 220 
        local count1 = 0
        local count2 = 0
        
        if not Player.data.equipment then Player.data.equipment = {} end

        for _, slot in ipairs(equipmentSlots) do
            local drawX, drawY
            local rowIdx = 0
            if slot.col == 1 then
                drawX = col1X
                rowIdx = count1
                count1 = count1 + 1
            else
                drawX = col2X
                rowIdx = count2
                count2 = count2 + 1
            end
            drawY = vContentY + rowIdx * (vSlotH + 10) 

            local sSlotX, sSlotY = Layout.toScreen(drawX, drawY)
            local sSlotW, sSlotH = Layout.toScreen(vSlotW, vSlotH)

            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.rectangle("fill", sSlotX, sSlotY, sSlotW, sSlotH, 5, 5)

            local sIconX, sIconY = Layout.toScreen(drawX + 6, drawY + 6)
            local sIconSize, _ = Layout.toScreen(vIconSize, vIconSize)
            love.graphics.setColor(COLORS.border)
            love.graphics.rectangle("line", sIconX, sIconY, sIconSize, sIconSize)

            local equippedDef = Player.data.equipment[slot.key]
            
            if equippedDef then
                -- 图标
                local img, quad = ItemManager.getIcon(equippedDef.id)
                if img then
                    love.graphics.setColor(1, 1, 1)
                    local iw, ih
                    if quad then _, _, iw, ih = quad:getViewport() else iw, ih = img:getWidth(), img:getHeight() end
                    local fitScale = math.min(sIconSize / iw, sIconSize / ih) * 0.9
                    local dx = sIconX + (sIconSize - iw * fitScale) / 2
                    local dy = sIconY + (sIconSize - ih * fitScale) / 2
                    if quad then love.graphics.draw(img, quad, dx, dy, 0, fitScale, fitScale)
                    else love.graphics.draw(img, dx, dy, 0, fitScale, fitScale) end
                end
                
                -- 文字
                local sTextX, sTextY = Layout.toScreen(drawX + 60, drawY + 8)
                love.graphics.setColor(COLORS.tab_active)
                love.graphics.printf(equippedDef.name, sTextX, sTextY, sSlotW - 65, "left")
                
                -- [修复 2] 属性显示 (拼接字符串)
                love.graphics.setColor(COLORS.label)
                local parts = {}
                if equippedDef.attack then table.insert(parts, "攻+"..equippedDef.attack) end
                if equippedDef.defense then table.insert(parts, "防+"..equippedDef.defense) end
                
                local info = table.concat(parts, "  ") -- 用空格连接
                
                local _, sLineH = Layout.toScreen(0, 20)
                love.graphics.print(info, sTextX, sTextY + sLineH)
            else
                local sTextX, sTextY = Layout.toScreen(drawX + 60, drawY + 20)
                love.graphics.setColor(COLORS.label)
                love.graphics.print(slot.name, sTextX, sTextY)
            end
        end

    -- [任务]
    elseif Player.activeTab == 3 then
        local sQuestX, sQuestY = Layout.toScreen(vContentX, vContentY)
        local _, sLineH = Layout.toScreen(0, 30)
        
        -- [修复 1] 补全任务列表的绘制代码
        if not Player.data.quests or #Player.data.quests == 0 then
            local _, sOffY = Layout.toScreen(0, 100)
            love.graphics.setColor(COLORS.label)
            love.graphics.printf("当前没有进行中的任务。", sQuestX, sQuestY + sOffY, sWinW-80, "center")
        else
            -- 遍历绘制任务
            local currentY = sQuestY
            for i, quest in ipairs(Player.data.quests) do
                -- 任务标题
                love.graphics.setColor(COLORS.text)
                love.graphics.setFont(fontLarge)
                love.graphics.print("★ " .. quest.name, sQuestX, currentY)
                
                -- 任务描述
                love.graphics.setColor(COLORS.label)
                love.graphics.setFont(fontNormal)
                local descY = currentY + 25
                -- 自动换行
                love.graphics.printf(quest.description, sQuestX + 20, descY, sWinW - 100, "left")
                
                -- 更新 Y 坐标 (标题+描述+间距)
                -- 这里简单估算高度，或者 Layout 自动排版
                currentY = currentY + 80
            end
        end
    end

    -- 按钮
    for i, btn in ipairs(Player.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local bw, bh = Layout.toScreen(btn.w, btn.h)
        
        if Player.hoveredButtonIndex == i then
            love.graphics.setColor(COLORS.tab_active)
        else
            love.graphics.setColor(COLORS.tab_inactive)
        end
        love.graphics.rectangle("fill", bx, by, bw, bh, 5, 5)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", bx, by, bw, bh, 5, 5)
        
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(btn.text, bx, by + (bh - 14)/2, bw, "center")
    end
    
    love.graphics.setColor(1, 1, 1)
end

-- === 5. 输入 ===

function Player.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)
    
    local vTabW, vTabH = 100, 35
    local vWinX, vWinY = 80, 80
    local vTabStartX = vWinX + 20
    for i, tab in ipairs(tabs) do
        local tx = vTabStartX + (i-1)*(vTabW+5)
        local ty = vWinY + 15
        if vx >= tx and vx <= tx + vTabW and vy >= ty and vy <= ty + vTabH then
            Player.activeTab = i
            return "player"
        end
    end
    
    local index = Layout.mousepressed(x, y, button, Player.buttons)
    if index then 
        local btn = Player.buttons[index]
        if btn and btn.onClick then btn.onClick() end
        return "player" 
    end
    return "player"
end

function Player.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)
    Player.hoveredTabIndex = nil
    local vTabW, vTabH = 100, 35
    local vWinX, vWinY = 80, 80
    local vTabStartX = vWinX + 20
    for i, tab in ipairs(tabs) do
        local tx = vTabStartX + (i-1)*(vTabW+5)
        local ty = vWinY + 15
        if vx >= tx and vx <= tx + vTabW and vy >= ty and vy <= ty + vTabH then
            Player.hoveredTabIndex = i
            break
        end
    end
    Player.hoveredButtonIndex = Layout.mousemoved(x, y, Player.buttons)
end

function Player.keypressed(key)
    if key == "escape" then 
        Player.save()
        return "game" 
    end
    return "player"
end

return Player