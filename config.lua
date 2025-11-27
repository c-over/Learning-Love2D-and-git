-- config.lua
local Config = {}
local json = require("dkjson") -- 提出来引用，稍微优化性能

-- [关键修改] 将 local data 改为 Config.data，使其能被外部访问
Config.data = {
    settings = {
        volume = 100,
        language = "中文"
    },
    player = {
        name   = "hero",
        level  = 1,
        hp     = 100,
        maxHp  = 100,
        mp     = 50,
        maxMp  = 50,
        exp    = 0,
        attack = 10,
        defense= 5,
        speed  = 5,
        gold   = 100,
        -- 这里给 nil，方便 game.lua 判断是否已设置过重生点
        -- 如果设为 0，Lua 会认为是有值的，可能会导致出生在 (0,0) 墙角
        respawnX = nil, 
        respawnY = nil,
        x      = 0,
        y      = 0
    },
    inventory = {
        {
            id = 1,
            name = "经验药水",
            icon = "assets/potion.png",
            count = 3,
            description = "使用后提升1级"
        },
        {
            id = 2,
            name = "大经验药水",
            icon = "assets/big_potion.png",
            count = 1,
            description = "使用后提升3级"
        }
    }
}

-- 保存到文件
function Config.save()
    -- [修改] 使用 Config.data
    local str = json.encode(Config.data, {indent = true})
    love.filesystem.write("save.json", str)
end

-- 从文件加载
function Config.load()
    if love.filesystem.getInfo("save.json") then
        local content = love.filesystem.read("save.json")
        local loaded = json.decode(content)
        if loaded then
            -- [修改] 更新 Config.data，而不是局部变量
            Config.data = loaded
        end
    end
end

-- 获取数据
function Config.get()
    return Config.data
end

-- 修改数据（例如更新音量）
function Config.setVolume(v)
    Config.data.settings.volume = v
    Config.save()
end

function Config.setLanguage(lang)
    Config.data.settings.language = lang
    Config.save()
end

function Config.updatePlayer(info)
    for k, v in pairs(info) do
        Config.data.player[k] = v
    end
    Config.save()
end

-- 重生点接口
function Config.setRespawn(x, y)
    -- [修改] 使用 Config.data
    Config.data.player.respawnX = x
    Config.data.player.respawnY = y
    Config.save()
end

function Config.getRespawn()
    -- [修改] 使用 Config.data
    if Config.data.player then
        return Config.data.player.respawnX, Config.data.player.respawnY
    end
    return nil, nil
end

function Config.updateInventory(newInventory)
    Config.data.inventory = newInventory
    Config.save()
end

return Config