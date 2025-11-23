local Player = require("player")
local Layout = require("layout")
local Config = require("config")
local InventoryUI = require("inventory_ui")
local Monster = require("monster")

local Battle = {}
smallFont = love.graphics.newFont("assets/simhei.ttf",14)

local DISPLAY_TIME = 3
local FADE_TIME = 2

Battle.state = {
    turn = "player",
    enemy = nil,
    enemyIndex = nil,
    log = {},
    onResolve = nil
}

-- 添加日志
function Battle.addLog(msg)
    table.insert(Battle.state.log, {text = msg, time = love.timer.getTime()})
end

-- 战斗开始
function Battle.start(enemyPayload, enemyIndex, onResolve)
    Battle.state.enemy = {
        name = enemyPayload.name,
        level = enemyPayload.level or 1,
        hp = enemyPayload.hp or 50,
        maxHp = enemyPayload.hp or 50
    }
    Battle.state.enemyIndex = enemyIndex
    Battle.state.onResolve = onResolve
    Battle.state.turn = "player"
    Battle.state.log = {}
    currentScene = "battle"
end

-- 战斗结束统一出口
function Battle.resolveBattle(result)
    if Battle.state.onResolve then
        Battle.state.onResolve(result, Battle.state.enemyIndex)
    end
    Battle.state.onResolve = nil
    currentScene = "game"
end

-- 玩家攻击
function Battle.playerAttack()
    local dmg = (Player.data.level or 1) * 10
    Battle.state.enemy.hp = math.max(Battle.state.enemy.hp - dmg, 0)
    Battle.addLog("玩家攻击造成 " .. dmg .. " 点伤害！")
    Battle.state.turn = "enemy"
end

-- 使用物品
function Battle.useItem()
    InventoryUI.previousScene = "battle"
    InventoryUI.onUseItem = function(item)
        Battle.addLog("使用了物品：" .. (item and item.name or "未知"))
        Battle.state.turn = "enemy"
    end
    currentScene = "inventory"
end

-- 敌人攻击
function Battle.enemyTurn()
    if Battle.state.enemy.hp <= 0 then return end
    local dmg = (Battle.state.enemy.level or 1) * 8
    Player.data.hp = math.max((Player.data.hp or 0) - dmg, 0)
    Battle.addLog(Battle.state.enemy.name .. " 攻击造成 " .. dmg .. " 点伤害！")
    Battle.state.turn = "player"
end

-- 胜负判定
function Battle.checkOutcome()
    if Battle.state.enemy.hp <= 0 then
        Battle.addLog("你击败了 " .. Battle.state.enemy.name .. "！")
        Battle.resolveBattle({ result = "win" })
    elseif (Player.data.hp or 0) <= 0 then
        Battle.addLog("你被击败了……")
        Config.setRespawn(0, 0)
        Battle.resolveBattle({ result = "lose" })
    end
end

-- 更新逻辑
function Battle.update(dt)
    if Battle.state.turn == "enemy" then
        Battle.enemyTurn()
        Battle.checkOutcome()
    end
end

