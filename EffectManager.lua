local EffectManager = {}
local json = require("dkjson")

-- === 1. Cache ===
local definitions = {}
local activeEffects = {} 
local textureCache = {}
local audioCache = {}
local animCache = {}    

-- === 2. Initialization ===
function EffectManager.load()
    local path = "data/effects.json"
    definitions = {}
    activeEffects = {}
    animCache = {} 
    
    if love.filesystem.getInfo(path) then
        local content = love.filesystem.read(path)
        local decoded, pos, err = json.decode(content)
        if decoded then
            definitions = decoded
        else
            print("[EffectManager] JSON Error: " .. tostring(err))
        end
    end
end

-- Helper: Get Resources
local function getResources(key)
    local def = definitions[key]
    if not def then return nil end
    
    -- Image
    if not textureCache[def.sheet] then
        if love.filesystem.getInfo(def.sheet) then
            local img = love.graphics.newImage(def.sheet)
            img:setFilter("nearest", "nearest")
            textureCache[def.sheet] = img
        else
            return nil
        end
    end
    
    -- Audio
    if def.sound and not audioCache[def.sound] then
        if love.filesystem.getInfo(def.sound) then
            audioCache[def.sound] = love.audio.newSource(def.sound, "static")
        end
    end
    
    -- Quads
    if not animCache[key] and textureCache[def.sheet] then
        local img = textureCache[def.sheet]
        local quads = {}
        local imgW, imgH = img:getDimensions()
        for i = 0, def.frames - 1 do
            local x = (def.startCol + i) * def.width
            local y = def.startRow * def.height
            if x + def.width <= imgW and y + def.height <= imgH then
                table.insert(quads, love.graphics.newQuad(x, y, def.width, def.height, imgW, imgH))
            end
        end
        animCache[key] = quads
    end
    
    return textureCache[def.sheet], animCache[key], audioCache[def.sound], def
end

local function playSound(source, def)
    if not source then return end
    source:stop()
    if def.soundStart then source:seek(def.soundStart) else source:seek(0) end
    source:setVolume(def.volume or 1.0)
    source:play()
end

-- === 3. Public Interface ===

function EffectManager.getAllKeys()
    local keys = {}
    for k, _ in pairs(definitions) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

function EffectManager.getData(key)
    local img, quads, sfx, def = getResources(key)
    if img and quads then
        return {img=img, quads=quads, sfx=sfx, def=def, duration=def.duration, frames=#quads}
    end
end

-- [修改] 增加 rotation 参数
function EffectManager.spawn(name, x, y, color, scale, rotation)
    local img, quads, sfx, def = getResources(name)
    if not def then return end 
    
    if sfx then playSound(sfx, def) end
    
    table.insert(activeEffects, {
        name = name,
        img = img,
        quads = quads,
        totalFrames = def.frames,
        frameDuration = def.duration / def.frames,
        
        x = x, y = y,
        color = color or {1, 1, 1},
        scale = scale or 1,
        
        -- [修改] 优先使用传入的旋转，如果没有传入，默认为 0 (正向)
        rotation = rotation or 0, 
        
        timer = 0,
        currentFrame = 1,
        sfx = sfx, audioEndTime = def.soundDuration, audioTimer = 0
    })
end

function EffectManager.update(dt)
    for i = #activeEffects, 1, -1 do
        local e = activeEffects[i]
        e.timer = e.timer + dt
        if e.timer >= e.frameDuration then
            e.timer = e.timer - e.frameDuration
            e.currentFrame = e.currentFrame + 1
        end
        if e.sfx and e.audioEndTime then
            e.audioTimer = e.audioTimer + dt
            if e.audioTimer >= e.audioEndTime then e.sfx:stop(); e.sfx = nil end
        end
        if e.currentFrame > e.totalFrames then table.remove(activeEffects, i) end
    end
end

function EffectManager.draw(camX, camY)
    camX = camX or 0
    camY = camY or 0
    
    local oldBlend = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    
    for _, e in ipairs(activeEffects) do
        -- [Fix 2] Use raw virtual coordinates. 
        -- Since Battle.lua draws monsters in virtual coords (800x600 space),
        -- we must match that space. Do NOT use Layout.toScreen here.
        local drawX = e.x - camX
        local drawY = e.y - camY
        
        if e.img and e.quads and e.quads[e.currentFrame] then
            local q = e.quads[e.currentFrame]
            local _, _, w, h = q:getViewport()
            
            love.graphics.setColor(e.color)
            love.graphics.draw(e.img, q, 
                drawX, drawY, 
                e.rotation, 
                e.scale, e.scale, 
                w/2, h/2 -- Center origin
            )
        end
    end
    
    love.graphics.setBlendMode(oldBlend)
    love.graphics.setColor(1, 1, 1)
end

return EffectManager