-- player.lua
local Config = require("config")
local Layout = require("layout")
local ItemManager = require("ItemManager")

local Player = {}

-- UI状态管理
Player.data = {}
Player.activeTab = 1 -- 默认选中 "玩家信息"
Player.hoveredTabIndex = nil
Player.hoveredButtonIndex = nil
Player.debugButtonsAdded = false -- 新增：用于跟踪调试按钮是否已添加

-- 标签页配置
local tabs = {"玩家信息", "玩家装备", "任务列表"}

-- UI按钮 (基础按钮，不包含调试按钮)
Player.buttons = {
    {
        x = 400, y = 500, w = 200, h = 50,
        text = "返回游戏",
        onClick = function()
            Player.save()
            currentScene = "game"
        end
    }
}

-- 装备槽位定义
local equipmentSlots = {
    {name = "武器", key = "weapon"},
    {name = "防具", key = "armor"},
    {name = "饰品", key = "accessory"}
}

--------------------------------------------------
-- 核心数据管理
--------------------------------------------------

-- 初始化默认属性
local function initDefaults()
    Player.data.name   = Player.data.name or "未命名"
    Player.data.level  = Player.data.level or 1
    Player.data.hp     = Player.data.hp or 100
    Player.data.maxHp  = Player.data.maxHp or 100
    Player.data.mp     = Player.data.mp or 50
    Player.data.maxMp  = Player.data.maxMp or 50
    Player.data.exp    = Player.data.exp or 0
    Player.data.attack = Player.data.attack or 10
    Player.data.defense= Player.data.defense or 5
    Player.data.speed  = Player.data.speed or 5
    Player.data.gold   = Player.data.gold or 100
    
    -- 初始化新数据结构
    Player.data.equipment = Player.data.equipment or {}
    Player.data.quests = Player.data.quests or {}
end

-- 保存数据
function Player.save()
    Config.updatePlayer(Player.data)
end

-- 加载存档
function Player.load()
    Config.load()
    local saveData = Config.get()
    Player.data = saveData.player or {}
    initDefaults()
end

--------------------------------------------------
-- 玩家行为接口
--------------------------------------------------
function Player.addLevel(amount)
    initDefaults()
    local inc = amount or 1
    Player.data.level  = Player.data.level + inc
    Player.data.maxHp  = Player.data.maxHp + 100 * inc
    Player.data.hp     = Player.data.maxHp
    Player.data.maxMp  = Player.data.maxMp + 20 * inc
    Player.data.mp     = Player.data.maxMp
    Player.data.attack = Player.data.attack + 5 * inc
    Player.data.defense= Player.data.defense + 3 * inc
    Player.save()
end

function Player.addHP(amount)
    initDefaults()
    Player.data.hp = math.min(Player.data.hp + (amount or 10), Player.data.maxHp)
    Player.save()
end

function Player.gainExp(amount)
    initDefaults()
    Player.data.exp = Player.data.exp + (amount or 10)
    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.addLevel(1)
    end
    Player.save()
end

function Player.addGold(amount)
    initDefaults()
    Player.data.gold = Player.data.gold + (amount or 10)
    Player.save()
end

function Player.takeDamage(amount)
    initDefaults()
    local dmg = math.max(amount - Player.data.defense, 1)
    Player.data.hp = math.max(Player.data.hp - dmg, 0)
    Player.save()
end

function Player.useMana(cost)
    initDefaults()
    if Player.data.mp >= cost then
        Player.data.mp = Player.data.mp - cost
        Player.save()
        return true
    else
        return false
    end
end

