local Title = require("title")
local Game = require("game")
local Layout = require("layout")
local Player = require("player")
local Battle = require("battle")
local ShopUI = require("shop_ui")
local Crafting = require("Crafting")
local GameOver = require("gameover")
local Settings = require("settings")
local Debug = require("debug_utils")
local Viewer = require("AssetViewer")
local Inventory = require("inventory")
local PauseMenu = require("PauseMenu")
local BattleMenu = require("BattleMenu")
local ItemManager = require("ItemManager")
Fonts = {}
-- === [新增] 转场系统 ===
local Transition = {
    alpha = 1,          -- 当前透明度 (1=全黑, 0=完全透明)
    state = "active",   -- 状态: "active" (正在变动) / "idle" (无事发生)
    duration = 1.5,     -- 渐变时长 (秒)
    timer = 0,
    mode = "fade_in",   -- 模式: "fade_in" (由黑变亮) / "fade_out" (由亮变黑)
    
    -- 方法：开始淡入
    fadeIn = function(self, time)
        self.mode = "fade_in"
        self.alpha = 1    -- 设为全黑
        self.duration = time or 1.0
        self.timer = 0
        self.state = "active"
    end,
    
    -- 方法：更新透明度数值
    update = function(self, dt)
        if self.state == "idle" then return end
        
        self.timer = self.timer + dt
        local progress = math.min(self.timer / self.duration, 1)
        
        if self.mode == "fade_in" then
            self.alpha = 1 - progress -- 1 -> 0 (慢慢变透明，显示出游戏画面)
        else
            self.alpha = progress     -- 0 -> 1 (慢慢变黑)
        end
        
        if progress >= 1 then
            self.state = "idle"
            self.alpha = (self.mode == "fade_in") and 0 or 1
        end
    end,
    
    -- 方法：绘制全屏黑遮罩
    draw = function(self)
        if self.alpha > 0 then
            local w, h = love.graphics.getDimensions()
            love.graphics.setColor(0, 0, 0, self.alpha) -- 黑色 + alpha
            love.graphics.rectangle("fill", 0, 0, w, h) -- 画一个盖住全屏的矩形
            love.graphics.setColor(1, 1, 1, 1) -- 恢复白色，以免影响后续绘制
        end
    end
}
function love.load()
    -- 全局初始化
    love.keyboard.setTextInput(false) 
    -- 统一配置字体路径
    local fontPath = "assets/simhei.ttf" 

    -- 初始化不同大小的字体对象
    -- 建议用语义化的名字，而不是 size14, size20
    Fonts.small   = love.graphics.newFont(fontPath, 14) -- 用于库存数量、角标
    Fonts.normal  = love.graphics.newFont(fontPath, 18) -- 用于正文、列表
    Fonts.medium  = love.graphics.newFont(fontPath, 20) -- 用于小标题、按钮
    Fonts.large   = love.graphics.newFont(fontPath, 24) -- 用于大标题、伤害数字
    Fonts.title   = love.graphics.newFont(fontPath, 32) -- 用于界面主标题
    love.graphics.setFont(Fonts.large)

    Layout.resize(love.graphics.getWidth(), love.graphics.getHeight()) 

    coinSound = love.audio.newSource("assets/sounds/coin.wav", "static")
    bgMusic = love.audio.newSource("assets/sounds/title.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:play()
    Settings.init(bgMusic)
    bossMusic = love.audio.newSource("assets/sounds/FinalBattle.mp3", "stream")
    bossMusic:setLooping(true) -- 循环播放
    bossMusic:setVolume(1.0)   -- 音量拉满

    debugMode = false  -- 初始关闭
    Player.load()   -- 从存档读取数据
    Inventory.load()
    Game.load()
    GameOver.load()
    PauseMenu.load()
    Crafting.load()
    ItemManager.preloadAll() -- 强制预加载所有图标

    currentScene = "title"
    Title.load()
end

function love.update(dt)
    -- 1. 启动阶段 (Boot) - 阻塞加载时不更新逻辑
    if currentScene == "boot" then
        loadGameContent() -- 执行资源加载
        currentScene = "title"
        Transition:fadeIn(1.5)
        return
    end

    -- 2. 全局系统更新
    Transition:update(dt)

    -- [关键修复] 无论在哪个场景，都必须更新 UI 逻辑
    -- 这使得飘字 (Floating Text) 的 y 轴位置和 life 透明度能正常变化
    require("game_ui").update(dt)
    -- 3. 场景更新
    if currentScene == "title" then
        Title.update(dt)
    elseif currentScene == "game" then
        Game.update(dt)
    elseif currentScene == "battle" then
        Battle.update(dt)
    elseif currentScene == "asset_viewer" then
        Viewer.update(dt)
    end 
end

function love.draw()  
    if currentScene == "title" then
        Title.draw()
    elseif currentScene == "game" then
        Game.draw()
    elseif currentScene == "settings" then
        Settings.draw()
    elseif currentScene == "menu" then
        PauseMenu.draw()
    elseif currentScene == "asset_viewer" then
        Viewer.draw()
    elseif currentScene == "battle" then
        Game.draw()
        BattleMenu.draw()
    elseif currentScene == "shop" then
        ShopUI.draw()
    elseif currentScene == "gameover" then
        GameOver.draw()
    end
    if debugMode then
        local Debug = require("debug_utils")
        
        if currentScene == "game" then
            local w, h = love.graphics.getDimensions()
            -- 获取摄像机位置 (假设 Game.player 存在)
            local camX = Game.player.x - w/2
            local camY = Game.player.y - h/2
            
            -- 绘制地图阻挡格 (红色)
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
    -- 3. [关键] 飘字绘制 (必须放在所有场景绘制之后，转场遮罩之前)
    if currentScene ~= "boot" then
        require("game_ui").drawFloatTexts()
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
    elseif currentScene == "menu" then
        if key == "escape" then currentScene = "game" end
    elseif currentScene == "settings" then
        Settings.keypressed(key)
    elseif currentScene == "asset_viewer" then
        if key == "escape" then currentScene = "title" end
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
    elseif currentScene == "menu" then
        PauseMenu.mousepressed(x, y, button)
    elseif currentScene == "battle" then
        local result = BattleMenu.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "battle_menu" then
        local result = BattleMenu.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "shop" then
        local result = ShopUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "gameover" then
        local result = GameOver.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "asset_viewer" then
        Viewer.mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if currentScene == "title" then
        Title.mousemoved(x,y)
    elseif currentScene == "game" then
        Game.mousemoved(x,y)
    elseif currentScene == "menu" then
        PauseMenu.mousemoved(x, y)
    elseif currentScene == "battle" then
        BattleMenu.mousemoved(x, y)
    elseif currentScene == "settings" then
        Settings.mousemoved(x, y)
    elseif currentScene == "asset_viewer" then
        Viewer.mousemoved(x, y, dx, dy)
    elseif currentScene == "shop" then
        ShopUI.mousemoved(x, y)
    end
end

function love.mousereleased(x, y, button)
    if currentScene == "asset_viewer" then
        Viewer.mousereleased(x, y, button)
    elseif currentScene == "menu" then
        PauseMenu.mousereleased(x,y, button)
    end
end

function love.wheelmoved(x, y)
    if currentScene == "asset_viewer" then
        Viewer.wheelmoved(x, y)
    elseif currentScene == "menu" then
        PauseMenu.wheelmoved(x, y)
    elseif currentScene == "battle" then
        BattleMenu.wheelmoved(x, y)
    end
end

function love.quit()
    print("正在退出... 保存游戏数据")
    local Config = require("config")
    Config.save()
    return false -- 返回 false 允许退出
end