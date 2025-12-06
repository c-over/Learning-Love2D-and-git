local AssetViewer = {}
local Layout = require("layout")
local UIGrid = require("UIGrid")
local ItemManager = require("ItemManager")
local EffectManager = require("EffectManager") -- [新增] 引用特效管理器

-- === 状态管理 ===
AssetViewer.currentMode = "items" -- items, tiles, anims, fonts, effects
AssetViewer.sidebarWidth = 140

-- === 模式配置 ===
local modes = {
    { key = "icons_source", text = "图标图集 (Source)" },
    { key = "items",        text = "已定义物品" },
    { key = "tiles",        text = "地图素材" },
    { key = "anims",        text = "角色动画" },
    { key = "effects",      text = "特效预览" },
    { key = "fonts",        text = "字体预览" }
}

-- === 子模块状态 ===
local IconSheetState = { img = nil, camX = 0, camY = 0, scale = 1, gridSize = 64, info = "" }
local TileState = { img = nil, camX = 0, camY = 0, scale = 2, tileSize = 16, padding = 1, info = "" }
local ItemState = { ids = {} }
local AnimState = { list = {}, timer = 0 }
-- [重构] 特效预览状态
local EffectState = { 
    keys = {},            -- 特效名称列表
    selectedKey = nil,    -- 当前选中的特效
    previewData = nil,    -- 缓存的数据 (img, quads)
    
    timer = 0,            -- 循环计时器
    currentFrame = 1,     -- 当前帧
    
    -- 颜色控制器 (RGB: 0~1)
    r = 1, g = 1, b = 1,
    
    -- 布局
    listScroll = 0
}
-- === 初始化 ===
function AssetViewer.load()
    -- 1. 加载 Items
    ItemState.ids = ItemManager.getAllIds()
    local winW, winH = Layout.virtualWidth, Layout.virtualHeight
    local gridW = winW - AssetViewer.sidebarWidth - 40
    local startX = AssetViewer.sidebarWidth + 20
    local slotSize = 64
    local cols = math.floor(gridW / (slotSize + 10))
    
    UIGrid.config("asset_items", {
        cols = cols, rows = 6, slotSize = slotSize, margin = 8,
        startX = startX, startY = 60
    })

    -- 2. 加载 Tiles
    if love.filesystem.getInfo("assets/tiles.png") then
        TileState.img = love.graphics.newImage("assets/tiles.png")
        TileState.img:setFilter("nearest", "nearest")
    end

    -- 3. 加载 Icons
    if love.filesystem.getInfo("assets/icon.png") then
        IconSheetState.img = love.graphics.newImage("assets/icon.png")
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

    -- 4. Effects
    EffectManager.load()
    EffectState.keys = EffectManager.getAllKeys()
end
function AssetViewer.selectEffect(key)
    EffectState.selectedKey = key
    EffectState.previewData = EffectManager.getData(key)
    EffectState.timer = 0
    EffectState.currentFrame = 1
    
    -- [新增] 选中时立即播放
    if EffectState.previewData and EffectState.previewData.sfx then
        local d = EffectState.previewData
        d.sfx:stop()
        if d.def.soundStart then d.sfx:seek(d.def.soundStart) end
        d.sfx:play()
    end
end
-- === 更新逻辑 ===
function AssetViewer.update(dt)
    local speed = 300
    if love.keyboard.isDown("lshift") then speed = 800 end

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
        
    -- 特效循环更新
    elseif AssetViewer.currentMode == "effects" then
        local data = EffectState.previewData
        if data then
            EffectState.timer = EffectState.timer + dt
            local frameDuration = data.duration / data.frames
            
            if EffectState.timer >= frameDuration then
                EffectState.timer = EffectState.timer - frameDuration
                EffectState.currentFrame = EffectState.currentFrame + 1
                
                -- [关键修改] 循环播放
                if EffectState.currentFrame > data.frames then
                    EffectState.currentFrame = 1
                    
                    -- [新增] 每一轮循环重新播放音效
                    if data.sfx then
                        data.sfx:stop()
                        if data.def.soundStart then data.sfx:seek(data.def.soundStart) end
                        data.sfx:play()
                    end
                end
            end
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
        if AssetViewer.currentMode == mode.key then love.graphics.setColor(0.2, 0.6, 1, 0.8)
        else love.graphics.setColor(0.3, 0.3, 0.3, 0.5) end
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
    elseif AssetViewer.currentMode == "effects" then AssetViewer.drawEffects()
    end
    
    love.graphics.setScissor()
    
    -- 3. 提示
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("ESC: 返回标题", 10, h - 30)
end

-- --- 子绘制函数 ---

-- 绘制 RGB 滑动条辅助函数
local function drawSlider(label, value, x, y, w)
    local h = 20
    -- 标签
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(label, x, y)
    
    -- 轨道
    local tx = x + 20
    local tw = w - 20
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", tx, y+6, tw, 8, 4)
    
    -- 滑块
    local bx = tx + value * tw
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", bx, y+10, 8)
    
    -- 数值
    love.graphics.print(string.format("%.2f", value), tx + tw + 10, y)
    
    return {x=tx, y=y, w=tw, h=h} -- 返回交互区域
end

