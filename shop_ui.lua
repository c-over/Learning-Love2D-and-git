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
-- 逻辑：优先看商人是否收购(在priceTable里)，如果没有，则读取物品原本价值的一半
local function getSellPrice(itemId)
    -- 1. 如果商人有定价，按商人的半价算 (可选，保持之前的逻辑)
    if ShopUI.priceTable[itemId] then
        return math.floor(ShopUI.priceTable[itemId] * 0.5)
    end
    
    -- 2. [修复] 如果商人没货，读取物品基础价格
    local def = ItemManager.get(itemId)
    if def and def.price then
        return math.floor(def.price * 0.5)
    end
    
    return 0 -- 无价之宝，不可出售
end

-- [修改] 获取玩家背包中可出售物品
-- 逻辑：只要 getSellPrice > 0 且不是重要物品，就可以出现在列表中
local function getSellableItems()
    local allItems = {}
    -- 遍历背包所有分类
    for _, category in ipairs(Inventory.categories) do
        local items = Inventory.getItemsByCategory(category)
        for _, item in ipairs(items) do
            local def = ItemManager.get(item.id)
            
            -- 排除: 1. 关键物品 2. 金币本身 3. 价格为0的物品
            if def and def.category ~= "key_item" and item.id ~= 5 then
                local price = getSellPrice(item.id)
                if price > 0 then
                    table.insert(allItems, item)
                end
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
        local vContentX = vWinX + 40
        local vContentY = vWinY + 80
        local sContentX, sContentY = Layout.toScreen(vContentX, vContentY)
        
        -- 绘制商人名字
        love.graphics.setColor(COLORS.gold)
        love.graphics.print(ShopUI.merchant.name or "商人", sContentX, sContentY)
        
        -- 绘制对话框背景
        local sRectX, sRectY = Layout.toScreen(vContentX, vContentY + 30)
        local sRectW, sRectH = Layout.toScreen(vWinW - 80, 200)
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", sRectX, sRectY, sRectW, sRectH, 5, 5)
        
        -- === [核心] 任务逻辑判断 ===
        -- 任务状态存储在 Player.data.questStatus 中
        -- nil: 未接, "active": 进行中, "killed": 已杀BOSS, "completed": 已交任务
        local status = Player.data.questStatus
        local dialogue = "欢迎光临！看看有什么需要的吗？"
        local btnText = nil
        
        if status == nil then
            dialogue = "最近北方的森林里出现了一个魔王，搞得人心惶惶。\n勇士，你能帮我去消灭它吗？"
            btnText = "接受任务"
        elseif status == "active" then
            dialogue = "魔王非常强大，请务必小心。它就在北边的森林深处。\n打败它后记得回来找我。"
        elseif status == "killed" then
            dialogue = "天哪！你真的做到了！\n这是传说中的【皇家徽章】，请收下它作为谢礼。"
            btnText = "交付任务"
        elseif status == "completed" then
            dialogue = "感谢你，伟大的英雄！你永远是本店的贵宾。"
        end
        
        -- 绘制对话文本
        local sTextX, sTextY = Layout.toScreen(vContentX + 20, vContentY + 50)
        local sTextW = Layout.toScreen(vWinW - 120, 0)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(dialogue, sTextX, sTextY, sTextW, "left")
        
        -- 绘制交互按钮 (如果有)
        if btnText then
            local vBtnX, vBtnY = vContentX + 20, vContentY + 180
            local sBtnX, sBtnY = Layout.toScreen(vBtnX, vBtnY)
            local sBtnW, sBtnH = Layout.toScreen(120, 40)
            
            -- 简单的按钮绘制
            local mx, my = love.mouse.getPosition()
            local hovered = (mx >= sBtnX and mx <= sBtnX + sBtnW and my >= sBtnY and my <= sBtnY + sBtnH)
            
            if hovered then love.graphics.setColor(0.2, 0.8, 0.2)
            else love.graphics.setColor(0.2, 0.6, 0.2) end
            
            love.graphics.rectangle("fill", sBtnX, sBtnY, sBtnW, sBtnH, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(btnText, sBtnX, sBtnY + select(2,Layout.toScreen(0,10)), sBtnW, "center")
            
            -- 记录按钮 rect 供点击检测 (临时存储在 ShopUI)
            ShopUI.questBtnRect = {x=vBtnX, y=vBtnY, w=120, h=40}
        else
            ShopUI.questBtnRect = nil
        end

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
        -- 一键出售按钮 (仅在卖出页显示)
        local btnW, btnH = 160, 40
        local btnX, btnY = Layout.toScreen(100, 80 - 60)
        local mx, my = love.mouse.getPosition()
        
        -- 悬停
        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
            love.graphics.setColor(0.8, 0.3, 0.3) -- 红色高亮
            -- 点击检测放在这里简化处理，或者移到 mousepressed
            if love.mouse.isDown(1) and not ShopUI.sellBtnClicked then
                ShopUI.sellBtnClicked = true
                local gold, count = Inventory:sellDuplicateEquipment()
                if count > 0 then
                    print("一键出售: " .. count .. "件，获得 " .. gold .. "金币")
                    -- 这里可以用 GameUI.addFloatText 提示
                end
            elseif not love.mouse.isDown(1) then
                ShopUI.sellBtnClicked = false
            end
        else
            love.graphics.setColor(0.6, 0.2, 0.2) -- 暗红
        end
        
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Fonts.normal)
        love.graphics.printf("一键出售重复装备", btnX, btnY + 10, btnW, "center")
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
    local isShift = love.keyboard.isDown("lshift", "rshift")

    -- 1. 标签页切换
    local tabW, tabH = 100, 35
    local winX, winY = 80, 80
    local tabStartX = winX + 20
    -- 注意：tabs 变量需要在文件顶部定义，如果提示 nil 请确保 local tabs = {"对话", "买入", "卖出"} 存在
    local tabs = {"对话", "买入", "卖出"} 
    
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

    -- 2. 底部按钮 (离开商店)
    if Layout.mousepressed(x, y, button, ShopUI.buttons) then return end
    
    -- 3. 一键出售按钮 (仅在卖出页)
    if ShopUI.activeTab == 3 then
        -- 重新计算按钮位置 (需与 draw 中的逻辑一致)
        local winW, winH = Layout.virtualWidth-160, Layout.virtualHeight-140
        local btnW, btnH = 160, 40
        local btnX = winX + 20
        local btnY = winY + winH - 60
        
        if vx >= btnX and vx <= btnX + btnW and vy >= btnY and vy <= btnY + btnH then
             -- 调用 Inventory 的出售重复装备逻辑
             local gold, count = Inventory:sellDuplicateEquipment()
             if count > 0 then 
                 -- 使用 GameUI 飘字 (如果有)
                 if package.loaded["game_ui"] and package.loaded["game_ui"].addFloatText then
                     require("game_ui").addFloatText("一键出售: +"..gold, vx, vy, {1,1,0})
                 else
                     print("一键出售完成")
                 end
             end 
             return
        end
    end

    -- 4. 物品列表交互 (买入/卖出)
    if ShopUI.activeTab == 2 or ShopUI.activeTab == 3 then
        local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
        if visualIndex and button == 1 then
            local itemsList = (ShopUI.activeTab == 2) and ShopUI.merchant.items or getSellableItems()
            local itemDataIndex = math.floor(UIGrid.scrollOffset) + visualIndex
            
            local item = itemsList[itemDataIndex]
            if item then
                local ItemManager = require("ItemManager")
                local def = ItemManager.get(item.id)
                local amount = isShift and 10 or 1
                
                if ShopUI.activeTab == 2 then
                    -- === [买入逻辑] ===
                    -- item 来自 merchant.items，包含 {id, price, stock}
                    local buyPrice = item.price
                    local successCount = 0
                    
                    for i=1, amount do
                        if Player.data.gold >= buyPrice then
                            if item.stock and item.stock <= 0 then break end -- 没货了
                            
                            Player.data.gold = Player.data.gold - buyPrice
                            Inventory:addItem(item.id, 1, def.category)
                            
                            if item.stock then item.stock = item.stock - 1 end
                            successCount = successCount + 1
                        else
                            break -- 没钱了
                        end
                    end
                    
                    if successCount > 0 and package.loaded["game_ui"] then
                         require("game_ui").addFloatText("购买成功 -"..(buyPrice*successCount), vx, vy, {1,0.8,0})
                    end
                    
                    -- 如果库存归零，可能需要刷新列表 (可选)
                    -- 但因为 itemsList 是引用，draw 会自动更新显示
                    
                else
                    -- === [卖出逻辑] ===
                    -- item 来自 Inventory，结构为 {id, count}
                    -- [核心修复] 使用 getSellPrice 获取单价，而不是 item.price
                    local unitSellPrice = getSellPrice(item.id)
                    
                    -- 能够卖出的数量不能超过拥有的数量
                    local canSellCount = math.min(amount, item.count)
                    
                    if canSellCount > 0 and unitSellPrice > 0 then
                        local totalEarn = unitSellPrice * canSellCount
                        
                        Player.data.gold = Player.data.gold + totalEarn
                        Inventory:removeItem(item.id, canSellCount, def.category)
                        
                        if package.loaded["game_ui"] then
                            require("game_ui").addFloatText("卖出 +"..totalEarn, vx, vy, {1,1,0})
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