local Player = require("player")
local Layout = require("layout")
local Config = require("config")
local InventoryUI = require("inventory_ui")
local Monster = require("monster")
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local MagicManager = require("MagicManager")

local Battle = {}

-- 资源与常量
local SMALL_FONT = love.graphics.newFont("assets/simhei.ttf", 14)
local DAMAGE_FONT = love.graphics.newFont("assets/simhei.ttf", 24)
local LOG_DISPLAY_TIME = 3
local LOG_FADE_TIME = 2

-- 战斗状态
Battle.state = {
    phase = "idle",
    turn = "player",
    enemy = nil,
    enemyIndex = nil,
    log = {},
    floatingTexts = {},
    timer = 0,
    shake = 0,
    onResolve = nil,
    menuLevel = "main" -- 新增：用于区分当前是 "main" 主菜单 还是 "magic" 魔法菜单
}

Battle.buttons = {}
Battle.selectedIndex = nil

-- ==========================================================
-- 辅助功能：视觉效果与日志
-- ==========================================================

function Battle.addLog(msg)
    table.insert(Battle.state.log, {text = msg, time = love.timer.getTime()})
    -- 限制日志长度
    if #Battle.state.log > 10 then table.remove(Battle.state.log, 1) end
end

-- 添加飘字 (例如: "-10", "MISS")
function Battle.addFloatText(text, x, y, color)
    table.insert(Battle.state.floatingTexts, {
        text = text,
        x = x,
        y = y,
        oy = 0, -- Y轴偏移量
        life = 1.0, -- 存在时间
        color = color or {1, 1, 1, 1}
    })
end

-- 触发屏幕震动
function Battle.triggerShake(amount)
    Battle.state.shake = amount or 5
end

-- 通用血条绘制
local function drawBar(label, val, max, x, y, w, h, colorMain)
    -- 背景
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- 血量/蓝量条
    local ratio = math.max(0, math.min(1, val / max))
    love.graphics.setColor(colorMain)
    love.graphics.rectangle("fill", x, y, w * ratio, h)
    
    -- 边框
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- 文字
    love.graphics.setColor(1, 1, 1)
    local text = string.format("%s %d/%d", label, math.floor(val), math.floor(max))
    love.graphics.print(text, x + 5, y + 2)
end

-- ==========================================================
-- 菜单切换逻辑 (新增)
-- ==========================================================

-- 生成主菜单按钮
function Battle.buildMainMenu()
    Battle.state.menuLevel = "main"
    Battle.buttons = {
        {text="攻击", onClick=function() Battle.playerAttackAction() end},
        {text="魔法", onClick=function() Battle.buildMagicMenu() end}, -- 新增魔法入口
        {text="物品", onClick=function() Battle.useItemAction() end},
        {text="逃跑", onClick=function() Battle.resolveBattle({ result = "escape" }) end}
    }
    Battle.layoutButtons()
end

-- 生成魔法菜单按钮
function Battle.buildMagicMenu()
    Battle.state.menuLevel = "magic"
    Battle.buttons = {}
    
    local spells = MagicManager.getAll()
    
    for _, spell in ipairs(spells) do
        table.insert(Battle.buttons, {
            text = spell.name .. " (" .. spell.cost .. ")",
            onClick = function() Battle.castSpellAction(spell) end
        })
    end
    
    -- 添加返回按钮
    table.insert(Battle.buttons, {
        text = "返回",
        onClick = function() Battle.buildMainMenu() end
    })
    
    Battle.layoutButtons()
end

-- 重新计算按钮位置布局
function Battle.layoutButtons()
    local btnCount = #Battle.buttons
    local bw, bh = 120, 40 
    local margin = 10
    
    -- 限制一行最多 4 个
    local cols = math.min(4, btnCount)
    
    -- 计算起始 X，使其在虚拟屏幕居中
    local totalW = cols * bw + (cols - 1) * margin
    local startX = (Layout.virtualWidth - totalW) / 2
    
    -- Y 轴位置：放在虚拟屏幕底部上方一点
    local startY = Layout.virtualHeight - 100 
    
    for i, btn in ipairs(Battle.buttons) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        
        btn.x = startX + col * (bw + margin)
        btn.y = startY + row * (bh + 5)
        btn.w = bw
        btn.h = bh
    end
end
-- ==========================================================
-- 核心逻辑
-- ==========================================================

