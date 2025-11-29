local Layout = {}

Layout.virtualWidth = 800
Layout.virtualHeight = 600
Layout.scaleX = 1
Layout.scaleY = 1

function Layout.resize(w, h)
    Layout.scaleX = w / Layout.virtualWidth
    Layout.scaleY = h / Layout.virtualHeight
end

-- 将虚拟坐标转换为屏幕坐标
function Layout.toScreen(x, y)
    return x * Layout.scaleX, y * Layout.scaleY
end

-- 将屏幕坐标转换为虚拟坐标（鼠标事件用）
function Layout.toVirtual(x, y)
    return x / Layout.scaleX, y / Layout.scaleY
end

-- 绘制统一布局（位置缩放，大小固定）
function Layout.draw(title, infoLines, buttons, selectedIndex)
    offsetY = offsetY or 0
    local font = love.graphics.getFont()

    -- 标题区
    love.graphics.setColor(1, 1, 1)
    local tx, ty = Layout.toScreen(0, 50 + offsetY)
    love.graphics.printf(title, tx, ty, love.graphics.getWidth(), "center")

    -- 信息区
    local infoY = 120 + offsetY
    for _, line in ipairs(infoLines) do
        local ix, iy = Layout.toScreen(200, infoY)
        love.graphics.print(line, ix, iy)
        infoY = infoY + 40
    end

    -- 按钮区
    for i, btn in ipairs(buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y + offsetY)
        local w, h = btn.w, btn.h  -- 大小保持不变
        if selectedIndex == i then
            love.graphics.setColor(0.2, 0.8, 1) --蓝色
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        local textY = by + (h - font:getHeight()) / 2
        love.graphics.printf(btn.text, bx, textY, w, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function Layout.mousemoved(x, y, buttons)
    x, y = Layout.toVirtual(x, y)
    local index = nil
    for i, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            index = i
        end
    end
    return index
end

function Layout.mousepressed(x, y, button, buttons)
    if button ~= 1 then return nil end
    x, y = Layout.toVirtual(x, y)
    for i, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            if btn.onClick then
                return btn.onClick()
            else
                return i
            end
        end
    end
    return nil
end
-- 绘制描边文字
function DrawOutlinedText(text, x, y, font, textColor, outlineColor)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(font or Fonts.normal)
    
    -- 绘制描边 (上下左右偏移1像素)
    love.graphics.setColor(outlineColor or {0,0,0,1})
    for ox = -1, 1 do
        for oy = -1, 1 do
            if ox ~= 0 or oy ~= 0 then
                love.graphics.print(text, x + ox, y + oy)
            end
        end
    end
    
    -- 绘制本体
    love.graphics.setColor(textColor or {1,1,1,1})
    love.graphics.print(text, x, y)
    
    love.graphics.setFont(oldFont)
end
return Layout
