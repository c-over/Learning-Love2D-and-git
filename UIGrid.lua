local Layout = require("layout")

local UIGrid = {}

-- === 基础状态 ===
UIGrid.configs = {}
UIGrid.activeConfig = nil

UIGrid.page = 1
UIGrid.itemsPerPage = 0
UIGrid.scrollOffset = 0

UIGrid.hoveredSlotIndex = nil
UIGrid.selectedIndex = nil

UIGrid.scrollbar = { isDragging = false, dragStartY = 0, startOffset = 0 }
UIGrid.dragItem = nil
UIGrid.actionMenu = nil
UIGrid.pendingTooltip = nil -- [新增] 延迟渲染文本

-- 1. 配置管理
function UIGrid.config(name, opts)
    local cfg = {
        cols = opts.cols or 5, rows = opts.rows or 4,
        slotSize = opts.slotSize or 64, margin = opts.margin or 10,
        startX = opts.startX or 100, startY = opts.startY or 100
    }
    UIGrid.configs[name or "default"] = cfg
    if not UIGrid.activeConfig then 
        UIGrid.activeConfig = cfg
        UIGrid.itemsPerPage = cfg.cols * cfg.rows
    end
    return cfg
end

function UIGrid.useConfig(name)
    local cfg = UIGrid.configs[name]
    if not cfg then cfg = UIGrid.config(name, {cols=5, rows=5}) end
    if UIGrid.activeConfig ~= cfg then
        UIGrid.activeConfig = cfg
        UIGrid.itemsPerPage = cfg.cols * cfg.rows
        UIGrid.scrollOffset = 0
        UIGrid.scrollbar.isDragging = false
        UIGrid.hoveredSlotIndex = nil
        UIGrid.hideActionMenu()
    end
end

local function cfg() return UIGrid.activeConfig end

-- 2. 几何计算
function UIGrid.getSlotRect(visualIndex)
    local c = cfg()
    local col = (visualIndex - 1) % c.cols
    local row = math.floor((visualIndex - 1) / c.cols)
    local x = c.startX + col * (c.slotSize + c.margin)
    local y = c.startY + row * (c.slotSize + c.margin)
    return x, y, c.slotSize, c.slotSize
end

function UIGrid.getIndexAtPosition(vx, vy)
    local c = cfg()
    local totalW = c.cols * (c.slotSize + c.margin) - c.margin
    local totalH = c.rows * (c.slotSize + c.margin) - c.margin
    if vx < c.startX or vx > c.startX + totalW or vy < c.startY or vy > c.startY + totalH then return nil end
    local col = math.floor((vx - c.startX) / (c.slotSize + c.margin))
    local row = math.floor((vy - c.startY) / (c.slotSize + c.margin))
    local relX = (vx - c.startX) % (c.slotSize + c.margin)
    local relY = (vy - c.startY) % (c.slotSize + c.margin)
    if relX > c.slotSize or relY > c.slotSize then return nil end
    if col < 0 or col >= c.cols or row < 0 or row >= c.rows then return nil end
    return row * c.cols + col + 1
end

-- 3. 滚动逻辑
function UIGrid.getMaxOffset(itemCount)
    local c = cfg()
    local totalRows = math.ceil(itemCount / c.cols)
    local viewRows = c.rows
    if totalRows <= viewRows then return 0 end
    return (totalRows - viewRows) * c.cols
end

function UIGrid.scroll(delta, itemCount)
    local maxOffset = UIGrid.getMaxOffset(itemCount)
    if maxOffset <= 0 then UIGrid.scrollOffset = 0; return end
    local step = cfg().cols
    UIGrid.scrollOffset = UIGrid.scrollOffset + delta * step
    if UIGrid.scrollOffset < 0 then UIGrid.scrollOffset = 0 end
    if UIGrid.scrollOffset > maxOffset then 
        local remainder = maxOffset % step
        UIGrid.scrollOffset = (remainder == 0) and maxOffset or (maxOffset - remainder + step)
        if UIGrid.scrollOffset > itemCount then UIGrid.scrollOffset = maxOffset end
    end
end

