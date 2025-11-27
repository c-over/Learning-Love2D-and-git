local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local UIGrid = require("UIGrid")

local InventoryUI = {}

-- === 1. 布局配置修复 ===
-- 将 startY 改为 160，避开顶部的标签页 (标签页大约占用 Y=100 到 130 的位置)
UIGrid.config("inventory", {
    cols = 5,
    rows = 4,
    slotSize = 64,
    margin = 10,
    startX = 100,
    startY = 160 -- <--- 修改这里：向下移动，防止与标签页重叠
})

InventoryUI.previousScene = nil
InventoryUI.onUseItem = nil

-- UI状态管理
InventoryUI.activeTab = 1
InventoryUI.hoveredSlotIndex = nil
InventoryUI.hoveredButtonIndex = nil
InventoryUI.hoveredTabIndex = nil
InventoryUI.debugButtonAdded = false -- 记录Debug按钮是否已添加

-- 标签页配置
local tabs = {"装备", "药水", "素材", "重要物品"}
local tabCategories = {
    "equipment",
    "potion",
    "material",
    "key_item"
}

-- UI按钮
InventoryUI.buttons = {
    {
        x = 200, y = 530, w = 200, h = 50,
        text = "返回游戏",
        onClick = function()
            currentScene = InventoryUI.previousScene or "game"
        end
    }
}

--------------------------------------------------
-- 辅助：创建一个闭包绘制函数
--------------------------------------------------
local function createSlotRenderer(items)
    return function(itemIndex, x, y, w, h, state)
        local item = items[itemIndex]
        if not item then return end

        -- 1. 绘制背景高亮
        if state.hovered then
            love.graphics.setColor(1, 1, 0, 0.3)
            love.graphics.rectangle("fill", x, y, w, h)
        else
            if state.dragTarget then
                love.graphics.setColor(0, 1, 0, 0.3)
                love.graphics.rectangle("fill", x, y, w, h)
            end
            if state.selected then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.3)
                love.graphics.rectangle("fill", x, y, w, h)
            end
        end

        -- 2. 绘制物品图标
        local iconImage, iconQuad = ItemManager.getIcon(item.id)
        
        if iconImage then
            love.graphics.setColor(1, 1, 1)
            
            local iw, ih
            if iconQuad then
                _, _, iw, ih = iconQuad:getViewport()
            else
                iw, ih = iconImage:getWidth(), iconImage:getHeight()
            end

            local scale = math.min(w / iw, h / ih) * 0.8
            local drawX = x + (w - iw * scale) / 2
            local drawY = y + (h - ih * scale) / 2

            if iconQuad then
                love.graphics.draw(iconImage, iconQuad, drawX, drawY, 0, scale, scale)
            else
                love.graphics.draw(iconImage, drawX, drawY, 0, scale, scale)
            end
        else
            local def = ItemManager.get(item.id)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(def and def.name or "???", x, y + h/2 - 7, w, "center")
        end

        -- 3. 绘制数量
        if item.count and item.count > 1 then
            love.graphics.setColor(1, 1, 1)
            local fontHeight = love.graphics.getFont():getHeight()
            love.graphics.printf(tostring(item.count), x, y + h - fontHeight, w - 4, "right")
        end
    end
end

