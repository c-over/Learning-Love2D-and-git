local Inventory = {}
local Player = require("player")
local Config = require("config")
local ItemManager = require("ItemManager")

Inventory.items = {}
Inventory.cols = 5
Inventory.rows = 4
Inventory.slotSize = 64
Inventory.margin = 10
Inventory.startX = 100
Inventory.startY = 100

function Inventory.load()
    local save = Config.get()
    if save.inventory and #save.inventory > 0 then
        Inventory.items = save.inventory
    else    --自动初始化物品
        Inventory.items = {
            {id = 1, count = 3},
            {id = 2, count = 1}
        }
        Config.updateInventory(Inventory.items)
    end
end

function Inventory:save()
    Config.updateInventory(self.items)
end

function Inventory:addItem(id, amount)
    for _, v in ipairs(self.items) do
        if v.id == id then
            v.count = v.count + (amount or 1)
            self:save()
            return
        end
    end
    table.insert(self.items, {id = id, count = amount or 1})
    self:save()
end

function Inventory:removeItem(id, amount)
    for i, v in ipairs(self.items) do
        if v.id == id then
            v.count = v.count - (amount or 1)
            if v.count <= 0 then
                table.remove(self.items, i)
            end
            self:save()
            return
        end
    end
end

function Inventory:useItem(id, amount)
    ItemManager.use(id, Player)
    self:removeItem(id, amount or 1)
end

return Inventory
