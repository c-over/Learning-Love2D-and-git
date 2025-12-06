local PauseMenu = {}

local Layout = require("layout")
local Player = require("player")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local MagicManager = require("MagicManager")
local UIGrid = require("UIGrid")
local Crafting = require("Crafting")
local Config = require("config")
local GameUI = require("game_ui") 

-- === 1. 状态 ===
PauseMenu.activeTab = "equip"
PauseMenu.itemSubTab = 1      
PauseMenu.questScroll = 0     
PauseMenu.craftScroll = 0     
PauseMenu.skillScroll = 0     
PauseMenu.hoveredSlotIndex = nil
PauseMenu.isDragging = false

-- 常量
local SIDEBAR_W = 120
local WIN_W = Layout.virtualWidth - 40
local WIN_H = Layout.virtualHeight - 40
local PANEL_BG = {0.15, 0.15, 0.18, 0.95}

local navButtons = {
    {key="equip",  text="状态 & 装备"},
    {key="item",   text="物品背包"},
    {key="craft",  text="合成制作"},
    {key="skill",  text="魔法技能"},
    {key="quest",  text="任务列表"},
    {key="system", text="系统设置"},
    {key="exit",   text="返回标题"}
}

local itemTabs = {"全部", "药水", "素材", "关键物品"}
local itemCategories = {nil, "potion", "material", "key_item"}
local equipmentSlots = {
    {key="main_hand", name="主手"}, {key="off_hand", name="副手"},
    {key="head", name="头部"}, {key="body", name="身体"}, {key="legs", name="腿部"},
    {key="accessory1", name="饰品1"}, {key="accessory2", name="饰品2"}, {key="accessory3", name="饰品3"}
}

-- === 2. 初始化 ===
function PauseMenu.load()
    UIGrid.config("menu_equip_bag", { cols = 6, rows = 6, slotSize = 56, margin = 8, startX = 360, startY = 100 })
    UIGrid.config("menu_item_bag", { cols = 9, rows = 6, slotSize = 56, margin = 8, startX = 170, startY = 90 })
    UIGrid.config("menu_craft_bag", { cols = 4, rows = 6, slotSize = 56, margin = 8, startX = 160, startY = 100 })
end

-- === 3. 辅助逻辑 ===
local function getCraftListLayout()
    return { x = 440, y = 100, w = 320, h = 450, headerH = 40, itemH = 70, gap = 5 }
end

local function getCurrentList()
    if PauseMenu.activeTab == "equip" then
        local list = {}
        for _, item in ipairs(Config.data.inventory) do
            local def = ItemManager.get(item.id)
            if def and (def.category == "equipment" or def.category == "weapon") then table.insert(list, item) end
        end
        return list
    elseif PauseMenu.activeTab == "item" then
        local cat = itemCategories[PauseMenu.itemSubTab]
        if cat == nil then return Config.data.inventory end
        return Inventory.getItemsByCategory(cat)
    elseif PauseMenu.activeTab == "craft" then
        return Inventory.getItemsByCategory("material")
    end
    return {}
end
-- 魔法列表布局配置
-- 统一管理 x, y, w, h，防止手写数字导致的偏差
local function getSkillLayout()
    -- 假设面板在右侧，避开左侧 Sidebar
    local listX = 160
    local listY = 60
    -- 宽度要减去左侧 Sidebar 和右侧边距
    local listW = Layout.virtualWidth - listX - 20 
    local listH = Layout.virtualHeight - 100
    
    return {
        x = listX,
        y = listY,
        w = listW,
        h = listH,
        itemH = 70,    -- 单项高度
        gap = 10,      -- 间距
        headerH = 50   -- 标题栏高度
    }
end
local function getStatDiff(targetItem)
    local diff = { attack = 0, defense = 0 }
    local def = ItemManager.get(targetItem.id)
    if not def or not def.slot then return diff end
    
    local targetSlot = def.slot
    local itemToReplace = nil
    
    if targetSlot == "accessory" then
        local slots = {"accessory1", "accessory2", "accessory3"}
        local foundEmpty = false
        for _, s in ipairs(slots) do
            local isOccupied = false
            for _, item in ipairs(Config.data.inventory) do
                if item.equipSlot == s then isOccupied = true; break end
            end
            if not isOccupied then targetSlot = s; foundEmpty = true; break end
        end
        if not foundEmpty then targetSlot = "accessory1" end
    end
    
    for _, item in ipairs(Config.data.inventory) do
        if item.equipSlot == targetSlot then itemToReplace = item; break end
    end
    
    if itemToReplace then
        local oldDef = ItemManager.get(itemToReplace.id)
        if oldDef then
            if oldDef.attack then diff.attack = diff.attack - oldDef.attack end
            if oldDef.defense then diff.defense = diff.defense - oldDef.defense end
        end
    end
    
    if def.attack then diff.attack = diff.attack + def.attack end
    if def.defense then diff.defense = diff.defense + def.defense end
    return diff
