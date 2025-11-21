local Layout = require("layout")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local Player = require("player")

local ShopUI = {}
ShopUI.merchant = nil
ShopUI.leftButtons = {}
ShopUI.rightButtons = {}
ShopUI.selectedSide = "right"
ShopUI.selectedIndex = 1

ShopUI.backButton = {
    { x = 350, y = 500, w = 100, h = 40, text = "返回", onClick = function()
        currentScene = "game"
    end }
}

function ShopUI.open(merchant)
    ShopUI.merchant = merchant
    ShopUI.selectedSide = "right"
    ShopUI.selectedIndex = 1
    ShopUI.leftButtons = {}
    ShopUI.rightButtons = {}

    -- 左列：背包物品
    local startY = 150
    for i, item in ipairs(Inventory.items) do
        local def = ItemManager.get(item.id)
        table.insert(ShopUI.leftButtons, {
            x = 100, y = startY + (i-1)*60 + 50, w = 250, h = 50,
            text = def.name,
            onClick = function()
                local sellPrice = math.floor((def.price or 10)*0.5)
                Player.data.gold = Player.data.gold + sellPrice
                Inventory:removeItem(item.id, 1)
                print("出售成功: "..def.name.." +"..sellPrice.."金币")
            end
        })
    end

    -- 右列：商人货物
    local startY2 = 150
    for i, item in ipairs(merchant.items) do
        local def = ItemManager.get(item.id)
        table.insert(ShopUI.rightButtons, {
            x = 450, y = startY2 + (i-1)*60 + 50, w = 250, h = 50,
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

    currentScene = "shop"
end

function ShopUI.draw()
    if not ShopUI.merchant then return end
    local infoLines = { "你的金币: "..Player.data.gold ,"出售物品              购买物品 "}

    -- 绘制左列（背包）
    Layout.draw("商店", infoLines, ShopUI.leftButtons,
        ShopUI.selectedSide=="left" and ShopUI.selectedIndex or nil)
    -- 绘制右列（商人）
    Layout.draw("商店", {}, ShopUI.rightButtons,
        ShopUI.selectedSide=="right" and ShopUI.selectedIndex or nil)
    -- 绘制返回按钮
    Layout.draw("", {}, ShopUI.backButton,
        ShopUI.selectedSide=="back" and ShopUI.selectedIndex or nil)

    -- 悬停提示框
    if ShopUI.selectedSide and ShopUI.selectedIndex then
        local def, text
        if ShopUI.selectedSide=="left" then
            local item = Inventory.items[ShopUI.selectedIndex]
            def = ItemManager.get(item.id)
            if def then
                local sellPrice = math.floor((def.price or 10)*0.5)
                text = def.name.." x"..item.count.."\n卖出价格: "..sellPrice.." 金币"
            end
        elseif ShopUI.selectedSide=="right" then
            local item = ShopUI.merchant.items[ShopUI.selectedIndex]
            def = ItemManager.get(item.id)
            if def then
                text = def.name.."\n买入价格: "..item.price.." 金币"
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
            love.graphics.rectangle("fill", mx, my, totalWidth, totalHeight)
            love.graphics.setColor(1,1,1)
            love.graphics.rectangle("line", mx, my, totalWidth, totalHeight)

            local yOffset = my + padding
            for _, line in ipairs(lines) do
                love.graphics.print(line, mx+padding, yOffset)
                yOffset = yOffset + font:getHeight()
            end
        end
    end

end

function ShopUI.mousemoved(x,y)
    -- 默认清空
    ShopUI.selectedSide = nil
    ShopUI.selectedIndex = nil
    -- 检查左列
    local idx = Layout.mousemoved(x,y,ShopUI.leftButtons)
    if idx then
        ShopUI.selectedSide = "left"
        ShopUI.selectedIndex = idx
        return
    end
    -- 检查右列
    idx = Layout.mousemoved(x,y,ShopUI.rightButtons)
    if idx then
        ShopUI.selectedSide = "right"
        ShopUI.selectedIndex = idx
    end

    idx = Layout.mousemoved(x,y,ShopUI.backButton)
    if idx then
        ShopUI.selectedSide = "back"
        ShopUI.selectedIndex = idx
    end
end

function ShopUI.mousepressed(x,y,button) -- 如果没有悬停到任何按钮，清空状态
    if Layout.mousepressed(x,y,button,ShopUI.leftButtons) then
        ShopUI.selectedSide="left"
    elseif Layout.mousepressed(x,y,button,ShopUI.rightButtons) then
        ShopUI.selectedSide="right"
    end
   
end

function ShopUI.keypressed(key)
    if ShopUI.selectedIndex then
        if key=="left" then
            ShopUI.selectedSide="left"
            ShopUI.selectedIndex=math.min(ShopUI.selectedIndex,#ShopUI.leftButtons)
        elseif key=="right" then
            ShopUI.selectedSide="right"
            ShopUI.selectedIndex=math.min(ShopUI.selectedIndex,#ShopUI.rightButtons)
        elseif key=="up" then
            ShopUI.selectedIndex=math.max(1,ShopUI.selectedIndex-1)
        elseif key=="down" then
            local max=(ShopUI.selectedSide=="left") and #ShopUI.leftButtons or #ShopUI.rightButtons
            ShopUI.selectedIndex=math.min(max,ShopUI.selectedIndex+1)
        elseif key=="return" or key=="space" then
            local btn=(ShopUI.selectedSide=="left") and ShopUI.leftButtons[ShopUI.selectedIndex] or ShopUI.rightButtons[ShopUI.selectedIndex]
            if btn and btn.onClick then btn.onClick() end
        end
    elseif key=="escape" then
        currentScene="game"
    end
end

return ShopUI
