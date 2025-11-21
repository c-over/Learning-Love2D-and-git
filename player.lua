local Config = require("config")
local Layout = require("layout")
local Player = {}

Player.data = {}
local buttons = {}
local selectedIndex = nil

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
end

-- 保存数据
function Player.save()
    Config.updatePlayer({
        name   = Player.data.name,
        level  = Player.data.level,
        hp     = Player.data.hp,
        maxHp  = Player.data.maxHp,
        mp     = Player.data.mp,
        maxMp  = Player.data.maxMp,
        exp    = Player.data.exp,
        attack = Player.data.attack,
        defense= Player.data.defense,
        speed  = Player.data.speed,
        gold   = Player.data.gold,
        x      = Player.data.x,
        y      = Player.data.y
    })
end

-- 升级
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
    save()
end

-- 增加血量
function Player.addHP(amount)
    initDefaults()
    Player.data.hp = math.min(Player.data.hp + (amount or 10), Player.data.maxHp)
    Player.save()
end

-- 增加魔法值
function Player.addMP(amount)
    initDefaults()
    Player.data.mp = math.min(Player.data.mp + (amount or 5), Player.data.maxMp)
    Player.save()
end

-- 经验值与升级
function Player.gainExp(amount)
    initDefaults()
    Player.data.exp = Player.data.exp + (amount or 10)
    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.addLevel(1)
    end
    Player.save()
end

--增加金币
function Player.addGold(amount)
    initDefaults()
    Player.data.gold = Player.data.gold + (amount or 10)
    Player.save()
end

-- 战斗接口：受伤
function Player.takeDamage(amount)
    initDefaults()
    local dmg = math.max(amount - Player.data.defense, 1)
    Player.data.hp = math.max(Player.data.hp - dmg, 0)
    Player.save()
end

-- 战斗接口：使用魔法
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

-- 加载存档
function Player.load()
    Config.load()
    local saveData = Config.get()
    Player.data = saveData.player or {}
    initDefaults()

    Player.data.x = saveData.player.respawnX or 0
    Player.data.y = saveData.player.respawnY or 0

    buttons = {
        {x=400,y=300,w=200,h=50,text="初始化",onClick=function()
            Player.data.level=1; Player.data.hp=100; Player.data.maxHp=100
            Player.data.mp=50; Player.data.maxMp=50; Player.data.exp=0
            Player.data.attack=10; Player.data.defense=5; Player.data.speed=5
            Player.save()
        end},
        {x=400,y=370,w=200,h=50,text="提升等级",onClick=function() Player.addLevel(1) end},
        {x=400,y=440,w=200,h=50,text="返回游戏",onClick=function()
            Player.save()
            currentScene="game"
        end}
    }
end

-- 绘制信息
function Player.draw()
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
    Layout.draw("玩家信息", infoLines, buttons, selectedIndex)
end

function Player.keypressed(key)
    if key == "escape" then currentScene = "game" end
end

function Player.mousepressed(x, y, button)
    Layout.mousepressed(x, y, button, buttons)
end

function Player.mousemoved(x, y)
    selectedIndex = Layout.mousemoved(x, y, buttons)
end

return Player
