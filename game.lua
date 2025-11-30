-- game.lua
local Game = {}
Game.keys = {}
local counter = 0
Game.justRespawned = false

local Map = require("map")
local Core = require("core")
local Layout = require("layout")
local GameUI = require("game_ui") 
local Debug = require("debug_utils")
local Player = require("player")
local Config = require("config")
local Monster = require("monster")
local Merchant = require("merchant")
local ShopUI = require("shop_ui")
local Pickup = require("pickup")
local Battle = require("battle")
local InventoryUI = require("inventory_ui")
local PlayerAnimation = require("PlayerAnimation")


local menuHeight = 120
local w, h = love.graphics.getWidth(), love.graphics.getHeight()
function Game.load()
    Game.tileSize = 32
    Game.noiseScale = 0.12
    Game.wallThreshold = 0.40
    
    -- 加载音效
    Game.coinSound = love.audio.newSource("assets/sounds/coin.wav", "static")

    -- 确保 Player.data 存在 (由 main.lua 中的 Player.load() 初始化)
    if not Player.data then Player.data = {} end

    -- === [关键修复开始] ===
    -- 只有当玩家没有坐标（新游戏）或者坐标为0时，才寻找新的出生点
    -- 注意：存档如果保存了 x,y，这里就不会覆盖
    if not Player.data.x or (Player.data.x == 0 and Player.data.y == 0) then
        local spawnX, spawnY
        
        -- 尝试寻找随机生成点
        spawnX, spawnY = Core.findSpawnPoint(Game.tileSize)
        
        -- 兜底
        if not spawnX or not spawnY then
            print("警告：无法找到有效出生点，使用默认 (100, 100)")
            spawnX, spawnY = 100, 100
        end
        
        Player.data.x = spawnX
        Player.data.y = spawnY
        print("新游戏/无坐标，生成新位置:", spawnX, spawnY)
    else
        print("读取存档位置:", Player.data.x, Player.data.y)
    end

    -- 补充必须的运行时数据（这些是不存入 json 的）
    Player.data.w = Player.data.w or 16
    Player.data.h = Player.data.h or 20
    
    -- [关键] 重新加载动画 (因为存档里不存 image/quad userdata)
    -- 务必重新加载动画，否则 anim 字段是 nil
    Player.data.anim = PlayerAnimation.load("assets/Character/Idle.png", "assets/Character/Walk.png", 32, 32)
    
    -- 如果存档里没有速度等属性（兼容旧存档），则补全默认值
    Player.data.speed = Player.data.speed or 240
    
    -- === [关键修复结束] ===
    -- 初始化 UI 按钮
    GameUI.load()
    -- 关联引用
    Game.player = Player.data
    
    print("\nplayer loaded complete (Game.load)")
    
    -- 初始计算一次属性 (应用装备加成)
    Player.recalcStats()
    if Player.data.questStatus == "active" then
        -- 简单检查一下场上有没有BOSS，防止重复生成
        local hasBoss = false
        for _, m in ipairs(Monster.list) do
            if m.isBoss then hasBoss = true break end
        end
        
        if not hasBoss then
            Monster.spawnBoss(-50, -1200)
            print("读档恢复：BOSS 已重新生成")
        end
    end
end

function Game.update(dt)
    counter = counter + dt
    local isMoving = Core.updatePlayerMovement(Game.player, dt, Game.tileSize)
    PlayerAnimation.update(Game.player.anim, dt, isMoving, {"down","up","right","left"})
    Monster.update(dt, Game.player, Game.tileSize, Core)
    Pickup.update(dt, Game.player, Game.tileSize, Core, coinSound)
    local i, monster = Monster.checkCollision(Game.player, Core.aabbOverlap)
    if i then
        Battle.enterBattle(i, monster)
    end
    GameUI.update(dt)
    local npc = Merchant.checkCollision(Game.player, aabbOverlap)
    if npc then
        Game.nearMerchant = npc
    else
        Game.nearMerchant = nil
    end
    
end

function Game.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local camX = Game.player.x - w/2
    local camY = Game.player.y - h/2

    -- 1. 最底层：地图
    Map.draw(Game, camX, camY)

    -- 2. 中间层：玩家
    local spriteOffset = (32 - Game.player.w) / 2 
    love.graphics.setColor(1, 1, 1)
    PlayerAnimation.draw(Game.player.anim,
        Game.player.x - spriteOffset - camX,
        Game.player.y - (32 - Game.player.h) - camY,
        isMoving)

    -- 3. 中间层：实体 (怪物、商人、掉落物)
    -- 这些必须在菜单之前绘制！
    Monster.draw(camX, camY)
    Merchant.draw(camX, camY)
    Pickup.draw(camX, camY)

    if Game.nearMerchant then
        love.graphics.setColor(1,1,1)
        love.graphics.print("按 Z 键与 "..Game.nearMerchant.name.." 交谈", 200, 50)
    end

    -- 4. 最顶层：UI (菜单、状态栏)
    GameUI.draw()
end

function Game.keypressed(key)
    if key == "z" and Game.nearMerchant then
        ShopUI.open(Game.nearMerchant)
    end
end

function Game.mousemoved(x, y)
    if currentScene == "player" then
        Player.mousemoved(x, y)
    elseif currentScene == "inventory" then
        InventoryUI.mousemoved(x, y)
    end
end
-- 辅助函数：生成木材掉落
local function dropWood(gx, gy)
    local count = love.math.random(3, 5)
    local tileSize = Game.tileSize
    
    -- 树的中心坐标
    local centerX = gx * tileSize + 16
    local centerY = gy * tileSize + 16

    for i = 1, count do
        -- 直接从树中心生成，Pickup.create 内部会赋予它们向四周炸开的速度
        Pickup.create(centerX, centerY, "wood", 1)
    end
    print("砍树成功！")
end
function Game.mousepressed(x, y, button)
    if currentScene == "player" then
        local result = Player.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    elseif currentScene == "inventory" then
        local result = InventoryUI.mousepressed(x, y, button)
        if result == "title" then currentScene = "title" end
    else
        local handled = GameUI.mousepressed(x, y, button)
    end
        -- 游戏场景点击
    if button == 1 and currentScene == "game" then
        local w, h = love.graphics.getDimensions()
        local camX = Game.player.x - w/2
        local camY = Game.player.y - h/2
        
        -- 鼠标的世界坐标
        local worldX = x + camX
        local worldY = y + camY
        
        -- 转换为格子坐标
        local gx = math.floor(worldX / Game.tileSize)
        local gy = math.floor(worldY / Game.tileSize)
        
        -- 判断是否点击了树
        -- (这里假设 Core.isSolidTile 或 Map.getTile 返回 "tree" 字符串)
        -- 你需要根据你 map.lua 的具体实现来获取 tile 类型
        local tileType = Map.getTile(gx, gy) 
        
        if tileType == "tree" then
            -- 简单的距离检测：太远不能砍
            local dist = math.sqrt((Game.player.x - worldX)^2 + (Game.player.y - worldY)^2)
            if dist < 100 then
                -- 1. 掉落木材
                dropWood(gx, gy)
                
                -- 2. 移除树木 (变成草地)
                Map.setTile(gx, gy, "grass") 
            else
                print("太远了，砍不到！")
            end
        end
    end
end

return Game
