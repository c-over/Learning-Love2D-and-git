local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local Player = require("player")

local ShopUI = {}
ShopUI.merchant = nil
ShopUI.buttons = {}       -- 所有按钮统一存放
ShopUI.selectedSide = nil -- "left" / "right" / "back"
ShopUI.selectedIndex = nil

-- 工具函数：计算卖出价
local function getSellPrice(def)
    return math.floor((def.price or 10) * 0.5)
end

-- 打开商店
function ShopUI.open(merchant)
    ShopUI.merchant = merchant
    ShopUI.buttons = {}
    ShopUI.selectedSide = "right"
    ShopUI.selectedIndex = 1

    -- 左列：背包物品
    local startY = 200
    for i, item in ipairs(Inventory.items) do
        local def = ItemManager.get(item.id)
        table.insert(ShopUI.buttons, {
            side = "left", index = i,
            x = 100, y = startY + (i-1)*60, w = 250, h = 50,
            text = def.name,
            onClick = function()
                local sellPrice = getSellPrice(def)
                Player.data.gold = Player.data.gold + sellPrice
                Inventory:removeItem(item.id, 1)
                print("出售成功: "..def.name.." +"..sellPrice.."金币")
            end
        })
    end

    -- 右列：商人货物
    local startY2 = 200
    for i, item in ipairs(merchant.items) do
        local def = ItemManager.get(item.id)
        table.insert(ShopUI.buttons, {
            side = "right", index = i,
            x = 450, y = startY2 + (i-1)*60, w = 250, h = 50,
            text = def.name,
            onClick = function()
                if Player.data.gold >= item.price then
                    Player.data.gold = Player.data.gold - item.price
                    Inventory:addItem(item.id, 1)
                    print("购买成功: "..def.name)
                else
                    print("金币不足！")
                end
            end
        })
    end

    -- 返回按钮
    table.insert(ShopUI.buttons, {
        side = "back", index = 1,
        x = 350, y = 500, w = 100, h = 40,
        text = "返回",
        onClick = function()
            currentScene = "game"
        end
    })

    currentScene = "shop"
end

-- 绘制
function ShopUI.draw()
    if not ShopUI.merchant then return end
    local infoLines = { "你的金币: "..Player.data.gold ,"出售物品              购买物品 "}

    -- 按钮分组绘制
    local leftButtons, rightButtons, backButtons = {}, {}, {}
    for _, btn in ipairs(ShopUI.buttons) do
        if btn.side == "left" then table.insert(leftButtons, btn)
        elseif btn.side == "right" then table.insert(rightButtons, btn)
        elseif btn.side == "back" then table.insert(backButtons, btn) end
    end

    Layout.draw("商店", infoLines, leftButtons,
        ShopUI.selectedSide=="left" and ShopUI.selectedIndex or nil)
    Layout.draw("商店", {}, rightButtons,
        ShopUI.selectedSide=="right" and ShopUI.selectedIndex or nil)
    Layout.draw("", {}, backButtons,
        ShopUI.selectedSide=="back" and ShopUI.selectedIndex or nil)

    -- 悬停提示框
    if ShopUI.selectedSide and ShopUI.selectedIndex then
        local text
        if ShopUI.selectedSide=="left" then
            local item = Inventory.items[ShopUI.selectedIndex]
            if item then
                local def = ItemManager.get(item.id)
                if def then
                    text = def.name.." x"..item.count.."\n卖出价格: "..getSellPrice(def).." 金币"
                end
            end
        elseif ShopUI.selectedSide=="right" then
            local item = ShopUI.merchant.items[ShopUI.selectedIndex]
            if item then
                local def = ItemManager.get(item.id)
                if def then
                    text = def.name.."\n买入价格: "..item.price.." 金币"
                end
            end
        elseif ShopUI.selectedSide=="back" then
            text = "返回游戏"
        end

        if text then
            local mx,my = love.mouse.getPosition()
            local padding = 8
            local font = love.graphics.getFont()
            local lines = {}
            for line in string.gmatch(text,"[^\n]+") do table.insert(lines,line) end
            local maxWidth = 0
            for _, line in ipairs(lines) do
                local w = font:getWidth(line)
                if w > maxWidth then maxWidth = w end
            end
            local totalHeight = #lines * font:getHeight() + padding*2
            local totalWidth = maxWidth + padding*2

            love.graphics.setColor(0,0,0,0.7)
            love.graphics.rectangle("fill", mx+16, my+16, totalWidth, totalHeight)
            love.graphics.setColor(1,1,1)
            love.graphics.rectangle("line", mx+16, my+16, totalWidth, totalHeight)

            local yOffset = my + 16 + padding
            for _, line in ipairs(lines) do
                love.graphics.print(line, mx+16+padding, yOffset)
                yOffset = yOffset + font:getHeight()
            end
        end
    end
end

-- 鼠标移动
function ShopUI.mousemoved(x,y)
    ShopUI.selectedSide = nil
    ShopUI.selectedIndex = nil
    for _, btn in ipairs(ShopUI.buttons) do
        local idx = Layout.mousemoved(x,y,{btn})
        if idx then
            ShopUI.selectedSide = btn.side
            ShopUI.selectedIndex = btn.index
            return
        end
    end
end

-- 鼠标点击
function ShopUI.mousepressed(x,y,button)
    for _, btn in ipairs(ShopUI.buttons) do
        if Layout.mousepressed(x,y,button,{btn}) then
            ShopUI.selectedSide = btn.side
            ShopUI.selectedIndex = btn.index
            if btn.onClick then btn.onClick() end
            return
        end
    end
end

-- 键盘操作
function ShopUI.keypressed(key)
    if ShopUI.selectedIndex then
        if key=="left" then
            ShopUI.selectedSide="left"
            ShopUI.selectedIndex=math.min(ShopUI.selectedIndex,#Inventory.items)
        elseif key=="right" then
            ShopUI.selectedSide="right"
            ShopUI.selectedIndex=math.min(ShopUI.selectedIndex,#ShopUI.merchant.items)
        elseif key=="up" then
            ShopUI.selectedIndex=math.max(1,ShopUI.selectedIndex-1)
        elseif key=="down" then
            local max=0
            if ShopUI.selectedSide=="left" then max=#Inventory.items
            elseif ShopUI.selectedSide=="right" then max=#ShopUI.merchant.items
            elseif ShopUI.selectedSide=="back" then max=1 end
            ShopUI.selectedIndex=math.min(max,ShopUI.selectedIndex+1)
        elseif key=="return" or key=="space" then
            for _, btn in ipairs(ShopUI.buttons) do
                if btn.side==ShopUI.selectedSide and btn.index==ShopUI.selectedIndex then
                    if btn.onClick then btn.onClick() end
                end
            end
        end
    elseif key=="escape" then
        currentScene="game"
    end
end

return ShopUI