function Battle.start(enemyPayload, enemyIndex, onResolve)
    Battle.state.enemy = {
        name = enemyPayload.name,
        level = enemyPayload.level or 1,
        hp = enemyPayload.hp or 50,
        maxHp = enemyPayload.maxHp or enemyPayload.hp or 50,
        attack = enemyPayload.attack,
        isBoss = enemyPayload.isBoss
    }
    Battle.state.enemyIndex = enemyIndex
    Battle.state.onResolve = onResolve
    Battle.state.turn = "player"
    Battle.state.phase = "idle"
    Battle.state.log = {}
    Battle.state.floatingTexts = {}
    Battle.state.timer = 0
    Battle.state.shake = 0
    
    -- 初始化主菜单
    Battle.buildMainMenu()

    currentScene = "battle"
    Battle.addLog("遭遇了 " .. Battle.state.enemy.name .. "！")
    -- 音乐切换逻辑
    if Battle.state.enemy.isBoss and bossMusic then
        -- 暂停平时的背景音乐
        if bgMusic:isPlaying() then
            bgMusic:pause() 
        end
        -- 播放 BOSS 音乐
        bossMusic:stop() -- 先停止以防万一
        bossMusic:play()
    end

end

function Battle.resolveBattle(result)
    if Battle.state.onResolve then
        Battle.state.onResolve(result, Battle.state.enemyIndex)
    end
    Battle.state.onResolve = nil
    -- 不要在这里切换场景，交给 onResolve 的回调去处理，或者在这里统一处理
    currentScene = "game" 
end

-- ==========================================================
-- 回合行动逻辑
-- ==========================================================

-- 1. 普通攻击 玩家点击攻击 -> 进入 acting 状态 -> 播放动画 -> 造成伤害 -> 延时 -> 敌人回合
function Battle.playerAttackAction()
    if Battle.state.phase ~= "idle" or Battle.state.turn ~= "player" then return end
    
    Battle.state.phase = "acting"
    
    -- 简单的随机伤害浮动
    local baseDmg = (Player.data.level or 1) * 10
    local dmg = math.floor(baseDmg * (math.random(80, 120) / 100))
    local isCrit = math.random() < 0.1 -- 10% 暴击率
    
    if isCrit then dmg = dmg * 2 end

    Battle.state.enemy.hp = math.max(Battle.state.enemy.hp - dmg, 0)
    
    -- 视觉反馈
    Battle.triggerShake(isCrit and 10 or 3)
    Battle.addLog("你攻击了 " .. Battle.state.enemy.name .. "！")
    
    -- 飘字
    local ex = love.graphics.getWidth() - 220
    local ey = 50
    local color = isCrit and {1, 1, 0} or {1, 1, 1}
    local text = isCrit and "暴击! -"..dmg or "-"..dmg
    Battle.addFloatText(text, ex + 50, ey + 50, color)

    -- 延时后切换到敌人
    Battle.state.timer = 1.0 
    Battle.state.nextTurn = "enemy"
end

-- 2. 施放魔法
function Battle.castSpellAction(spell)
    if Battle.state.phase ~= "idle" then return end
    
    -- 1. 检查蓝量 (使用你提供的函数)
    -- 注意：Player.useMana 需要在 player.lua 中定义并确保能访问 Player.data
    local success = Player.useMana(spell.cost)
    
    if not success then
        Battle.addLog("法力不足！需要 " .. spell.cost .. " MP")
        return -- 不消耗回合
    end
    
    Battle.state.phase = "acting"
    Battle.addLog("使用了 " .. spell.name .. "！")
    
    -- 2. 根据类型产生效果
    if spell.type == "damage" then
        -- 计算伤害 (可以加上智力加成等)
        local dmg = spell.power + (Player.data.level * 2) 
        dmg = math.floor(dmg * (math.random(90, 110) / 100))
        
        Battle.state.enemy.hp = math.max(Battle.state.enemy.hp - dmg, 0)
        Battle.triggerShake(8) -- 魔法震动大一点
        Battle.addFloatText("-"..dmg, love.graphics.getWidth() - 150, 50, {0.5, 0.5, 1}) -- 蓝色数字
        Battle.addLog("造成了 " .. dmg .. " 点魔法伤害！")
        
    elseif spell.type == "heal" then
        -- 治疗逻辑
        local healAmount = spell.power + (Player.data.level * 2)
        local oldHp = Player.data.hp
        Player.data.hp = math.min(Player.data.hp + healAmount, Player.data.maxHp)
        local actualHeal = Player.data.hp - oldHp
        
        Battle.addFloatText("+"..actualHeal, 100, love.graphics.getHeight() - 150, {0, 1, 0}) -- 绿色数字
        Battle.addLog("恢复了 " .. actualHeal .. " 点生命值。")
    end
    
    -- 施法后切回主菜单布局，并进入敌人回合
    Battle.buildMainMenu() 
    Battle.state.timer = 1.0
    Battle.state.nextTurn = "enemy"
