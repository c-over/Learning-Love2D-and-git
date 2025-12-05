local AssetViewer = {}
local Layout = require("layout")
local UIGrid = require("UIGrid")
local ItemManager = require("ItemManager")

-- === 状态管理 ===
AssetViewer.currentMode = "icons_source" -- 默认打开新功能方便调试
AssetViewer.sidebarWidth = 140 -- 稍微加宽一点

-- === 模式配置 ===
local modes = {
    { key = "icons_source", text = "图标图集 (Source)" }, -- [新增]
    { key = "items",        text = "已定义物品" },
    { key = "tiles",        text = "地图素材" },
    { key = "anims",        text = "角色动画" },
    { key = "fonts",        text = "字体预览" }
}

-- === 子模块状态 ===

-- 1. [新增] 图标源文件查看状态
local IconSheetState = {
    img = nil,
    camX = 0, camY = 0,
    scale = 1,
    gridSize = 64, -- [关键] 这里设定为 64
    info = ""
}

-- 2. TileSelector 状态
local TileState = {
    img = nil,
    camX = 0, camY = 0,
    scale = 2,
    tileSize = 16, padding = 1,
    info = ""
}

-- 3. Items 状态
local ItemState = { ids = {} }

-- 4. Animation 状态
local AnimState = { list = {}, timer = 0 }

-- === 初始化 ===
function AssetViewer.load()
    -- 1. 加载 Items 数据
    ItemState.ids = ItemManager.getAllIds()
    
    local winW, winH = Layout.virtualWidth, Layout.virtualHeight
    local gridW = winW - AssetViewer.sidebarWidth - 40
    local startX = AssetViewer.sidebarWidth + 20
    local slotSize = 64
    local cols = math.floor(gridW / (slotSize + 10))
    
    UIGrid.config("asset_items", {
        cols = cols, rows = 6,
        slotSize = slotSize, margin = 8,
        startX = startX, startY = 60
    })

    -- 2. 加载 Tile 数据
    if love.filesystem.getInfo("assets/tiles.png") then
        TileState.img = love.graphics.newImage("assets/tiles.png")
        TileState.img:setFilter("nearest", "nearest")
    end

    -- 3. [新增] 加载 Icon Source 数据
    if love.filesystem.getInfo("assets/icon.png") then
        IconSheetState.img = love.graphics.newImage("assets/icon.png")
        -- 这里不一定要 nearest，看图标风格，通常像素风需要
        IconSheetState.img:setFilter("nearest", "nearest") 
    end

    -- 4. 加载 Animation 数据
    local slimeImg = love.graphics.newImage("assets/monsters/slime.png")
    local playerIdleImg = love.graphics.newImage("assets/Character/Idle.png")
    local playerWalkImg = love.graphics.newImage("assets/Character/Walk.png")
    
    -- [辅助函数] 生成单行动画 Quads
    -- frames: 总帧数
    local function makeRowQuads(img, frames)
        local w, h = img:getWidth() / frames, img:getHeight()
        local qs = {}
        for i=0, frames-1 do table.insert(qs, love.graphics.newQuad(i*w, 0, w, h, img:getDimensions())) end
        return qs, w, h
    end
    
    -- [新增] 生成多方向动画的特定一行 Quads
    -- cols: 列数(帧数), rows: 行数(方向数), targetRow: 取第几行(从1开始)
    local function makeGridQuads(img, cols, rows, targetRow)
        local w, h = img:getWidth() / cols, img:getHeight() / rows
        local qs = {}
        -- targetRow 转为 0-based索引
        local r = targetRow - 1
        for c=0, cols-1 do
            table.insert(qs, love.graphics.newQuad(c*w, r*h, w, h, img:getDimensions()))
        end
        return qs, w, h
    end
    
    -- 配置动画列表
    -- 假设 Player 图片结构：3行 (下, 上, 右)，每行 4 帧
    -- 这里的参数根据你的实际素材调整：cols=4, rows=3
    AnimState.list = {
        -- 史莱姆 (单行，8帧)
        { 
            name = "史莱姆", 
            img = slimeImg, 
            quads = select(1, makeRowQuads(slimeImg, 8)), 
            w = 32, h = 32, frame = 1, max = 8, speed = 0.2 
        },
        -- 玩家 Idle (取第1行：正面)
        { 
            name = "玩家待机(正)", 
            img = playerIdleImg, 
            quads = select(1, makeGridQuads(playerIdleImg, 4, 3, 1)), -- 4列3行，取第1行
            w = 32, h = 32, frame = 1, max = 4, speed = 0.2 
        },
        -- 玩家 Walk (取第3行：侧面)
        { 
            name = "玩家行走(侧)", 
            img = playerWalkImg, 
            quads = select(1, makeGridQuads(playerWalkImg, 6, 3, 3)), -- 6列3行，取第3行
            w = 32, h = 32, frame = 1, max = 6, speed = 0.15 
        }
    }
