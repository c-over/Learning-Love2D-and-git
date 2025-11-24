-- shop_ui.lua
local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local Player = require("player")
local UIGrid = require("UIGrid")

local ShopUI = {}
ShopUI.merchant = nil
ShopUI.previousScene = nil

-- UI状态管理
ShopUI.activeTab = 1 -- 默认选中 "对话"
ShopUI.hoveredTabIndex = nil
ShopUI.hoveredButtonIndex = nil

-- 标签页配置
local tabs = {"对话", "买入", "卖出"}

-- UI按钮
ShopUI.buttons = {
    {
        x = 350, y = 500, w = 100, h = 50,
        text = "返回",
        onClick = function()
            currentScene = ShopUI.previousScene or "game"
        end
    }
}

-- 初始化买入和卖出界面的格子布局
UIGrid.config("shop_buy", {
    cols = 5,
    rows = 4,
    slotSize = 64,
    margin = 10,
    startX = 100,
    startY = 150
})

UIGrid.config("shop_sell", {
    cols = 5,
    rows = 4,
    slotSize = 64,
    margin = 10,
    startX = 100,
    startY = 150
})

--------------------------------------------------
-- 核心功能
--------------------------------------------------

-- 打开商店
function ShopUI.open(merchant)
    ShopUI.merchant = merchant
    ShopUI.previousScene = currentScene
    ShopUI.activeTab = 1 -- 默认打开对话页
    currentScene = "shop"
end

-- 工具函数：聚合玩家所有可出售的物品
local function getSellableItems()
    local allItems = {}
    for _, category in ipairs(Inventory.categories) do
        for _, item in ipairs(Inventory.getItemsByCategory(category)) do
            local def = ItemManager.get(item.id)
            -- 假设除了任务物品外，其他都可以卖
            if def and def.category ~= "key_item" then
                table.insert(allItems, item)
            end
        end
    end
    return allItems
end

--------------------------------------------------
-- 绘制函数
--------------------------------------------------

-- 绘制买入界面的单个物品格子
local function drawBuyItemSlot(itemIndex, x, y, w, h, state)
    local item = ShopUI.merchant.items[itemIndex]
    if not item then return end

    local def = ItemManager.get(item.id)
    if not def then return end

    -- 1. 绘制高亮效果
    if state.hovered then
        love.graphics.setColor(1, 1, 0, 0.3)
        love.graphics.rectangle("fill", x, y, w, h)
    end
    if state.selected then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.3)
        love.graphics.rectangle("fill", x, y, w, h)
    end

    -- 2. 绘制物品图标
    local iconImage, iconQuad = ItemManager.getIcon(item.id)
    if iconImage then
        love.graphics.setColor(1, 1, 1)
        local scale, offsetX, offsetY
        if iconQuad then
            _, _, iconW, iconH = iconQuad:getViewport()
            scale = math.min(w / iconW, h / iconH)
            offsetX = (w - iconW * scale) / 2
            offsetY = (h - iconH * scale) / 2
        else
            local imgW, imgH = iconImage:getWidth(), iconImage:getHeight()
            scale = math.min(w / imgW, h / imgH)
            offsetX = (w - imgW * scale) / 2
            offsetY = (h - imgH * scale) / 2
        end
        
        -- 关键修复：根据 iconQuad 是否存在来决定如何调用 love.graphics.draw
        if iconQuad then
            love.graphics.draw(iconImage, iconQuad, x + offsetX, y + offsetY, 0, scale, scale)
        else
            love.graphics.draw(iconImage, x + offsetX, y + offsetY, 0, scale, scale)
        end
    end
end