--------------------------------------------------
-- 主绘制函数
--------------------------------------------------
function InventoryUI.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- 确保配置生效
    UIGrid.useConfig("inventory")

    local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])

    -- 半透明背景
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- 窗口边框
    local winX, winY, winW, winH = 80, 80, screenW-160, screenH-160
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", winX, winY, winW, winH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", winX, winY, winW, winH)

    -- 顶部标签页 (Y坐标约为 100)
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 40
        local bx, by = Layout.toScreen(tabX + (i-1)*(w+10), tabY)
        
        if InventoryUI.activeTab == i then
            love.graphics.setColor(0.2, 0.8, 1)
            love.graphics.rectangle("fill", bx, by, w, h)
            love.graphics.setColor(0, 0, 0)
        elseif InventoryUI.hoveredTabIndex == i then
            love.graphics.setColor(0.7, 0.7, 0.7)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(tab, bx, by+5, w, "center")
    end
    
    love.graphics.setColor(1, 1, 1)

    -- 1. 绘制格子 (基于 config 中的 startY=160，现在应该在标签页下方了)
    UIGrid.drawAll(createSlotRenderer(currentItems), currentItems, InventoryUI.hoveredSlotIndex)

    -- 2. UI覆盖层
    UIGrid.drawActionMenu()
    UIGrid.drawScrollbar(#currentItems)
    UIGrid.drawDraggingItem(ItemManager)

    -- 3. 描述框
    if InventoryUI.hoveredSlotIndex then
        local baseDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset
        local itemDataIndex = baseDataIndex + InventoryUI.hoveredSlotIndex - 1
        local item = currentItems[itemDataIndex]
        if item then
            local def = ItemManager.get(item.id)
            if def and def.description then
                UIGrid.drawTooltip(def.description)
            end
        end
    end

    -- === 2. Debug 按钮逻辑恢复 ===
    -- 动态检查 debugMode，如果开启则添加按钮，关闭则移除
    if debugMode and not InventoryUI.debugButtonAdded then
        table.insert(InventoryUI.buttons, {
            x = 420, y = 530, w = 200, h = 50, -- 放在"返回游戏"按钮右边
            text = "图标浏览器",
            onClick = function() currentScene = "icon_browser" end
        })
        InventoryUI.debugButtonAdded = true
    elseif not debugMode and InventoryUI.debugButtonAdded then
        -- 如果 debugMode 关闭了，移除最后一个按钮（假设它是刚才加的）
        -- 更严谨的做法是遍历查找 text="图标浏览器" 的删掉，这里简化处理
        if InventoryUI.buttons[#InventoryUI.buttons].text == "图标浏览器" then
            table.remove(InventoryUI.buttons, #InventoryUI.buttons)
        end
        InventoryUI.debugButtonAdded = false
    end

    -- 4. 绘制按钮
    for i, btn in ipairs(InventoryUI.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local w, h = btn.w, btn.h
        if InventoryUI.hoveredButtonIndex == i then
            love.graphics.setColor(0.2, 0.8, 1)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(btn.text, bx, by + (h - love.graphics.getFont():getHeight()) / 2, w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

--------------------------------------------------
-- 输入事件处理 (保持不变)
--------------------------------------------------
function InventoryUI.keypressed(key)
    if key == "escape" then
        currentScene = InventoryUI.previousScene or "game"
    elseif key == "pagedown" then
        local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
        UIGrid.nextPage(#currentItems)
    elseif key == "pageup" then
        UIGrid.prevPage()
    end
end

local isDragging = false

function InventoryUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)

    if UIGrid.clickActionMenu(vx, vy) then return end

    -- 标签页点击
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            if InventoryUI.activeTab ~= i then
                InventoryUI.activeTab = i
                UIGrid.page = 1
                UIGrid.scrollOffset = 0
                UIGrid.selectedIndex = nil
                UIGrid.hideActionMenu()
            end
            return
        end
    end

    -- 按钮点击
    local clickedButtonIndex = Layout.mousepressed(x, y, button, InventoryUI.buttons)
    if clickedButtonIndex then return end

    -- 物品格子点击
    local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
    if visualIndex then
        local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
        local itemDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset + visualIndex - 1
        
        if itemDataIndex > #currentItems then return end
        local item = currentItems[itemDataIndex]

        if button == 1 then
            if item then
                UIGrid.startDrag(visualIndex, item, itemDataIndex)
                isDragging = true
            end
        elseif button == 2 then
            if not item then return end
            if UIGrid.selectedIndex == visualIndex then
                UIGrid.selectedIndex = nil
                UIGrid.hideActionMenu()
                return
            end

            UIGrid.selectedIndex = visualIndex
            local def = ItemManager.get(item.id)
            local options = {}
            
            if def.usable then
                table.insert(options, { text="使用", action=function()
                    local success, err = pcall(function()
                        if InventoryUI.onUseItem then InventoryUI.onUseItem(item) end
                    end)
                    if not success then print("Inventory Error:", err) end
                    Inventory:useItem(item.id, 1, tabCategories[InventoryUI.activeTab])
                    currentScene = InventoryUI.previousScene or "game"
                end })
            end
            
            if debugMode then
                if def.stackable then
                    table.insert(options, {text="添加", action=function()
                        Inventory:addItem(item.id, 1, tabCategories[InventoryUI.activeTab])
                    end})
                end
            end
            
            if def.posable then
                table.insert(options, {text="丢弃", action=function()
                    Inventory:removeItem(item.id, 1, tabCategories[InventoryUI.activeTab])
                end})
            end
            
            UIGrid.showActionMenu(visualIndex, options)
        end
    end
end

function InventoryUI.mousereleased(x, y, button)
    if button == 1 and isDragging then
        local vx, vy = Layout.toVirtual(x, y)
        local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
        UIGrid.endDrag(vx, vy, currentItems)
        isDragging = false
    end
end

function InventoryUI.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)

    InventoryUI.hoveredTabIndex = nil
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            InventoryUI.hoveredTabIndex = i
            break
        end
    end

    InventoryUI.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    InventoryUI.hoveredButtonIndex = Layout.mousemoved(x, y, InventoryUI.buttons)
end

function InventoryUI.wheelmoved(x, y)
    local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
    UIGrid.scroll(-y, #currentItems)
end

return InventoryUI