end

-- 2. 使用物品
function Battle.useItemAction()
    if Battle.state.phase ~= "idle" then return end
    
    InventoryUI.previousScene = "battle"
    
    InventoryUI.onUseItem = function(item)
        if not item then 
            currentScene = "battle"
            return 
        end

        local def = ItemManager.get(item.id)
        local itemName = def and def.name or "未知物品"
        
        -- [新增] 标志位：用于记录是否触发了伤害逻辑
        local isDamageItem = false

        -- 1. 构建战斗代理
        local battleProxy = {
            -- 转发给 Player
            addHP = Player.addHP,
            addMP = Player.addMP,
            addLevel = Player.addLevel,

            -- 拦截伤害逻辑
            dealDamage = function(amount)
                -- [标记] 说明这个物品调用了 dealDamage
                isDamageItem = true 
                
                if Battle.state.enemy then
                    local dmg = tonumber(amount) or 0
                    Battle.state.enemy.hp = math.max(Battle.state.enemy.hp - dmg, 0)
                    
                    Battle.addLog("投掷了 " .. itemName .. "！")
                    Battle.addLog("造成了 " .. dmg .. " 点伤害！")
                    
                    Battle.triggerShake(5)
                    Battle.addFloatText("-"..dmg, love.graphics.getWidth() - 200, 100, {1, 0, 0})
                end
            end
        }

        -- 2. 使用物品
        local success, msg = ItemManager.use(item.id, battleProxy)

        if success then
            -- [修复] 不再检查 def.onUse 字符串，而是检查标志位
            -- 如果没有触发伤害逻辑（说明是普通药水等），则打印通用日志
            if not isDamageItem then
                Battle.addLog("使用了 " .. itemName)
            end

            -- 3. 从背包移除
            local category = ItemManager.getCategory(item.id)
            Inventory:removeItem(item.id, 1, category)

            Battle.buildMainMenu()
            Battle.state.phase = "acting"
            Battle.state.timer = 1.0
            Battle.state.nextTurn = "enemy"
            currentScene = "battle"
        else
            print("使用失败: " .. tostring(msg))
            currentScene = "battle"
        end
    end
    
    currentScene = "inventory"
end

-- 4. 敌人回合逻辑
function Battle.processEnemyTurn()
    if Battle.state.enemy.hp <= 0 then return end

    local enemy = Battle.state.enemy
    local actionName = "攻击"
    local dmg = 0
    local heal = 0
    
    -- 基础伤害
    local baseDmg = (enemy.level or 1) * 8
    if enemy.attack then baseDmg = enemy.attack end -- 如果有自定义攻击力

    -- === BOSS AI 逻辑 ===
    if enemy.isBoss then
        local hpPercent = enemy.hp / enemy.maxHp
        
        -- 阶段 3: 血量 < 30% (增加回血技能)
        if hpPercent < 0.3 and math.random() < 0.3 then -- 30% 概率回血
            actionName = "暗影治愈"
            heal = math.floor(enemy.maxHp * 0.1) -- 回复 10%
            enemy.hp = math.min(enemy.hp + heal, enemy.maxHp)
            
        -- 阶段 2: 血量 < 80% (增加重击)
        elseif hpPercent < 0.8 and math.random() < 0.4 then -- 40% 概率重击
            actionName = "毁灭重击"
            dmg = math.floor(baseDmg * 2.0) -- 2倍伤害
            
        -- 阶段 1: 正常攻击
        else
            actionName = "普通攻击"
            dmg = math.floor(baseDmg * (math.random(90, 110) / 100))
        end
    else
        -- 普通怪物逻辑
        dmg = math.floor(baseDmg * (math.random(90, 110) / 100))
    end

    -- === 结算 ===
    if heal > 0 then
        Battle.addLog(enemy.name .. " 使用了 " .. actionName .. "！")
        Battle.addLog("恢复了 " .. heal .. " 点生命。")
        Battle.addFloatText("+"..heal, love.graphics.getWidth() - 100, 150, {0, 1, 0})
    else
        -- 玩家扣血 (计算防御)
        Player.takeDamage(dmg)
        
        -- 显示日志
        Battle.triggerShake(dmg > baseDmg and 10 or 5) -- 重击震动大
        
        local def = Player.data.defense or 0
        local actualDmg = math.max(dmg - def, 1)
        
        Battle.addLog(enemy.name .. " 使用 " .. actionName .. " 造成 " .. actualDmg .. " 伤害！")
        Battle.addFloatText("-"..actualDmg, 40, love.graphics.getHeight() - 150, {1, 0.2, 0.2})
    end
    
    Battle.state.timer = 1.0
    Battle.state.nextTurn = "player"