end

-- === 更新逻辑 ===
function AssetViewer.update(dt)
    local speed = 300
    if love.keyboard.isDown("lshift") then speed = 800 end

    -- 通用摄像机控制 (针对 tiles 和 icons_source)
    if AssetViewer.currentMode == "tiles" then
        if love.keyboard.isDown("w", "up") then TileState.camY = TileState.camY - speed * dt end
        if love.keyboard.isDown("s", "down") then TileState.camY = TileState.camY + speed * dt end
        if love.keyboard.isDown("a", "left") then TileState.camX = TileState.camX - speed * dt end
        if love.keyboard.isDown("d", "right") then TileState.camX = TileState.camX + speed * dt end
    
    elseif AssetViewer.currentMode == "icons_source" then
        if love.keyboard.isDown("w", "up") then IconSheetState.camY = IconSheetState.camY - speed * dt end
        if love.keyboard.isDown("s", "down") then IconSheetState.camY = IconSheetState.camY + speed * dt end
        if love.keyboard.isDown("a", "left") then IconSheetState.camX = IconSheetState.camX - speed * dt end
        if love.keyboard.isDown("d", "right") then IconSheetState.camX = IconSheetState.camX + speed * dt end

    elseif AssetViewer.currentMode == "anims" then
        AnimState.timer = AnimState.timer + dt
        for _, anim in ipairs(AnimState.list) do
            local frame = math.floor(AnimState.timer / anim.speed) % anim.max + 1
            anim.frame = frame
        end
    end
end

-- === 绘制逻辑 ===
function AssetViewer.draw()
    local w, h = love.graphics.getDimensions()
    
    -- 1. 左侧边栏
    love.graphics.setColor(0.15, 0.15, 0.18, 1)
    love.graphics.rectangle("fill", 0, 0, AssetViewer.sidebarWidth, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.line(AssetViewer.sidebarWidth, 0, AssetViewer.sidebarWidth, h)
    
    local btnH = 40
    for i, mode in ipairs(modes) do
        local y = 60 + (i-1) * (btnH + 10)
        
        if AssetViewer.currentMode == mode.key then
            love.graphics.setColor(0.2, 0.6, 1, 0.8)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
        end
        love.graphics.rectangle("fill", 10, y, AssetViewer.sidebarWidth - 20, btnH, 5)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Fonts.normal)
        love.graphics.printf(mode.text, 10, y + 10, AssetViewer.sidebarWidth - 20, "center")
    end
    
    -- 2. 右侧内容
    love.graphics.setScissor(AssetViewer.sidebarWidth, 0, w - AssetViewer.sidebarWidth, h)
    
    if AssetViewer.currentMode == "items" then AssetViewer.drawItems()
    elseif AssetViewer.currentMode == "tiles" then AssetViewer.drawTiles()
    elseif AssetViewer.currentMode == "icons_source" then AssetViewer.drawIconSheet()
    elseif AssetViewer.currentMode == "anims" then AssetViewer.drawAnims()
    elseif AssetViewer.currentMode == "fonts" then AssetViewer.drawFonts()
    end
    
    love.graphics.setScissor()
    
    -- 3. 提示
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("ESC: 返回标题", 10, h - 30)
end

-- --- 子绘制函数 ---