end
-- [新增] 丢弃重复装备 (不给金币，直接销毁)
-- 用于背包界面的一键整理
function Inventory:discardDuplicateEquipment()
    local inventory = Config.data.inventory
    local ItemManager = require("ItemManager")
    local discardCount = 0
    
    -- 记录已保留的装备ID
    local keptIds = {}
    
    for i = #inventory, 1, -1 do
        local item = inventory[i]
        local def = ItemManager.get(item.id)
        
        if def and (def.category == "equipment" or def.category == "weapon") then
            -- 已装备的强制保留
            if item.equipSlot then
                keptIds[item.id] = true
            else
                if not keptIds[item.id] then
                    keptIds[item.id] = true -- 保留第一件
                else
                    -- [修改] 发现重复，直接移除，不计算金币
                    table.remove(inventory, i)
                    discardCount = discardCount + 1
                end
            end
        end
    end
    
    if discardCount > 0 then
        Config.save()
    end
    
    return discardCount
end
-- === 4. 绘制 ===
local function createSlotRenderer(items)
    return function(index, x, y, w, h, state)
        local item = items[index]
        if state.hovered then
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("fill", x, y, w, h)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.rectangle("line", x, y, w, h)
        end
        if state.selected then
            love.graphics.setColor(1, 1, 0, 0.2)
            love.graphics.rectangle("fill", x, y, w, h)
            love.graphics.setColor(1, 1, 0, 0.8)
            love.graphics.rectangle("line", x, y, w, h)
        end
        if not item then return end
        if item.equipSlot then
            love.graphics.setColor(0, 0.6, 0, 0.3)
            love.graphics.rectangle("fill", x+2, y+2, w-4, h-4)
            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.rectangle("line", x+2, y+2, w-4, h-4)
        end
        local img, quad = ItemManager.getIcon(item.id)
        love.graphics.setColor(1, 1, 1, 1)
        if img then

            local iw, ih
            if quad then _,_,iw,ih = quad:getViewport() else iw,ih = img:getWidth(), img:getHeight() end
            local s = math.min(w/iw, h/ih) * 0.85
            local dx, dy = x+(w-iw*s)/2, y+(h-ih*s)/2
            if quad then love.graphics.draw(img, quad, dx, dy, 0, s, s) else love.graphics.draw(img, dx, dy, 0, s, s) end
        end
        if item.count > 1 then
            love.graphics.setFont(Fonts.normal)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print(item.count, x+w-20+1, y+h-20+1)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(item.count, x+w-20, y+h-20)
        end
        if item.equipSlot then
            love.graphics.setFont(Fonts.small)
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("E", x+3, y+1)
        end
    end
end

