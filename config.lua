local Config = {}
local json = require("dkjson")

-- 1. 定义默认数据
local defaultData = {
    settings = { volume = 100, language = "en" },
    player = {
        name = "Hero", level = 1, hp = 100, maxHp = 100, mp = 50, maxMp = 50,
        exp = 0, attack = 10, defense = 5, speed = 200, gold = 100,
        respawnX = nil, respawnY = nil, x = 0, y = 0
    },
    inventory = {} 
}

-- 深拷贝辅助函数
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

Config.data = deepCopy(defaultData)

-- 保存前的数据清理 (防止保存 userdata 导致崩溃)
local function cleanDataForSave(t, level)
    if type(t) ~= "table" then return t end
    level = level or 0
    if level > 10 then return nil end 
    
    local res = {}
    for k, v in pairs(t) do
        local keyStr = tostring(k)
        -- 过滤掉 userdata, function, 动画对象, 临时缓存(_)
        if type(v) ~= "userdata" and type(v) ~= "function" 
           and k ~= "anim" and not keyStr:find("^_") then
            
            if type(v) == "table" then
                res[k] = cleanDataForSave(v, level + 1)
            else
                res[k] = v
            end
        end
    end
    return res
end

function Config.save()
    local safeData = cleanDataForSave(Config.data)
    local str = json.encode(safeData, {indent = true})
    love.filesystem.write("save.json", str)
end

function Config.load()
    if not love.filesystem.getInfo("save.json") then 
        return 
    end

    local content = love.filesystem.read("save.json")
    local loaded, pos, err = json.decode(content)
    
    if not loaded then
        print("[Config] Error loading save: " .. tostring(err))
        return 
    end

    print("[Config] Save loaded successfully.")

    -- 1. 恢复玩家数据
    if loaded.player then
        for k, v in pairs(loaded.player) do
            Config.data.player[k] = v
        end
    end

    -- 2. 恢复设置
    if loaded.settings then
        for k, v in pairs(loaded.settings) do
            Config.data.settings[k] = v
        end
    end

    -- 3. 恢复并清洗背包数据
    if loaded.inventory then
        local cleanInventory = {}
        for k, v in pairs(loaded.inventory) do
            if type(v) == "table" and v.id then
                table.insert(cleanInventory, {
                    id = v.id,
                    count = v.count or 1,
                    -- [关键修改] 读取 equipSlot 字段
                    -- 如果存档里没有这个字段，它就是 nil，表示未装备
                    equipSlot = v.equipSlot 
                })
            end
        end
        -- 按 ID 排序 (可选，如果喜欢固定顺序的话)
        -- table.sort(cleanInventory, function(a, b) return a.id < b.id end)
        
        Config.data.inventory = cleanInventory
    end
end

-- 接口
-- 更新设置的通用接口
function Config.updateSettings(key, value)
    if not Config.data.settings then Config.data.settings = {} end
    Config.data.settings[key] = value
    Config.save()
end
function Config.get() return Config.data end
function Config.updatePlayer(info) for k, v in pairs(info) do Config.data.player[k] = v end; Config.save() end
function Config.setRespawn(x, y) Config.data.player.respawnX = x; Config.data.player.respawnY = y; Config.save() end
function Config.getRespawn() if Config.data.player then return Config.data.player.respawnX, Config.data.player.respawnY end return nil, nil end
function Config.updateInventory(newInventory) Config.data.inventory = newInventory; Config.save() end

return Config