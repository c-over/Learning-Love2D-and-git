-- IconBrowser.lua
local IconBrowser = {}
local ItemManager = require("ItemManager")
local UIGrid = require("UIGrid")
local Layout = require("layout")

local ids = {}
local hoveredId = nil

function IconBrowser.load()
    ids = ItemManager.getAllIds()

    -- 注册 IconBrowser 的格子配置（不在这里激活）
    UIGrid.config("icon_browser", {
        cols = 10, rows = 6,
        slotSize = 64, margin = 8,
        startX = 20, startY = 20
    })
end

function IconBrowser.wheelmoved(_, y)
    UIGrid.scroll(-y * 3, #ids)
end

function IconBrowser.mousemoved(mx, my)
    hoveredId = nil
    local vx, vy = Layout.toVirtual(mx, my)
    local localIndex = UIGrid.getIndexAtPosition(vx, vy)
    if not localIndex then return end

    local startIndex = (UIGrid.page - 1) * UIGrid.itemsPerPage + 1 + UIGrid.scrollOffset
    local absoluteIndex = startIndex + (localIndex - 1)
    if ids[absoluteIndex] then
        hoveredId = ids[absoluteIndex]
    end
end

local function drawIconSlot(absoluteIndex, x, y, w, h)
    local id = ids[absoluteIndex]
    if not id then return end

    -- [关键修复] 删除 Layout.toScreen 调用
    -- UIGrid 传进来的 x, y 已经是转换好的屏幕坐标，w, h 也是屏幕尺寸
    local sx, sy = x, y 
    
    local img, quad, scale = ItemManager.getIcon(id)
    if not img then return end

    if quad then
        love.graphics.draw(img, quad, sx, sy) -- 如果有缩放问题，这里可能也要调整 scale
    else
        local iw, ih = img:getWidth(), img:getHeight()
        -- 重新计算缩放，确保适配传入的屏幕格子大小 w, h
        local displayScale = math.min(w / iw, h / ih) * 0.8
        
        local offsetX = (w - iw * displayScale) / 2
        local offsetY = (h - ih * displayScale) / 2
        
        love.graphics.draw(img, sx + offsetX, sy + offsetY, 0, displayScale, displayScale)
    end
end

function IconBrowser.update()
end

function IconBrowser.draw(currentScene, targetScene)
    if currentScene ~= "icon_browser" then return end
    UIGrid.useConfig("icon_browser")

    UIGrid.selectedIndex = nil
    UIGrid.hideActionMenu()

    UIGrid.drawAll(drawIconSlot, ids)
    UIGrid.drawScrollbar(#ids)

    if hoveredId then
        local def = ItemManager.get(hoveredId)
        local text = (def and def.name) or ("ID " .. tostring(hoveredId))
        UIGrid.drawTooltip(text)
    end
end

return IconBrowser
