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

-- [新增] 交换两个物品在总表中的位置
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

return Inventory