--------------------------------------------------
-- 绘制函数
--------------------------------------------------
function Player.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- 半透明背景
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- 窗口边框
    local winX, winY, winW, winH = 80, 80, screenW-160, screenH-160
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", winX, winY, winW, winH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", winX, winY, winW, winH)

    -- 顶部标签页
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local bx, by = Layout.toScreen(tabX + (i-1)*(w+10), tabY)
        if Player.activeTab == i then
            love.graphics.setColor(0.2, 0.8, 1)
        elseif Player.hoveredTabIndex == i then
            love.graphics.setColor(0.7, 0.7, 0.7)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(tab, bx, by+5, w, "center")
    end

    -- 根据当前标签页绘制内容
    local contentY = 150
    if Player.activeTab == 1 then
        -- 1. 玩家信息
        local infoLines = {
            "名字: " .. Player.data.name,
            "等级: " .. Player.data.level,
            "血量: " .. Player.data.hp .. "/" .. Player.data.maxHp,
            "魔法: " .. Player.data.mp .. "/" .. Player.data.maxMp,
            "经验: " .. Player.data.exp,
            "攻击: " .. Player.data.attack,
            "防御: " .. Player.data.defense,
            "速度: " .. Player.data.speed,
            "金钱: " .. Player.data.gold
        }
        local lineY = contentY
        for _, line in ipairs(infoLines) do
            local sx, sy = Layout.toScreen(120, lineY)
            love.graphics.setColor(1,1,1)
            love.graphics.print(line, sx, sy)
            lineY = lineY + 30
        end

    elseif Player.activeTab == 2 then
        -- 2. 玩家装备
        local slotY = contentY
        for _, slot in ipairs(equipmentSlots) do
            local sx, sy = Layout.toScreen(120, slotY)
            love.graphics.setColor(1,1,1)
            love.graphics.print(slot.name .. ":", sx, sy)
            
            local equippedItem = Player.data.equipment[slot.key]
            if equippedItem then
                local def = ItemManager.get(equippedItem.id)
                local iconImage, iconQuad = ItemManager.getIcon(equippedItem.id)
                if iconImage then
                    love.graphics.draw(iconImage, iconQuad, sx + 100, sy - 10, 0, 0.5, 0.5)
                end
                love.graphics.printf(def and def.name or "未知装备", sx + 180, sy, 200, "left")
            else
                love.graphics.setColor(0.5,0.5,0.5)
                love.graphics.printf("无", sx + 100, sy, 200, "left")
            end
            slotY = slotY + 60
        end

    elseif Player.activeTab == 3 then
        -- 3. 任务列表
        local questY = contentY
        if #Player.data.quests == 0 then
            local sx, sy = Layout.toScreen(120, questY)
            love.graphics.setColor(0.7,0.7,0.7)
            love.graphics.print("当前没有进行中的任务。", sx, sy)
        else
            for _, quest in ipairs(Player.data.quests) do
                local sx, sy = Layout.toScreen(120, questY)
                love.graphics.setColor(1,1,1)
                love.graphics.print("- " .. quest.name, sx, sy)
                questY = questY + 25
                local desc_sx, desc_sy = Layout.toScreen(140, questY)
                love.graphics.setColor(0.8,0.8,0.8)
                love.graphics.printf(quest.description, desc_sx, desc_sy, 400, "left")
                questY = questY + 50
            end
        end
    end

    -- 关键修改：动态管理调试按钮
    if debugMode and not Player.debugButtonsAdded then
        table.insert(Player.buttons, {
            x = 400, y = 300, w = 200, h = 50,
            text = "初始化",
            onClick = function()
                Player.data = {}
                initDefaults()
                Player.save()
            end
        })
        table.insert(Player.buttons, {
            x = 400, y = 370, w = 200, h = 50,
            text = "提升等级",
            onClick = function()
                Player.addLevel(1)
            end
        })
        Player.debugButtonsAdded = true
    end

    if not debugMode and Player.debugButtonsAdded then
        -- 移除最后两个按钮（调试按钮）
        table.remove(Player.buttons)
        table.remove(Player.buttons)
        Player.debugButtonsAdded = false
    end

    -- 绘制按钮
    for i, btn in ipairs(Player.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local w, h = btn.w, btn.h
        if Player.hoveredButtonIndex == i then
            love.graphics.setColor(0.2, 0.8, 1)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", bx, by, w, h)
        love.graphics.printf(btn.text, bx, by + (h - love.graphics.getFont():getHeight()) / 2, w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

--------------------------------------------------
-- 输入事件处理
--------------------------------------------------
function Player.keypressed(key)
    if key == "escape" then
        Player.save()
        currentScene = "game"
    end
end

function Player.mousepressed(x, y, button)
    local vx, vy = Layout.toVirtual(x, y)

    -- 1. 检查标签页点击
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            Player.activeTab = i
            return
        end
    end

    -- 2. 检查按钮点击
    local clickedButtonIndex = Layout.mousepressed(x, y, button, Player.buttons) -- 使用 Player.buttons
    if clickedButtonIndex then
        local btn = Player.buttons[clickedButtonIndex]
        if btn and btn.onClick then
            btn.onClick()
        end
        return
    end
end

function Player.mousemoved(x, y)
    local vx, vy = Layout.toVirtual(x, y)

    -- 更新悬停的标签索引
    Player.hoveredTabIndex = nil
    local tabX, tabY = 100, 100
    for i, tab in ipairs(tabs) do
        local w, h = 120, 30
        local tx, ty = tabX + (i-1)*(w+10), tabY
        if vx >= tx and vx <= tx + w and vy >= ty and vy <= ty + h then
            Player.hoveredTabIndex = i
            break
        end
    end

    -- 更新悬停的按钮索引
    Player.hoveredButtonIndex = Layout.mousemoved(x, y, Player.buttons) -- 使用 Player.buttons
end

return Player