local GameUI = {}
local Player = require("player")
local Layout = require("layout")
local Config = require("config")
local ItemManager = require("ItemManager")
local Inventory = require("inventory")

-- === 状态 ===
GameUI.floatingTexts = {}
GameUI.isHovering = false 

-- === 配置 ===
local HOTBAR_SLOTS = 10 
local SLOT_SIZE = 50
local SLOT_MARGIN = 5
local statusMargin = 15
local statusBarW = 240
local statusBarH = 26

local COLORS = {
    hp      = {0.9, 0.3, 0.3, 1},
    mp      = {0.3, 0.5, 0.9, 1},
    exp     = {0.4, 0.8, 0.4, 1},
    bg_bar  = {0.2, 0.2, 0.2, 0.8},
    text    = {1, 1, 1, 1},
    shadow  = {0, 0, 0, 0.8}
}

function GameUI.load() end

-- === 飘字系统 ===
function GameUI.addFloatText(text, x, y, color)
    -- [安全修复] 强制转为字符串，防止 nil 导致后续绘制崩溃
    if text == nil then return end
    text = tostring(text)

    table.insert(GameUI.floatingTexts, {
        text = text,
        x = x,
        y = y,
        oy = 0, 
        life = 1.5,
        color = color or {1, 1, 1, 1}
    })
end

-- === 快捷栏逻辑 ===
local function getHotbarItems()
    local list = {}
    for _, item in ipairs(Config.data.inventory) do
        local def = ItemManager.get(item.id)
        if def and (def.slot or def.usable) and def.category ~= "material" and def.category ~= "key_item" then
            table.insert(list, item)
        end
        if #list >= HOTBAR_SLOTS then break end
    end
    return list
end

function GameUI.useHotbarSlot(index)
    local validItems = getHotbarItems()
    local item = validItems[index]
    
    if item then
        if item.equipSlot then
            Player.unequipItem(item)
        else
            local def = ItemManager.get(item.id)
            if def.slot then
                Player.equipItem(item)
            elseif def.usable then
                -- 快捷栏使用物品是在游戏场景中，直接飘字在玩家头顶
                local ok, msg = ItemManager.use(item.id, Player)
                if ok then 
                    Inventory:removeItem(item.id, 1) 
                    GameUI.addFloatText(msg, Player.data.x, Player.data.y - 20, {0,1,0})
                else
                    GameUI.addFloatText(msg, Player.data.x, Player.data.y - 20, {1,0,0})
                end
            end
        end
    end
end

-- === 更新 ===
function GameUI.update(dt)
    for i = #GameUI.floatingTexts, 1, -1 do
        local f = GameUI.floatingTexts[i]
        f.life = f.life - dt
        f.oy = f.oy - dt * 40 
        if f.life <= 0 then table.remove(GameUI.floatingTexts, i) end
    end
end

-- === 绘制飘字 (独立函数) ===
function GameUI.drawFloatTexts()
    local font = Fonts.medium or love.graphics.getFont()
    love.graphics.setFont(font)
    
    local w, h = love.graphics.getDimensions()
    
    -- 判断是否需要摄像机偏移
    -- 只有在 "game" 或 "battle" 场景，且不是在菜单覆盖下时，才应用摄像机
    -- 但你的需求是：快捷栏使用(在游戏里) -> 玩家头顶；菜单使用 -> 屏幕顶部
    -- 我们可以通过判断当前场景来决定
    local useCamera = (currentScene == "game" or currentScene == "battle")
    
    local camX, camY = 0, 0
    if useCamera and package.loaded["game"] and package.loaded["game"].player then
        local p = require("game").player
        camX = p.x - w/2
        camY = p.y - h/2
    end

    for _, f in ipairs(GameUI.floatingTexts) do
        local sx, sy
        
        if useCamera then
            -- 游戏模式：世界坐标 - 摄像机
            sx = f.x - camX
            sy = f.y - camY + f.oy
        else
            -- 菜单模式：传入的就是屏幕虚拟坐标 (800x600 基于 Layout)
            -- 直接转屏幕坐标
            sx, sy = Layout.toScreen(f.x, f.y + f.oy)
        end
        
        -- 阴影
        love.graphics.setColor(0, 0, 0, f.life)
        love.graphics.print(f.text, sx + 2, sy + 2)
        
        -- 本体
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], f.life)
        love.graphics.print(f.text, sx, sy)
    end
    love.graphics.setColor(1, 1, 1)
end
-- === 绘制状态栏 ===
local function drawStatusBar()
    local vX = Layout.virtualWidth - statusBarW - statusMargin
    local vY = statusMargin
    local totalH = statusBarH * 3 + 10 * 2 + 10 
    
    local sX, sY = Layout.toScreen(vX, vY)
    local sW, sH = Layout.toScreen(statusBarW, statusBarH)
    local sContainerH = select(2, Layout.toScreen(0, totalH))
    local _, sGap = Layout.toScreen(0, 8) 
    local _, sPad = Layout.toScreen(0, 5)

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", sX - sPad, sY - sPad, sW + sPad*2, sContainerH, 10, 10)

    local function drawBar(label, cur, max, color, index)
        local drawY = sY + (index - 1) * (sH + sGap)
        love.graphics.setColor(COLORS.bg_bar)
        love.graphics.rectangle("fill", sX, drawY, sW, sH, 6, 6)
        local ratio = math.max(0, math.min(cur / max, 1))
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", sX, drawY, sW * ratio, sH, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", sX, drawY, sW * ratio, sH * 0.4, 6, 6)

        local font = Fonts.medium or love.graphics.getFont()
        love.graphics.setFont(font)
        local text = string.format("%d / %d", math.floor(cur), math.floor(max))
        if label == "EXP" then text = string.format("%.1f%%", (cur/max)*100) end
        
        local tx = sX + 10
        local ty = drawY + (sH - font:getHeight())/2 - 2
        love.graphics.setColor(COLORS.shadow)
        love.graphics.print(label, tx + 1, ty + 1)
        love.graphics.printf(text, sX, ty + 1, sW - 10, "right")
        love.graphics.setColor(COLORS.text)
        love.graphics.print(label, tx, ty)
        love.graphics.printf(text, sX, ty, sW - 10, "right")
    end

    drawBar("HP", Player.data.hp, Player.data.maxHp, COLORS.hp, 1)
    drawBar("MP", Player.data.mp, Player.data.maxMp, COLORS.mp, 2)
    local nextLevelExp = Player.data.level * 100
    drawBar("EXP", Player.data.exp, nextLevelExp, COLORS.exp, 3)
    love.graphics.setColor(1, 1, 1)
