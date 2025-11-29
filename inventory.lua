-- inventory.lua
local Inventory = {}
local Player = require("player")
local Config = require("config")
local ItemManager = require("ItemManager")

-- 将物品按类别存储
Inventory.items = {
    weapon = {},
    equipment = {},
    potion = {},
    material = {},
    key_item = {}
}

-- 所有已知的类别，用于迭代和验证
Inventory.categories = {"weapon","equipment", "potion", "material", "key_item"}

function Inventory.load()
    local save = Config.get()
    -- 使用 love.filesystem 判断是否存在存档文件，这是判断“新游戏”最准确的方法
    local hasSaveFile = love.filesystem.getInfo("save.json")

    -- === 情况 1: 新游戏初始化 ===
    if not hasSaveFile then
        print("[Inventory] 未找到存档文件，正在初始化新游戏物品...")
        
        -- 确保背包是空的
        Config.data.inventory = {}
        
        -- 发放新手大礼包
        Inventory:addItem(1, 3, "potion")    -- 治疗药水 x3
        Inventory:addItem(2, 1, "potion")    -- 魔力药水 x1
        Inventory:addItem(3, 5, "potion")    -- 经验药水 x5
        Inventory:addItem(4, 1, "equipment") -- 锚 x1
        Inventory:addItem(5, 99, "material") -- 金币 x99 (ID:5 是金币)
        
        print("[Inventory] 新游戏物品发放完毕。")
        -- 立即保存一次，确保下次启动能识别为“有存档”
        Inventory:save()
        return
    end

    -- === 情况 2: 读取现有存档 ===
    -- 代码走到这里，说明 save.json 存在，且 Config.load() 已经把数据读进 Config.data.inventory 了。
    -- 我们不需要做任何“迁移”或“循环添加”，直接使用 Config 里的数据即可。
    
    -- 简单的完整性检查：确保 inventory 字段是一个表
    if not save.inventory then
        save.inventory = {}
    end

    print(string.format("[Inventory] 存档加载成功，当前背包共有 %d 格物品。", #save.inventory))
    
    -- [可选] 可以在这里遍历一下背包，剔除一些非法物品（比如 ID 不存在的），防止报错
    -- for i = #save.inventory, 1, -1 do
    --     local item = save.inventory[i]
    --     if not require("ItemManager").get(item.id) then
    --         table.remove(save.inventory, i)
    --     end
    -- end
    for _, cat in ipairs(Inventory.categories) do
        Inventory.items[cat] = Inventory.items[cat] or {}
    end
end

function Inventory:save()
    Config.updateInventory(self.items)
end

-- 核心辅助函数：在指定类别中查找物品
function Inventory.getItemsByCategory(category)
    local list = {}
    if not Config.data.inventory then Config.data.inventory = {} end
    
    for _, item in pairs(Config.data.inventory) do
        local def = ItemManager.get(item.id)
        if def and def.category == category then
            table.insert(list, item)
        end
    end
    table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return list
end

function Inventory:addItem(id, count, category)
    if not Config.data.inventory then Config.data.inventory = {} end
    local def = ItemManager.get(id)
    if not def then return end

    -- [调试] 打印添加操作
    print(string.format("[Inventory] 请求添加物品 ID:%d (%s) 数量:%d | 堆叠:%s", 
        id, def.name, count, tostring(def.stackable)))

    -- 1. 堆叠逻辑
    if def.stackable then
        for _, item in ipairs(Config.data.inventory) do
            if item.id == id then
                item.count = item.count + count
                print(string.format("  -> 已合并，当前数量: %d", item.count))
                Config.save()
                return
            end
        end
    end

    -- 2. 新增逻辑
    for i = 1, count do
        local newItem = {
            id = id,
            count = 1,
            equipped = false
        }
        table.insert(Config.data.inventory, newItem)
        print("  -> 新格子已创建")
    end
    
    print(string.format("[Inventory] 添加后背包总数: %d", #Config.data.inventory))
    -- Config.save()
end

function Inventory:removeItem(id, count, category)
    if not Config.data.inventory then return end
    print(string.format("[Inventory] 移除物品 ID:%d 数量:%d", id, count))
    
    for i = #Config.data.inventory, 1, -1 do
        local item = Config.data.inventory[i]
        if item.id == id then
            if item.count > count then
                item.count = item.count - count
                print("  -> 数量减少")
            else
                table.remove(Config.data.inventory, i)
                print("  -> 格子移除")
            end
            Config.save()
            return
        end
    end
end
-- 使用物品 (需要指定类别)
function Inventory:useItem(id, amount, category)
    category = category or ItemManager.getCategory(id)
    ItemManager.use(id, Player)
    self:removeItem(id, amount or 1, category)
end

return Inventory