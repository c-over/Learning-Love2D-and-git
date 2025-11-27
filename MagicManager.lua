local MagicManager = {}
local json = require("dkjson") -- 确保你项目里有 dkjson

-- 加载魔法数据
function MagicManager.load()
    if love.filesystem.getInfo("data/magic.json") then
        local content = love.filesystem.read("data/magic.json")
        local data = json.decode(content)
        MagicManager.spells = {}
        -- 转为以 ID 为键的表，方便查找
        for _, spell in ipairs(data) do
            MagicManager.spells[spell.id] = spell
        end
    else
        print("Error: data/magic.json not found")
        MagicManager.spells = {}
    end
end

function MagicManager.get(id)
    return MagicManager.spells[id]
end

function MagicManager.getAll()
    local list = {}
    for _, spell in pairs(MagicManager.spells) do
        table.insert(list, spell)
    end
    -- 按 ID 排序
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- 初始化加载
MagicManager.load()

return MagicManager