end

-- 5. 胜负检测
function Battle.checkOutcome()
    if Battle.state.phase == "victory" or Battle.state.phase == "defeat" then return end

    if Battle.state.enemy.hp <= 0 then
        Battle.state.phase = "victory"
        Battle.addLog("胜利！")
        Battle.state.timer = 1.5 -- 胜利后停留一会
    elseif (Player.data.hp or 0) <= 0 then
        Battle.state.phase = "defeat"
        Battle.addLog("你倒下了...")
        Battle.state.timer = 2.0
    end
end

-- ==========================================================
-- Update & Draw
-- ==========================================================

function Battle.update(dt)
    -- 更新计时器
    if Battle.state.timer > 0 then
        Battle.state.timer = Battle.state.timer - dt
        if Battle.state.timer <= 0 then
            -- 计时结束后的逻辑
            if Battle.state.phase == "acting" then
                Battle.state.phase = "idle"
                Battle.state.turn = Battle.state.nextTurn
                Battle.checkOutcome() -- 检查是否打死怪了
                
                -- 如果没死，且轮到敌人，立即执行敌人逻辑
                if Battle.state.turn == "enemy" and Battle.state.phase == "idle" then
                     Battle.state.phase = "acting" -- 锁定状态防止玩家操作
                     Battle.processEnemyTurn()
                     Battle.checkOutcome() -- 检查是否被打死了
                end
            elseif Battle.state.phase == "victory" then
                Battle.resolveBattle({ result = "win" })
            elseif Battle.state.phase == "defeat" then
                Config.setRespawn(0, 0)
                Battle.resolveBattle({ result = "lose" })
            end
        end
    end

    -- 更新震动
    if Battle.state.shake > 0 then
        Battle.state.shake = math.max(0, Battle.state.shake - dt * 20) -- 震动衰减
    end

    -- 更新飘字
    for i = #Battle.state.floatingTexts, 1, -1 do
        local f = Battle.state.floatingTexts[i]
        f.life = f.life - dt
        f.oy = f.oy - dt * 30 -- 向上飘
        if f.life <= 0 then
            table.remove(Battle.state.floatingTexts, i)
        end
    end
end

function Battle.draw()
    -- 震动效果
    if Battle.state.shake > 0 then
        local dx = math.random(-Battle.state.shake, Battle.state.shake)
        local dy = math.random(-Battle.state.shake, Battle.state.shake)
        love.graphics.push()
        love.graphics.translate(dx, dy)
    end

    -- 绘制背景 (可选：变暗)
    love.graphics.setColor(0, 0, 0, 0.8)
    -- love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- 绘制 UI 区域
    local barW, barH = 200, 24
    local margin = 20
    
    -- 1. 玩家状态区 (左下)
    local pY = love.graphics.getHeight() - 140
    drawBar("HP", Player.data.hp or 0, Player.data.maxHp or 1, margin, pY, barW, barH, {0.8, 0, 0})
    drawBar("MP", Player.data.mp or 0, Player.data.maxMp or 1, margin, pY + 30, barW, barH, {0.2, 0.2, 0.8})

    -- 2. 敌人状态区 (右上)
    local eX = love.graphics.getWidth() - barW - margin
    if Battle.state.enemy then
        drawBar(Battle.state.enemy.name, Battle.state.enemy.hp, Battle.state.enemy.maxHp, eX, margin, barW, barH, {0.9, 0.1, 0.1})
        love.graphics.print("Lv." .. (Battle.state.enemy.level or 1), eX, margin + 30)
    end

    -- 3. 按钮 (替换原有的 Layout.draw)
    -- 只有在玩家回合且非动画状态才显示
    if Battle.state.turn == "player" and Battle.state.phase == "idle" then
        local mx, my = love.mouse.getPosition()
        -- 获取鼠标悬停的按钮索引
        local hoveredIndex = Layout.mousemoved(mx, my, Battle.buttons)
        
        for i, btn in ipairs(Battle.buttons) do
            -- [关键] 将虚拟坐标转换为屏幕坐标
            local bx, by = Layout.toScreen(btn.x, btn.y)
            local bw, bh = Layout.toScreen(btn.w, btn.h)
            
            -- 悬停效果
            if i == hoveredIndex then
                love.graphics.setColor(0.2, 0.8, 1, 0.8) -- 亮蓝
                love.graphics.rectangle("fill", bx, by + 2, bw, bh, 5, 5) -- 下沉效果
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 0.6) -- 半透明黑底
                love.graphics.rectangle("fill", bx, by, bw, bh, 5, 5)
                love.graphics.setColor(1, 1, 1, 0.5) -- 白边框
                love.graphics.rectangle("line", bx, by, bw, bh, 5, 5)
            end
            
            -- 按钮文字
            love.graphics.setColor(1, 1, 1)
            -- 如果有 Fonts.medium 就用，没有就用默认
            local font = Fonts.medium or love.graphics.getFont()
            love.graphics.setFont(font)
            
            local textY = by + (bh - font:getHeight()) / 2
            if i == hoveredIndex then textY = textY + 2 end -- 文字跟随下沉
            
            love.graphics.printf(btn.text, bx, textY, bw, "center")
        end
    end

    -- 4. 战斗日志 (右侧)
    love.graphics.setFont(Fonts.small)
    local logX = love.graphics.getWidth() - 320
    local logY = 120
    for i = #Battle.state.log, 1, -1 do
        local entry = Battle.state.log[i]
        local age = love.timer.getTime() - entry.time
        if age < LOG_DISPLAY_TIME + LOG_FADE_TIME then
            local alpha = 1
            if age > LOG_DISPLAY_TIME then
                alpha = 1 - (age - LOG_DISPLAY_TIME) / LOG_FADE_TIME
            end
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.printf(entry.text, logX, logY + (i * 20), 300, "right")
        end
    end

    -- 5. 飘字绘制 (最上层)
    love.graphics.setFont(Fonts.large)
    for _, f in ipairs(Battle.state.floatingTexts) do
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], f.life) -- alpha随寿命减少
        -- 文字带黑边，增加可读性
        love.graphics.print(f.text, f.x + 1, f.y + f.oy + 1) -- 阴影
        love.graphics.setColor(f.color)
        love.graphics.print(f.text, f.x, f.y + f.oy)
    end
    
    love.graphics.setColor(1, 1, 1, 1)

    -- 结束震动变换
    if Battle.state.shake > 0 then
        love.graphics.pop()
    end
