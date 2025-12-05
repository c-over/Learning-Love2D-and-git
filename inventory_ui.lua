local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local Player = require("player")
local UIGrid = require("UIGrid")
local Crafting = require("Crafting") 

local InventoryUI = {}

-- === 1. 布局配置 ===
UIGrid.config("inventory_full", { cols = 9, rows = 5, slotSize = 64, margin = 10, startX = 60, startY = 140 })
UIGrid.config("inventory_half", { cols = 5, rows = 5, slotSize = 64, margin = 10, startX = 60, startY = 140 })

InventoryUI.previousScene = nil
InventoryUI.activeTab = 1
InventoryUI.craftingScroll = 0
InventoryUI.hoveredButtonIndex = nil
InventoryUI.hoveredTabIndex = nil
InventoryUI.isDragging = false

local tabs = {"武器", "装备", "药水", "素材", "重要物品"}
local tabCategories = { "weapon", "equipment", "potion", "material", "key_item" }
InventoryUI.buttons = {}

-- === 2. 辅助函数 ===
local function updateButtons()
    InventoryUI.buttons = {
        {x=300, y=530, w=120, h=40, text="返回游戏", onClick=function() currentScene=InventoryUI.previousScene or "game" end}
    }
end

-- 绘制描边文字的辅助函数
local function drawOutlinedText(text, x, y, color)
    love.graphics.setColor(0, 0, 0, 1) -- 黑边
    for ox = -1, 1 do
        for oy = -1, 1 do
            if ox ~= 0 or oy ~= 0 then love.graphics.print(text, x + ox, y + oy) end
        end
    end
    love.graphics.setColor(color or {1, 1, 1})
    love.graphics.print(text, x, y)
end

local function createSlotRenderer(items)
    return function(index, x, y, w, h, state)
        -- === 1. 绘制格子底座 (凹槽感) ===
        -- 深色背景
        love.graphics.setColor(0, 0, 0, 0.6) 
        love.graphics.rectangle("fill", x, y, w, h, 4, 4) -- 圆角
        -- 边框 (稍微亮一点，形成层次)
        love.graphics.setColor(1, 1, 1, 0.1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)

        local item = items[index]
        if not item then return end
        
        -- === 2. 状态高亮 (优化视觉) ===
        if state.selected then
            -- 选中：金色边框
            love.graphics.setColor(1, 0.9, 0.2, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, w, h, 4, 4)
            -- 微弱填充
            love.graphics.setColor(1, 0.9, 0.2, 0.1)
            love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        elseif state.hovered then
            -- 悬停：亮白色边框 + 微微发亮
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, w, h, 4, 4)
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        end
        love.graphics.setLineWidth(1) -- 恢复线宽
        
        -- === 3. 装备背景 (特殊颜色区分) ===
        if item.equipSlot then
            love.graphics.setColor(0.1, 0.6, 0.2, 0.3) -- 柔和的绿色背景
            love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 4, 4)
        end
        
        -- === 4. 绘制图标 ===
        local img, quad = ItemManager.getIcon(item.id)
        if img then
            love.graphics.setColor(1, 1, 1)
            local iw, ih
            if quad then _,_,iw,ih = quad:getViewport() else iw,ih = img:getWidth(), img:getHeight() end
            
            -- 缩放逻辑 (留出 10% 边距，不贴边)
            local s = math.min(w/iw, h/ih) * 0.85
            local dx = x + (w - iw*s)/2
            local dy = y + (h - ih*s)/2
            
            if quad then love.graphics.draw(img, quad, dx, dy, 0, s, s)
            else love.graphics.draw(img, dx, dy, 0, s, s) end
        end
        
        -- === 5. 数量显示 (带背景，更清晰) ===
        if item.count > 1 then
            love.graphics.setFont(Fonts.medium or love.graphics.getFont())
            local txt = tostring(item.count)
            local font = love.graphics.getFont()
            local tw = font:getWidth(txt)
            local th = font:getHeight()
            
            -- 数字背景 (右下角的小胶囊)
            local bgW = tw + 6
            local bgH = th + 2
            local bgX = x + w - bgW - 2
            local bgY = y + h - bgH - 2
            
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", bgX, bgY, bgW, bgH, 4, 4)
            
            -- 数字本体
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(txt, bgX + 3, bgY + 1)
        end
        
        -- === 6. 装备标记 "E" (带背景) ===
        if item.equipSlot then
            love.graphics.setFont(Fonts.small or love.graphics.getFont())
            -- 左上角小标签
            love.graphics.setColor(0.8, 0.6, 0.1, 0.9) -- 金色背景
            love.graphics.rectangle("fill", x+2, y+2, 14, 14, 3, 3)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("E", x+5, y+2)
        end
    end
