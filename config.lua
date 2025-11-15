-- config.lua
local Config = {}

-- 默认数据结构
local data = {
    settings = {
        volume = 100,
        language = "中文"
    },
    player = {
        name = "Hero",
        level = 1,
        hp = 100
    },
    inventory = {
        {name = "Potion", count = 2},
        {name = "Sword", count = 1}
    }
}

-- 保存到文件
function Config.save()
    local json = require("dkjson").encode(data, {indent = true})
    love.filesystem.write("save.json", json)
end

-- 从文件加载
function Config.load()
    if love.filesystem.getInfo("save.json") then
        local content = love.filesystem.read("save.json")
        local loaded = require("dkjson").decode(content)
        if loaded then
            data = loaded
        end
    end
end

-- 获取数据
function Config.get()
    return data
end

-- 修改数据（例如更新音量）
function Config.setVolume(v)
    data.settings.volume = v
    Config.save()
end

function Config.setLanguage(lang)
    data.settings.language = lang
    Config.save()
end

function Config.updatePlayer(info)
    for k, v in pairs(info) do
        data.player[k] = v
    end
    Config.save()
end

function Config.updateInventory(newInventory)
    data.inventory = newInventory
    Config.save()
end

return Config
