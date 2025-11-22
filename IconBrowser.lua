-- IconBrowser.lua
local IconBrowser = {}
local ItemManager = require("ItemManager")

local ICON = 64
local PADDING = 8
local COLS = 10
local scrollY = 0
local maxScroll = 0
local hoveredId = nil

function IconBrowser.load()
    local ids = ItemManager.getAllIds()
    local totalItems = #ids
    local totalRows = math.ceil(totalItems / COLS)
    -- 20 顶部留白，底部不强制留白
    maxScroll = math.max(0, totalRows * (ICON + PADDING) - love.graphics.getHeight() + 20)
end

function IconBrowser.wheelmoved(_, y)
    scrollY = scrollY - y * 30
    scrollY = math.max(0, math.min(scrollY, maxScroll))
end

function IconBrowser.mousemoved(mx, my)
    hoveredId = nil

    local startX = 20
    local startY = 20 - scrollY
    local ids = ItemManager.getAllIds()

    -- 用“有序 ids 数组”遍历，保证格子布局与 draw 一致
    for i = 1, #ids do
        local id = ids[i]
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local gx = startX + col * (ICON + PADDING)
        local gy = startY + row * (ICON + PADDING)

        if mx > gx and mx < gx + ICON and my > gy and my < gy + ICON then
            hoveredId = id
            break
        end
    end
end

function IconBrowser.update()
    -- 留作扩展
end

function IconBrowser.draw(currentScene, targetScene)
    if currentScene ~= targetScene then return end

    local startX = 20
    local startY = 20 - scrollY
    local ids = ItemManager.getAllIds()

    for i = 1, #ids do
        local id = ids[i]
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local x = startX + col * (ICON + PADDING)
        local y = startY + row * (ICON + PADDING)

        local img, quad, scale = ItemManager.getIcon(id)
        if img then
            if quad then
                love.graphics.draw(img, quad, x, y)
            else
                local iw, ih = img:getWidth(), img:getHeight()
                local offsetX = (ICON - iw * scale) / 2
                local offsetY = (ICON - ih * scale) / 2
                love.graphics.draw(img, x + offsetX, y + offsetY, 0, scale, scale)
            end
        end
    end

    -- 悬停提示
    if hoveredId then
        local def = ItemManager.get(hoveredId)
        if def then
            local mx, my = love.mouse.getPosition()
            local text = def.name or ("ID " .. tostring(hoveredId))
            local pad = 8
            local font = love.graphics.getFont()
            local w = font:getWidth(text) + pad * 2
            local h = font:getHeight() + pad * 2

            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", mx, my, w, h)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("line", mx, my, w, h)
            love.graphics.print(text, mx + pad, my + pad)
        end
    end
end

return IconBrowser