-- 4. 滚动条
local function getScrollbarLayout(itemCount)
    local c = cfg()
    local gridW = c.cols * (c.slotSize + c.margin) - c.margin
    local gridH = c.rows * (c.slotSize + c.margin) - c.margin
    local trackX = c.startX + gridW + 15
    local trackY = c.startY
    local trackW = 12
    local trackH = gridH
    local maxOffset = UIGrid.getMaxOffset(itemCount)
    if maxOffset <= 0 then return trackX, trackY, trackW, trackH, trackY, trackH end
    local totalRows = math.ceil(itemCount / c.cols)
    local ratio = c.rows / totalRows
    local handleH = math.max(30, trackH * ratio)
    local availableH = trackH - handleH
    local progress = UIGrid.scrollOffset / maxOffset
    local handleY = trackY + progress * availableH
    return trackX, trackY, trackW, trackH, handleY, handleH
end

function UIGrid.checkScrollbarPress(vx, vy, itemCount)
    if UIGrid.getMaxOffset(itemCount) <= 0 then return false end
    local tx, ty, tw, th = getScrollbarLayout(itemCount)
    if vx >= tx - 10 and vx <= tx + tw + 10 and vy >= ty and vy <= ty + th then
        UIGrid.scrollbar.isDragging = true
        UIGrid.scrollbar.dragStartY = vy
        UIGrid.scrollbar.startOffset = UIGrid.scrollOffset
        return true
    end
    return false
end

function UIGrid.updateScrollbarDrag(vx, vy, itemCount)
    if not UIGrid.scrollbar.isDragging then return end
    local _, _, _, trackH, _, handleH = getScrollbarLayout(itemCount)
    local availableH = trackH - handleH
    local maxOffset = UIGrid.getMaxOffset(itemCount)
    if availableH <= 0 or maxOffset <= 0 then return end
    local dy = vy - UIGrid.scrollbar.dragStartY
    local moveRatio = dy / availableH
    local newOffset = UIGrid.scrollbar.startOffset + moveRatio * maxOffset
    local step = cfg().cols
    newOffset = math.floor((newOffset + step/2) / step) * step
    UIGrid.scrollOffset = math.max(0, math.min(newOffset, maxOffset))
end

function UIGrid.releaseScrollbar() UIGrid.scrollbar.isDragging = false end

-- 5. 绘制主体
function UIGrid.drawAll(drawFunc, items, hoveredSlotIndex)
    local baseIndex = math.floor(UIGrid.scrollOffset) + 1
    UIGrid.pendingTooltip = nil -- 重置延迟提示

    for i = 1, UIGrid.itemsPerPage do
        local vx, vy, vw, vh = UIGrid.getSlotRect(i)
        local sx, sy = Layout.toScreen(vx, vy)
        local sw, sh = Layout.toScreen(vw, vh)
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        love.graphics.rectangle("line", sx, sy, sw, sh)
        
        local actualIndex = baseIndex + i - 1
        local state = {
            selected = (UIGrid.selectedIndex == i),
            hovered = (hoveredSlotIndex == i),
            dragTarget = (UIGrid.dragItem and UIGrid.getIndexAtPosition(Layout.toVirtual(love.mouse.getPosition())) == i)
        }
        
        local item = items[actualIndex]
        local isBeingDragged = (UIGrid.dragItem and UIGrid.dragItem.item == item)
        
        if not isBeingDragged then
            drawFunc(actualIndex, sx, sy, sw, sh, state)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function UIGrid.drawScrollbar(itemCount)
    if UIGrid.getMaxOffset(itemCount) <= 0 then return end
    local tx, ty, tw, th, hy, hh = getScrollbarLayout(itemCount)
    local sx, sy = Layout.toScreen(tx, ty)
    local sw, sh = Layout.toScreen(tw, th)
    local _, shy = Layout.toScreen(0, hy)
    local _, shh = Layout.toScreen(0, hh)
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", sx, sy, sw, sh, 4)
    if UIGrid.scrollbar.isDragging then love.graphics.setColor(0.4, 0.8, 1, 0.9)
    else love.graphics.setColor(0.3, 0.6, 0.9, 0.6) end
    love.graphics.rectangle("fill", sx, shy, sw, shh, 4)
    love.graphics.setColor(1, 1, 1)
end

-- 6. 交互组件
function UIGrid.showActionMenu(visualIndex, options)
    local x, y, w, h = UIGrid.getSlotRect(visualIndex)
    UIGrid.actionMenu = {x=x+w, y=y, w=100, h=35, options=options}
    UIGrid.selectedIndex = visualIndex
end
function UIGrid.hideActionMenu() UIGrid.actionMenu = nil; UIGrid.selectedIndex = nil end

