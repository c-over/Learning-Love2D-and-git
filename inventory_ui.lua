-- inventory_ui.lua
local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local UIGrid = require("UIGrid")

local InventoryUI = {}
InventoryUI.previousScene = nil
InventoryUI.onUseItem = nil

-- 顶部标签页
local tabs = {"人物状态", "背包", "任务", "商店"}
InventoryUI.activeTab = 2 -- 默认背包

-- 返回按钮
InventoryUI.buttons = {
    {
        x = 200, y = 530, w = 200, h = 50,
        text = "返回游戏",
        onClick = function()
            currentScene = InventoryUI.previousScene or "game"
        end
    }
}
-- 初始化格子布局
UIGrid.config("inventory", {
    cols = 5,
    rows = 4,
    slotSize = 64,
    margin = 10,
    startX = 100,
    startY = 150
})
UIGrid.useConfig("inventory")

--------------------------------------------------
-- 绘制单个物品格子
--------------------------------------------------
local function drawItemSlot(i, x, y, w, h, state)
    local item = Inventory.items[i]
    local sx, sy = Layout.toScreen(x, y)

    -- 空格子绘制
    if not item then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("line", sx, sy, w, h)
        return
    end

    local def = ItemManager.get(item.id)

    -- 高亮选中
    if UIGrid.selectedIndex == i then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.3)
        love.graphics.rectangle("fill", sx, sy, w, h)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", sx, sy, w, h)

    -- 绘制图标或名字
    if def and def.icon then
        def._image = def._image or love.graphics.newImage(def.icon)
        local img = def._image
        local iw, ih = img:getWidth(), img:getHeight()
        local scale = math.min(48/iw, 48/ih)
        local offsetX = (w - iw*scale)/2
        local offsetY = (h - ih*scale)/2
        love.graphics.draw(img, sx+offsetX, sy+offsetY, 0, scale, scale)
    else
        love.graphics.print(def and def.name or "未知物品", sx+5, sy+5)
    end

    -- 数量
    love.graphics.print(item.count, sx+w-20, sy+h-20)
end

--------------------------------------------------
-- 绘制函数
--------------------------------------------------
function InventoryUI.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- 确保使用背包的格子配置
    UIGrid.useConfig("inventory")

    -- 半透明背景层
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- 背包窗口边框
    local winX, winY, winW, winH = 80, 80, screenW-160, screenH-160
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", winX, winY, winW, winH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", winX, winY, winW, winH)

    -- 顶部标签页（人物状态 / 背包 / 任务 / 商店）
    local tabX, tabY = 100, 100
    for i, tab in ipairs({"人物状态", "背包", "任务", "商店"}) do
        local w, h = 120, 30
        local bx, by = Layout.toScreen(tabX + (i-1)*(w+10), tabY)
        if InventoryUI.activeTab == i then
            love.graphics.setColor(0.2, 0.8, 1)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(tab, bx, by+5, w, "center")
    end

    -- 绘制物品格子
    UIGrid.drawAll(drawItemSlot, Inventory.items)

    -- 绘制操作菜单
    UIGrid.drawActionMenu()

    -- 绘制描述框
    if UIGrid.hoveredIndex then
        local item = Inventory.items[UIGrid.hoveredIndex]
        if item then
            local def = ItemManager.get(item.id)
            if def and def.description then
                UIGrid.drawTooltip(def.description)
            end
        end
    end

    -- 绘制滚动条
    UIGrid.drawScrollbar(#Inventory.items)

    -- 绘制拖动物品
    UIGrid.drawDraggingItem(ItemManager)

    -- 绘制按钮

    -- 如果 debugMode 打开，确保按钮存在
    if debugMode == true and not InventoryUI.debugButtonAdded then
        table.insert(InventoryUI.buttons, {
            x = 420, y = 530, w = 200, h = 50,
            text = "图标浏览器",
            onClick = function()
                print("切换场景到 icon_browser")
                currentScene = "icon_browser"
            end
        })
        InventoryUI.debugButtonAdded = true
    end

    -- 绘制按钮
    local hoveredIndex = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), InventoryUI.buttons)
    for i, btn in ipairs(InventoryUI.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local w, h = btn.w, btn.h
        if hoveredIndex == i then
            love.graphics.setColor(0.2, 0.8, 1)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(btn.text, bx, by + (h - love.graphics.getFont():getHeight()) / 2, w, "center")
    end
    love.graphics.setColor(1, 1, 1)

    if debugMode == false and InventoryUI.debugButtonAdded then
        -- 移除最后一个按钮（图标浏览器）
        table.remove(InventoryUI.buttons, #InventoryUI.buttons)
        InventoryUI.debugButtonAdded = false
        end
end


--------------------------------------------------
-- 输入事件
--------------------------------------------------
function InventoryUI.keypressed(key)
    if key == "escape" then
        currentScene = InventoryUI.previousScene or "game"
    elseif key == "pagedown" then
        UIGrid.nextPage(#Inventory.items)
    elseif key == "pageup" then
        UIGrid.prevPage()
    end
end

function InventoryUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)

    -- 点击操作菜单
    if UIGrid.clickActionMenu(vx, vy) then return end

    -- 点击格子
    local index = UIGrid.getIndexAtPosition(vx, vy)
    if index then
        local item = Inventory.items[index]
        if not item then return end

        if button == 1 then -- 左键
            -- 如果点击的是当前选中的格子 → 取消选中
            if UIGrid.selectedIndex == index then
                UIGrid.selectedIndex = nil
                UIGrid.hideActionMenu()
                return
            end

            -- 否则正常选中或拖动
            if love.keyboard.isDown("lshift") then
                UIGrid.startDrag(index, item, x, y)
            else
                UIGrid.selectedIndex = index
                local def = ItemManager.get(item.id)
                local options = {}
                if def.usable then
                    table.insert(options, {
                        text="使用",
                        action=function()
                            Inventory:useItem(item.id, 1)
                            if InventoryUI.onUseItem then InventoryUI.onUseItem(item) end
                            currentScene = InventoryUI.previousScene or "game"
                        end
                    })
                end
                if def.stackable and debugMode then
                    table.insert(options, {text="添加", action=function() Inventory:addItem(item.id, 1) end})
                end
                if def.posable then
                    table.insert(options, {text="丢弃", action=function() Inventory:removeItem(item.id, 1) end})
                end
                UIGrid.showActionMenu(index, options)
            end
        end
    end

     -- 传递给 Layout.mousepressed，返回被点击的按钮索引
    local clickedIndex = Layout.mousepressed(x, y, button, InventoryUIbuttons)
    if clickedIndex then
        local btn = buttons[clickedIndex]
        if btn and btn.onClick then
            btn.onClick() -- 执行按钮逻辑
        end
    end
end

function InventoryUI.mousereleased(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)
    UIGrid.endDrag(vx, vy, Inventory.items)
end

function InventoryUI.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)
    local index = UIGrid.getIndexAtPosition(vx, vy)
    if index and UIGrid.selectedIndex ~= index then
        UIGrid.hoveredIndex = index
    else
        UIGrid.hoveredIndex = nil
    end
end

function InventoryUI.wheelmoved(x, y)
    UIGrid.scroll(-y, #Inventory.items) -- 鼠标滚轮控制滚动
end

return InventoryUI
