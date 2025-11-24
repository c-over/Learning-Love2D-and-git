-- inventory.lua
local Inventory = {}
local Player = require("player")
local Config = require("config")
local ItemManager = require("ItemManager")

-- 将物品按类别存储
Inventory.items = {
    equipment = {},
    potion = {},
    material = {},
    key_item = {}
}

-- 所有已知的类别，用于迭代和验证
Inventory.categories = {"equipment", "potion", "material", "key_item"}

function Inventory.load()
    -- 从 Config 模块获取完整的存档数据
    local save = Config.get()

    -- 情况1: 存档文件中没有 inventory 数据 (新游戏)
    if not save.inventory then
        print("未找到物品存档，正在初始化...")
        Inventory.items = {
            equipment = {},
            potion = {},
            material = {},
            key_item = {}
        }
        -- 添加初始物品
        -- Inventory:addItem(1, 3, "potion")
        Inventory:addItem(2, 1, "potion")
        Inventory:addItem(3, 5, "potion")
        Inventory:addItem(4, 1, "material")
        Inventory:addItem(5, 99, "material")
        print("初始化完成。")
    else
        -- 存档中有 inventory 数据，需要判断是旧格式还是新格式
        -- 旧格式的特征是它的第一个元素是数字键 (例如 save.inventory[1] 存在)
        if save.inventory[1] and type(save.inventory[1]) == "table" and save.inventory[1].id then
            -- 情况2: 检测到旧版（扁平）存档，需要进行迁移
            print("检测到旧版存档，正在迁移物品数据...")
            Inventory.items = { equipment = {}, potion = {}, material = {}, key_item = {} }
            for _, item in ipairs(save.inventory) do
                local category = ItemManager.getCategory(item.id)
                Inventory:addItem(item.id, item.count, category)
            end
            print("迁移完成。")
        else
            -- 情况3: 检测到新版（分类）存档，直接加载
            print("正在加载物品存档...")
            -- 直接将存档中的数据赋值给内存中的 Inventory.items
            Inventory.items = save.inventory
            -- 确保所有类别都存在，防止因存档损坏而报错
            for _, cat in ipairs(Inventory.categories) do
                Inventory.items[cat] = Inventory.items[cat] or {}
            end
            print("加载完成。")
        end
    end
    Inventory:save()
end

function Inventory:save()
    Config.updateInventory(self.items)
end

-- 核心辅助函数：在指定类别中查找物品
local function findItemInCategory(itemsTable, id, category)
    if not itemsTable[category] then return nil, nil end
    for i, item in ipairs(itemsTable[category]) do
        if item.id == id then
            return item, i
        end
    end
    return nil, nil
end

-- 添加物品 (需要指定类别)
function Inventory:addItem(id, amount, category)
    -- 如果没有指定类别，则从 ItemManager 获取
    category = category or ItemManager.getCategory(id)
    if not self.items[category] then
        self.items[category] = {}
    end

    local item, index = findItemInCategory(self.items, id, category)
    if item then
        item.count = item.count + (amount or 1)
    else
        table.insert(self.items[category], {id = id, count = amount or 1})
    end
    self:save()
end

-- 移除物品 (需要指定类别)
function Inventory:removeItem(id, amount, category)
    category = category or ItemManager.getCategory(id)
    local item, index = findItemInCategory(self.items, id, category)

    if item then
        item.count = item.count - (amount or 1)
        if item.count <= 0 then
            table.remove(self.items[category], index)
        end
        self:save()
    end
end

-- 使用物品 (需要指定类别)
function Inventory:useItem(id, amount, category)
    category = category or ItemManager.getCategory(id)
    ItemManager.use(id, Player)
    self:removeItem(id, amount or 1, category)
end

-- 新增：获取指定类别的所有物品 (已修正)
function Inventory.getItemsByCategory(category)
    -- 使用模块表名 Inventory 而不是 self
    return Inventory.items[category] or {}
end

return Inventory