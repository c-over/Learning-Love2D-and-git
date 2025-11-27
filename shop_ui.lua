local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local Player = require("player")
local UIGrid = require("UIGrid")

local ShopUI = {}
ShopUI.merchant = nil
ShopUI.previousScene = nil
ShopUI.priceTable = {} -- [新增] 用于快速查询当前商人的物品定价

-- 常量定义
local GOLD_ITEM_ID = 5 -- 金币在 items.json 中的 ID
local ICON_SIZE_SMALL = 24 -- 顶部金币栏图标显示大小

-- UI状态管理
ShopUI.activeTab = 1
ShopUI.hoveredTabIndex = nil
ShopUI.hoveredButtonIndex = nil

-- === 视觉配置 ===
local COLORS = {
    bg          = {0.1, 0.1, 0.15, 0.95},
    panel       = {0.18, 0.18, 0.22, 1},
    border      = {0.6, 0.5, 0.3, 1},
    tab_active  = {0.2, 0.6, 1, 1},
    tab_inactive= {0.3, 0.3, 0.35, 1},
    text        = {1, 1, 1, 1},
    gold        = {1, 0.9, 0.2, 1},
    price_ok    = {0.5, 1, 0.5, 1},
    price_no    = {1, 0.3, 0.3, 1}
}

local tabs = {"对话", "买入", "卖出"}

ShopUI.buttons = {
    {
        x = 650, y = 520, w = 120, h = 40,
        text = "离开商店",
        onClick = function()
            currentScene = ShopUI.previousScene or "game"
        end
    }
}

-- === 布局配置 ===
local GRID_CONFIG = {
    cols = 5, rows = 4, slotSize = 64, margin = 12, startX = 100, startY = 170
}
UIGrid.config("shop_buy", GRID_CONFIG)
UIGrid.config("shop_sell", GRID_CONFIG)

--------------------------------------------------
-- 核心功能
--------------------------------------------------

function ShopUI.open(merchant)
    ShopUI.merchant = merchant
    ShopUI.previousScene = currentScene
    ShopUI.activeTab = 1
    
    -- [新增] 构建当前商人的价格查询表
    -- 结构: { [itemId] = price, ... }
    ShopUI.priceTable = {}
    if merchant and merchant.items then
        for _, item in ipairs(merchant.items) do
            if item.id and item.price then
                ShopUI.priceTable[item.id] = item.price
            end
        end
    end
    
    currentScene = "shop"
end

-- [修改] 获取卖出价格
-- 逻辑：查找 priceTable，如果是商人也在卖的东西，回收价 = 商人售价 * 0.5
local function getSellPrice(itemId)
    local merchantPrice = ShopUI.priceTable[itemId]
    if merchantPrice then
        return math.floor(merchantPrice * 0.5)
    end
    return 0 -- 如果商人不卖这个东西，回收价为 0（或者你可以设置一个默认底价）
end

-- 获取玩家背包中可出售物品
local function getSellableItems()
    local allItems = {}
    for _, category in ipairs(Inventory.categories) do
        for _, item in ipairs(Inventory.getItemsByCategory(category)) do
            local def = ItemManager.get(item.id)
            -- 排除任务物品和金币本身
            if def and def.category ~= "key_item" and item.id ~= GOLD_ITEM_ID then
                table.insert(allItems, item)
            end
        end
    end
    return allItems
end

--------------------------------------------------
-- 绘制辅助函数
--------------------------------------------------

-- 绘制金币图标和数量 (使用 ItemManager 中的图标)
local function drawGoldDisplay(x, y)
    local iconImage, iconQuad = ItemManager.getIcon(GOLD_ITEM_ID)
    local textOffset = 15

    if iconImage then
        love.graphics.setColor(1, 1, 1)
        local iw, ih
        if iconQuad then
            _, _, iw, ih = iconQuad:getViewport()
        else
            iw, ih = iconImage:getWidth(), iconImage:getHeight()
        end
        local scale = ICON_SIZE_SMALL / math.max(iw, ih)
        
        if iconQuad then
            love.graphics.draw(iconImage, iconQuad, x, y, 0, scale, scale)
        else
            love.graphics.draw(iconImage, x, y, 0, scale, scale)
        end
        textOffset = ICON_SIZE_SMALL + 5
    else
        love.graphics.setColor(COLORS.gold)
        love.graphics.circle("fill", x + 10, y + 12, 8)
        textOffset = 25
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(tostring(Player.data.gold), x + textOffset, y + 4)
end

