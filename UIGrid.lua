local Layout = require("layout")

local UIGrid = {}

-- 状态
UIGrid.configs = {}
UIGrid.activeConfig = nil
UIGrid.itemsPerPage = 0
UIGrid.scrollOffset = 0

UIGrid.hoveredSlotIndex = nil
UIGrid.selectedIndex = nil

UIGrid.scrollbar = { isDragging = false, dragStartY = 0, startOffset = 0 }
UIGrid.dragItem = nil
UIGrid.actionMenu = nil

-- 1. 配置
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
    local cfg = UIGrid.configs[name] or UIGrid.configs["default"]
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

-- [新增] 计算最大滚动偏移量 (基于行)
function UIGrid.getMaxOffset(itemCount)
    local c = cfg()
    local totalRows = math.ceil(itemCount / c.cols)
    local viewRows = c.rows
    if totalRows <= viewRows then return 0 end
    -- 最大偏移 = (总行数 - 可视行数) * 每行个数
    return (totalRows - viewRows) * c.cols
end

-- 3. 滚动逻辑 (修复为整行)
function UIGrid.scroll(delta, itemCount)
    local maxOffset = UIGrid.getMaxOffset(itemCount)
    if maxOffset <= 0 then 
        UIGrid.scrollOffset = 0 
        return 
    end
    
    local step = cfg().cols -- 每次滚一行
    UIGrid.scrollOffset = UIGrid.scrollOffset + delta * step
    
    -- 边界限制
    if UIGrid.scrollOffset < 0 then UIGrid.scrollOffset = 0 end
    if UIGrid.scrollOffset > maxOffset then UIGrid.scrollOffset = maxOffset end
end

-- 4. 滚动条交互
local function getScrollbarLayout(itemCount)
    local c = cfg()
    local gridW = c.cols * (c.slotSize + c.margin) - c.margin
    local gridH = c.rows * (c.slotSize + c.margin) - c.margin
    
    local trackX = c.startX + gridW + 15
    local trackY = c.startY
    local trackW = 12
    local trackH = gridH
    
    local maxOffset = UIGrid.getMaxOffset(itemCount)
    if maxOffset <= 0 then 
        return trackX, trackY, trackW, trackH, trackY, trackH 
    end

    local totalRows = math.ceil(itemCount / c.cols)
    local ratio = c.rows / totalRows
    local handleH = math.max(30, trackH * ratio)
    local availableH = trackH - handleH
    -- 当前比例
    local progress = UIGrid.scrollOffset / maxOffset
    local handleY = trackY + progress * availableH
    
    return trackX, trackY, trackW, trackH, handleY, handleH
end

function UIGrid.checkScrollbarPress(vx, vy, itemCount)
    if UIGrid.getMaxOffset(itemCount) <= 0 then return false end
    local tx, ty, tw, th = getScrollbarLayout(itemCount) -- 复用前4个返回值
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
    
    -- 吸附到最近的行
    local step = cfg().cols
    newOffset = math.floor((newOffset + step/2) / step) * step
    
    UIGrid.scrollOffset = math.max(0, math.min(newOffset, maxOffset))
end

function UIGrid.releaseScrollbar() UIGrid.scrollbar.isDragging = false end

-- 5. 绘制
function UIGrid.drawAll(drawFunc, items, hoveredSlotIndex)
    local baseIndex = math.floor(UIGrid.scrollOffset) + 1
    
    -- 绘制底框 (即使没有物品也绘制)
    for i = 1, UIGrid.itemsPerPage do
        local vx, vy, vw, vh = UIGrid.getSlotRect(i)
        local sx, sy = Layout.toScreen(vx, vy)
        local sw, sh = Layout.toScreen(vw, vh)
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        love.graphics.rectangle("line", sx, sy, sw, sh)
        
        -- 计算物品
        local actualIndex = baseIndex + i - 1
        local state = {
            selected = (UIGrid.selectedIndex == i),
            hovered = (hoveredSlotIndex == i),
            dragTarget = (UIGrid.dragItem and UIGrid.getIndexAtPosition(Layout.toVirtual(love.mouse.getPosition())) == i)
        }
        
        -- 调用回调绘制物品 (如果 index 超出 items 范围，item 为 nil，回调需处理)
        local item = items[actualIndex]
        
        -- 如果是被拖拽的源物品，本体不绘制
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
function UIGrid.hideActionMenu()
    UIGrid.actionMenu = nil
    UIGrid.selectedIndex = nil