end

-- === 3. 绘制 ===
function InventoryUI.draw()
    updateButtons()
    local activeCat = tabCategories[InventoryUI.activeTab]
    local isMaterialTab = (activeCat == "material")
    
    if isMaterialTab then UIGrid.useConfig("inventory_half") else UIGrid.useConfig("inventory_full") end
    local currentItems = Inventory.getItemsByCategory(activeCat)

    -- 背景
    local vWinX, vWinY = 40, 60
    local vWinW, vWinH = Layout.virtualWidth - 80, Layout.virtualHeight - 120
    local sWinX, sWinY = Layout.toScreen(vWinX, vWinY)
    local sWinW, sWinH = Layout.toScreen(vWinW, vWinH)

    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", sWinX, sWinY, sWinW, sWinH, 8, 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sWinX, sWinY, sWinW, sWinH, 8, 8)
    love.graphics.setLineWidth(1)

    -- 标签页
    local vTabX, vTabY = 60, 80
    local vTabW, vTabH = 100, 35
    for i, tab in ipairs(tabs) do
        local vTx = vTabX + (i-1) * (vTabW + 5)
        local sTx, sTy = Layout.toScreen(vTx, vTabY)
        local sTw, sTh = Layout.toScreen(vTabW, vTabH)
        
        if InventoryUI.activeTab == i then
            love.graphics.setColor(0.2, 0.6, 1)
        elseif InventoryUI.hoveredTabIndex == i then
            love.graphics.setColor(0.3, 0.5, 0.7)
        else
            love.graphics.setColor(0.25, 0.25, 0.25)
        end
        love.graphics.rectangle("fill", sTx, sTy, sTw, sTh, 5, 5)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Fonts.normal or love.graphics.getFont())
        local _, sTextY = Layout.toScreen(0, 8)
        love.graphics.printf(tab, sTx, sTy + sTextY, sTw, "center")
    end

    UIGrid.drawAll(createSlotRenderer(currentItems), currentItems, InventoryUI.hoveredSlotIndex)
    UIGrid.drawScrollbar(#currentItems)
    
    -- 制作面板
    if isMaterialTab then
        local vPanelX, vPanelY = 460, 140
        local vPanelW, vPanelH = 280, 380
        local sPanelX, sPanelY = Layout.toScreen(vPanelX, vPanelY)
        local sPanelW, sPanelH = Layout.toScreen(vPanelW, vPanelH)
        
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", sPanelX, sPanelY, sPanelW, sPanelH, 8, 8)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("line", sPanelX, sPanelY, sPanelW, sPanelH, 8, 8)
        
        love.graphics.setColor(1, 0.8, 0.2)
        local sTitleX, sTitleY = Layout.toScreen(vPanelX + 10, vPanelY + 10)
        love.graphics.setFont(Fonts.medium or love.graphics.getFont())
        love.graphics.print("制作列表", sTitleX, sTitleY)
        
        local _, sHeaderH = Layout.toScreen(0, 40)
        love.graphics.setScissor(sPanelX, sPanelY + sHeaderH, sPanelW, sPanelH - sHeaderH - 10)
        
        local vItemH = 70
        local startY = vPanelY + 45 - InventoryUI.craftingScroll
        
        for i, recipe in ipairs(Crafting.recipes) do
            local canCraft = Crafting.canCraft(recipe)
            local resDef = ItemManager.get(recipe.resultId)
            local vItemY = startY + (i-1) * (vItemH + 5)
            local sItemX, sItemY = Layout.toScreen(vPanelX + 10, vItemY)
            local sItemW, sItemH = Layout.toScreen(vPanelW - 20, vItemH)
            
            local mx, my = love.mouse.getPosition()
            if mx >= sItemX and mx <= sItemX + sItemW and my >= sItemY and my <= sItemY + sItemH then
                love.graphics.setColor(1, 1, 1, 0.1)
                love.graphics.rectangle("fill", sItemX, sItemY, sItemW, sItemH, 5, 5)
            end
            
            love.graphics.setColor(canCraft and {0.3, 0.8, 0.3} or {0.3, 0.3, 0.3})
            love.graphics.rectangle("line", sItemX, sItemY, sItemW, sItemH, 5, 5)
            
            local img, quad = ItemManager.getIcon(recipe.resultId)
            local sIconSize = select(2, Layout.toScreen(0, 48))
            love.graphics.setColor(1, 1, 1)
            if img then
                local s = sIconSize / (quad and select(3, quad:getViewport()) or img:getWidth())
                if quad then love.graphics.draw(img, quad, sItemX + 5, sItemY + 5, 0, s, s)
                else love.graphics.draw(img, sItemX + 5, sItemY + 5, 0, s, s) end
            end
            
            love.graphics.setFont(Fonts.normal or love.graphics.getFont())
            love.graphics.setColor(canCraft and {1, 1, 1} or {0.6, 0.6, 0.6})
            love.graphics.print(resDef.name, sItemX + sIconSize + 15, sItemY + 5)
            
            love.graphics.setFont(Fonts.small or love.graphics.getFont())
            love.graphics.setColor(0.7, 0.7, 0.7)
            local reqText = ""
            for _, mat in ipairs(recipe.materials) do
                local mDef = ItemManager.get(mat.id)
                reqText = reqText .. mDef.name .. " x" .. mat.count .. "  "
            end
            local _, sLineH = Layout.toScreen(0, 25)
            love.graphics.print(reqText, sItemX + sIconSize + 15, sItemY + sLineH)
            
            if canCraft then
                love.graphics.setColor(0.2, 1, 0.2)
                love.graphics.print("制作", sItemX + sItemW - 40, sItemY + sItemH/2 - 10)
            end
        end
        love.graphics.setScissor()
    end

    for i, btn in ipairs(InventoryUI.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local bw, bh = Layout.toScreen(btn.w, btn.h)
        if InventoryUI.hoveredButtonIndex == i then love.graphics.setColor(0.2, 0.8, 1) else love.graphics.setColor(1, 1, 1) end
        love.graphics.rectangle("line", bx, by, bw, bh, 5, 5)
        love.graphics.setFont(Fonts.normal or love.graphics.getFont())
        love.graphics.printf(btn.text, bx, by + (bh - 16)/2, bw, "center")
    end

    UIGrid.drawActionMenu()
    UIGrid.drawDraggingItem(ItemManager)
    
    if UIGrid.hoveredSlotIndex then
        local idx = math.floor(UIGrid.scrollOffset) + UIGrid.hoveredSlotIndex
        local item = currentItems[idx]
        if item then
             local def = ItemManager.get(item.id)
             if def and def.description then UIGrid.drawTooltip(def.description) end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- === 4. 输入处理 ===
function InventoryUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)
    local activeCat = tabCategories[InventoryUI.activeTab]
    local currentItems = Inventory.getItemsByCategory(activeCat)
    
    if button == 1 then
        if UIGrid.checkScrollbarPress(vx, vy, #currentItems) then return end
    end

    local vTabX, vTabY = 60, 80
    for i, tab in ipairs(tabs) do
        local w, h = 100, 35
        local tx = vTabX + (i-1)*(w+5)
        if vx >= tx and vx <= tx + w and vy >= vTabY and vy <= vTabY + h then
            InventoryUI.activeTab = i
            UIGrid.page = 1
            UIGrid.scrollOffset = 0
            UIGrid.selectedIndex = nil
            UIGrid.hideActionMenu()
            return
        end
    end

    if activeCat == "material" and button == 1 then
        local vPanelX, vPanelY = 460, 140
        local vPanelW, vPanelH = 280, 380
        if vx >= vPanelX and vx <= vPanelX + vPanelW and vy >= vPanelY and vy <= vPanelY + vPanelH then
            local startY = vPanelY + 45 - InventoryUI.craftingScroll
            local index = math.floor((vy - startY) / 75) + 1
            if index > 0 and index <= #Crafting.recipes then
                local success, msg = Crafting.craft(Crafting.recipes[index])
                if require("game_ui").addFloatText then print(msg) end
                return
            end
        end
    end

    if UIGrid.clickActionMenu(vx, vy) then return end
    
    local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
    
    if visualIndex then
        local itemDataIndex = math.floor(UIGrid.scrollOffset) + visualIndex
        local item = currentItems[itemDataIndex]
        
        if button == 1 then
            if UIGrid.selectedIndex then
                UIGrid.selectedIndex = nil
                UIGrid.hideActionMenu()
                return 
            end
            if item then
                UIGrid.startDrag(visualIndex, item, currentItems)
                InventoryUI.isDragging = true
            end
        elseif button == 2 and item then
            UIGrid.selectedIndex = visualIndex
            local def = ItemManager.get(item.id)
            local options = {}
            
            -- [装备/卸下]
            if def.slot then
                local txt = item.equipSlot and "卸下" or "装备"
                table.insert(options, {text=txt, action=function() 
                    if item.equipSlot then Player.unequipItem(item) else Player.equipItem(item) end 
                    UIGrid.hideActionMenu() 
                end})
            end
            
            -- [使用/投掷]
            -- 修复：不调用 Inventory:useItem（防止双重触发），直接调用removeItem
            if def.usable then
                local actionName = (def.category == "weapon") and "投掷/使用" or "使用"
                table.insert(options, { text=actionName, action=function()
                    if InventoryUI.onUseItem then
                        InventoryUI.onUseItem(item)
                    else
                        local success, msg = ItemManager.use(item.id, Player)
                        if success then
                            -- 使用成功后，只调用移除，不再次调用 use
                            Inventory:removeItem(item.id, 1, activeCat)
                        else
                            print(msg)
                        end
                    end
                    UIGrid.hideActionMenu()
                end })
            end
            
            -- [丢弃]
            if def.posable then
                table.insert(options, {text="丢弃", action=function() 
                    Inventory:removeItem(item.id, 1, activeCat)
                    UIGrid.hideActionMenu() 
                end})
            end
            
            -- [修复 3: Debug 添加物品]
            if debugMode then
                table.insert(options, {text="添加 (Debug)", action=function()
                    Inventory:addItem(item.id, 1, activeCat)
                    UIGrid.hideActionMenu()
                end})
            end
            
            UIGrid.showActionMenu(visualIndex, options)
        end
    else
        if button == 1 then
            UIGrid.selectedIndex = nil
            UIGrid.hideActionMenu()
        end
    end
    
    Layout.mousepressed(x, y, button, InventoryUI.buttons)
end

function InventoryUI.mousereleased(x, y, button)
    if button == 1 then
        UIGrid.releaseScrollbar()
        if InventoryUI.isDragging then
            local vx, vy = Layout.toVirtual(x, y)
            local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
            local swapResult = UIGrid.endDrag(vx, vy, currentItems)
            if swapResult then
                Inventory:swapItems(swapResult.sourceItem, swapResult.targetItem)
            end
            InventoryUI.isDragging = false
        end
    end
end

function InventoryUI.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)
    
    if UIGrid.scrollbar.isDragging then
        local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
        UIGrid.updateScrollbarDrag(vx, vy, #currentItems)
    else
        UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    end
    
    InventoryUI.hoveredTabIndex = nil
    local vTabX, vTabY = 60, 80
    for i, tab in ipairs(tabs) do
        local w, h = 100, 35
        local tx = vTabX + (i-1)*(w+5)
        if vx >= tx and vx <= tx + w and vy >= vTabY and vy <= vTabY + h then
            InventoryUI.hoveredTabIndex = i
            break
        end
    end
    
    InventoryUI.hoveredButtonIndex = Layout.mousemoved(x, y, InventoryUI.buttons)
end

function InventoryUI.wheelmoved(x, y)
    local activeCat = tabCategories[InventoryUI.activeTab]
    local isMaterialTab = (activeCat == "material")
    local vx, vy = Layout.toVirtual(love.mouse.getPosition())
    
    if isMaterialTab and vx > 420 then
        InventoryUI.craftingScroll = math.max(0, InventoryUI.craftingScroll - y * 30)
    else
        local currentItems = Inventory.getItemsByCategory(activeCat)
        UIGrid.scroll(-y, #currentItems)
    end
end

function InventoryUI.keypressed(key)
    if key == "escape" then currentScene = InventoryUI.previousScene or "game" end
end

return InventoryUI