local Inventory = {}
local Player = require("player")
local Config = require("config")
local ItemManager = require("ItemManager")

Inventory.items = { equipment = {}, weapon = {}, potion = {}, material = {}, key_item = {} }
Inventory.categories = {"equipment", "weapon", "potion", "material", "key_item"}

function Inventory.load()
    local save = Config.get()
    local hasSaveFile = love.filesystem.getInfo("save.json")

    if not hasSaveFile then
        print("[Inventory] 初始化新游戏物品...")
        Config.data.inventory = {}
        Inventory:addItem(1, 3, "potion")
        Inventory:addItem(2, 1, "potion")
        Inventory:addItem(3, 5, "potion")
        Inventory:addItem(4, 1, "weapon")
        Inventory:save()
        return
    end

    if not save.inventory then save.inventory = {} end
    print(string.format("[Inventory] 加载成功: %d 物品", #save.inventory))
end

function Inventory:save()
    Config.updateInventory(Config.data.inventory)
end

function Inventory.getItemsByCategory(category)
    local list = {}
    if not Config.data.inventory then Config.data.inventory = {} end
    
    for _, item in pairs(Config.data.inventory) do
        local def = ItemManager.get(item.id)
        -- 兼容旧数据：如果没有category，尝试获取默认
        local itemCat = def and def.category or "material"
        if itemCat == category then
            table.insert(list, item)
        end
    end
    -- [关键修改] 移除 table.sort，允许玩家手动整理背包顺序
    return list
end

function Inventory:addItem(id, count, category)
    if not Config.data.inventory then Config.data.inventory = {} end
    local def = ItemManager.get(id)
    if not def then return end

    if def.stackable then
        for _, item in ipairs(Config.data.inventory) do
            if item.id == id then
                item.count = item.count + count
                Config.save()
                return
            end
        end
    end

    local newItem = { id = id, count = count, equipSlot = nil }
    table.insert(Config.data.inventory, newItem)
    Config.save() -- 自动保存
end

function Inventory:removeItem(id, count, category)
    if not Config.data.inventory then return end
    
    for i = #Config.data.inventory, 1, -1 do
        local item = Config.data.inventory[i]
        if item.id == id then
            if item.count > count then
                item.count = item.count - count
            else
                table.remove(Config.data.inventory, i)
            end
            Config.save()
            return
        end
    end
end

function Inventory:useItem(id, amount, category)
    category = category or ItemManager.getCategory(id)
    ItemManager.use(id, Player)
    self:removeItem(id, amount or 1, category)
end

-- 交换两个物品在总表中的位置
function Inventory:swapItems(itemA, itemB)
    local list = Config.data.inventory
    local indexA, indexB = nil, nil
    
    -- 在总表中寻找这两个对象的索引
    for i, item in ipairs(list) do
        if item == itemA then indexA = i end
        if item == itemB then indexB = i end
    end
    
    if indexA and indexB then
        list[indexA], list[indexB] = list[indexB], list[indexA]
        Config.save() -- 交换后立即保存顺序
    end
end

-- 背包整理 (排序)
function Inventory:sort()
    if not Config.data.inventory then return end
    
    table.sort(Config.data.inventory, function(a, b)
        -- 1. 已装备的排在最前面
        if a.equipSlot and not b.equipSlot then return true end
        if not a.equipSlot and b.equipSlot then return false end
        
        -- 2. 按 ID 排序 (ID通常对应了种类)
        if a.id ~= b.id then
            return a.id < b.id
        end
        
        -- 3. 按数量排序
        return a.count > b.count
    end)
    
    Config.save()
end

-- 出售重复装备 (保留一件，出售其余)
-- 返回值: 出售获得的总金币数, 出售的件数
function Inventory:sellDuplicateEquipment()
    local inventory = Config.data.inventory
    local ItemManager = require("ItemManager")
    local totalGold = 0
    local soldCount = 0
    
    -- 记录已保留的装备ID
    local keptIds = {}
    
    -- 倒序遍历以便安全移除
    for i = #inventory, 1, -1 do
        local item = inventory[i]
        local def = ItemManager.get(item.id)
        
        -- 只处理装备和武器
        if def and (def.category == "equipment" or def.category == "weapon") then
            -- 如果已装备，强制保留
            if item.equipSlot then
                keptIds[item.id] = true
            else
                -- 如果之前没遇到过这个ID，且当前也没装备这个ID，则保留这第一件
                if not keptIds[item.id] then
                    keptIds[item.id] = true
                else
                    -- 已经有了一件(或者身上穿着一件)，这件是多余的 -> 卖掉
                    -- 卖出价通常是原价的一半
                    local price = math.floor((def.price or 0) * 0.5)
                    totalGold = totalGold + price
                    
                    table.remove(inventory, i)
                    soldCount = soldCount + 1
                end
            end
        end
    end
    
    if soldCount > 0 then
        local Player = require("player")
        Player.addGold(totalGold)
        Config.save()
    end
    
    return totalGold, soldCount
end

return Inventory