end
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

-- 拖拽逻辑 (不修改列表，通过回调返回结果)
function UIGrid.startDrag(visualIndex, item, items)
    local baseIndex = math.floor(UIGrid.scrollOffset) + 1
    local actualIndex = baseIndex + visualIndex - 1
    UIGrid.dragItem = { item = item, visualIndex = visualIndex, actualIndex = actualIndex }
end
-- [关键修改] endDrag 现在返回 targetItem 的实际索引，由外部处理交换
function UIGrid.endDrag(vx, vy, items)
    if not UIGrid.dragItem then return nil end
    local result = nil
    
    local targetVisual = UIGrid.getIndexAtPosition(vx, vy)
    if targetVisual then
        local baseIndex = math.floor(UIGrid.scrollOffset) + 1
        local targetActual = baseIndex + targetVisual - 1
        
        -- 只有目标位置在有效范围内，且不是自己时才返回
        -- 注意：如果 targetActual > #items，说明拖到了空位，也应该允许交换（即移动到最后）
        -- 但因为 Inventory.getItemsByCategory 返回的是连续数组，空位意味着追加。
        -- 这里我们简单处理：只允许与现有物品交换。
        -- 如果你想支持“任意格子摆放”，那需要 Inventory 改为基于 Slot ID 的系统。
        -- 这里按“列表重新排序”逻辑：
        
        if targetActual <= #items and targetActual ~= UIGrid.dragItem.actualIndex then
            result = {
                sourceItem = UIGrid.dragItem.item,
                targetItem = items[targetActual]
            }
        end
    end
    
    UIGrid.dragItem = nil
    return result
end

function UIGrid.drawDraggingItem(ItemManager)
    if not UIGrid.dragItem then return end
    local item = UIGrid.dragItem.item
    local mx, my = love.mouse.getPosition()
    
    local img, quad = ItemManager.getIcon(item.id)
    if img then
        -- 1. 计算缩放比例 (强制缩放到 64x64 左右，并放大 10% 以示区别)
        local targetSize = 64 * 1.1 
        local iw, ih
        if quad then _,_,iw,ih = quad:getViewport() else iw,ih = img:getWidth(), img:getHeight() end
        local scale = math.min(targetSize/iw, targetSize/ih)
        
        -- 计算居中偏移 (鼠标在图标中心)
        local drawW, drawH = iw * scale, ih * scale
        local dx = mx - drawW / 2
        local dy = my - drawH / 2
        
        -- 2. 绘制阴影 (偏移 + 半透明黑色) -> 营造悬浮感
        love.graphics.setColor(0, 0, 0, 0.5)
        local shadowOffset = 5
        if quad then 
            love.graphics.draw(img, quad, dx + shadowOffset, dy + shadowOffset, 0, scale, scale)
        else 
            love.graphics.draw(img, dx + shadowOffset, dy + shadowOffset, 0, scale, scale) 
        end

        -- 3. 绘制本体
        love.graphics.setColor(1, 1, 1, 1) -- 保持原色，不透明
        if quad then 
            love.graphics.draw(img, quad, dx, dy, 0, scale, scale)
        else 
            love.graphics.draw(img, dx, dy, 0, scale, scale) 
        end
        
        -- 4. (可选) 绘制数量
        if item.count > 1 then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(item.count, dx + drawW - 15, dy + drawH - 20)
        end
    end
    -- 重置颜色
    love.graphics.setColor(1, 1, 1)
end
function UIGrid.drawTooltip(text)
    if not text or UIGrid.dragItem or UIGrid.actionMenu then return end
    local mx, my = love.mouse.getPosition()
    local font = love.graphics.getFont()
    local tw, th = font:getWidth(text), font:getHeight()
    local w, h = tw + 20, th + 20
    local x, y = mx + 15, my + 15
    if x + w > love.graphics.getWidth() then x = mx - w - 10 end
    if y + h > love.graphics.getHeight() then y = my - h - 10 end
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, w, h, 4)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, w, h, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, x + 10, y + 10)
end

return UIGrid