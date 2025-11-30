local IconBrowser = {}
local ItemManager = require("ItemManager")
local UIGrid = require("UIGrid")
local Layout = require("layout")

local ids = {}
local hoveredId = nil

-- === 1. 初始化 ===
function IconBrowser.load()
    ids = ItemManager.getAllIds()

    -- [优化] 配置居中的 Grid，避开左上角 Debug 信息
    -- 虚拟分辨率 800x600
    local winW, winH = Layout.virtualWidth, Layout.virtualHeight
    local gridW = 640 -- 10列 * 64
    local startX = (winW - gridW) / 2
    
    UIGrid.config("icon_browser", {
        cols = 9, 
        rows = 6,
        slotSize = 64, 
        margin = 8,
        startX = startX, -- 水平居中
        startY = 100     -- [修复] 下移 100 像素，避开 Debug 信息
    })
end

-- === 2. 辅助渲染函数 ===
local function drawIconSlot(absoluteIndex, x, y, w, h, state)
    local id = ids[absoluteIndex]
    if not id then return end

    -- 1. 绘制背景/高亮
    if state.hovered then
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", x, y, w, h)
    end

    -- 2. [修复] 绘制图标 (强制重置颜色为白色)
    love.graphics.setColor(1, 1, 1, 1) 
    
    local img, quad = ItemManager.getIcon(id)
    if img then
        local iw, ih
        if quad then 
            _, _, iw, ih = quad:getViewport() 
        else 
            iw, ih = img:getWidth(), img:getHeight() 
        end
        
        -- 动态缩放适应格子 (64x64)
        local scale = math.min(w/iw, h/ih) * 0.8
        local dx = x + (w - iw * scale) / 2
        local dy = y + (h - ih * scale) / 2

        if quad then
            love.graphics.draw(img, quad, dx, dy, 0, scale, scale)
        else
            love.graphics.draw(img, dx, dy, 0, scale, scale)
        end
    end

    -- 3. 绘制 ID (方便查找)
    love.graphics.setFont(Fonts.small or love.graphics.getFont())
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(tostring(id), x + 2, y + h - 14)
end

-- === 3. 更新与绘制 ===
function IconBrowser.update(dt)
    -- 可以在这里处理简单的逻辑
end

function IconBrowser.draw(currentScene)
    if currentScene ~= "icon_browser" then return end
    
    -- 强制应用配置
    UIGrid.useConfig("icon_browser")

    -- 1. 绘制面板背景 (美化)
    local vX, vY = 40, 60
    local vW, vH = Layout.virtualWidth - 80, Layout.virtualHeight - 120
    local sX, sY = Layout.toScreen(vX, vY)
    local sW, sH = Layout.toScreen(vW, vH)

    love.graphics.setColor(0.1, 0.1, 0.12, 0.95)
    love.graphics.rectangle("fill", sX, sY, sW, sH, 8, 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sX, sY, sW, sH, 8, 8)
    love.graphics.setLineWidth(1)

    -- 2. 标题
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.setFont(Fonts.large or love.graphics.getFont())
    love.graphics.print("图标浏览器 (点击复制 ID)", sX + 20, sY + 10)

    -- 3. 绘制网格
    UIGrid.drawAll(drawIconSlot, ids, UIGrid.hoveredSlotIndex)
    UIGrid.drawScrollbar(#ids)

    -- 4. Tooltip
    if UIGrid.hoveredSlotIndex then
        -- 计算实际数据索引
        local idx = math.floor(UIGrid.scrollOffset) + UIGrid.hoveredSlotIndex
        local id = ids[idx]
        if id then
            local def = ItemManager.get(id)
            local text = string.format("ID: %d\nName: %s\nIndex: %s", 
                id, 
                def.name or "未命名", 
                tostring(def.iconIndex or "N/A")
            )
            UIGrid.drawTooltip(text)
        end
    end
    
    -- 5. 绘制返回提示
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setFont(Fonts.normal or love.graphics.getFont())
    love.graphics.print("按 ESC 返回", sX + 20, sY + sH - 30)
end

-- === 4. 输入处理 ===

-- [修复] 确保在处理任何输入前，UIGrid 配置已激活
local function activate()
    UIGrid.useConfig("icon_browser")
end

function IconBrowser.wheelmoved(x, y)
    activate()
    UIGrid.scroll(-y, #ids)
end

function IconBrowser.mousemoved(x, y)
    activate() -- [关键修复] 防止 page 为 nil
    local vx, vy = Layout.toVirtual(x, y)
    
    if UIGrid.scrollbar.isDragging then
        UIGrid.updateScrollbarDrag(vx, vy, #ids)
    else
        UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(vx, vy)
    end
end

function IconBrowser.mousepressed(x, y, button)
    activate()
    local vx, vy = Layout.toVirtual(x, y)

    -- 滚动条点击
    if button == 1 then
        if UIGrid.checkScrollbarPress(vx, vy, #ids) then return end
    end

    -- 图标点击 (复制 ID)
    local visualIndex = UIGrid.getIndexAtPosition(vx, vy)
    if visualIndex and button == 1 then
        local idx = math.floor(UIGrid.scrollOffset) + visualIndex
        local id = ids[idx]
        if id then
            -- 复制到剪贴板
            love.system.setClipboardText(tostring(id))
            print("Copied ID to clipboard: " .. tostring(id))
            
            -- 可选：飘字提示
            if require("game_ui").addFloatText then
                -- 转换回屏幕坐标显示提示
                local sx, sy = Layout.toScreen(vx, vy)
                -- 这里需要传入相对于游戏世界的坐标，或者修改 game_ui 支持屏幕坐标飘字
                -- 简单起见，仅控制台打印
            end
        end
    end
end

function IconBrowser.mousereleased(x, y, button)
    if button == 1 then
        UIGrid.releaseScrollbar()
    end
end

return IconBrowser