-- [新增] 绘制图标源文件
function AssetViewer.drawIconSheet()
    local ts = IconSheetState
    if not ts.img then 
        love.graphics.print("assets/icon.png not found", 200, 200) 
        return 
    end
    
    love.graphics.push()
    love.graphics.translate(AssetViewer.sidebarWidth, 0)
    love.graphics.translate(-ts.camX, -ts.camY)
    
    -- 绘制大图
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(ts.img, 0, 0, 0, ts.scale, ts.scale)
    
    -- 计算交互
    local iw, ih = ts.img:getDimensions()
    local unit = ts.gridSize * ts.scale
    
    local mx, my = love.mouse.getPosition()
    local worldX = mx - AssetViewer.sidebarWidth + ts.camX
    local worldY = my + ts.camY
    
    local col = math.floor(worldX / unit)
    local row = math.floor(worldY / unit)
    
    -- 计算 Index
    local colsInSheet = math.floor(iw / ts.gridSize)
    local index = -1
    
    if col >= 0 and row >= 0 and col < colsInSheet then
        index = row * colsInSheet + col
        -- 绘制选中框
        love.graphics.setColor(0, 1, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", col*unit, row*unit, unit, unit)
        ts.info = string.format("Index: %d (Row:%d, Col:%d)", index, row, col)
    else
        ts.info = "Mouse out of bounds"
    end
    
    love.graphics.pop()
    
    -- UI 信息
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", AssetViewer.sidebarWidth, 0, 300, 90)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.medium)
    love.graphics.print("图标查找器 (64x64)", AssetViewer.sidebarWidth + 10, 10)
    love.graphics.setFont(Fonts.normal)
    love.graphics.print(ts.info, AssetViewer.sidebarWidth + 10, 40)
    love.graphics.print("点击复制 Index 到剪贴板", AssetViewer.sidebarWidth + 10, 65)
end

-- 物品模式
function AssetViewer.drawItems()
    UIGrid.useConfig("asset_items")
    UIGrid.drawAll(function(idx, x, y, w, h, state)
        local id = ItemState.ids[idx]
        if not id then return end
        
        if state.hovered then
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("fill", x, y, w, h)
        end
        
        local img, quad = ItemManager.getIcon(id)
        if img then
            love.graphics.setColor(1, 1, 1)
            local iw, ih
            if quad then _,_,iw,ih = quad:getViewport() else iw,ih = img:getWidth(), img:getHeight() end
            local s = math.min(w/iw, h/ih) * 0.8
            local dx = x + (w - iw*s)/2
            local dy = y + (h - ih*s)/2
            if quad then love.graphics.draw(img, quad, dx, dy, 0, s, s)
            else love.graphics.draw(img, dx, dy, 0, s, s) end
        end
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.print(id, x+2, y+2)
    end, ItemState.ids, UIGrid.hoveredSlotIndex)
    
    UIGrid.drawScrollbar(#ItemState.ids)
    
    if UIGrid.hoveredSlotIndex then
        local idx = math.floor(UIGrid.scrollOffset) + UIGrid.hoveredSlotIndex
        local id = ItemState.ids[idx]
        if id then
            local def = ItemManager.get(id)
            UIGrid.drawTooltip(string.format("ID: %d\nName: %s", id, def.name))
        end
    end
end

-- B. 地图模式
function AssetViewer.drawTiles()
    local ts = TileState
    if not ts.img then return end
    
    love.graphics.push()
    love.graphics.translate(AssetViewer.sidebarWidth, 0)
    love.graphics.translate(-ts.camX, -ts.camY)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(ts.img, 0, 0, 0, ts.scale, ts.scale)
    
    local unit = (ts.tileSize + ts.padding) * ts.scale
    local mx, my = love.mouse.getPosition()
    local worldX = mx - AssetViewer.sidebarWidth + ts.camX
    local worldY = my + ts.camY
    local col = math.floor(worldX / unit)
    local row = math.floor(worldY / unit)
    
    if col >= 0 and row >= 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", col*unit, row*unit, ts.tileSize*ts.scale, ts.tileSize*ts.scale)
        ts.info = string.format("Tile: x=%d, y=%d", col, row)
    end
    
    love.graphics.pop()
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", AssetViewer.sidebarWidth, 0, 300, 60)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(ts.info, AssetViewer.sidebarWidth + 10, 20)
end

-- C. 动画模式
function AssetViewer.drawAnims()
    local startX = AssetViewer.sidebarWidth + 50
    local startY = 100
    local gapX = 150
    
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.setFont(Fonts.large)
    love.graphics.print("角色动画预览", startX, 20)
    
    for i, anim in ipairs(AnimState.list) do
        local x = startX + (i-1) * gapX
        local y = startY
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", x, y, 100, 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, 100, 100)
        
        if anim.img and anim.quads then
            local q = anim.quads[anim.frame]
            -- 放大2倍显示
            love.graphics.draw(anim.img, q, x + 50, y + 50, 0, 2, 2, anim.w/2, anim.h/2)
        end
        
        -- 标签
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(anim.name, x, y + 110, 100, "center")
        love.graphics.printf("Frame: "..anim.frame, x, y + 130, 100, "center")
    end
end

function AssetViewer.drawFonts()
    local x = AssetViewer.sidebarWidth + 40
    local y = 40
    local sample = "Hello World! 你好世界 12345"
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Fonts.small); love.graphics.print("Small: " .. sample, x, y); y=y+40
    love.graphics.setFont(Fonts.normal); love.graphics.print("Normal: " .. sample, x, y); y=y+40
    love.graphics.setFont(Fonts.medium); love.graphics.print("Medium: " .. sample, x, y); y=y+50
    love.graphics.setFont(Fonts.large); love.graphics.print("Large: " .. sample, x, y); y=y+60
    love.graphics.setFont(Fonts.title); love.graphics.print("Title: " .. sample, x, y); y=y+70
end

-- === 输入事件 ===
function AssetViewer.mousepressed(x, y, button)
    if x < AssetViewer.sidebarWidth then
        local btnH = 40
        for i, mode in ipairs(modes) do
            local by = 60 + (i-1) * (btnH + 10)
            if y >= by and y <= by + btnH then
                AssetViewer.currentMode = mode.key
                UIGrid.scrollOffset = 0
                return
            end
        end
    end
    
    if AssetViewer.currentMode == "items" then
        if button == 1 then
            local vx, vy = Layout.toVirtual(x, y)
            if UIGrid.checkScrollbarPress(vx, vy, #ItemState.ids) then return end
            local idx = UIGrid.getIndexAtPosition(vx, vy)
            if idx then
                local realIdx = math.floor(UIGrid.scrollOffset) + idx
                local id = ItemState.ids[realIdx]
                if id then
                    love.system.setClipboardText(tostring(id))
                    print("Copied Item ID: " .. id)
                end
            end
        end
    
    -- [新增] 图标源文件点击
    elseif AssetViewer.currentMode == "icons_source" then
        if button == 1 then
            local ts = IconSheetState
            local mx, my = love.mouse.getPosition()
            local worldX = mx - AssetViewer.sidebarWidth + ts.camX
            local worldY = my + ts.camY
            local unit = ts.gridSize * ts.scale
            
            local col = math.floor(worldX / unit)
            local row = math.floor(worldY / unit)
            local colsInSheet = math.floor(ts.img:getWidth() / ts.gridSize)
            
            if col >= 0 and row >= 0 then
                local index = row * colsInSheet + col
                love.system.setClipboardText(tostring(index))
                print("Copied Icon Index: " .. index)
            end
        end
        
    elseif AssetViewer.currentMode == "tiles" then
        if button == 1 then
            local ts = TileState
            local mx, my = love.mouse.getPosition()
            local worldX = mx - AssetViewer.sidebarWidth + ts.camX
            local worldY = my + ts.camY
            local unit = (ts.tileSize + ts.padding) * ts.scale
            local col = math.floor(worldX / unit)
            local row = math.floor(worldY / unit)
            if col >= 0 and row >= 0 then
                local code = string.format("{ x=%d, y=%d },", col, row)
                love.system.setClipboardText(code)
                print("Copied Tile: " .. code)
            end
        end
    end
end

function AssetViewer.wheelmoved(x, y)
    if AssetViewer.currentMode == "items" then
        UIGrid.useConfig("asset_items")
        UIGrid.scroll(-y, #ItemState.ids)
    elseif AssetViewer.currentMode == "tiles" then
        local ts = TileState
        if y > 0 then ts.scale = math.min(10, ts.scale + 1)
        elseif y < 0 then ts.scale = math.max(1, ts.scale - 1) end
    elseif AssetViewer.currentMode == "icons_source" then
        local ts = IconSheetState
        if y > 0 then ts.scale = math.min(5, ts.scale + 0.2)
        elseif y < 0 then ts.scale = math.max(0.2, ts.scale - 0.2) end
    end
end

function AssetViewer.mousemoved(x, y, dx, dy)
    if AssetViewer.currentMode == "items" then
        UIGrid.useConfig("asset_items")
        if UIGrid.scrollbar.isDragging then
            UIGrid.updateScrollbarDrag(Layout.toVirtual(x, y), #ItemState.ids)
        else
            UIGrid.hoveredSlotIndex = UIGrid.getIndexAtPosition(Layout.toVirtual(x, y))
        end
    end
end

function AssetViewer.mousereleased(x, y, button)
    if AssetViewer.currentMode == "items" then
        UIGrid.releaseScrollbar()
    end
end

return AssetViewer