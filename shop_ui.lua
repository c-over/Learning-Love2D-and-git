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
local FONT_SMALL = love.graphics.newFont("assets/simhei.ttf", 12)
local FONT_NORMAL = love.graphics.newFont("assets/simhei.ttf", 28)

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
            local Config = require("config")
            Config.save()
            print("离开商店，自动保存")
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
    -- 保存当前字体 (良好的编程习惯)
    local oldFont = love.graphics.getFont()
    local vWinX, vWinY = 80, 80
    local vWinW, vWinH = Layout.virtualWidth - 160, Layout.virtualHeight - 140
    
    -- 转换为屏幕坐标
    local sWinX, sWinY = Layout.toScreen(vWinX, vWinY)
    local sWinW, sWinH = Layout.toScreen(vWinW, vWinH)

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
        local vTx = vTabStartX + (i-1) * (vTabW + 5)
        local vTy = vWinY + 15
        
        local sTx, sTy = Layout.toScreen(vTx, vTy)
        local sTw, sTh = Layout.toScreen(vTabW, vTabH)
        
        if ShopUI.activeTab == i then
            love.graphics.setColor(COLORS.tab_active)
        elseif ShopUI.hoveredTabIndex == i then
            love.graphics.setColor(COLORS.tab_active[1], COLORS.tab_active[2], COLORS.tab_active[3], 0.7)
        else
            love.graphics.setColor(COLORS.tab_inactive)
        end
        love.graphics.rectangle("fill", sTx, sTy, sTw, sTh, 5, 5)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(tab, sTx, sTy + (sTh-14)/2, sTw, "center")
    end

    drawGoldDisplay(vWinX + vWinW - 120, vWinY + 20)

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
            
            -- 1. 价格显示
            if Player.data.gold >= price then
                love.graphics.setColor(COLORS.price_ok)
            else
                love.graphics.setColor(COLORS.price_no)
            end
            love.graphics.printf("$"..price, x, y + h - 18, w, "center")

            -- 2. [新增] 库存显示 (右上角)
            love.graphics.setFont(Fonts.small)
            if item.stock then
                -- 有限库存：显示剩余数量
                if item.stock <= 3 then
                    love.graphics.setColor(1, 0.3, 0.3) -- 库存紧张显示红色
                else
                    love.graphics.setColor(1, 1, 1)
                end
                love.graphics.print("剩余:"..item.stock, x + 2, y + 2)
            else
                -- 无限库存：显示 ∞
                love.graphics.setColor(0.5, 0.5, 1)
                love.graphics.print("∞", x + 2, y + 2)
            end
            love.graphics.setFont(Fonts.normal)
            
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
        love.graphics.setFont(oldFont)
    end

    -- 内容区域 (标签页1: 对话)
    if ShopUI.activeTab == 1 then
        -- [关键修复] 使用虚拟坐标基准
        local vContentX = vWinX + 40
        local vContentY = vWinY + 80
        
        local sContentX, sContentY = Layout.toScreen(vContentX, vContentY)
        local sTextBoxY = select(2, Layout.toScreen(0, vContentY + 30)) -- 只转换Y坐标
        local sTextBoxW, sTextBoxH = Layout.toScreen(vWinW - 80, 200)

        love.graphics.setColor(COLORS.gold)
        love.graphics.print(ShopUI.merchant.name or "商人", sContentX, sContentY)
        
        love.graphics.setColor(0, 0, 0, 0.3)
        -- 注意：这里 sTextBoxY 实际上算错了，应该是 Layout.toScreen(vContentX, vContentY + 30) 的 Y
        local sRectX, sRectY = Layout.toScreen(vContentX, vContentY + 30)
        love.graphics.rectangle("fill", sRectX, sRectY, sTextBoxW, sTextBoxH, 5, 5)
        
        local sTextX, sTextY = Layout.toScreen(vContentX + 20, vContentY + 50)
        local sTextWidth = Layout.toScreen(vWinW - 120, 0)
        
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(ShopUI.merchant.dialogue or "欢迎！", sTextX, sTextY, sTextWidth, "left")

    elseif ShopUI.activeTab == 2 then
        -- 买卖界面的 UIGrid 已经处理了 Layout.toScreen，所以不需要大改
        -- 但要确保 UIGrid.config 里的 startY 是虚拟坐标
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
        
        -- [关键修复] 缩放宽高
        local bw, bh = Layout.toScreen(btn.w, btn.h)

        if ShopUI.hoveredButtonIndex == i then
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
                        -- [买入逻辑]
                        if Player.data.gold >= item.price then
                            -- 1. 扣钱，加货
                            Player.data.gold = Player.data.gold - item.price
                            Inventory:addItem(item.id, 1, def.category)
                            
                            -- 2. [关键修改] 库存处理逻辑
                            if item.stock then
                                -- 如果有库存限制
                                item.stock = item.stock - 1
                                print("购买成功！剩余库存: " .. item.stock)
                                
                                -- 如果库存归零，从列表中移除
                                if item.stock <= 0 then
                                    table.remove(ShopUI.merchant.items, itemDataIndex)
                                    -- 防止悬停索引越界，重置一下
                                    UIGrid.hoveredSlotIndex = nil
                                    print("商品已售罄！")
                                end
                            else
                                -- 无限库存，不进行 remove 操作
                                print("购买成功！(无限供应)")
                            end
                            
                        else
                            print("金币不足！")
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