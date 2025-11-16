-- ItemManager.lua
local ItemManager = {}

-- 所有物品的定义表
ItemManager.definitions = {
    [1] = {
        name = "经验药水",
        icon = "assets/potion.png",
        description = "使用后提升1级",
        usable = true,
        stackable = true,
        onUse = function(player)
            player.addLevel(1)
        end
    },
    [2] = {
        name = "大经验药水",
        icon = "assets/big_potion.png",
        description = "使用后提升3级",
        usable = false,
        stackable = true,
        onUse = function(player)
            player.addLevel(3)
        end
    -- },
    -- [3] = {
    --     name = "治疗药水",
    --     icon = "assets/heal.png",
    --     usable = true,
    --     stackable = true,
    --     description = "恢复50点生命值",
    --     onUse = function(player)
    --         player.addHP(50)
    --     end
    }
}

-- 获取物品定义
function ItemManager.get(id)
    return ItemManager.definitions[id]
end

-- 使用物品
function ItemManager.use(id, player)
    local def = ItemManager.get(id)
    if def and def.onUse then
        def.onUse(player)
    end
end

return ItemManager
