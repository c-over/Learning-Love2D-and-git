-- battle.lua
local Player = require("player")
local Layout = require("layout")
local Config = require("config")
local ItemManager = require("ItemManager")

local Battle = {}
-- 在 love.load 或 Battle.load 中定义一个小字号字体
smallFont = love.graphics.newFont("assets/simhei.ttf",14)

local DISPLAY_TIME = 3      -- 完全显示时间
local FADE_TIME = 2         -- 渐变暗时间

Battle.state = {
    turn = "player",
    enemy = nil,          -- 敌人数据在 start() 时注入
    enemyIndex = nil,     -- 地图上对应索引（不直接访问 Game）
    log = {},
    onResolve = nil       -- 战斗结束回调（由 Game 注入）
}
local buttons = {
    {x=100, y=400, w=120, h=40, text="攻击", onClick=function() Battle.playerAttack() end},
    {x=250, y=400, w=120, h=40, text="物品", onClick=function() Battle.useItem(3) end}, -- 示例：治疗药水
    {x=400, y=400, w=120, h=40, text="逃跑", onClick=function() currentScene = "game" end}
}

local selectedIndex = nil

local function addLog(msg)  --显示日志
    table.insert(Battle.state.log, {text = msg, time = love.timer.getTime()})
end

function Battle.start(enemyPayload, enemyIndex, onResolve)
    Battle.state.enemy = {
        name = enemyPayload.name,
        level = enemyPayload.level or 1,
        hp = enemyPayload.hp or 50
    }
    Battle.state.enemyIndex = enemyIndex
    Battle.state.onResolve = onResolve
    Battle.state.turn = "player"
    Battle.state.log = {}
    currentScene = "battle"
end

local function resolveBattle(result)
    if Battle.state.onResolve then
        Battle.state.onResolve(result, Battle.state.enemyIndex)
    end
    Battle.state.onResolve = nil
    currentScene = "game"
end

function Battle.playerAttack()
    local dmg = (Player.data.level or 1) * 10
    Battle.state.enemy.hp = Battle.state.enemy.hp - dmg
    addLog("玩家攻击造成 " .. dmg .. " 点伤害！")
    Battle.state.turn = "enemy"
end

-- 使用物品：调用 ItemManager
function Battle.useItem(itemId)
    ItemManager.use(itemId, Player)
    local item = ItemManager.get(itemId)
    addLog("使用了物品：" .. (item and item.name or "未知"))
    Battle.state.turn = "enemy"
end

function Battle.enemyTurn()
    if Battle.state.enemy.hp <= 0 then return end
    local dmg = (Battle.state.enemy.level or 1) * 8
    Player.data.hp = (Player.data.hp or 0) - dmg
    addLog(Battle.state.enemy.name .. " 攻击造成 " .. dmg .. " 点伤害！")
    Battle.state.turn = "player"
end

local function checkOutcome()
    if Battle.state.enemy.hp <= 0 then
        addLog("你击败了 " .. Battle.state.enemy.name .. "！")
        resolveBattle({ result = "win" })
    elseif (Player.data.hp or 0) <= 0 then
        addLog("你被击败了……")
        Config.setRespawn(0, 0)  -- 安全的默认坐标
        currentScene = "title"
    end
end

-- 更新逻辑
function Battle.update(dt)
    if Battle.state.turn == "enemy" then
        Battle.enemyTurn()
        checkOutcome()
    end
end

-- 绘制战斗界面
function Battle.draw()
     -- 保存当前字体
    local oldFont = love.graphics.getFont()

    local infoLines = {
        "玩家 HP: " .. (Player.data.hp or 0),
        "玩家等级: " .. (Player.data.level or 1),
        "敌人 HP: " .. (Battle.state.enemy and Battle.state.enemy.hp or 0),
        "敌人等级: " .. (Battle.state.enemy and Battle.state.enemy.level or 1),
    }
    Layout.draw("战斗界面", infoLines, buttons, selectedIndex or -1, 0)

    -- 绘制操作信息日志在屏幕右侧
    love.graphics.setFont(smallFont)
    local now = love.timer.getTime()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local logX = screenW - 300   -- 消息框宽度 300px
    local logY = 100             -- 距离顶部 100px
    local logWidth = 280         -- 文本区域宽度

    for i = #Battle.state.log, 1, -1 do
        local entry = Battle.state.log[i]
        local msg = entry.text or tostring(entry)
        local age = now - (entry.time or now)
        if age < DISPLAY_TIME + FADE_TIME then
            local alpha = 1
            if age > DISPLAY_TIME then
                alpha = 1 - (age - DISPLAY_TIME) / FADE_TIME
            end
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.printf(msg, logX, logY, logWidth, "right")
            logY = logY + 20
        end
    end

    -- 恢复原字体，避免影响其他绘制
    love.graphics.setFont(oldFont)
    love.graphics.setColor(1,1,1,1)
end


function Battle.mousepressed(x, y, button)
    Layout.mousepressed(x, y, button, buttons)
end

function Battle.mousemoved(x, y)
    selectedIndex = Layout.mousemoved(x, y, buttons)
end

function Battle.keypressed(key)
    if key == "escape" then
        currentScene = "game"
    end
end

return Battle