-- 绘制卖出界面的单个物品格子
local function drawSellItemSlot(itemIndex, x, y, w, h, state)
    local item = getSellableItems()[itemIndex]
    if not item then return end

    local def = ItemManager.get(item.id)
    if not def then return end

    -- 1. 绘制高亮效果
    if state.hovered then
        love.graphics.setColor(1, 1, 0, 0.3)
        love.graphics.rectangle("fill", x, y, w, h)
    end
    if state.selected then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.3)
        love.graphics.rectangle("fill", x, y, w, h)
    end

    -- 2. 绘制物品图标
    local iconImage, iconQuad = ItemManager.getIcon(item.id)
    if iconImage then
        love.graphics.setColor(1, 1, 1)
        local scale, offsetX, offsetY
        if iconQuad then
            _, _, iconW, iconH = iconQuad:getViewport()
            scale = math.min(w / iconW, h / iconH)
            offsetX = (w - iconW * scale) / 2
            offsetY = (h - iconH * scale) / 2
        else
            local imgW, imgH = iconImage:getWidth(), iconImage:getHeight()
            scale = math.min(w / imgW, h / imgH)
            offsetX = (w - imgW * scale) / 2
            offsetY = (h - imgH * scale) / 2
        end

        -- 关键修复：根据 iconQuad 是否存在来决定如何调用 love.graphics.draw
        if iconQuad then
            love.graphics.draw(iconImage, iconQuad, x + offsetX, y + offsetY, 0, scale, scale)
        else
            love.graphics.draw(iconImage, x + offsetX, y + offsetY, 0, scale, scale)
        end
    end

    -- 3. 绘制物品名称、数量和价格
    love.graphics.setColor(1, 1, 1)
    if item.count > 1 then
        love.graphics.printf("x" .. item.count, x, y + h - 20, w, "center")
    end
end