function UIGrid.clickActionMenu(vx, vy)
    if not UIGrid.actionMenu then return false end
    local m = UIGrid.actionMenu
    for i, opt in ipairs(m.options) do
        local itemY = m.y + (i-1) * m.h
        if vx >= m.x and vx <= m.x + m.w and vy >= itemY and vy <= itemY + m.h then
            opt.action(); UIGrid.hideActionMenu(); return true
        end
    end
    return false
end

-- [修复] 恢复 drawActionMenu
function UIGrid.drawActionMenu()
    if not UIGrid.actionMenu then return end
    local m = UIGrid.actionMenu
    for i, opt in ipairs(m.options) do
        local sx, sy = Layout.toScreen(m.x, m.y + (i-1)*m.h)
        local sw, sh = Layout.toScreen(m.w, m.h)
        love.graphics.setColor(0.15, 0.15, 0.2, 0.95)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("line", sx, sy, sw, sh)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(opt.text, sx, sy + (sh-14)/2, sw, "center")
    end
end

-- 7. 拖拽
function UIGrid.startDrag(visualIndex, item, items)
    local baseIndex = math.floor(UIGrid.scrollOffset) + 1
    local actualIndex = baseIndex + visualIndex - 1
    UIGrid.dragItem = { item = item, visualIndex = visualIndex, actualIndex = actualIndex }
end

function UIGrid.endDrag(vx, vy, items)
    if not UIGrid.dragItem then return nil end
    local result = nil
    local targetVisual = UIGrid.getIndexAtPosition(vx, vy)
    if targetVisual then
        local baseIndex = math.floor(UIGrid.scrollOffset) + 1
        local targetActual = baseIndex + targetVisual - 1
        if targetActual <= #items and targetActual ~= UIGrid.dragItem.actualIndex then
            result = { sourceItem = UIGrid.dragItem.item, targetItem = items[targetActual] }
        end
    end
    UIGrid.dragItem = nil
    return result
end

-- [修复] 恢复 drawDraggingItem
function UIGrid.drawDraggingItem(ItemManager)
    if not UIGrid.dragItem then return end
    local item = UIGrid.dragItem.item
    local mx, my = love.mouse.getPosition()
    local img, quad = ItemManager.getIcon(item.id)
    if img then
        local targetSize = 64 * 1.1 
        local iw, ih
        if quad then _,_,iw,ih = quad:getViewport() else iw,ih = img:getWidth(), img:getHeight() end
        local scale = math.min(targetSize/iw, targetSize/ih)
        local drawW, drawH = iw * scale, ih * scale
        local dx, dy = mx - drawW / 2, my - drawH / 2
        
        love.graphics.setColor(0, 0, 0, 0.5)
        if quad then love.graphics.draw(img, quad, dx+5, dy+5, 0, scale, scale)
        else love.graphics.draw(img, dx+5, dy+5, 0, scale, scale) end
        
        love.graphics.setColor(1, 1, 1, 1)
        if quad then love.graphics.draw(img, quad, dx, dy, 0, scale, scale)
        else love.graphics.draw(img, dx, dy, 0, scale, scale) end

        if item.count > 1 then
            love.graphics.print(item.count, dx + drawW - 20, dy + drawH - 20)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- 8. Tooltip
function UIGrid.setTooltip(text)
    UIGrid.pendingTooltip = text
end

-- [修复] 恢复 drawTooltip
function UIGrid.drawTooltip(text)
    if not text or text == "" then return end
    local mx, my = love.mouse.getPosition()
    local font = love.graphics.getFont()
    local width, wrapped = font:getWrap(text, 250)
    local height = #wrapped * font:getHeight()
    local w, h = width + 20, height + 20
    local x, y = mx + 15, my + 15
    if x + w > love.graphics.getWidth() then x = mx - w - 10 end
    if y + h > love.graphics.getHeight() then y = my - h - 10 end
    
    love.graphics.setColor(0.1, 0.1, 0.12, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", x, y, w, h, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x + 10, y + 10, width, "left")
end

-- [修复] 恢复 drawOverlay 并调用上述函数
function UIGrid.drawOverlay(ItemManager)
    UIGrid.drawActionMenu()
    UIGrid.drawDraggingItem(ItemManager)
    if UIGrid.pendingTooltip and not UIGrid.actionMenu and not UIGrid.dragItem then
        UIGrid.drawTooltip(UIGrid.pendingTooltip)
    end
    UIGrid.pendingTooltip = nil
end

return UIGrid