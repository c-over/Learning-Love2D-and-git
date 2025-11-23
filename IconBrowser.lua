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

    local sx, sy = Layout.toScreen(x, y)
    local img, quad, scale = ItemManager.getIcon(id)
    if not img then return end

    if quad then
        love.graphics.draw(img, quad, sx, sy)
    else
        local iw, ih = img:getWidth(), img:getHeight()
        local offsetX = (w - iw * scale) / 2
        local offsetY = (h - ih * scale) / 2
        love.graphics.draw(img, sx + offsetX, sy + offsetY, 0, scale, scale)
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