--------------------------------------------------
-- 主绘制函数
--------------------------------------------------
function ShopUI.draw()
    if not ShopUI.merchant then return end
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- 背景与面板
    love.graphics.setColor(COLORS.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    local winX, winY, winW, winH = 80, 80, screenW-160, screenH-140
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", winX, winY, winW, winH, 10, 10)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", winX, winY, winW, winH, 10, 10)
    love.graphics.setLineWidth(1)

    -- 标签页
    local tabW, tabH = 100, 35
    local tabStartX = winX + 20
    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i-1) * (tabW + 5)
        local ty = winY + 15
        
        if ShopUI.activeTab == i then
            love.graphics.setColor(COLORS.tab_active)
        elseif ShopUI.hoveredTabIndex == i then
            love.graphics.setColor(COLORS.tab_active[1], COLORS.tab_active[2], COLORS.tab_active[3], 0.7)
        else
            love.graphics.setColor(COLORS.tab_inactive)
        end
        love.graphics.rectangle("fill", tx, ty, tabW, tabH, 5, 5)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(tab, tx, ty + 8, tabW, "center")
    end

    drawGoldDisplay(winX + winW - 120, winY + 20)

    -- 内容区域数据准备
    local currentItems = {}
    if ShopUI.activeTab == 2 then
        currentItems = ShopUI.merchant.items
    elseif ShopUI.activeTab == 3 then
        currentItems = getSellableItems()
    end

    -- 格子绘制逻辑
    local drawSlot = function(index, x, y, w, h, state)
        local item = currentItems[index]
        if not item then return end
        
        local def = ItemManager.get(item.id)
        if not def then return end

        -- 背景
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)

        -- 高亮
        if state.hovered then
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.rectangle("fill", x, y, w, h, 4, 4)
            love.graphics.setColor(COLORS.tab_active)
            love.graphics.rectangle("line", x, y, w, h, 4, 4)
        end

        -- 图标
        local iconImage, iconQuad = ItemManager.getIcon(item.id)
        if iconImage then
            love.graphics.setColor(1, 1, 1)
            local iw, ih
            if iconQuad then _, _, iw, ih = iconQuad:getViewport() else iw, ih = iconImage:getWidth(), iconImage:getHeight() end
            
            local scale = math.min(w/iw, h/ih) * 0.7 
            local dx = x + (w - iw*scale)/2
            local dy = y + (h - ih*scale)/2 - 5

            if iconQuad then
                love.graphics.draw(iconImage, iconQuad, dx, dy, 0, scale, scale)
            else
                love.graphics.draw(iconImage, dx, dy, 0, scale, scale)
            end
        end

        -- 价格/数量显示
        if ShopUI.activeTab == 2 then -- [买入]
            local price = item.price or 9999
            if Player.data.gold >= price then
                love.graphics.setColor(COLORS.price_ok)
            else
                love.graphics.setColor(COLORS.price_no)
            end
            love.graphics.printf("$"..price, x, y + h - 18, w, "center")
            
        elseif ShopUI.activeTab == 3 then -- [卖出]
            -- [关键修改] 使用基于商人的价格计算
            local sellPrice = getSellPrice(item.id)
            
            -- 如果价格为0，显示灰色或提示不可卖
            if sellPrice > 0 then
                love.graphics.setColor(COLORS.gold)
                love.graphics.printf("+"..sellPrice, x, y + h - 18, w, "center")
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.printf("--", x, y + h - 18, w, "center")
            end
            
            if item.count > 1 then
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(item.count, x + w - 20, y + 2)
            end
        end
    end

    -- 根据标签页绘制
    if ShopUI.activeTab == 1 then
        local contentY = winY + 80
        local contentX = winX + 40
        love.graphics.setColor(COLORS.gold)
        love.graphics.print(ShopUI.merchant.name or "商人", contentX, contentY)
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", contentX, contentY + 30, winW - 80, 200, 5, 5)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(ShopUI.merchant.dialogue or "欢迎！", contentX + 20, contentY + 50, winW - 120, "left")

    elseif ShopUI.activeTab == 2 then
        UIGrid.useConfig("shop_buy")
        UIGrid.drawAll(drawSlot, currentItems, UIGrid.hoveredSlotIndex)
        UIGrid.drawScrollbar(#currentItems)

    elseif ShopUI.activeTab == 3 then
        UIGrid.useConfig("shop_sell")
        UIGrid.drawAll(drawSlot, currentItems, UIGrid.hoveredSlotIndex)
        UIGrid.drawScrollbar(#currentItems)
    end

    -- Tooltip
    if ShopUI.activeTab ~= 1 and UIGrid.hoveredSlotIndex then
        local itemDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset + UIGrid.hoveredSlotIndex - 1
        local item = currentItems[itemDataIndex]
        if item then
            local def = ItemManager.get(item.id)
            if def then
                local desc = def.name .. "\n" .. (def.description or "没有描述。")
                if ShopUI.activeTab == 2 then
                    desc = desc .. "\n\n买入价: " .. (item.price or 0)
                else
                    -- [修改] Tooltip 显示半价
                    local sellPrice = getSellPrice(item.id)
                    if sellPrice > 0 then
                        desc = desc .. "\n\n卖出价: " .. sellPrice
                    else
                        desc = desc .. "\n\n(该商人不收购此物品)"
                    end
                end
                UIGrid.drawTooltip(desc)
            end
        end
    end

    -- 底部按钮
    for i, btn in ipairs(ShopUI.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        if ShopUI.hoveredButtonIndex == i then
            love.graphics.setColor(COLORS.tab_active)
        else
            love.graphics.setColor(COLORS.tab_inactive)
        end
        love.graphics.rectangle("fill", bx, by, btn.w, btn.h, 5, 5)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", bx, by, btn.w, btn.h, 5, 5)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(btn.text, bx, by + (btn.h - 14)/2, btn.w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

--------------------------------------------------
-- 输入事件处理
--------------------------------------------------
function ShopUI.keypressed(key)
    if key == "escape" then
        currentScene = ShopUI.previousScene or "game"
    elseif key == "1" or key == "2" or key == "3" then
        ShopUI.activeTab = tonumber(key)
        UIGrid.page = 1
        UIGrid.scrollOffset = 0
    end
end

function ShopUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)

    -- 标签页
    local tabW, tabH = 100, 35
    local winX, winY = 80, 80
    local tabStartX = winX + 20
    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i-1) * (tabW + 5)
        local ty = winY + 15
        if vx >= tx and vx <= tx + tabW and vy >= ty and vy <= ty + tabH then
            ShopUI.activeTab = i
            UIGrid.page = 1
            UIGrid.scrollOffset = 0
            return
        end
    end

    -- 按钮
    local clickedButtonIndex = Layout.mousepressed(x, y, button, ShopUI.buttons)
    if clickedButtonIndex then return end

    -- 物品买卖
    if ShopUI.activeTab == 2 or ShopUI.activeTab == 3 then
        local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
        if visualIndex and button == 1 then
            local itemsList = (ShopUI.activeTab == 2) and ShopUI.merchant.items or getSellableItems()
            local itemDataIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset + visualIndex - 1
            
            local item = itemsList[itemDataIndex]
            if item then
                local def = ItemManager.get(item.id)
                if def then
                    if ShopUI.activeTab == 2 then
                        -- 买入
                        if Player.data.gold >= item.price then
                            Player.data.gold = Player.data.gold - item.price
                            Inventory:addItem(item.id, 1, def.category)
                        end
                    else
                        -- [修改] 卖出逻辑
                        local sellPrice = getSellPrice(item.id)
                        if sellPrice > 0 then
                            Player.data.gold = Player.data.gold + sellPrice
                            Inventory:removeItem(item.id, 1, def.category)
                        else
                            -- 可以在这里加个提示音：商人不收这个
                            print("商人不收购此物品")
                        end
                    end
                end
            end
        end
    end
end

function ShopUI.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)

    ShopUI.hoveredTabIndex = nil
    local tabW, tabH = 100, 35
    local winX, winY = 80, 80
    local tabStartX = winX + 20
    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i-1) * (tabW + 5)
        local ty = winY + 15
        if vx >= tx and vx <= tx + tabW and vy >= ty and vy <= ty + tabH then
            ShopUI.hoveredTabIndex = i
            break
        end
    end

    if ShopUI.activeTab == 2 or ShopUI.activeTab == 3 then
        UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    else
        UIGrid.hoveredSlotIndex = nil
    end

    ShopUI.hoveredButtonIndex = Layout.mousemoved(x, y, ShopUI.buttons)
end

function ShopUI.wheelmoved(x, y)
    local count = 0
    if ShopUI.activeTab == 2 then
        count = #ShopUI.merchant.items
    elseif ShopUI.activeTab == 3 then
        count = #getSellableItems()
    end
    if count > 0 then UIGrid.scroll(-y, count) end
end

return ShopUI