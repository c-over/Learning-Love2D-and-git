-- GridLayout.lua
local Layout = require("layout")

local GridLayout = {}

-- 初始化配置（不同界面可调用一次）
function GridLayout.config(opts)
    GridLayout.cols     = opts.cols or 5
    GridLayout.rows     = opts.rows or 4
    GridLayout.slotSize = opts.slotSize or 64
    GridLayout.margin   = opts.margin or 10
    GridLayout.startX   = opts.startX or 100
    GridLayout.startY   = opts.startY or 100
end

-- 根据索引获取格子矩形（虚拟坐标）
function GridLayout.getSlotRect(index)
    local col = (index-1) % GridLayout.cols
    local row = math.floor((index-1) / GridLayout.cols)
    local x = GridLayout.startX + col * (GridLayout.slotSize + GridLayout.margin)
    local y = GridLayout.startY + row * (GridLayout.slotSize + GridLayout.margin)
    return x, y, GridLayout.slotSize, GridLayout.slotSize
end

-- 获取格子中心点（虚拟坐标）
function GridLayout.getSlotCenter(index)
    local x, y, w, h = GridLayout.getSlotRect(index)
    return x + w/2, y + h/2
end

-- 根据虚拟坐标返回格子索引
function GridLayout.getIndexAtPosition(vx, vy)
    for i = 1, GridLayout.cols * GridLayout.rows do
        local x, y, w, h = GridLayout.getSlotRect(i)
        if vx >= x and vx <= x+w and vy >= y and vy <= y+h then
            return i
        end
    end
    return nil
end

-- 绘制调试格子边框
function GridLayout.drawDebug()
    for i = 1, GridLayout.cols * GridLayout.rows do
        local x, y, w, h = GridLayout.getSlotRect(i)
        local sx, sy = Layout.toScreen(x, y)
        love.graphics.setColor(0,1,0,0.3)
        love.graphics.rectangle("line", sx, sy, w*Layout.scaleX, h*Layout.scaleY)
    end
    love.graphics.setColor(1,1,1,1)
end

return GridLayout