local function drawPanelBase()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, Layout.virtualWidth, Layout.virtualHeight)
    local sx, sy = Layout.toScreen(20, 20)
    local sw, sh = Layout.toScreen(WIN_W, WIN_H)
    love.graphics.setColor(PANEL_BG)
    love.graphics.rectangle("fill", sx, sy, sw, sh, 10)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx, sy, sw, sh, 10)
    local lineX = Layout.toScreen(SIDEBAR_W + 20, 0)
    love.graphics.line(lineX, sy, lineX, sy + sh)
    love.graphics.setFont(Fonts.normal)
    for i, btn in ipairs(navButtons) do
        local bx, by = 30, 40 + (i-1) * 60
        local bw, bh = SIDEBAR_W - 20, 40
        local sbx, sby = Layout.toScreen(bx, by)
        local sbw, sbh = Layout.toScreen(bw, bh)
        if PauseMenu.activeTab == btn.key then love.graphics.setColor(0.2, 0.6, 1, 0.8)
        else
            local mx, my = love.mouse.getPosition()
            local vx, vy = Layout.toVirtual(mx, my)
            if vx>=bx and vx<=bx+bw and vy>=by and vy<=by+bh then love.graphics.setColor(1,1,1,0.2) else love.graphics.setColor(1,1,1,0.05) end
        end
        love.graphics.rectangle("fill", sbx, sby, sbw, sbh, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(btn.text, sbx, sby + (sbh - Fonts.normal:getHeight())/2, sbw, "center")
    end
end

local function drawEquipTab()
    UIGrid.useConfig("menu_equip_bag")
    local currentItems = getCurrentList()
    local leftX, leftY = 160, 60
    local pData = Player.data
    
    love.graphics.setColor(1, 1, 1)
    if pData.anim then
        local stateObj = pData.anim.idle or pData.anim.walk
        if stateObj and stateObj.image and stateObj.quads then
            local quad = nil
            if stateObj.quads[1] and stateObj.quads[1][1] then quad = stateObj.quads[1][1] end
            if quad then
                local sx, sy = Layout.toScreen(leftX + 20, leftY)
                love.graphics.draw(stateObj.image, quad, sx, sy, 0, 3, 3)
            end
        end
    end
    
    local slotStartY = leftY + 110
    for i, slot in ipairs(equipmentSlots) do
        local y = slotStartY + (i-1) * 35
        local sx, sy = Layout.toScreen(leftX, y)
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", sx, sy, 200, 30, 4)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(Fonts.small)
        love.graphics.print(slot.name, sx + 5, sy + 8)
        local equippedDef = pData.equipment[slot.key]
        if equippedDef then
            love.graphics.setColor(1, 1, 0.5)
            love.graphics.setFont(Fonts.normal)
            love.graphics.print(equippedDef.name, sx + 50, sy + 5)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.print("-", sx + 50, sy + 5)
        end
    end
    
    local statY = slotStartY + #equipmentSlots * 35 + 20
    local sx, sy = Layout.toScreen(leftX, statY)
    local diff = {attack=0, defense=0}
    if UIGrid.hoveredSlotIndex then
        local idx = math.floor(UIGrid.scrollOffset) + UIGrid.hoveredSlotIndex
        local item = currentItems[idx]
        if item and not item.equipSlot then diff = getStatDiff(item) end
    end
    
    local function drawStat(label, base, d, col, row)
        local px = sx + col * 110
        local py = sy + row * 25
        love.graphics.setFont(Fonts.normal)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(label, px, py)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(base, px + 50, py)
        if d and d ~= 0 then
            local str = string.format("%+d", d)
            love.graphics.setColor(d > 0 and {0,1,0} or {1,0.3,0.3})
            love.graphics.print(str, px + 80, py)
        end
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.medium)
    love.graphics.print("属性状态", sx, sy - 30)
    drawStat("攻击", pData.attack, diff.attack, 0, 0)
    drawStat("防御", pData.defense, diff.defense, 0, 1)
    drawStat("速度", pData.speed, 0, 0, 2)
    drawStat("金币", pData.gold, 0, 1, 0)
    drawStat("生命", pData.maxHp, 0, 1, 1)
    drawStat("魔力", pData.maxMp, 0, 1, 2)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.medium)
    love.graphics.print("装备箱", Layout.toScreen(380, 60))
    UIGrid.drawAll(createSlotRenderer(currentItems), currentItems, UIGrid.hoveredSlotIndex)
    UIGrid.drawScrollbar(#currentItems)
end

local function drawItemTab()
    UIGrid.useConfig("menu_item_bag")
    local currentItems = getCurrentList()
    local tabStartX, tabY = 160, 40
    local tabW, tabH = 80, 30
    for i, title in ipairs(itemTabs) do
        local tx = tabStartX + (i-1) * (tabW + 10)
        local sx, sy = Layout.toScreen(tx, tabY)
        local sw, sh = Layout.toScreen(tabW, tabH)
        if PauseMenu.itemSubTab == i then love.graphics.setColor(0.2, 0.6, 1)
        else love.graphics.setColor(0.3, 0.3, 0.3) end
        love.graphics.rectangle("fill", sx, sy, sw, sh, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Fonts.normal)
        love.graphics.printf(title, sx, sy + 5, sw, "center")
    end
    
    UIGrid.drawAll(createSlotRenderer(currentItems), currentItems, UIGrid.hoveredSlotIndex)
    UIGrid.drawScrollbar(#currentItems)
    
    local btnW, btnH = 160, 40
    local btnX, btnY = Layout.toScreen(170, 520)
    love.graphics.setColor(0.3, 0.5, 0.3)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("一键整理", btnX, btnY + 10, btnW, "center")
    PauseMenu.sortBtnRect = {x=170, y=520, w=160, h=40}

    -- [修改] 一键丢弃按钮
    local discardW, discardH = 160, 40
    local discardX, discardY = Layout.toScreen(350, 520)
    
    -- 使用红色警示色
    love.graphics.setColor(0.7, 0.2, 0.2) 
    love.graphics.rectangle("fill", discardX, discardY, discardW, discardH, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("丢弃重复装备", discardX, discardY + 10, discardW, "center")
    
    -- 记录按钮区域 (改个名以免混淆)
    PauseMenu.discardBtnRect = {x=350, y=520, w=160, h=40}
end

local function drawCraftTab()
    UIGrid.useConfig("menu_craft_bag")
    local currentItems = getCurrentList()
    UIGrid.drawAll(createSlotRenderer(currentItems), currentItems, UIGrid.hoveredSlotIndex)
    UIGrid.drawScrollbar(#currentItems)
    
    local L = getCraftListLayout()
    local sx, sy = Layout.toScreen(L.x, L.y)
    local sw, sh = Layout.toScreen(L.w, L.h)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", sx, sy, sw, sh, 8)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("line", sx, sy, sw, sh, 8)
    love.graphics.setColor(1, 0.8, 0.2)
    local sTitleX, sTitleY = Layout.toScreen(L.x+10, L.y+10)
    love.graphics.setFont(Fonts.medium)
    love.graphics.print("制作列表", sTitleX, sTitleY)
    
    local _, sHeaderH = Layout.toScreen(0, L.headerH)
    love.graphics.setScissor(sx, sy + sHeaderH, sw, sh - sHeaderH - 10)
    local startY = L.y + L.headerH + 5 - PauseMenu.craftScroll
    local displayList = {}
    for _, r in ipairs(Crafting.recipes) do
        if Crafting.isRecipeVisible(r) then table.insert(displayList, r) end
    end
    PauseMenu.visibleRecipes = displayList
    
    for i, recipe in ipairs(displayList) do
        local vItemY = startY + (i-1)*(L.itemH + L.gap)
        if vItemY + L.itemH > L.y and vItemY < L.y + L.h then
            local sItemX, sItemY = Layout.toScreen(L.x + 10, vItemY)
            local sItemW, sItemH = Layout.toScreen(L.w - 20, L.itemH)
            
            local canCraft = Crafting.canCraft(recipe)
            local res = ItemManager.get(recipe.resultId)
            local mx, my = love.mouse.getPosition()
            if mx>=sItemX and mx<=sItemX+sItemW and my>=sItemY and my<=sItemY+sItemH then
                love.graphics.setColor(1, 1, 1, 0.1)
                love.graphics.rectangle("fill", sItemX, sItemY, sItemW, sItemH, 5)
            end
            if canCraft then love.graphics.setColor(0.3, 0.8, 0.3) else love.graphics.setColor(0.3, 0.3, 0.3) end
            love.graphics.rectangle("line", sItemX, sItemY, sItemW, sItemH, 5)
            
            love.graphics.setColor(1,1,1)
            local img, quad = ItemManager.getIcon(recipe.resultId)
            if img then
                local s = select(2, Layout.toScreen(0, 48)) / (quad and select(3, quad:getViewport()) or img:getWidth())
                if quad then love.graphics.draw(img, quad, sItemX+5, sItemY+5, 0, s, s)
                else love.graphics.draw(img, sItemX+5, sItemY+5, 0, s, s) end
            end
            
            love.graphics.setFont(Fonts.normal)
            love.graphics.setColor(canCraft and {1, 1, 1} or {0.6, 0.6, 0.6})
            love.graphics.print(res.name, sItemX+70, sItemY+5)
            love.graphics.setFont(Fonts.small)
            love.graphics.setColor(0.7, 0.7, 0.7)
            local reqText = ""
            for _, mat in ipairs(recipe.materials) do reqText = reqText .. ItemManager.get(mat.id).name .. "x" .. mat.count .. " " end
            love.graphics.print(reqText, sItemX+70, sItemY+35)
            if canCraft then 
                love.graphics.setFont(Fonts.normal)
                love.graphics.setColor(0, 1, 0)
                love.graphics.print("制作", sItemX+sItemW-50, sItemY+25)
            end
        end
    end
    love.graphics.setScissor()
end

local function drawSkillTab() 
    local spells = MagicManager.getPlayerSpells()
    
    local L = getSkillLayout() -- [关键] 获取统一布局
    
    local sx, sy = Layout.toScreen(L.x, L.y)
    local sw, sh = Layout.toScreen(L.w, L.h)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.large)
    love.graphics.print("魔法技能 (Lv." .. Player.data.level .. ")", sx, sy)
    
    -- 裁剪区域
    local _, sHeaderH = Layout.toScreen(0, L.headerH - 10)
    love.graphics.setScissor(sx, sy + sHeaderH, sw, sh - sHeaderH)
    
    local startY = L.y + L.headerH - PauseMenu.skillScroll
    
    for i, spell in ipairs(spells) do
        local dy = startY + (i-1) * (L.itemH + L.gap)
        
        -- 仅绘制可见部分
        if dy + L.itemH > L.y and dy < L.y + L.h then
            
            -- [新增] 绘制逻辑判定框 (Debug)
            -- 这里的 L.x 和 L.w 是虚拟坐标，完全对应下面的点击判定
            Layout.drawDebugBox(L.x, dy, L.w, L.itemH)
            
            local mx, my = love.mouse.getPosition()
            local dsx, dsy = Layout.toScreen(L.x, dy)
            local dsw, dsh = Layout.toScreen(L.w, L.itemH)
            
            -- 屏幕坐标检测悬停 (视觉效果)
            local isHover = (mx >= dsx and mx <= dsx + dsw and my >= dsy and my <= dsy + dsh)
            
            if isHover then love.graphics.setColor(1, 1, 1, 0.15) else love.graphics.setColor(0, 0, 0, 0.3) end
            love.graphics.rectangle("fill", dsx, dsy, dsw, dsh, 5)
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("line", dsx, dsy, dsw, dsh, 5)
            love.graphics.setColor(1, 1, 1, 1) 
            local img, quad = MagicManager.getIcon(spell.id)
            local iconSize = select(2, Layout.toScreen(0, 48))
            if img then
                local s = iconSize / (quad and select(3, quad:getViewport()) or img:getWidth())
                if quad then love.graphics.draw(img, quad, dsx+10, dsy+10, 0, s, s) else love.graphics.draw(img, dsx+10, dsy+10, 0, s, s) end
            end
            love.graphics.setFont(Fonts.medium)
            love.graphics.setColor(1,1,1)
            love.graphics.print(spell.name, dsx+70, dsy+5)
            love.graphics.setFont(Fonts.small)
            love.graphics.setColor(0.4, 0.6, 1)
            love.graphics.print("MP: " .. spell.mp, dsx+70, dsy+35)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(spell.description, dsx+160, dsy+12, dsw-260, "left")
            if spell.menuUsable then
                love.graphics.setFont(Fonts.normal)
                love.graphics.setColor(isHover and {0,1,0} or {0,0.7,0})
                love.graphics.print("[点击使用]", dsx+dsw-100, dsy+25)
            else
                love.graphics.setFont(Fonts.small)
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print("[战斗限定]", dsx+dsw-100, dsy+25)
            end
        end
    end
    love.graphics.setScissor()
end 

local function drawQuestTab()
    local sx, sy = Layout.toScreen(160, 60)
    local sw, sh = Layout.toScreen(WIN_W - 140, WIN_H - 80)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.large)
    love.graphics.print("当前任务", sx, sy)
    local quests = Player.data.quests or {}
    love.graphics.setScissor(sx, sy+40, sw, sh-40)
    local startY = sy + 50 - PauseMenu.questScroll
    if #quests == 0 then
        love.graphics.setFont(Fonts.normal)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("暂无进行中的任务。", sx, startY)
    else
        for i, q in ipairs(quests) do
            local qy = startY + (i-1) * 100
            if qy + 80 > sy then
                love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
                love.graphics.rectangle("fill", sx, qy, sw, 80, 5)
                love.graphics.setColor(1, 0.8, 0.2)
                love.graphics.setFont(Fonts.medium)
                love.graphics.print("★ " .. q.name, sx + 10, qy + 10)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.setFont(Fonts.normal)
                love.graphics.printf(q.description, sx + 20, qy + 40, sw-40, "left")
            end
        end
    end
    love.graphics.setScissor()
end

local function drawSystemTab()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setFont(Fonts.title)
    local w = Layout.virtualWidth
    local _, y = Layout.toScreen(0, 300)
    love.graphics.printf("系统设置\n(功能开发中)", SIDEBAR_W, y, w - SIDEBAR_W, "center")
end

-- === 5. 主绘制 ===
function PauseMenu.draw()
    drawPanelBase()
    if PauseMenu.activeTab == "equip" then drawEquipTab()
    elseif PauseMenu.activeTab == "item" then drawItemTab()
    elseif PauseMenu.activeTab == "craft" then drawCraftTab()
    elseif PauseMenu.activeTab == "skill" then drawSkillTab()
    elseif PauseMenu.activeTab == "quest" then drawQuestTab()
    elseif PauseMenu.activeTab == "system" then drawSystemTab()
    end
    
    -- [核心修改] 统一绘制 Tooltip & 拖拽物
    if PauseMenu.activeTab == "equip" or PauseMenu.activeTab == "item" or PauseMenu.activeTab == "craft" then
        if UIGrid.hoveredSlotIndex and not UIGrid.actionMenu and not UIGrid.dragItem then
            local items = getCurrentList()
            local idx = math.floor(UIGrid.scrollOffset) + UIGrid.hoveredSlotIndex
            local item = items[idx]
            if item then
                local def = ItemManager.get(item.id)
                if def then 
                    local text = def.name .. "\n" .. (def.description or "")
                    if PauseMenu.activeTab == "equip" and not item.equipSlot then
                        local diff = getStatDiff(item)
                        if diff.attack ~= 0 or diff.defense ~= 0 then
                            text = text .. "\n----------\n"
                            if diff.attack ~= 0 then text = text .. string.format("攻: %+d ", diff.attack) end
                            if diff.defense ~= 0 then text = text .. string.format("防: %+d", diff.defense) end
                        end
                        text = text .. "\n[左键: 装备]"
                    elseif PauseMenu.activeTab == "equip" and item.equipSlot then
                        text = text .. "\n\n[左键: 卸下]"
                    end
                    UIGrid.setTooltip(text) 
                end
            end
        end
    end
    UIGrid.drawOverlay(ItemManager) -- 统一入口
    love.graphics.setColor(1, 1, 1)
end

-- === 6. 交互处理 ===
function PauseMenu.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)
    local isShift = love.keyboard.isDown("lshift", "rshift")
    
    -- 定义菜单内飘字的统一位置 (屏幕顶部中央)
    local tipX = Layout.virtualWidth / 2 - 50
    local tipY = 60 

    -- 0. 优先处理已打开的菜单
    if UIGrid.actionMenu then
        if UIGrid.clickActionMenu(vx, vy) then return end
        UIGrid.hideActionMenu()
        return
    end
    
    -- 1. 导航栏点击
    for i, btn in ipairs(navButtons) do
        local bx = 30
        local by = 40 + (i-1) * 60
        if vx >= bx and vx <= bx + SIDEBAR_W - 20 and vy >= by and vy <= by + 40 then
            PlayButtonSound()
            if btn.key == "exit" then Config.save(); currentScene = "title"; return end
            PauseMenu.activeTab = btn.key
            UIGrid.scrollOffset = 0
            UIGrid.hideActionMenu()
            PauseMenu.isDragging = false
            return
        end
    end
    
    -- 2. 装备页 (Equip Tab) - 仅左键穿脱
    if PauseMenu.activeTab == "equip" then
        local currentItems = getCurrentList()
        if UIGrid.checkScrollbarPress(vx, vy, #currentItems) then return end
        
        local idx = UIGrid.getIndexAtPosition(vx, vy)
        if idx then
            local realIdx = math.floor(UIGrid.scrollOffset) + idx
            local item = currentItems[realIdx]
            if button == 1 and item then
                if item.equipSlot then Player.unequipItem(item) else Player.equipItem(item) end
            end
        end
    
    -- 3. 物品页 (Item Tab)
    elseif PauseMenu.activeTab == "item" then
        -- A. 子标签切换
        local tabStartX, tabY = 160, 40
        for i, title in ipairs(itemTabs) do
            local tx = tabStartX + (i-1) * 90
            if vx >= tx and vx <= tx + 80 and vy >= tabY and vy <= tabY + 30 then
                PlayButtonSound()
                PauseMenu.itemSubTab = i; UIGrid.scrollOffset = 0; UIGrid.hideActionMenu(); return
            end
        end
        
        -- B. 功能按钮
        if PauseMenu.sortBtnRect then
            local b = PauseMenu.sortBtnRect
            if vx>=b.x and vx<=b.x+b.w and vy>=b.y and vy<=b.y+b.h then
                PlayButtonSound()
                Inventory:sort()
                if GameUI.addFloatText then GameUI.addFloatText("背包已整理", tipX, tipY, {0,1,0}) end
                return
            end
        end
        -- [修改] 一键丢弃逻辑
        if PauseMenu.discardBtnRect then
            local b = PauseMenu.discardBtnRect
            if vx >= b.x and vx <= b.x + b.w and vy >= b.y and vy <= b.y + b.h then
                -- 调用 Inventory 的丢弃函数
                local count = Inventory:discardDuplicateEquipment()
                
                if count > 0 then
                    -- 飘红字提示
                    if GameUI.addFloatText then 
                        GameUI.addFloatText("已丢弃 "..count.." 件重复装备", vx, vy, {1,0.5,0.5}) 
                    end
                else
                    -- 如果没有可丢弃的
                    if GameUI.addFloatText then
                        GameUI.addFloatText("没有重复装备", vx, vy, {1,1,1})
                    end
                end
                return
            end
        end
        
        -- C. 物品网格交互
        local cat = itemCategories[PauseMenu.itemSubTab]
        local currentItems = (cat == nil) and Config.data.inventory or Inventory.getItemsByCategory(cat)
        
        if UIGrid.checkScrollbarPress(vx, vy, #currentItems) then return end
        if UIGrid.clickActionMenu(vx, vy) then return end
        
        local idx = UIGrid.getIndexAtPosition(vx, vy)
        if idx then
            local realIdx = math.floor(UIGrid.scrollOffset) + idx
            local item = currentItems[realIdx]
            
            if item then
                -- A. [Shift + 左键] 快捷使用
                if isShift and button == 1 then
                    local def = ItemManager.get(item.id)
                    if def.usable then
                        -- [逻辑] 获取返回值 ok
                        local ok, msg = ItemManager.use(item.id, Player)
                        
                        if ok then 
                            Inventory:removeItem(item.id, 1, def.category)
                            -- [修改] 成功：飘绿字在鼠标位置，不切场景
                            if GameUI.addFloatText then GameUI.addFloatText(msg, vx, vy, {0,1,0}) end
                        else
                            -- [修改] 失败：飘红字在鼠标位置，不扣物品
                            if GameUI.addFloatText then GameUI.addFloatText(msg, vx, vy, {1,0,0}) end
                        end
                    end
                    return
                end

                -- 左键拖拽
                if button == 1 then
                    UIGrid.startDrag(idx, item, currentItems)
                    PauseMenu.isDragging = true
                
                -- B. [右键菜单]
                elseif button == 2 then
                    local def = ItemManager.get(item.id)
                    local options = {}
                    local amount = isShift and 10 or 1
                    local suffix = isShift and " x10" or ""
                    
                    -- Debug 添加
                    if debugMode and def.stackable then
                         local addCount = isShift and 100 or 1
                         table.insert(options, {text="Debug: 加"..addCount, action=function()
                             Inventory:addItem(item.id, addCount, def.category)
                             UIGrid.hideActionMenu()
                         end})
                    end

                    -- 使用选项 (核心修复)
                    if def.usable then
                        table.insert(options, {text="使用"..suffix, action=function()
                            local successCount = 0
                            local lastMsg = ""
                            
                            for i=1, amount do
                                if item.count > 0 then
                                    -- [逻辑] 检查 ok，如果为 false 则中断循环且不扣物品
                                    local ok, msg = ItemManager.use(item.id, Player)
                                    if ok then 
                                        Inventory:removeItem(item.id, 1, def.category)
                                        successCount = successCount + 1
                                        lastMsg = msg
                                    else 
                                        lastMsg = msg
                                        break -- 失败立即停止 (如满血)
                                    end
                                else break end
                            end
                            
                            if successCount > 0 then
                                -- [视觉] 成功 -> 飘在玩家头顶 -> 回游戏
                                local msg = (amount > 1) and ("批量使用 x"..successCount) or lastMsg
                                if GameUI.addFloatText then 
                                    GameUI.addFloatText(msg, Player.data.x, Player.data.y - 40, {0,1,0}) 
                                end
                                currentScene = "game"
                            else
                                -- [视觉] 失败 -> 飘在鼠标位置 -> 留菜单
                                if GameUI.addFloatText then 
                                    GameUI.addFloatText(lastMsg, vx, vy, {1,0,0}) 
                                end
                            end
                            
                            UIGrid.hideActionMenu()
                        end})
                    end
                    
                    -- 装备选项
                    if def.slot then
                        local txt = item.equipSlot and "卸下" or "装备"
                        table.insert(options, {text=txt, action=function()
                            if item.equipSlot then Player.unequipItem(item) else Player.equipItem(item) end
                            UIGrid.hideActionMenu()
                        end})
                    end
                    
                    -- 丢弃选项
                    if def.posable then
                        table.insert(options, {text="丢弃"..suffix, action=function()
                            local count = math.min(amount, item.count)
                            Inventory:removeItem(item.id, count, def.category)
                            -- 丢弃始终在菜单内飘字
                            if GameUI.addFloatText then 
                                GameUI.addFloatText("丢弃 x"..count, vx, vy, {1,0.5,0.5}) 
                            end
                            UIGrid.hideActionMenu()
                        end})
                    end
                    
                    UIGrid.showActionMenu(idx, options)
                end
            end
        end
        
    -- 4. 制作页 (Craft Tab)
    elseif PauseMenu.activeTab == "craft" then
        local L = getCraftListLayout()
        if vx > L.x and vx < L.x + L.w and vy > L.y + L.headerH and vy < L.y + L.h then
            local relativeY = vy - L.y - L.headerH + PauseMenu.craftScroll
            local index = math.floor(relativeY / (L.itemH + L.gap)) + 1
            local displayList = PauseMenu.visibleRecipes or {}
            
            if index > 0 and index <= #displayList then
                PlayButtonSound()
                local recipe = displayList[index]
                local loop = isShift and 5 or 1
                local success = 0
                local failReason = ""
                
                for i=1, loop do
                    local res, msg = Crafting.craft(recipe)
                    if res then 
                        success = success + 1 
                    else 
                        failReason = msg
                        break 
                    end
                end
                
                if success > 0 then
                    if GameUI.addFloatText then GameUI.addFloatText("制作成功 x"..success, tipX, tipY, {0,1,0}) end
                else
                    if GameUI.addFloatText then GameUI.addFloatText(failReason, tipX, tipY, {1,0,0}) end
                end
            end
        end
        
    -- 5. 魔法页 (Skill Tab)
    elseif PauseMenu.activeTab == "skill" then
        local L = getSkillLayout() -- [关键] 获取统一布局
        
        -- 1. 区域判定：是否点在列表范围内
        if vx > L.x and vx < L.x + L.w and vy > L.y + L.headerH and vy < L.y + L.h then
            local spells = MagicManager.getPlayerSpells()
            
            -- 2. 索引计算
            local startY = L.y + L.headerH - PauseMenu.skillScroll
            local unitH = L.itemH + L.gap
            
            -- (鼠标Y - 列表起始Y) / 单行高度
            local index = math.floor((vy - startY) / unitH) + 1
            
            if index > 0 and index <= #spells then
                    PlayButtonSound()
               local spell = spells[index]
                   -- [情况 A] 可以在菜单使用 (如治疗、Buff)
               if spell.menuUsable then
                   local ok, msg = MagicManager.cast(spell.id, Player.data)
                   if ok then
                           -- 1. 成功: 切换回游戏，飘字显示在玩家头顶 (世界坐标)
                           if GameUI.addFloatText then 
                               -- 传玩家的世界坐标
                               GameUI.addFloatText(msg, Player.data.x, Player.data.y - 40, {0,1,0}) 
                           end
                       currentScene = "game"
                   else
                           -- 2. 失败 (如满血): 留在菜单，飘字显示在鼠标位置 (虚拟坐标)
                           if GameUI.addFloatText then 
                               -- 传鼠标点击位置
                               GameUI.addFloatText(msg, vx, vy, {1,0,0}) 
                           end
                   end
                       
                   -- [情况 B] 不可在菜单使用 (如火球)
                   else
                       -- [新增] 补充提示，不再沉默
                       if GameUI.addFloatText then 
                           GameUI.addFloatText("仅战斗可用", vx, vy, {0.6, 0.6, 0.6}) 
                       end
                   end
               end
            
        end
    end
end

function PauseMenu.mousereleased(x, y, button)
    if button == 1 then
        UIGrid.releaseScrollbar()
        if PauseMenu.isDragging then
            local vx, vy = Layout.toVirtual(x, y)
            local currentItems = getCurrentList()
            local res = UIGrid.endDrag(vx, vy, currentItems)
            if res then Inventory:swapItems(res.sourceItem, res.targetItem) end
            PauseMenu.isDragging = false
        end
    end
end

function PauseMenu.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)
    if PauseMenu.activeTab == "equip" then UIGrid.useConfig("menu_equip_bag")
    elseif PauseMenu.activeTab == "item" then UIGrid.useConfig("menu_item_bag")
    elseif PauseMenu.activeTab == "craft" then UIGrid.useConfig("menu_craft_bag") end
    
    if UIGrid.scrollbar.isDragging then
        UIGrid.updateScrollbarDrag(vx, vy, #getCurrentList())
    else
        UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    end
end

function PauseMenu.wheelmoved(x, y)
    if PauseMenu.activeTab == "quest" then
        PauseMenu.questScroll = math.max(0, PauseMenu.questScroll - y * 30)
    elseif PauseMenu.activeTab == "skill" then
        PauseMenu.skillScroll = math.max(0, PauseMenu.skillScroll - y * 30)
    elseif PauseMenu.activeTab == "craft" then
        local mx, my = love.mouse.getPosition()
        local vx, vy = Layout.toVirtual(mx, my)
        if vx > 400 then PauseMenu.craftScroll = math.max(0, PauseMenu.craftScroll - y * 30)
        else UIGrid.scroll(-y, #getCurrentList()) end
    else
        UIGrid.scroll(-y, #getCurrentList())
    end
end

return PauseMenu
