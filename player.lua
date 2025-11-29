local Player = {}
local Layout = require("layout")
local Config = require("config")
-- ItemManager 需要在函数内 require，防止循环引用

-- UI 状态
Player.data = {}
Player.activeTab = 1
Player.hoveredTabIndex = nil
Player.hoveredButtonIndex = nil
Player.debugButtonsAdded = false

-- === 1. 配置与配色 ===
local tabs = {"状态", "装备", "任务"}

-- 装备槽位定义 (key 对应 items.json 中的 slot 字段)
local equipmentSlots = {
    {key = "head",      name = "头部", col = 1, icon = "assets/icon.png"}, -- 可以在这里预设底图
    {key = "body",      name = "身体", col = 1},
    {key = "legs",      name = "腿部", col = 1},
    {key = "accessory1",name = "饰品 I", col = 1, type = "accessory"}, -- type用于逻辑判断

    {key = "main_hand", name = "主手", col = 2},
    {key = "off_hand",  name = "副手", col = 2},
    {key = "accessory2",name = "饰品 II", col = 2, type = "accessory"},
    {key = "accessory3",name = "饰品 III",col = 2, type = "accessory"},
}

local COLORS = {
    bg          = {0.1, 0.1, 0.15, 0.95}, -- 深色背景
    panel       = {0.18, 0.18, 0.22, 1},  -- 面板背景
    border      = {0.6, 0.5, 0.3, 1},     -- 金色边框
    text        = {1, 1, 1, 1},           -- 白色文字
    label       = {0.7, 0.7, 0.7, 1},     -- 灰色标签
    tab_active  = {0.2, 0.6, 1, 1},       -- 激活标签蓝
    tab_inactive= {0.3, 0.3, 0.35, 1},    -- 未激活灰
    bar_bg      = {0.1, 0.1, 0.1, 1},     -- 进度条底色
    hp          = {0.8, 0.2, 0.2, 1},     -- 红色HP
    mp          = {0.2, 0.4, 0.9, 1},     -- 蓝色MP
    exp         = {0.8, 0.8, 0.2, 1}      -- 黄色EXP
}

-- 基础按钮
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

-- === 2. 核心数据管理 ===

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
    Player.data.speed  = Player.data.speed or 5
    Player.data.gold   = Player.data.gold or 100
    Player.data.x = Player.data.x or 0
    Player.data.y = Player.data.y or 0
    Player.data.w = Player.data.w or 16
    Player.data.h = Player.data.h or 20
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

-- === 3. 玩家行为接口 ===

-- 重新计算玩家属性 & 整理装备数据
function Player.recalcStats()
    local ItemManager = require("ItemManager")
    
    local totalDef = 5  -- 基础防御
    local totalAtk = 10 -- 基础攻击
    
    -- 清空装备槽记录
    Player.data.equipment = {} 
    
    local inventory = require("config").data.inventory
    if inventory then
        for _, item in ipairs(inventory) do
            -- [关键修改] 以前是 if item.equipped，现在检查 item.equipSlot 是否存在
            if item.equipSlot then
                local def = ItemManager.get(item.id)
                if def then
                    -- 累加数值
                    if def.defense then totalDef = totalDef + def.defense end
                    if def.attack then totalAtk = totalAtk + def.attack end
                    
                    -- 记录到槽位用于显示
                    -- item.equipSlot 存储的是 "head", "accessory1" 等具体位置
                    Player.data.equipment[item.equipSlot] = def
                end
            end
        end
    end
    
    Player.data.defense = totalDef
    Player.data.attack = totalAtk
    print(string.format("[Stats] 属性重算: Def=%d, Atk=%d", totalDef, totalAtk))
end
function Player.equipItem(targetItem)
    local ItemManager = require("ItemManager")
    local def = ItemManager.get(targetItem.id)
    if not def or not def.slot then return end

    local targetSlot = def.slot -- 物品定义的槽位，如 "accessory"
    local finalSlot = nil       -- 最终实际放入的槽位，如 "accessory2"

    local inventory = require("config").data.inventory

    -- === 逻辑：确定最终槽位 ===
    if targetSlot == "accessory" then
        -- 饰品特殊处理：寻找空闲的 1, 2, 3
        local slots = {"accessory1", "accessory2", "accessory3"}
        
        -- 1. 先找空的
        for _, s in ipairs(slots) do
            local isOccupied = false
            for _, item in ipairs(inventory) do
                if item.equipSlot == s then isOccupied = true break end
            end
            if not isOccupied then
                finalSlot = s
                break
            end
        end
        
        -- 2. 如果都满了，默认顶掉 accessory1 (或者你可以设计弹窗选择)
        if not finalSlot then finalSlot = "accessory1" end
    else
        -- 非饰品，直接一一对应 (如 head -> head)
        finalSlot = targetSlot
    end

    -- === 逻辑：卸下该槽位已有的装备 ===
    for _, item in ipairs(inventory) do
        if item.equipSlot == finalSlot then
            item.equipSlot = nil -- 卸下旧的
        end
    end

    -- === 逻辑：装备新的 ===
    targetItem.equipSlot = finalSlot
    Player.recalcStats()
