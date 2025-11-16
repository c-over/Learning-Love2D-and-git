-- inventory_ui.lua
local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")

local buttons = {
    {
        x = 200, y = 500, w = 200, h = 50,
        text = "返回主菜单",
        onClick = function()
            return "menu"
        end
    }
}

local InventoryUI = {}
InventoryUI.selectedItemIndex = nil
InventoryUI.actionMenu = nil
InventoryUI.hoveredItemIndex = nil

function InventoryUI.draw()
    local slotSize = 64
    local margin = 10
    local startX, startY = 100, 100

    -- 绘制物品格子
    for i, item in ipairs(Inventory.items) do
        local def = ItemManager.get(item.id)
        local col = (i-1) % 5
        local row = math.floor((i-1) / 5)
        local vx = startX + col * (slotSize + margin)
        local vy = startY + row * (slotSize + margin)
        local x, y = Layout.toScreen(vx, vy)

        -- 高亮选中格子
        if InventoryUI.selectedItemIndex == i then
            love.graphics.setColor(0.8, 0.8, 0.2, 0.3)
            love.graphics.rectangle("fill", x, y, slotSize, slotSize)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, slotSize, slotSize)

        -- 绘制物品图标或名字
        if def and def.icon then
            def._image = def._image or love.graphics.newImage(def.icon)
            local img = def._image
            local iw, ih = img:getWidth(), img:getHeight()
            local scale = math.min(48/iw, 48/ih)
            local offsetX = (slotSize - iw*scale)/2
            local offsetY = (slotSize - ih*scale)/2
            love.graphics.draw(img, x+offsetX, y+offsetY, 0, scale, scale)
        else
            love.graphics.print(def and def.name or "未知物品", x+5, y+5)
        end

        -- 绘制数量
        love.graphics.print(item.count, x+slotSize-20, y+slotSize-20)
    end

    -- 绘制操作菜单
    if InventoryUI.actionMenu then
        for i, opt in ipairs(InventoryUI.actionMenu.options) do
            local bx, by = Layout.toScreen(
                InventoryUI.actionMenu.x,
                InventoryUI.actionMenu.y + (i-1)*InventoryUI.actionMenu.h
            )
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", bx, by, InventoryUI.actionMenu.w, InventoryUI.actionMenu.h)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", bx, by, InventoryUI.actionMenu.w, InventoryUI.actionMenu.h)
            love.graphics.printf(opt.text, bx, by+5, InventoryUI.actionMenu.w, "center")
        end
    end
    -- 绘制描述框
    if InventoryUI.hoveredItemIndex then
        local item = Inventory.items[InventoryUI.hoveredItemIndex]
        local def = ItemManager.get(item.id)
        if def and def.description then
            local mx, my = love.mouse.getPosition()
            local text = def.description
            local padding = 8
            local font = love.graphics.getFont()
            local w = font:getWidth(text) + padding*2
            local h = font:getHeight() + padding*2

            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", mx, my, w, h)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", mx, my, w, h)
            love.graphics.print(text, mx+padding, my+padding)
        end
    end

    -- 绘制返回按钮（带悬停高亮）
    local hoveredIndex = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), buttons)
    for i, btn in ipairs(buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local w, h = btn.w, btn.h
        if hoveredIndex == i then
            love.graphics.setColor(0.2, 0.8, 1) -- 悬停高亮颜色
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(btn.text, bx, by + (h - love.graphics.getFont():getHeight()) / 2, w, "center")
    end

    love.graphics.setColor(1, 1, 1)
end


function InventoryUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)

    -- 点击操作菜单
    if InventoryUI.actionMenu then
        for i, opt in ipairs(InventoryUI.actionMenu.options) do
            local bx = InventoryUI.actionMenu.x
            local by = InventoryUI.actionMenu.y + (i-1)*InventoryUI.actionMenu.h
            if vx > bx and vx < bx+InventoryUI.actionMenu.w and vy > by and vy < by+InventoryUI.actionMenu.h then
                opt.action()
                InventoryUI.actionMenu = nil
                return
            end
        end
    end

    -- 点击格子
    local slotSize, margin, startX, startY = 64, 10, 100, 100
    for i, item in ipairs(Inventory.items) do
        local col = (i-1) % 5
        local row = math.floor((i-1) / 5)
        local gx = startX + col * (slotSize + margin)
        local gy = startY + row * (slotSize + margin)

        if vx > gx and vx < gx+slotSize and vy > gy and vy < gy+slotSize then
            -- 如果再次点击同一个格子 → 取消选中
            if InventoryUI.selectedItemIndex == i then
                InventoryUI.selectedItemIndex = nil
                InventoryUI.actionMenu = nil
            else
                InventoryUI.selectedItemIndex = i
                -- 动态生成菜单
                local def = ItemManager.get(item.id)
                local options = {}
                if def.usable then
                    table.insert(options, {text="使用", action=function() Inventory:useItem(item.id, 1) end})
                end
                if def.stackable then
                    table.insert(options, {text="添加", action=function() Inventory:addItem(item.id, 1) end})
                end
                table.insert(options, {text="丢弃", action=function() Inventory:removeItem(item.id, 1) end})
                InventoryUI.actionMenu = {
                    x = gx + slotSize + 10,
                    y = gy,
                    w = 100,
                    h = 30,
                    options = options
                }
            end
        end
    end

    -- 返回按钮
    local result = Layout.mousepressed(x, y, button, buttons)
    if result == "menu" then
        return "menu"
    end
    return result
end

function InventoryUI.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)
    InventoryUI.hoveredItemIndex = nil

    local slotSize, margin, startX, startY = 64, 10, 100, 100
    for i, item in ipairs(Inventory.items) do
        local col = (i-1) % 5
        local row = math.floor((i-1) / 5)
        local gx = startX + col * (slotSize + margin)
        local gy = startY + row * (slotSize + margin)

        if vx > gx and vx < gx+slotSize and vy > gy and vy < gy+slotSize then
            -- 如果该物品未被选中，才显示悬停提示
            if InventoryUI.selectedItemIndex ~= i then
                InventoryUI.hoveredItemIndex = i
            end
        end
    end
end

return InventoryUI
