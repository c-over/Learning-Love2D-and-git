local StoryManager = {}
local json = require("dkjson")
local Player = require("player")

local textData = {}

-- === 1. 加载文本 ===
function StoryManager.load()
    local path = "data/story.json"
    if love.filesystem.getInfo(path) then
        local content = love.filesystem.read(path)
        local decoded, pos, err = json.decode(content)
        if decoded then
            textData = decoded
            print("[StoryManager] Text loaded.")
        else
            print("[StoryManager] JSON Error: " .. tostring(err))
        end
    end
    
    -- 确保玩家有进度存储表
    if not Player.data.progress then
        Player.data.progress = {}
    end
end

-- === 2. 获取文本 (支持嵌套 key，如 "merchant.greet_normal") ===
function StoryManager.getText(keyPath)
    local keys = {}
    for k in string.gmatch(keyPath, "[^%.]+") do table.insert(keys, k) end
    
    local current = textData
    for _, k in ipairs(keys) do
        if current[k] then
            current = current[k]
        else
            return "Missing Text: " .. keyPath
        end
    end
    
    if type(current) == "string" then return current end
    return "Invalid Text Key: " .. keyPath
end

-- === 3. 变量操作接口 (供 Debug 和 游戏逻辑使用) ===

-- 获取变量 (默认为 0)
function StoryManager.getVar(key)
    return Player.data.progress[key] or 0
end

-- 设置变量
function StoryManager.setVar(key, value)
    Player.data.progress[key] = value
    print(string.format("[Story] Set '%s' to %s", key, tostring(value)))
end

-- 增加变量 (用于计数器，如杀怪数)
function StoryManager.addVar(key, amount)
    local old = StoryManager.getVar(key)
    StoryManager.setVar(key, old + (amount or 1))
end

return StoryManager