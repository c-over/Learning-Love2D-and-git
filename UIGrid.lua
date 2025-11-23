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
end

function UIGrid.useConfig(name)
    UIGrid.activeConfig = UIGrid.configs[name]
    UIGrid.slotStates = {}
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
function UIGrid.drawAll(drawFunc, items)
    local c = cfg()
    local startIndex = (UIGrid.page-1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset
    local endIndex = math.min(startIndex + UIGrid.itemsPerPage - 1, #items)

    local slotIndex = 1
    for i = startIndex, endIndex do
        local x, y, w, h = UIGrid.getSlotRect(slotIndex)
        drawFunc(i, x, y, w, h, UIGrid.getSlotState(slotIndex))
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
        h = 30,
        options = options
    }
    UIGrid.selectedIndex = index
end

function UIGrid.hideActionMenu()
    UIGrid.actionMenu = nil
end

function UIGrid.drawActionMenu()
    if not UIGrid.actionMenu then return end
    for i,opt in ipairs(UIGrid.actionMenu.options) do
        local bx, by = Layout.toScreen(
            UIGrid.actionMenu.x,
            UIGrid.actionMenu.y + (i-1)*UIGrid.actionMenu.h
        )
        love.graphics.setColor(0.2,0.2,0.2)
        love.graphics.rectangle("fill", bx, by, UIGrid.actionMenu.w, UIGrid.actionMenu.h)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("line", bx, by, UIGrid.actionMenu.w, UIGrid.actionMenu.h)
        love.graphics.printf(opt.text, bx, by+5, UIGrid.actionMenu.w, "center")
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
    if not text then return end
    local mx,my = love.mouse.getPosition()
    local padding = 8
    local font = love.graphics.getFont()
    local w = font:getWidth(text) + padding*2
    local h = font:getHeight() + padding*2
    love.graphics.setColor(0,0,0,0.7)
    love.graphics.rectangle("fill", mx, my, w, h)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", mx, my, w, h)
    love.graphics.print(text, mx+padding, my+padding)
end

--------------------------------------------------
-- 拖动
--------------------------------------------------
function UIGrid.startDrag(index, item, mx, my)
    UIGrid.draggingItem = {index=index, item=item, offsetX=mx, offsetY=my}
end

function UIGrid.endDrag(vx, vy, items)
    if not UIGrid.draggingItem then return end
    local targetIndex = UIGrid.getIndexAtPosition(vx, vy)
    if targetIndex and targetIndex ~= UIGrid.draggingItem.index then
        local tmp = items[targetIndex]
        items[targetIndex] = UIGrid.draggingItem.item
        items[UIGrid.draggingItem.index] = tmp
    end
    UIGrid.draggingItem = nil
end

function UIGrid.drawDraggingItem(ItemManager)
    if not UIGrid.draggingItem then return end
    local mx, my = love.mouse.getPosition()
    local def = ItemManager.get(UIGrid.draggingItem.item.id)
    if def and def.icon then
        def._image = def._image or love.graphics.newImage(def.icon)
        local img = def._image
        love.graphics.setColor(1,1,1,0.7)
        love.graphics.draw(img, mx-24, my-24, 0, 0.75, 0.75)
    else
        love.graphics.setColor(1,1,1,0.7)
        love.graphics.print(def and def.name or "未知物品", mx, my)
    end
end

return UIGrid
