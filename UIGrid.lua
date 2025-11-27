-- UIGrid.lua
local Layout = require("layout")

local UIGrid = {}

UIGrid.configs = {}
UIGrid.activeConfig = nil
UIGrid.slotStates = {}

-- 翻页与滚动
UIGrid.page = 1
UIGrid.itemsPerPage = 0
UIGrid.scrollOffset = 0

-- 拖动
UIGrid.draggingItem = nil

-- 操作菜单与悬停
UIGrid.actionMenu = nil
UIGrid.hoveredIndex = nil
UIGrid.selectedIndex = nil

--------------------------------------------------
-- 配置与布局
--------------------------------------------------
function UIGrid.config(name, opts)
    local cfg = {
        cols     = opts.cols or 5,
        rows     = opts.rows or 4,
        slotSize = opts.slotSize or 64,
        margin   = opts.margin or 10,
        startX   = opts.startX or 100,
        startY   = opts.startY or 100,
        scale    = opts.scale or 1
    }
    UIGrid.configs[name or "default"] = cfg
    UIGrid.activeConfig = cfg
    UIGrid.slotStates = {}
    UIGrid.itemsPerPage = cfg.cols * cfg.rows
    return cfg
end

function UIGrid.useConfig(name)
    -- 尝试获取配置
    local cfg = UIGrid.configs[name]
    
    -- 如果找不到指定配置，尝试回退到 "default"
    if not cfg then
        cfg = UIGrid.configs["default"]
    end

    -- 如果连默认配置都没有，为了防止崩溃，现场创建一个临时配置
    if not cfg then
        print("Warning: UIGrid config '" .. tostring(name) .. "' not found and no default config. Using fallback.")
        cfg = {
            cols = 5, rows = 4, slotSize = 64, margin = 10, 
            startX = 100, startY = 100, scale = 1
        }
        -- 将其存入 configs 避免下次再报警
        UIGrid.configs[name or "default"] = cfg
    end

    UIGrid.activeConfig = cfg
    UIGrid.slotStates = {}
    
    -- 现在 activeConfig 肯定不为空了，可以安全计算
    UIGrid.itemsPerPage = UIGrid.activeConfig.cols * UIGrid.activeConfig.rows
end

local function cfg() return UIGrid.activeConfig end

--------------------------------------------------
-- 坐标与索引
--------------------------------------------------
function UIGrid.getSlotRect(index)
    local c = cfg()
    local col = (index-1) % c.cols
    local row = math.floor((index-1) / c.cols)
    local x = c.startX + col * (c.slotSize + c.margin)
    local y = c.startY + row * (c.slotSize + c.margin)
    local size = c.slotSize * c.scale
    return x, y, size, size
end

function UIGrid.getIndexAtPosition(vx, vy)
    local c = cfg()
    local col = math.floor((vx - c.startX) / (c.slotSize + c.margin))
    local row = math.floor((vy - c.startY) / (c.slotSize + c.margin))
    if col < 0 or col >= c.cols or row < 0 or row >= c.rows then return nil end
    return row * c.cols + col + 1
end

--------------------------------------------------
-- 翻页与滚动
--------------------------------------------------
function UIGrid.totalPages(itemCount)
    return math.max(1, math.ceil(itemCount / UIGrid.itemsPerPage))
end

function UIGrid.nextPage(itemCount)
    local total = UIGrid.totalPages(itemCount)
    UIGrid.page = math.min(UIGrid.page + 1, total)
    UIGrid.scrollOffset = 0
end

function UIGrid.prevPage()
    UIGrid.page = math.max(UIGrid.page - 1, 1)
    UIGrid.scrollOffset = 0
end

function UIGrid.scroll(delta, itemCount)
    local maxOffset = math.max(0, itemCount - UIGrid.itemsPerPage)
    UIGrid.scrollOffset = math.max(0, math.min(UIGrid.scrollOffset + delta, maxOffset))
end

function UIGrid.drawScrollbar(itemCount)
    if itemCount <= UIGrid.itemsPerPage then return end
    local barHeight = 200
    local barX, barY = cfg().startX + cfg().cols*(cfg().slotSize+cfg().margin) + 20, cfg().startY
    local handleHeight = math.max(20, barHeight * (UIGrid.itemsPerPage / itemCount))
    local handleY = barY + (barHeight - handleHeight) * (UIGrid.scrollOffset / (itemCount - UIGrid.itemsPerPage))

    love.graphics.setColor(1,1,1,0.3)
    love.graphics.rectangle("fill", barX, barY, 10, barHeight)
    love.graphics.setColor(0.2,0.8,1,0.6)
    love.graphics.rectangle("fill", barX, handleY, 10, handleHeight)
end

--------------------------------------------------
-- 状态管理
--------------------------------------------------
function UIGrid.setSlotState(index, state)
    UIGrid.slotStates[index] = state
