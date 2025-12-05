local Crafting = {}
local Inventory = require("inventory")
local ItemManager = require("ItemManager")
local Config = require("config")
local json = require("dkjson")

Crafting.recipes = {}

-- === 1. 加载配方 ===
function Crafting.load()
    local path = "data/recipes.json"
    if love.filesystem.getInfo(path) then
        local content = love.filesystem.read(path)
        -- decode 返回的直接是数组表
        Crafting.recipes = json.decode(content)
        print("[Crafting] Loaded " .. #Crafting.recipes .. " recipes.")
    else
        print("[Crafting] Error: recipes.json not found!")
        Crafting.recipes = {}
    end
end

-- === 2. 检查配方可见性 ===
-- 规则：Debug模式可见 OR 背包里拥有至少一种该配方所需的材料
function Crafting.isRecipeVisible(recipe)
    if debugMode then return true end
    
    local inventory = Config.data.inventory
    for _, mat in ipairs(recipe.materials) do
        -- 遍历背包看有没有这个材料（数量 > 0）
        for _, item in ipairs(inventory) do
            if item.id == mat.id and item.count > 0 then
                return true
            end
        end
    end
    return false
end

-- === 3. 检查是否可制作 (材料足够) ===
function Crafting.canCraft(recipe)
    -- Debug 模式下永远可以制作，忽略材料限制
    if debugMode then return true end

    local inventoryData = Config.data.inventory
    for _, mat in ipairs(recipe.materials) do
        local hasCount = 0
        for _, item in ipairs(inventoryData) do
            if item.id == mat.id then
                hasCount = hasCount + item.count
            end
        end
        if hasCount < mat.count then
            return false -- 材料不足
        end
    end
    return true
end

-- === 4. 执行合成 ===
function Crafting.craft(recipe)
    if not Crafting.canCraft(recipe) then return false, "材料不足" end
    
    local resDef = ItemManager.get(recipe.resultId)
    
    -- 1. 消耗材料 (Debug 模式不消耗)
    if not debugMode then
        for _, mat in ipairs(recipe.materials) do
            local cat = ItemManager.getCategory(mat.id)
            Inventory:removeItem(mat.id, mat.count, cat)
        end
    end
    
    -- 2. 获得产物
    local resCat = resDef.category or "material"
    Inventory:addItem(recipe.resultId, recipe.count, resCat)
    
    local msg = "合成成功: " .. resDef.name
    if debugMode then msg = "[Debug] 免费合成: " .. resDef.name end
    
    return true, msg
end

return Crafting