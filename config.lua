local Config = {}
local json = require("dkjson")

-- 1. 定义默认数据 (这是这道防线的基石)
local defaultData = {
    settings = { volume = 100, language = "en" },
    player = {
        name = "Hero", level = 1, hp = 100, maxHp = 100, mp = 50, maxMp = 50,
        exp = 0, attack = 10, defense = 5, speed = 100, gold = 100,
        respawnX = nil, respawnY = nil, x = 0, y = 0
    },
    inventory = {} 
}

-- 初始化 Config.data 为默认值的深拷贝
-- (简单的深拷贝实现，防止修改 Config.data 影响 defaultData)
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

Config.data = deepCopy(defaultData)

-- [数据清理] 用于保存前移除 userdata 和循环引用
local function cleanDataForSave(t, level)
    if type(t) ~= "table" then return t end
    level = level or 0
    if level > 10 then return nil end -- 防止过深
    
    local res = {}
    for k, v in pairs(t) do
        local keyStr = tostring(k)
        -- 过滤规则：移除 userdata, function, 动画对象, 临时缓存(_)
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
    -- print("[Config] Saving...")
    local safeData = cleanDataForSave(Config.data)
    local str = json.encode(safeData, {indent = true})
    love.filesystem.write("save.json", str)
end

function Config.load()
    if not love.filesystem.getInfo("save.json") then 
        return -- 无存档，直接使用当前的默认 Config.data
    end

    local content = love.filesystem.read("save.json")
    local loaded, pos, err = json.decode(content)
    
    if not loaded then
        print("[Config] Error loading save: " .. tostring(err))
        return 
    end

    print("[Config] Save loaded successfully.")

    -- [关键修复] 合并数据，而不是直接替换
    -- 1. 恢复玩家数据
    if loaded.player then
        -- 逐个字段覆盖，防止 loaded.player 少了某些新加的属性导致报错
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
        -- 无论存档里是数组还是对象，这里统一转为数组
        for k, v in pairs(loaded.inventory) do
            if type(v) == "table" and v.id then
                -- 断开引用，创建新对象
                table.insert(cleanInventory, {
                    id = v.id,
                    count = v.count or 1,
                    equipped = v.equipped or false
                })
            end
        end
        -- 按 ID 排序，保证背包顺序稳定
        table.sort(cleanInventory, function(a, b) return a.id < b.id end)
        
        Config.data.inventory = cleanInventory
    end
    
    -- 注意：这里绝对不再调用 Config.save()，只在内存中生效
end

-- 接口保持不变
function Config.get() return Config.data end
function Config.updatePlayer(info) for k, v in pairs(info) do Config.data.player[k] = v end; Config.save() end
function Config.setRespawn(x, y) Config.data.player.respawnX = x; Config.data.player.respawnY = y; Config.save() end
function Config.getRespawn() if Config.data.player then return Config.data.player.respawnX, Config.data.player.respawnY end return nil, nil end
function Config.updateInventory(newInventory) Config.data.inventory = newInventory; Config.save() end

return Config