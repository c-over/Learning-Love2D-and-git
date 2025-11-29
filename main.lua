-- 1. 解决控制台输出延迟/不换行的问题
-- 关闭标准输出缓冲，让 print 立即显示
io.stdout:setvbuf("no")

-- 2. 解决 Windows 控制台中文乱码问题
-- 如果是 Windows 系统，强制将控制台代码页切换为 65001 (UTF-8)
if love.system.getOS() == "Windows" then
    os.execute("chcp 65001 >nul")
end
local Title = require("title")
local Game = require("game")
local Layout = require("layout")
local Player = require("player")
local Battle = require("battle")
local ShopUI = require("shop_ui")
local Settings = require("settings")
local Debug = require("debug_utils")
local Inventory = require("inventory")
local IconBrowser = require("IconBrowser")
local InventoryUI = require("inventory_ui")

Fonts = {}

function love.load()
    -- 全局初始化
    -- 统一配置字体路径
    local fontPath = "assets/simhei.ttf" 

    -- 初始化不同大小的字体对象
    -- 建议用语义化的名字，而不是 size14, size20
    Fonts.small   = love.graphics.newFont(fontPath, 12) -- 用于库存数量、角标
    Fonts.normal  = love.graphics.newFont(fontPath, 16) -- 用于正文、列表
    Fonts.medium  = love.graphics.newFont(fontPath, 20) -- 用于小标题、按钮
    Fonts.large   = love.graphics.newFont(fontPath, 24) -- 用于大标题、伤害数字
    Fonts.title   = love.graphics.newFont(fontPath, 32) -- 用于界面主标题
    love.graphics.setFont(Fonts.large)
    IconBrowser.load("assets/icon.png") -- 加载图标素材

    Layout.resize(love.graphics.getWidth(), love.graphics.getHeight()) 

    coinSound = love.audio.newSource("assets/sounds/coin.wav", "static")
    bgMusic = love.audio.newSource("assets/sounds/title.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
    Settings.init(bgMusic)

    debugMode = false  -- 初始关闭
    Player.load()   -- 从存档读取数据
    Inventory.load()
    Game.load()

    local ItemManager = require("ItemManager")
    ItemManager.preloadAll() -- [新增] 强制预加载所有图标

    currentScene = "title"
    Title.load()
end

function love.update(dt)
    if currentScene == "title" then
        Title.update(dt)
    elseif currentScene == "game" then
        Game.update(dt)
    elseif currentScene == "battle" then
        Battle.update(dt)
    elseif currentScene == "icon_browser" then
        IconBrowser.update(dt)
    end 
end

function love.draw()  
    if currentScene == "title" then
        Title.draw()
    elseif currentScene == "game" then
        Game.draw()
    elseif currentScene == "settings" then
        Settings.draw()
    elseif currentScene == "player" then
        Player.draw()
    elseif currentScene == "inventory" then
        InventoryUI.draw()
    elseif currentScene == "icon_browser" then
        IconBrowser.draw(currentScene, "icon_browser")
    elseif currentScene == "battle" then
        Battle.draw()
    elseif currentScene == "shop" then
        ShopUI.draw()
    end
    if debugMode then
        local Debug = require("debug_utils")
        
        if currentScene == "game" then
            local w, h = love.graphics.getDimensions()
            -- 获取摄像机位置 (假设 Game.player 存在)
            local camX = Game.player.x - w/2
            local camY = Game.player.y - h/2
            
            -- [新增] 绘制地图阻挡格 (红色)
            -- 这会直接显示 Core.isSolidTile 为真的格子，绝对准确
            Debug.drawMapGrid(camX, camY, Game.tileSize or 32, w, h)
            
            -- 绘制实体碰撞箱 (绿色)
            Debug.drawEntityHitbox(Game.player, camX, camY)
            -- 如果有怪物列表，也可以遍历绘制:
            -- local Monster = require("monster")
            -- for _, m in ipairs(Monster.list) do Debug.drawEntityHitbox(m, camX, camY) end
        end

        -- 绘制 UI 面板 (信息 + 按钮 + 日志)
        -- 传入 player 数据和 timer
        local pData = (currentScene == "game" or currentScene == "player") and Player.data or nil
        Debug.drawInfo(pData, love.timer.getTime())
    end
end

function love.resize(w, h)
    Layout.resize(w, h)
    
    -- [可选] 如果菜单按钮是根据 Layout.virtualHeight 创建的，
    -- 这里不需要重新创建，因为 virtualHeight 没变，Layout.draw 会自动处理缩放。
    -- 但如果你的 UI 依赖实时屏幕宽高，这里需要触发刷新。
    print("Window resized to: " .. w .. "x" .. h)
end

function love.keypressed(key)
    if key == "f3" then
        debugMode = not debugMode  -- 按下 F3 切换调试模式
    end
    if currentScene == "title" then
        Title.keypressed(key)
    elseif currentScene == "game" then
        Game.keypressed(key)
    elseif currentScene == "settings" then
        Settings.keypressed(key)
    elseif currentScene == "inventory" then
        InventoryUI.keypressed(key)
    elseif currentScene == "icon_browser" and key == "escape" then
        currentScene = InventoryUI.previousScene or "inventory"
    elseif currentScene == "battle" then
        Battle.keypressed(key)
    elseif currentScene == "shop" then
        ShopUI.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    -- 优先处理 Debug 点击
    local Debug = require("debug_utils")
    if debugMode and Debug.mousepressed(x, y, button) then
        return -- 如果调试按钮被点击，直接返回，不执行下面的逻辑
    end
    if currentScene == "title" then
        local result = Title.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "game" then
        local result = Game.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "settings" then
        local result = Settings.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "player" then
        local result = Player.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "inventory" then
        local result = InventoryUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "battle" then
        local result = Battle.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "shop" then
        local result = ShopUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if currentScene == "title" then
        Title.mousemoved(x,y)
    elseif currentScene == "game" then
        Game.mousemoved(x,y)
    elseif currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "battle" then
        Battle.mousemoved(x, y)
    elseif currentScene == "settings" then
        Settings.mousemoved(x, y)
    elseif currentScene == "inventory" then
        InventoryUI.mousemoved(x, y)
    elseif currentScene == "icon_browser" then
        IconBrowser.mousemoved(x, y)
    elseif currentScene == "shop" then
        ShopUI.mousemoved(x, y)
    end
end

function love.mousereleased(x, y, button)
    -- 转发给 InventoryUI
    if currentScene == "inventory" then
        InventoryUI.mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
    if currentScene == "icon_browser" then
        IconBrowser.wheelmoved(x, y)
    end
end

function love.quit()
    print("正在退出... 保存游戏数据")
    local Config = require("config")
    Config.save()
    return false -- 返回 false 允许退出
end