-- 特效预览界面
function AssetViewer.drawEffects()
    local startX = AssetViewer.sidebarWidth + 20
    local startY = 60
    local winW = Layout.virtualWidth - AssetViewer.sidebarWidth - 40
    
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.setFont(Fonts.large)
    love.graphics.print("特效调试器", startX, 20)
    
    -- A. 左侧列表
    local listW = 200
    local listH = Layout.virtualHeight - 100
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
    love.graphics.rectangle("fill", startX, startY, listW, listH)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", startX, startY, listW, listH)
    
    local itemH = 35
    love.graphics.setScissor(startX, startY, listW, listH)
    for i, key in ipairs(EffectState.keys) do
        local y = startY + (i-1)*itemH - EffectState.listScroll
        if y + itemH > startY and y < startY + listH then
            if key == EffectState.selectedKey then love.graphics.setColor(0.2, 0.6, 1, 0.6)
            else love.graphics.setColor(0.2, 0.2, 0.2) end
            love.graphics.rectangle("fill", startX+2, y+2, listW-4, itemH-4)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(Fonts.normal)
            love.graphics.print(key, startX+10, y+8)
        end
    end
    love.graphics.setScissor()
    
    -- B. 右侧预览区
    local previewX = startX + listW + 40
    local previewY = startY
    local previewW = 300
    local previewH = 300
    
    -- 绘制棋盘格背景 (Checkerboard) 表示透明
    love.graphics.setScissor(previewX, previewY, previewW, previewH)
    local checkSize = 20
    for cx = 0, previewW, checkSize do
        for cy = 0, previewH, checkSize do
            if (cx/checkSize + cy/checkSize) % 2 == 0 then love.graphics.setColor(0.2, 0.2, 0.2)
            else love.graphics.setColor(0.25, 0.25, 0.25) end
            love.graphics.rectangle("fill", previewX+cx, previewY+cy, checkSize, checkSize)
        end
    end
    love.graphics.setScissor()
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", previewX, previewY, previewW, previewH)
    
    -- 绘制当前特效 (循环播放)
    local data = EffectState.previewData
    if data and data.img then
        local cx = previewX + previewW/2
        local cy = previewY + previewH/2
        local q = data.quads[EffectState.currentFrame]
        if q then
            local _, _, w, h = q:getViewport()
            -- 放大显示
            local scale = 3
            
            -- 混合模式
            local oldBlend = love.graphics.getBlendMode()
            love.graphics.setBlendMode("add")
            
            -- 应用颜色
            love.graphics.setColor(EffectState.r, EffectState.g, EffectState.b, 1)
            
            love.graphics.draw(data.img, q, cx, cy, 0, scale, scale, w/2, h/2)
            
            love.graphics.setBlendMode(oldBlend)
        end
    end
    
    -- C. 颜色控制条 (在预览窗下方)
    local sliderY = previewY + previewH + 20
    local sliderW = previewW
    
    -- 我们只在这里绘制，具体的交互检测在 mousepressed/mousemoved 里
    -- 为了方便，我们记录区域到 State
    EffectState.sliderR = drawSlider("R", EffectState.r, previewX, sliderY, sliderW)
    love.graphics.setColor(EffectState.r, 0, 0); love.graphics.rectangle("fill", previewX+sliderW+50, sliderY+6, 20, 20)
    
    EffectState.sliderG = drawSlider("G", EffectState.g, previewX, sliderY + 30, sliderW)
    love.graphics.setColor(0, EffectState.g, 0); love.graphics.rectangle("fill", previewX+sliderW+50, sliderY+36, 20, 20)
    
    EffectState.sliderB = drawSlider("B", EffectState.b, previewX, sliderY + 60, sliderW)
    love.graphics.setColor(0, 0, EffectState.b); love.graphics.rectangle("fill", previewX+sliderW+50, sliderY+66, 20, 20)
    
    -- 最终合成色展示
    love.graphics.setColor(EffectState.r, EffectState.g, EffectState.b)
    love.graphics.rectangle("fill", previewX+sliderW+50, sliderY+100, 40, 40)
    love.graphics.setColor(1,1,1); love.graphics.rectangle("line", previewX+sliderW+50, sliderY+100, 40, 40)
end
-- 绘制图标源文件
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
    local ts = TileState; if not ts.img then return end
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
    
    -- 1. 特效预览点击
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
    -- 特效交互
    elseif AssetViewer.currentMode == "effects" then
        -- 1. 列表点击
        local listW = 200
        local listH = Layout.virtualHeight - 100
        local startX = AssetViewer.sidebarWidth + 20
        local startY = 60
        local itemH = 35
        
        if x >= startX and x <= startX + listW and y >= startY and y <= startY + listH then
            local idx = math.floor((y - startY + EffectState.listScroll) / itemH) + 1
            local key = EffectState.keys[idx]
            if key then AssetViewer.selectEffect(key) end
        end
        
        -- 2. 滑动条点击 (也支持拖拽)
        local function checkSlider(prop, rect)
            if rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                local val = (x - rect.x) / rect.w
                EffectState[prop] = math.max(0, math.min(val, 1))
            end
        end
        checkSlider("r", EffectState.sliderR)
        checkSlider("g", EffectState.sliderG)
        checkSlider("b", EffectState.sliderB)
    
    
    -- 2. 图标点击 (Source)
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
    -- 3. 物品点击 (Items)
    elseif AssetViewer.currentMode == "items" then
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
    elseif AssetViewer.currentMode == "effects" then
        -- 滚动列表
        EffectState.listScroll = math.max(0, EffectState.listScroll - y * 30)
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
    elseif AssetViewer.currentMode == "effects" and love.mouse.isDown(1) then
        local function updateSlider(prop, rect)
            if rect and x >= rect.x - 20 and x <= rect.x + rect.w + 20 and y >= rect.y - 10 and y <= rect.y + rect.h + 10 then
                local val = (x - rect.x) / rect.w
                EffectState[prop] = math.max(0, math.min(val, 1))
            end
        end
        updateSlider("r", EffectState.sliderR)
        updateSlider("g", EffectState.sliderG)
        updateSlider("b", EffectState.sliderB)
    end
end

function AssetViewer.mousereleased(x, y, button)
    if AssetViewer.currentMode == "items" then
        UIGrid.releaseScrollbar()
    end
end

return AssetViewer