-- 绘制战斗界面
function Battle.draw()
    local oldFont = love.graphics.getFont()

    -- 玩家 HP/MP 条
    local barWidth, barHeight = 200, 20
    local margin = 20
    local x = margin
    local y = love.graphics.getHeight() - 100

    -- HP
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    local hpRatio = (Player.data.hp or 0) / (Player.data.maxHp or 1)
    love.graphics.setColor(1,0,0)
    love.graphics.rectangle("fill", x, y, barWidth * hpRatio, barHeight)
    love.graphics.setColor(1,1,1)
    love.graphics.print("HP: "..(Player.data.hp or 0).."/"..(Player.data.maxHp or 0), x, y)

    -- MP
    local mpY = y + barHeight + 5
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", x, mpY, barWidth, barHeight)
    local mpRatio = (Player.data.mp or 0) / (Player.data.maxMp or 1)
    love.graphics.setColor(0,0,1)
    love.graphics.rectangle("fill", x, mpY, barWidth * mpRatio, barHeight)
    love.graphics.setColor(1,1,1)
    love.graphics.print("MP: "..(Player.data.mp or 0).."/"..(Player.data.maxMp or 0), x, mpY)

    -- 敌人 HP 条
    local ex = love.graphics.getWidth() - barWidth - margin
    local ey = margin
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", ex, ey, barWidth, barHeight)
    local enemyHpRatio = (Battle.state.enemy and Battle.state.enemy.hp or 0) / (Battle.state.enemy and Battle.state.enemy.maxHp or 1)
    love.graphics.setColor(1,0,0)
    love.graphics.rectangle("fill", ex, ey, barWidth * enemyHpRatio, barHeight)
    love.graphics.setColor(1,1,1)
    if Battle.state.enemy then
        love.graphics.print(Battle.state.enemy.name.." HP: "..Battle.state.enemy.hp.."/"..Battle.state.enemy.maxHp, ex, ey)
    end

    -- 信息与按钮
    local infoLines = {
        "玩家等级: " .. (Player.data.level or 1),
        "敌人等级: " .. (Battle.state.enemy and Battle.state.enemy.level or 1),
    }
    Layout.draw("战斗界面", infoLines, Battle.buttons, Battle.selectedIndex or -1, 0)

    -- 日志
    love.graphics.setFont(smallFont)
    local now = love.timer.getTime()
    local screenW = love.graphics.getWidth()
    local logX = screenW - 300
    local logY = 150
    local logWidth = 280

    for i = #Battle.state.log, 1, -1 do
        local entry = Battle.state.log[i]
        local msg = entry.text or tostring(entry)
        local age = now - (entry.time or now)
        if age < DISPLAY_TIME + FADE_TIME then
            local alpha = 1
            if age > DISPLAY_TIME then
                alpha = 1 - (age - DISPLAY_TIME) / FADE_TIME
            end
            love.graphics.setColor(1,1,1,alpha)
            love.graphics.printf(msg, logX, logY, logWidth, "right")
            logY = logY + 20
        end
    end

    love.graphics.setFont(oldFont)
    love.graphics.setColor(1,1,1,1)
end

-- 按钮定义（放在 resolveBattle 之后）
Battle.buttons = {
    {x=100, y=400, w=120, h=40, text="攻击", onClick=function() Battle.playerAttack() end},
    {x=250, y=400, w=120, h=40, text="物品", onClick=function() Battle.useItem() end},
    {x=400, y=400, w=120, h=40, text="逃跑", onClick=function() Battle.resolveBattle({ result = "escape" }) end}
}

Battle.selectedIndex = nil

-- 输入事件
function Battle.mousepressed(x, y, button)
    Layout.mousepressed(x, y, button, Battle.buttons)
end

function Battle.mousemoved(x, y)
    Battle.selectedIndex = Layout.mousemoved(x, y, Battle.buttons)
end

function Battle.keypressed(key)
    if key == "escape" then
        Battle.resolveBattle({ result = "escape" })
    end
end

-- === 整合 BattleManager 的入口 ===
function Battle.enterBattle(i, monster)
    if monster.cooldown and monster.cooldown > 0 then
        print(monster.name .. " 还在冷却中，暂时不会进入战斗")
        return
    end

    Battle.start(
        { name = monster.name, level = monster.level, hp = monster.hp },
        i,
        function(outcome, enemyIndex)
            if outcome.result == "win" then
                table.remove(Monster.list, enemyIndex)
                local expReward = monster.level * 50
                local goldReward = monster.level * 10
                Player.gainExp(expReward)
                Player.addGold(goldReward)
                print("获得经验：" .. expReward)
                print("获得金币：" .. goldReward)

            elseif outcome.result == "lose" then
                Player.data.hp = 1
                print("你被击败了，血量保留一滴")
                monster.cooldown = monster.cooldownDuration or 5.0
                print(monster.name .. " 进入冷却状态")
                currentScene = "title"

            elseif outcome.result == "escape" then
                monster.cooldown = monster.cooldownDuration or 5.0
                print(monster.name .. " 进入冷却状态")
            end

            if outcome.result ~= "lose" then
                currentScene = "game"
            end
        end
    )
end

return Battle