end
function UIGrid.getSlotState(index)
    return UIGrid.slotStates[index]
end
--------------------------------------------------
-- 批量绘制
--------------------------------------------------
function UIGrid.drawAll(drawFunc, items, hoveredSlotIndex)
    local c = cfg()
    local baseIndex = (UIGrid.page-1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset
    local endIndex = math.min(baseIndex + UIGrid.itemsPerPage - 1, #items)

    -- 1. 绘制所有格子的背景 (使用屏幕坐标)
    for i = 1, c.cols * c.rows do
        local x, y, w, h = UIGrid.getSlotRect(i)
        -- 关键修复：将虚拟坐标转换为屏幕坐标
        local sx, sy = Layout.toScreen(x, y)
        local sw, sh = Layout.toScreen(w, h)

        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        love.graphics.rectangle("line", sx, sy, sw, sh)
    end

    -- 2. 循环绘制物品和高亮效果
    local slotIndex = 1
    for i = baseIndex, endIndex do
        local x, y, w, h = UIGrid.getSlotRect(slotIndex)

        -- 关键修复：将虚拟坐标转换为屏幕坐标
        local sx, sy = Layout.toScreen(x, y)
        local sw, sh = Layout.toScreen(w, h)

        -- 检查当前格子是否是拖动源
        local isDragSource = (UIGrid.draggingItem and UIGrid.draggingItem.visualIndex == slotIndex)

        -- 如果不是拖动源，则正常绘制
        if not isDragSource then
            -- 准备一个状态表，用于传递给 drawFunc
            local state = {}

            -- 检查是否被选中
            if UIGrid.selectedIndex == slotIndex then
                state.selected = true
            end
            
            -- 检查是否是拖动目标
            if UIGrid.draggingItem then
                local mx, my = love.mouse.getPosition()
                local vx, vy = Layout.toVirtual(mx, my)
                local targetSlot = UIGrid.getIndexAtPosition(vx, vy)
                if targetSlot == slotIndex then
                    state.dragTarget = true
                end
            end

            -- 检查鼠标是否悬停在此格子上
            if hoveredSlotIndex == slotIndex then
                state.hovered = true
            end

            -- 调用绘制函数，传递屏幕坐标
            drawFunc(i, sx, sy, sw, sh, state)
        end

        slotIndex = slotIndex + 1
    end
end
--------------------------------------------------
-- 操作菜单
--------------------------------------------------
function UIGrid.showActionMenu(index, options)
    local x,y,w,h = UIGrid.getSlotRect(index)
    UIGrid.actionMenu = {
        x = x + w + 10,
        y = y,
        w = 100,
        h = 35,
        options = options
    }
    UIGrid.selectedIndex = index
end

function UIGrid.hideActionMenu()
    UIGrid.actionMenu = nil
    UIGrid.selectedIndex = nil
end

function UIGrid.drawActionMenu()
    if not UIGrid.actionMenu then return end

    -- 获取菜单的虚拟位置和尺寸
    local menuVx = UIGrid.actionMenu.x
    local menuVy = UIGrid.actionMenu.y
    local menuVw = UIGrid.actionMenu.w
    local menuVh = UIGrid.actionMenu.h

    for i, opt in ipairs(UIGrid.actionMenu.options) do
        -- 计算每个菜单项的虚拟位置和尺寸
        local itemVx = menuVx
        local itemVy = menuVy + (i - 1) * menuVh
        local itemVw = menuVw
        local itemVh = menuVh

        -- 关键修复：将虚拟坐标和尺寸都转换为屏幕坐标
        local sx, sy = Layout.toScreen(itemVx, itemVy)
        local sw, sh = Layout.toScreen(itemVw, itemVh)

        -- 使用屏幕坐标进行绘制
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", sx, sy, sw, sh)
        love.graphics.printf(opt.text, sx, sy + 5, sw, "center")
    end
end

function UIGrid.clickActionMenu(vx, vy)
    if not UIGrid.actionMenu then return false end
    for i,opt in ipairs(UIGrid.actionMenu.options) do
        local bx = UIGrid.actionMenu.x
        local by = UIGrid.actionMenu.y + (i-1)*UIGrid.actionMenu.h
        if vx > bx and vx < bx+UIGrid.actionMenu.w and vy > by and vy < by+UIGrid.actionMenu.h then
            opt.action()
            UIGrid.hideActionMenu()
            return true
        end
    end
    return false
end

--------------------------------------------------
-- 描述框
--------------------------------------------------
function UIGrid.drawTooltip(text)
    -- 1. 如果没有文本，或者正在拖动物品，则不显示
    if not text or UIGrid.draggingItem then
        return
    end

    local mx, my = love.mouse.getPosition()
    local padding = 8
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    
    local w = textW + padding * 2
    local h = textH + padding * 2

    -- 2. 设置提示框的初始位置为鼠标右下方
    local offset = 15 -- 鼠标与提示框的间距
    local x = mx + offset
    local y = my + offset

    -- 3. 边界检测：如果超出屏幕，则移动到鼠标左上方
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    if x + w > screenW then
        x = mx - w - offset
    end
    if y + h > screenH then
        y = my - h - offset
    end

    -- 4. 绘制提示框
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.print(text, x + padding, y + padding)
end
--------------------------------------------------
-- 拖动
--------------------------------------------------
UIGrid.autoSortAfterDrag = false -- 默认为关闭状态

function UIGrid.startDrag(visualIndex, item, items)
    -- 计算当前视图的第一个物品在 items 数组中的索引
    local baseIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset
    -- 视觉槽位 visualIndex 对应的实际数组索引
    local actualIndex = baseIndex + visualIndex - 1

    -- 记录被拖动物品的信息
    UIGrid.draggingItem = {
        visualIndex = visualIndex,      -- 保存视觉槽位索引，用于绘制高亮等
        actualIndex = actualIndex, -- 保存实际数组索引，用于交换
        item = item
    }
end

function UIGrid.endDrag(vx, vy, items)
    if not UIGrid.draggingItem then return end

    local sourceActualIndex = UIGrid.draggingItem.actualIndex
    local targetVisualIndex = UIGrid.getIndexAtPosition(vx, vy)

    if targetVisualIndex then
        -- 计算目标位置的实际数组索引
        local baseIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset
        local targetActualIndex = baseIndex + targetVisualIndex - 1

        -- 确保目标索引在有效范围内
        if targetActualIndex > 0 and targetActualIndex <= #items and sourceActualIndex ~= targetActualIndex then
            -- 交换物品
            local tmp = items[targetActualIndex]
            items[targetActualIndex] = UIGrid.draggingItem.item
            items[sourceActualIndex] = tmp

            -- 如果开启了自动排序，则在拖放后对物品列表进行排序
            if UIGrid.autoSortAfterDrag then
                UIGrid.autoSort(items)
                -- 排序后重置视图，以防当前页为空或物品位置错乱
                UIGrid.page = 1
                UIGrid.scrollOffset = 0
            end
        end
    end

    -- 清理拖动状态
    UIGrid.draggingItem = nil
end

function UIGrid.autoSort(items)
    table.sort(items, function(a, b)
        if not a and not b then return false end
        if not a then return true end
        if not b then return false end

        local defA = ItemManager.get(a.id)
        local defB = ItemManager.get(b.id)

        local nameA = defA and defA.name or ""
        local nameB = defB and defB.name or ""
        return nameA < nameB
    end)
end

--------------------------------------------------
-- 拖动
--------------------------------------------------
function UIGrid.drawDraggingItem(ItemManager)
    if not UIGrid.draggingItem then return end

    local mx, my = love.mouse.getPosition() -- 鼠标位置已经是屏幕坐标
    local item = UIGrid.draggingItem.item

    -- 关键修复：使用 ItemManager.getIcon 来统一获取图标
    local iconImage, iconQuad = ItemManager.getIcon(item.id)

    if iconImage then
        love.graphics.setColor(1, 1, 1, 0.7) -- 设置半透明效果

        local scale, offsetX, offsetY

        if iconQuad then
            -- 如果有 iconQuad，说明是图标集
            local _, _, iconW, iconH = iconQuad:getViewport()
            -- 定义拖动图标的固定大小，例如 64x64
            local DRAG_ICON_SIZE = 64 
            scale = math.min(DRAG_ICON_SIZE / iconW, DRAG_ICON_SIZE / iconH)
            offsetX = (DRAG_ICON_SIZE - iconW * scale) / 2
            offsetY = (DRAG_ICON_SIZE - iconH * scale) / 2
        else
            -- 如果没有 iconQuad，说明是单个图标文件
            local imgW, imgH = iconImage:getWidth(), iconImage:getHeight()
            local DRAG_ICON_SIZE = 64
            scale = math.min(DRAG_ICON_SIZE / imgW, DRAG_ICON_SIZE / imgH)
            offsetX = (DRAG_ICON_SIZE - imgW * scale) / 2
            offsetY = (DRAG_ICON_SIZE - imgH * scale) / 2
        end
        
        -- 关键修复：根据 iconQuad 是否存在来决定如何调用 love.graphics.draw
        if iconQuad then
            love.graphics.draw(iconImage, iconQuad, mx - offsetX, my - offsetY, 0, scale, scale)
        else
            love.graphics.draw(iconImage, mx - offsetX, my - offsetY, 0, scale, scale)
        end
    else
        -- 如果图标不存在，则显示物品名称
        local def = ItemManager.get(item.id)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print(def and def.name or "未知物品", mx, my)
    end

    -- 恢复颜色设置，避免影响后续绘制
    love.graphics.setColor(1, 1, 1, 1)
end
return UIGrid