end

-- === 主绘制 ===
function GameUI.draw()
    drawStatusBar()
    
    local w = Layout.virtualWidth
    local h = Layout.virtualHeight
    local totalW = HOTBAR_SLOTS * (SLOT_SIZE + SLOT_MARGIN)
    local startX = (w - totalW) / 2
    local startY = h - SLOT_SIZE - 10
    local mx, my = love.mouse.getPosition()
    local vx, vy = Layout.toVirtual(mx, my)
    GameUI.isHovering = false 
    
    local hotbarItems = getHotbarItems()
    
    for i = 1, HOTBAR_SLOTS do
        local x = startX + (i-1) * (SLOT_SIZE + SLOT_MARGIN)
        local y = startY
        local sx, sy = Layout.toScreen(x, y)
        local ss, _ = Layout.toScreen(SLOT_SIZE, 0)
        local hovered = (vx >= x and vx <= x + SLOT_SIZE and vy >= y and vy <= y + SLOT_SIZE)
        if hovered then GameUI.isHovering = true end
        
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", sx, sy, ss, ss, 4)
        love.graphics.setColor(1, 1, 1, hovered and 0.8 or 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, ss, ss, 4)
        
        local item = hotbarItems[i]
        if item then
            local img, quad = ItemManager.getIcon(item.id)
            if img then
                love.graphics.setColor(1, 1, 1)
                local scale = (ss * 0.8) / (quad and select(3, quad:getViewport()) or img:getWidth())
                if quad then love.graphics.draw(img, quad, sx+ss*0.1, sy+ss*0.1, 0, scale, scale)
                else love.graphics.draw(img, sx+ss*0.1, sy+ss*0.1, 0, scale, scale) end
            end
            if item.count > 1 then
                love.graphics.setFont(Fonts.small)
                love.graphics.print(item.count, sx + ss - 15, sy + ss - 15)
            end
            if item.equipSlot then
                love.graphics.setColor(0, 1, 0)
                love.graphics.print("E", sx + 2, sy + 2)
            end
        end
        
        local keyNum = i
        if i == 10 then keyNum = 0 end
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setFont(Fonts.small)
        love.graphics.print(keyNum, sx + 2, sy - 12)
    end
    
    local handX = startX - 120
    local function drawHand(slotKey, label, offsetX)
        local hx = handX + offsetX
        local shx, shy = Layout.toScreen(hx, startY)
        local shs = select(2, Layout.toScreen(0, 50))
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", shx, shy, shs, shs, 4)
        love.graphics.setColor(1, 0.8, 0.2, 0.5)
        love.graphics.rectangle("line", shx, shy, shs, shs, 4)
        
        local def = Player.data.equipment[slotKey]
        if def then
            local img, quad = ItemManager.getIcon(def.id)
            if img then
                love.graphics.setColor(1, 1, 1)
                local scale = (shs * 0.8) / (quad and select(3, quad:getViewport()) or img:getWidth())
                if quad then love.graphics.draw(img, quad, shx+5, shy+5, 0, scale, scale)
                else love.graphics.draw(img, shx+5, shy+5, 0, scale, scale) end
            end
        end
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print(label, shx, shy - 15)
    end
    drawHand("main_hand", "主手", 0)
    drawHand("off_hand", "副手", 60)
    
    love.graphics.setColor(1, 1, 1)
end

-- === 输入处理 ===
function GameUI.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)
    local w = Layout.virtualWidth
    local h = Layout.virtualHeight
    
    local totalW = HOTBAR_SLOTS * (SLOT_SIZE + SLOT_MARGIN)
    local startX = (w - totalW) / 2
    local startY = h - SLOT_SIZE - 10
    
    if button == 1 then
        for i = 1, HOTBAR_SLOTS do
            local bx = startX + (i-1) * (SLOT_SIZE + SLOT_MARGIN)
            if vx >= bx and vx <= bx + SLOT_SIZE and vy >= startY and vy <= startY + SLOT_SIZE then
                GameUI.useHotbarSlot(i)
                return true
            end
        end
    end
    return false
end

function GameUI.keypressed(key)
    local n = tonumber(key)
    if n then
        if n >= 1 and n <= 9 then
            GameUI.useHotbarSlot(n)
            return true
        elseif n == 0 then
            GameUI.useHotbarSlot(10)
            return true
        end
    end
    
    if key == "tab" or key == "e" then
        require("PauseMenu").activeTab = "item"
        currentScene = "menu"
    end
end

return GameUI