end

function Player.unequipItem(targetItem)
    targetItem.equipSlot = nil
    Player.recalcStats()
end

function Player.takeDamage(amount)
    initDefaults()
    local def = Player.data.defense or 0
    local actualDmg = math.max(amount - def, 1)
    Player.data.hp = math.max(Player.data.hp - actualDmg, 0)
    print(string.format("受到伤害: %d (防御抵消: %d)", actualDmg, def))
    Player.save()
end

function Player.dealDamage(amount)
    -- 背包误伤逻辑
    print("在非战斗状态使用了武器，误伤自己！")
    Player.takeDamage(amount)
end

-- 基础增益函数
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

-- === 4. 绘制辅助函数 ===

local function drawProgressBar(label, cur, max, x, y, w, h, color)
    -- Label
    love.graphics.setColor(COLORS.label)
    love.graphics.print(label, x, y - 20)
    
    -- Bar Background
    love.graphics.setColor(COLORS.bar_bg)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    
    -- Bar Fill
    local ratio = math.min(math.max(cur / max, 0), 1)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w * ratio, h, 4, 4)
    
    -- Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(math.floor(cur).."/"..math.floor(max), x, y + 2, w, "center")
end

-- === 5. 主绘制函数 ===

function Player.draw()
    local ItemManager = require("ItemManager")
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local fontLarge = Fonts.large or love.graphics.getFont()
    local fontNormal = Fonts.normal or love.graphics.getFont()

    -- 1. 定义虚拟坐标 (逻辑布局)
    local vWinX, vWinY = 80, 80
    local vWinW, vWinH = Layout.virtualWidth - 160, Layout.virtualHeight - 160
    
    -- 2. 背景绘制 (转屏幕坐标)
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

    -- 3. 标签页绘制
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
        love.graphics.printf(tab, sTx, sTy + (sTh - fontNormal:getHeight())/2, sTw, "center")
    end
    
    -- 分割线 (先算虚拟Y，再转屏幕Y)
    local vLineY = vWinY + 60
    local _, sLineY = Layout.toScreen(0, vLineY)
    love.graphics.setColor(COLORS.border)
    love.graphics.line(sWinX, sLineY, sWinX + sWinW, sLineY)

    -- 4. 内容区域绘制
    -- [关键修复] 所有内部元素都基于 vWinX/Y 计算虚拟偏移，最后统一转 Screen
    local vContentX = vWinX + 40
    local vContentY = vWinY + 80

    if Player.activeTab == 1 then
        -- [状态面板]
        local sCX, sCY = Layout.toScreen(vContentX, vContentY)
        
        -- 左侧：基础信息
        love.graphics.setColor(COLORS.text)
        love.graphics.setFont(fontLarge)
        love.graphics.print(Player.data.name or "Hero", sCX, sCY)
        
        -- 计算 "等级" 的位置
        local sLevelX, sLevelY = Layout.toScreen(vContentX, vContentY + 30)
        love.graphics.setFont(fontNormal)
        love.graphics.setColor(COLORS.label)
        love.graphics.print("等级 " .. (Player.data.level or 1), sLevelX, sLevelY)

        -- 中间：属性数值
        local vStatX = vContentX + 250
        local sStatX, sStatY = Layout.toScreen(vStatX, vContentY)
        -- 注意：行间距也需要 Layout 处理，或者简单地累加 Screen Y
        -- 这里为了对齐，建议每行都转一次，或者算出一个 sLineHeight
        local _, sLineH = Layout.toScreen(0, 30) -- 算出30像素在屏幕上是多高

        love.graphics.setColor(COLORS.text)
        love.graphics.print("攻击力: " .. (Player.data.attack or 0), sStatX, sStatY)
        love.graphics.print("防御力: " .. (Player.data.defense or 0), sStatX, sStatY + sLineH)
        love.graphics.print("速  度: " .. (Player.data.speed or 0), sStatX, sStatY + sLineH*2)
        love.graphics.setColor(1, 0.9, 0.2)
        love.graphics.print("金  币: " .. (Player.data.gold or 0), sStatX, sStatY + sLineH*3)

        -- 底部：进度条
        -- 进度条的 Y 也是基于 ContentY 下移 150
        local vBarY = vContentY + 150
        local vBarW = vWinW - 80
        
        -- 辅助函数：需要重写以支持传入 Screen 坐标
        local function drawBarSafe(label, cur, max, vx, vy, vw, vh, color)
            local sx, sy = Layout.toScreen(vx, vy)
            local sw, sh = Layout.toScreen(vw, vh)
            
            -- Label (offset -20)
            local _, sOffY = Layout.toScreen(0, 20)
            
            love.graphics.setColor(COLORS.label)
            love.graphics.print(label, sx, sy - sOffY)
            
            -- Bar BG
            love.graphics.setColor(COLORS.bar_bg)
            love.graphics.rectangle("fill", sx, sy, sw, sh, 4, 4)
            
            -- Bar Fill
            local ratio = math.min(math.max(cur / max, 0), 1)
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", sx, sy, sw * ratio, sh, 4, 4)
            
            -- Text
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(math.floor(cur).."/"..math.floor(max), sx, sy + 2, sw, "center")
        end

        drawBarSafe("生命值", Player.data.hp, Player.data.maxHp, vContentX, vBarY, vBarW, 20, COLORS.hp)
        drawBarSafe("法力值", Player.data.mp, Player.data.maxMp, vContentX, vBarY + 50, vBarW, 20, COLORS.mp)
        
        local nextLevelExp = Player.data.level * 100
        drawBarSafe("经验值", Player.data.exp, nextLevelExp, vContentX, vBarY + 100, vBarW, 10, COLORS.exp)

    elseif Player.activeTab == 2 then
        -- [装备面板 - 双列布局]
        local vSlotW, vSlotH = 170, 60 -- 稍微缩窄一点，放下两列
        local col1X = vContentX
        local col2X = vContentX + 190 -- 右列偏移
        
        if not Player.data.equipment then Player.data.equipment = {} end

        for _, slot in ipairs(equipmentSlots) do
            -- 确定当前槽位的 X, Y
            local drawX = (slot.col == 1) and col1X or col2X
            -- 每一列内部单独计算 Y 偏移
            -- 假设 equipmentSlots 定义顺序是：左1, 左2, 左3, 左4, 右1...
            -- 我们可以通过索引简单计算，或者用累加器。
            -- 这里用简单算法：根据它在 slot 定义表里的位置，手动调整 Y
            -- 为了通用，建议使用一个计数器：
            
            local rowInCol = 0
            for k, s in ipairs(equipmentSlots) do
                if s == slot then break end
                if s.col == slot.col then rowInCol = rowInCol + 1 end
            end
            local drawY = vContentY + rowInCol * (vSlotH + 10)

            -- 开始绘制
            local sSlotX, sSlotY = Layout.toScreen(drawX, drawY)
            local sSlotW, sSlotH = Layout.toScreen(vSlotW, vSlotH)

            -- 槽位背景
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.rectangle("fill", sSlotX, sSlotY, sSlotW, sSlotH, 5, 5)

            -- 图标框
            local iconSize = 48
            local sIconSize, _ = Layout.toScreen(iconSize, iconSize)
            local sIconX, sIconY = Layout.toScreen(drawX + 6, drawY + 6)
            
            love.graphics.setColor(COLORS.border)
            love.graphics.rectangle("line", sIconX, sIconY, sIconSize, sIconSize)

            -- 获取该槽位的装备数据
            local equippedDef = Player.data.equipment[slot.key]

            if equippedDef then
                -- 绘制图标
                local img, quad, scale = ItemManager.getIcon(equippedDef.id)
                if img then
                    love.graphics.setColor(1, 1, 1)
                    local screenScaleX = Layout.scaleX
                    local drawScale = scale * screenScaleX * 0.8 -- 微调比例
                    -- 居中
                    local offset = (sIconSize - 32 * drawScale) / 2 
                    -- 简单的居中逻辑，这里直接画
                    if quad then
                        love.graphics.draw(img, quad, sIconX, sIconY, 0, drawScale, drawScale)
                    else
                        love.graphics.draw(img, sIconX, sIconY, 0, drawScale, drawScale)
                    end
                end
                
                -- 绘制名字
                local sTextX, sTextY = Layout.toScreen(drawX + 60, drawY + 8)
                love.graphics.setColor(COLORS.tab_active)
                -- 限制文字宽度防止超框
                love.graphics.printf(equippedDef.name, sTextX, sTextY, sSlotW - 65, "left")
                
                -- 简略属性
                love.graphics.setColor(COLORS.label)
                local info = ""
                if equippedDef.attack then info = "攻+"..equippedDef.attack 
                elseif equippedDef.defense then info = "防+"..equippedDef.defense end
                
                local _, sLineH = Layout.toScreen(0, 20)
                love.graphics.print(info, sTextX, sTextY + sLineH)
            else
                -- 空槽位
                local sTextX, sTextY = Layout.toScreen(drawX + 60, drawY + 20)
                love.graphics.setColor(COLORS.label)
                love.graphics.print(slot.name, sTextX, sTextY)
            end
        end

    elseif Player.activeTab == 3 then
        -- [任务面板]
        local vQuestY = vContentY
        local sQuestX, sQuestY = Layout.toScreen(vContentX, vQuestY)
        
        if not Player.data.quests or #Player.data.quests == 0 then
            local _, sOffY = Layout.toScreen(0, 100)
            love.graphics.setColor(COLORS.label)
            love.graphics.printf("当前没有进行中的任务。", sQuestX, sQuestY + sOffY, sWinW-80, "center")
        else
            for _, quest in ipairs(Player.data.quests) do
                love.graphics.setColor(COLORS.text)
                love.graphics.print("★ " .. quest.name, contentX, questY)
                love.graphics.setColor(COLORS.label)
                love.graphics.printf(quest.description, contentX + 20, questY + 25, vWinW - 100, "left")
                questY = questY + 80
            end
        end
    end

    -- 5. 按钮绘制
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
    -- 5. Debug 按钮逻辑
    if debugMode and not Player.debugButtonsAdded then
        table.insert(Player.buttons, {
            x = 350, y = 520, w = 120, h = 40,
            text = "重置数据",
            onClick = function()
                Player.data = {} 
                initDefaults()
                Player.save()
                -- 强制刷新一次界面
                currentScene = "player" 
            end
        })
        table.insert(Player.buttons, {
            x = 480, y = 520, w = 120, h = 40,
            text = "升级",
            onClick = function() Player.addLevel(1) end
        })
        Player.debugButtonsAdded = true
    end

    if not debugMode and Player.debugButtonsAdded then
        -- 移除最后两个
        table.remove(Player.buttons)
        table.remove(Player.buttons)
        Player.debugButtonsAdded = false
    end

    -- 绘制按钮
    for i, btn in ipairs(Player.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        
        -- [关键修复] 宽高也要经过 Layout 缩放！
        local bw, bh = Layout.toScreen(btn.w, btn.h)
        
        if Player.hoveredButtonIndex == i then
            love.graphics.setColor(COLORS.tab_active)
        else
            love.graphics.setColor(COLORS.tab_inactive)
        end
        
        -- 使用 bw, bh 绘制
        love.graphics.rectangle("fill", bx, by, bw, bh, 5, 5)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", bx, by, bw, bh, 5, 5)
        
        love.graphics.setColor(COLORS.text)
        -- 文字居中也用 bw, bh
        love.graphics.printf(btn.text, bx, by + (bh - 14)/2, bw, "center")
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.large)
end

-- === 6. 输入处理 ===

function Player.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)
    
    -- 标签页点击
    local tabW, tabH = 100, 35
    local winX, winY = 80, 80
    local tabStartX = winX + 20
    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i-1)*(tabW+5)
        local ty = winY + 15
        if vx >= tx and vx <= tx + tabW and vy >= ty and vy <= ty + tabH then
            Player.activeTab = i
            return "player"
        end
    end
    
    -- 按钮点击
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
    
    -- 标签悬停
    Player.hoveredTabIndex = nil
    local tabW, tabH = 100, 35
    local winX, winY = 80, 80
    local tabStartX = winX + 20
    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i-1)*(tabW+5)
        local ty = winY + 15
        if vx >= tx and vx <= tx + tabW and vy >= ty and vy <= ty + tabH then
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