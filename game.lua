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
local PlayerAnimation = require("PlayerAnimation")


local menuHeight = 120
local w, h = love.graphics.getWidth(), love.graphics.getHeight()
-- 挖掘状态
Game.miningState = {
    active = false,
    timer = 0,
    maxTime = 1.5, -- 基础挖掘时间 (秒)
    targetGx = -1,
    targetGy = -1
}
function Game.load()
    Core.init() -- 确保 Core 加载了 Map
    Game.tileSize = 32
    Game.noiseScale = 0.12
    Game.wallThreshold = 0.40
    
    -- 加载音效
    Game.coinSound = love.audio.newSource("assets/sounds/coin.wav", "static")

    -- 确保 Player.data 存在 (由 main.lua 中的 Player.load() 初始化)
    if not Player.data then Player.data = {} end

    -- === [新增] 地图种子初始化 ===
    if not Player.data.seedX or not Player.data.seedY then
        -- 如果没有种子，生成随机的大数字作为偏移量
        -- love.math.random 范围很大，足以保证地图完全不同
        Player.data.seedX = love.math.random(1000, 999999)
        Player.data.seedY = love.math.random(1000, 999999)
        print("生成新地图种子:", Player.data.seedX, Player.data.seedY)
        
        -- 立即保存，确保种子被写入 save.json
        local Config = require("config")
        Config.updatePlayer(Player.data)
    else
        print("读取地图种子:", Player.data.seedX, Player.data.seedY)
    end

    -- 将种子应用到 Map 模块
    Map.seedX = Player.data.seedX
    Map.seedY = Player.data.seedY
    
    -- [注意] 因为种子变了，如果在游戏运行中重置（例如死亡），
    -- 需要清空 Map 的 chunk 缓存，否则可能还会显示旧地图的缓存
    Map.chunks = {} 
    Map.colliders = {}

    local targetX, targetY = 0, 0
    
    -- 如果是读档且有坐标，尝试使用存档坐标
    if Player.data.x and Player.data.x ~= 0 then
        targetX, targetY = Player.data.x, Player.data.y
    else
        -- 新游戏，目标原点
        targetX, targetY = 0, 0
    end
    
    -- 使用 Core 验证并修正坐标 (搜索半径 100格)
    local safeX, safeY = Core.findSpawnPoint(targetX, targetY, 100)
    Player.data.x = safeX
    Player.data.y = safeY

    -- 补充必须的运行时数据（这些是不存入 json 的）
    Player.data.w = Player.data.w or 16
    Player.data.h = Player.data.h or 20
    
    -- [关键] 重新加载动画 (因为存档里不存 image/quad userdata)
    -- 务必重新加载动画，否则 anim 字段是 nil
    Player.data.anim = PlayerAnimation.load("assets/Character/Idle.png", "assets/Character/Walk.png", 32, 32)
    
    -- 如果存档里没有速度等属性（兼容旧存档），则补全默认值
    Player.data.speed = Player.data.speed or 240

    -- 初始化 UI 按钮
    GameUI.load()
    -- 商人生成
    local merchantTargetX = Player.data.x + 64
    local merchantTargetY = Player.data.y
    
    for _, npc in ipairs(Merchant.list) do
        -- 同样使用 Core 寻找最近的空地 (半径 20格)
        local nx, ny = Core.findSpawnPoint(merchantTargetX, merchantTargetY, 20)
        npc.x = nx
        npc.y = ny
        -- 如果玩家和商人重叠太近，稍微移开一点（可选）
    end
    -- 关联引用
    Game.player = Player.data
    
    print("\nplayer loaded complete (Game.load)")
    
    -- 初始计算一次属性 (应用装备加成)
    Player.recalcStats()
    -- BOSS生成
    if Player.data.questStatus == "active" then
        local Monster = require("monster")
        -- 检查 BOSS 是否存在，不存在则生成
        local hasBoss = false
        for _, m in ipairs(Monster.list) do if m.isBoss then hasBoss = true break end end
        
        if not hasBoss then
            -- 使用 Core 保证 BOSS 不会卡在树里或水里
            Monster.spawnBoss(0, -3200)
        end
    end
