-- inventory_ui.lua
local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local UIGrid = require("UIGrid")

UIGrid.config("inventory", {
    cols = 5,
    rows = 4,
    slotSize = 64,
    margin = 10,
    startX = 100,
    startY = 150
})
local InventoryUI = {}

InventoryUI.previousScene = nil
InventoryUI.onUseItem = nil

-- UI状态管理
InventoryUI.activeTab = 1 -- 默认选中第一个标签 "装备"
InventoryUI.hoveredSlotIndex = nil
InventoryUI.hoveredButtonIndex = nil
InventoryUI.hoveredTabIndex = nil

-- 将配置放在这里，它会在 require 时执行一次

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

-- 注意：我们移除了文件顶部的 UIGrid.config 调用
-- 现在配置在 draw 函数内部处理，以确保每次绘制时都正确

--------------------------------------------------
-- 绘制单个物品格子
--------------------------------------------------
local function drawItemSlot(itemIndex, x, y, w, h, state)
    local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
    local item = currentItems[itemIndex]
    if not item then return end

    -- 1. 绘制高亮效果
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

    -- 2. 绘制物品内容 (这是关键修改部分)
    local iconImage, iconQuad = ItemManager.getIcon(item.id)
    
    if iconImage then
        love.graphics.setColor(1, 1, 1)
        local scale, offsetX, offsetY

        if iconQuad then
            -- 如果有 iconQuad，说明是图标集
            local _, _, iconW, iconH = iconQuad:getViewport()
            scale = math.min(w / iconW, h / iconH)
            offsetX = (w - iconW * scale) / 2
            offsetY = (h - iconH * scale) / 2
        else
            -- 如果没有 iconQuad，说明是单个图标文件
            local imgW, imgH = iconImage:getWidth(), iconImage:getHeight()
            scale = math.min(w / imgW, h / imgH)
            offsetX = (w - imgW * scale) / 2
            offsetY = (h - imgH * scale) / 2
        end
        
        -- 关键修复：根据 iconQuad 是否存在来决定如何调用 love.graphics.draw
        if iconQuad then
            -- 绘制图标集的一部分 (Quad 存在)
            love.graphics.draw(iconImage, iconQuad, x + offsetX, y + offsetY, 0, scale, scale)
        else
            -- 绘制整个图标文件 (Quad 不存在)
            love.graphics.draw(iconImage, x + offsetX, y + offsetY, 0, scale, scale)
        end
    else
        -- 如果图标不存在，则显示物品名称
        local def = ItemManager.get(item.id)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(def and def.name or "未知物品", x, y, w, "center")
    end

    -- 3. 绘制物品数量
    if item.count and item.count > 1 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(tostring(item.count), x, y + h - 18, w - 4, "right")
    end
end
--------------------------------------------------
-- 主绘制函数
--------------------------------------------------
function InventoryUI.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- 关键修复：在每次绘制时，都确保使用正确的配置
    -- 这可以防止其他UI（如商店）意外修改了UIGrid的全局配置
    UIGrid.useConfig("inventory")

    -- 获取当前标签页的物品列表
    local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])

    -- 半透明背景层
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- 背包窗口边框
    local winX, winY, winW, winH = 80, 80, screenW-160, screenH-160
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", winX, winY, winW, winH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", winX, winY, winW, winH)

    -- 顶部标签页
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local bx, by = Layout.toScreen(tabX + (i-1)*(w+10), tabY)
        if InventoryUI.activeTab == i then
            love.graphics.setColor(0.2, 0.8, 1)
        elseif InventoryUI.hoveredTabIndex == i then
            love.graphics.setColor(0.7, 0.7, 0.7)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(tab, bx, by+5, w, "center")
    end

    -- 1. 绘制物品格子和物品
    UIGrid.drawAll(drawItemSlot, currentItems, InventoryUI.hoveredSlotIndex)

    -- 2. 绘制UI覆盖层
    UIGrid.drawActionMenu()
    UIGrid.drawScrollbar(#currentItems)
    UIGrid.drawDraggingItem(ItemManager)

    -- 3. 绘制描述框
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

    -- 调试按钮的逻辑
    if debugMode and not InventoryUI.debugButtonAdded then
        table.insert(InventoryUI.buttons, {
            x = 420, y = 530, w = 200, h = 50,
            text = "图标浏览器",
            onClick = function() currentScene = "icon_browser" end
        })
        InventoryUI.debugButtonAdded = true
    end
    if not debugMode and InventoryUI.debugButtonAdded then
        table.remove(InventoryUI.buttons, #InventoryUI.buttons)
        InventoryUI.debugButtonAdded = false
    end
end
--------------------------------------------------
-- 输入事件处理
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

    -- 1. 优先处理操作菜单的点击
    if UIGrid.clickActionMenu(vx, vy) then
        return
    end

    -- 2. 其次处理标签页的点击
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            InventoryUI.activeTab = i
            -- 切换标签时，重置UI状态
            UIGrid.page = 1
            UIGrid.scrollOffset = 0
            UIGrid.selectedIndex = nil
            UIGrid.hideActionMenu()
            return
        end
    end

    -- 3. 然后处理UI按钮点击
    local clickedButtonIndex = Layout.mousepressed(x, y, button, InventoryUI.buttons)
    if clickedButtonIndex then
        return
    end

    -- 4. 最后处理物品栏格子点击
    local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
    if visualIndex then
        local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
        local itemDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset + visualIndex - 1
        if itemDataIndex > #currentItems then return end

        local item = currentItems[itemDataIndex]

        if button == 1 then -- 左键按下
            if item then
                UIGrid.startDrag(visualIndex, item, itemDataIndex)
                isDragging = true
            end
        elseif button == 2 then -- 右键按下
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
                     -- 1.使用 pcall 可以防止回调中的错误导致整个程序中断
                    local success, err = pcall(function()
                        if InventoryUI.onUseItem then
                            InventoryUI.onUseItem(item)
                        end
                    end)
                    if not success then
                        -- 如果回调出错，在控制台打印错误信息，方便调试
                        print("Error in InventoryUI.onUseItem callback: " .. tostring(err))
                    end
                    -- 2.使用物品并从背包中移除
                    Inventory:useItem(item.id, 1, tabCategories[InventoryUI.activeTab])
                    -- 3. 切换回上一个场景
                    currentScene = InventoryUI.previousScene or "game"
                end })
            end
            if def.stackable and debugMode then
                table.insert(options, {text="添加", action=function()
                    Inventory:addItem(item.id, 1, tabCategories[InventoryUI.activeTab])
                end})
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

    -- 更新悬停的标签索引
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

    -- 更新悬停的格子索引
    InventoryUI.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)

    -- 更新悬停的按钮索引
    InventoryUI.hoveredButtonIndex = Layout.mousemoved(x, y, InventoryUI.buttons)
end

function InventoryUI.wheelmoved(x, y)
    local currentItems = Inventory.getItemsByCategory(tabCategories[InventoryUI.activeTab])
    UIGrid.scroll(-y, #currentItems)
end

return InventoryUI