end

-- ==========================================================
-- 输入处理
-- ==========================================================

function Battle.mousepressed(x, y, button)
    -- 只有玩家回合且空闲时才能点击
    if Battle.state.turn == "player" and Battle.state.phase == "idle" then
        Layout.mousepressed(x, y, button, Battle.buttons)
    end
end

function Battle.mousemoved(x, y)
    if Battle.state.turn == "player" and Battle.state.phase == "idle" then
        Battle.selectedIndex = Layout.mousemoved(x, y, Battle.buttons)
    end
end

function Battle.keypressed(key)
    if key == "escape" and Battle.state.turn == "player" then
        Battle.resolveBattle({ result = "escape" })
    end
end

-- ==========================================================
-- 外部调用入口
-- ==========================================================

function Battle.enterBattle(i, monster)
    if monster.cooldown and monster.cooldown > 0 then
        -- 可以添加一个屏幕提示："怪物正在恢复中..."
        return
    end

    Battle.start(
        monster,
        i,
        function(outcome, enemyIndex)
            -- 如果 BOSS 音乐正在播放，说明刚才是在打 BOSS
            if bossMusic and bossMusic:isPlaying() then
                bossMusic:stop()
                -- 恢复平时的背景音乐
                bgMusic:play()
            end
            if outcome.result == "win" then
                table.remove(Monster.list, enemyIndex)

                -- BOSS 掉落与任务更新
                if monster.isBoss then
                    print("BOSS 被击败！")
                    Player.data.questStatus = "killed" -- 更新状态
                    -- 掉落大量金币
                    local Pickup = require("pickup")
                    Pickup.create(monster.x, monster.y, "coin", 5000)
                    
                    -- 更新任务描述 (UI显示用)
                    for _, q in ipairs(Player.data.quests) do
                        if q.id == "kill_boss" then
                            q.description = "魔王已被击败！快回去找商人领赏。"
                        end
                    end
                else
                    -- 普通怪奖励
                    local expReward = monster.level * 20
                    Player.gainExp(expReward)
                    Player.addGold(monster.level * 5)
                end

            elseif outcome.result == "lose" then
                Player.data.hp = 1
                monster.cooldown = monster.cooldownDuration or 5.0
                print("战斗失败...")
                currentScene = "title" -- 或者 gameover 场景

            elseif outcome.result == "escape" then
                monster.cooldown = monster.cooldownDuration or 5.0
                print("逃跑成功")
            end

            if outcome.result ~= "lose" then
                currentScene = "game"
            end
        end
    )
end

return Battle