end
-- 掉落逻辑封装
local function triggerDrop(gx, gy, tileType)
    local tileSize = Game.tileSize
    -- 掉落物生成在格子中心
    local centerX = gx * tileSize + 16
    local centerY = gy * tileSize + 16
    
    if tileType == "tree" then
        local count = love.math.random(3, 5)
        for i=1, count do Pickup.create(centerX, centerY, "wood", 1) end
        
    elseif tileType == "rock" then
        local count = love.math.random(1, 3)
        for i=1, count do 
            -- 这里调用的是 pickup.lua 里注册的 "stone" 类型
            Pickup.create(centerX, centerY, "stone", 1) 
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
    -- === [核心修改] 持续挖掘逻辑 ===
    if love.mouse.isDown(1) and not GameUI.isHovering then -- 确保没点在UI上
        local mx, my = love.mouse.getPosition()
        -- 转换世界坐标
        local camX = Game.player.x - love.graphics.getWidth()/2
        local camY = Game.player.y - love.graphics.getHeight()/2
        local wx, wy = mx + camX, my + camY
        
        local gx = math.floor(wx / Game.tileSize)
        local gy = math.floor(wy / Game.tileSize)
        local tile = Map.getTile(gx, gy)
        
        -- 检查距离
        local dist = math.sqrt((Game.player.x - wx)^2 + (Game.player.y - wy)^2)
        
        if dist < 100 and (tile == "tree" or tile == "rock") then
            -- 如果目标变了，重置计时器
            if gx ~= Game.miningState.targetGx or gy ~= Game.miningState.targetGy then
                Game.miningState.timer = 0
                Game.miningState.targetGx = gx
                Game.miningState.targetGy = gy
            end
            
            Game.miningState.active = true
            
            -- [修改] 根据目标类型调用不同的工具判定
            local speedMult = Player.getToolEfficiency(tile) -- 传入 "tree" 或 "rock"
            Game.miningState.timer = Game.miningState.timer + dt * speedMult
            
            -- 挖掘完成
            if Game.miningState.timer >= Game.miningState.maxTime then
                triggerDrop(gx, gy, tile)
                Map.setTile(gx, gy, "grass")
                -- 播放音效 (可选)
                Game.miningState.active = false
                Game.miningState.timer = 0
            end
        else
            Game.miningState.active = false
            Game.miningState.timer = 0
        end
    else
        Game.miningState.active = false
        Game.miningState.timer = 0
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

    -- 4.绘制挖掘进度条
    if Game.miningState.active then
        local camX = Game.player.x - love.graphics.getWidth()/2
        local camY = Game.player.y - love.graphics.getHeight()/2
        
        local gx, gy = Game.miningState.targetGx, Game.miningState.targetGy
        local screenX = gx * Game.tileSize - camX
        local screenY = gy * Game.tileSize - camY
        
        -- 进度比例
        local progress = math.min(Game.miningState.timer / Game.miningState.maxTime, 1)
        
        -- 画一个小条
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", screenX + 4, screenY - 10, 24, 6)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.rectangle("fill", screenX + 5, screenY - 9, 22 * progress, 4)
        love.graphics.setColor(1, 1, 1)
    end
    -- 5. 最顶层：UI (菜单、状态栏)
    GameUI.draw()
end

function Game.keypressed(key)
    if key == "z" and Game.nearMerchant then
        ShopUI.open(Game.nearMerchant)
    end
    if key == "escape" then currentScene = "menu" 
    else GameUI.keypressed(key)end
end

function Game.mousemoved(x, y)
    if currentScene == "player" then
        Player.mousemoved(x, y)
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
    GameUI.mousepressed(x, y, button)
end

return Game