-- 主绘制函数
-- 主绘制函数
function ShopUI.draw()
    if not ShopUI.merchant then return end
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- 半透明背景层
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- 商店窗口边框
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
        if ShopUI.activeTab == i then
            love.graphics.setColor(0.2, 0.8, 1)
        elseif ShopUI.hoveredTabIndex == i then
            love.graphics.setColor(0.7, 0.7, 0.7)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(tab, bx, by+5, w, "center")
    end

    -- 根据当前标签页绘制内容
    if ShopUI.activeTab == 1 then
        -- 1. 对话
        love.graphics.setColor(1, 1, 1)
        local dialogue = ShopUI.merchant.dialogue or "..."
        local dialogX, dialogY = Layout.toScreen(120, 150)
        local dialogLimit = 500 * Layout.scaleX
        love.graphics.printf(dialogue, dialogX, dialogY, dialogLimit, "left")

    elseif ShopUI.activeTab == 2 then
        -- 2. 买入
        UIGrid.useConfig("shop_buy")
        
        -- 在右侧绘制金钱数量
        local goldX, goldY = Layout.toScreen(550, 150)
        love.graphics.setColor(1, 1, 0) -- 金色
        love.graphics.print("你的金币: " .. Player.data.gold, goldX, goldY)

        UIGrid.drawAll(drawBuyItemSlot, ShopUI.merchant.items, UIGrid.hoveredSlotIndex)
        UIGrid.drawScrollbar(#ShopUI.merchant.items)
        UIGrid.drawActionMenu()

    elseif ShopUI.activeTab == 3 then
        -- 3. 卖出
        UIGrid.useConfig("shop_sell")
        local sellableItems = getSellableItems()

        -- 在右侧绘制金钱数量
        local goldX, goldY = Layout.toScreen(550, 150)
        love.graphics.setColor(1, 1, 0) -- 金色
        love.graphics.print("你的金币: " .. Player.data.gold, goldX, goldY)

        UIGrid.drawAll(drawSellItemSlot, sellableItems, UIGrid.hoveredSlotIndex)
        UIGrid.drawScrollbar(#sellableItems)
        UIGrid.drawActionMenu()
    end

    -- 绘制提示框
    if ShopUI.activeTab ~= 1 and UIGrid.hoveredSlotIndex then
        local isBuyTab = ShopUI.activeTab == 2
        local itemsList = isBuyTab and ShopUI.merchant.items or getSellableItems()
        local itemDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset + UIGrid.hoveredSlotIndex - 1
        local item = itemsList[itemDataIndex]
        if item then
            local def = ItemManager.get(item.id)
            if def and def.description then
                local tooltipText = def.description
                if isBuyTab then
                    tooltipText = tooltipText .. "\n价格: " .. item.price
                else
                    local sellPrice = math.floor((def.price or 10) * 0.5)
                    tooltipText = tooltipText .. "\n售价: " .. sellPrice
                end
                UIGrid.drawTooltip(tooltipText)
            end
        end
    end

    -- 绘制按钮
    for i, btn in ipairs(ShopUI.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local w, h = btn.w, btn.h
        if ShopUI.hoveredButtonIndex == i then
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
-- 输入事件处理
--------------------------------------------------
function ShopUI.keypressed(key)
    if key == "escape" then
        currentScene = ShopUI.previousScene or "game"
    end
    if key == "1" then ShopUI.activeTab = 1
    elseif key == "2" then ShopUI.activeTab = 2
    elseif key == "3" then ShopUI.activeTab = 3
    end
end

function ShopUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)

    -- 1. 检查标签页点击
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            ShopUI.activeTab = i
            -- 切换标签时，重置UI状态
            UIGrid.page = 1
            UIGrid.scrollOffset = 0
            -- 移除了对 selectedIndex 和 actionMenu 的重置，因为不再需要
            return
        end
    end

    -- 2. 检查物品栏格子点击 (仅在买入和卖出页)
    if ShopUI.activeTab == 2 or ShopUI.activeTab == 3 then
        local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
        if visualIndex and button == 1 then -- 只处理左键点击
            local isBuyTab = ShopUI.activeTab == 2
            local itemsList = isBuyTab and ShopUI.merchant.items or getSellableItems()
            local itemDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset + visualIndex - 1
            if itemDataIndex > #itemsList then return end

            local item = itemsList[itemDataIndex]
            if not item then return end

            local def = ItemManager.get(item.id)
            if not def then return end

            if isBuyTab then
                -- 买入逻辑
                if Player.data.gold >= item.price then
                    Player.data.gold = Player.data.gold - item.price
                    local category = ItemManager.getCategory(item.id)
                    Inventory:addItem(item.id, 1, category)
                    print("购买成功: " .. def.name)
                else
                    print("金币不足！")
                end
            else
                -- 卖出逻辑
                local sellPrice = math.floor((def.price or 10) * 0.5)
                Player.data.gold = Player.data.gold + sellPrice
                local category = ItemManager.getCategory(item.id)
                Inventory:removeItem(item.id, 1, category)
                print("出售成功: " .. def.name .. " +" .. sellPrice .. "金币")
            end
        end
    end

    -- 3. 检查UI按钮点击
    local clickedButtonIndex = Layout.mousepressed(x, y, button, ShopUI.buttons)
    if clickedButtonIndex then
        local btn = ShopUI.buttons[clickedButtonIndex]
        if btn and btn.onClick then
            btn.onClick()
        end
        return
    end
end

function ShopUI.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)

    -- 更新悬停的标签索引
    ShopUI.hoveredTabIndex = nil
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            ShopUI.hoveredTabIndex = i
            break
        end
    end

    -- 更新悬停的格子索引 (仅在买入和卖出页)
    if ShopUI.activeTab == 2 or ShopUI.activeTab == 3 then
        UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    else
        UIGrid.hoveredSlotIndex = nil
    end

    -- 更新悬停的按钮索引
    ShopUI.hoveredButtonIndex = Layout.mousemoved(x, y, ShopUI.buttons)
end

function ShopUI.wheelmoved(x, y)
    -- 仅在买入和卖出页滚动
    if ShopUI.activeTab == 2 then
        UIGrid.scroll(-y, #ShopUI.merchant.items)
    elseif ShopUI.activeTab == 3 then
        UIGrid.scroll(-y, #getSellableItems())
    end
end

return ShopUI