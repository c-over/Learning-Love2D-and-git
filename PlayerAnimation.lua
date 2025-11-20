-- PlayerAnimation.lua
local PlayerAnimation = {}

local directions = { "down", "up", "right", "left" }

-- 允许在外部传入真实的行顺序映射，例如：
-- PlayerAnimation.load(idlePath, walkPath, frameW, frameH, {"down","right","left","up"})
function PlayerAnimation.load(idlePath, walkPath, frameW, frameH, dirOrder)
    local order = dirOrder or directions

    local function loadSheet(path)
        local sheet = love.graphics.newImage(path)
        local quads = {}
        for row, dir in ipairs(order) do
            quads[dir] = {}
            -- 列数用 floor，避免非整除带来的半帧/越界
            local cols = math.floor(sheet:getWidth() / frameW)
            for col = 0, cols - 1 do
                local quad = love.graphics.newQuad(
                    col * frameW,
                    (row - 1) * frameH,
                    frameW, frameH,
                    sheet:getDimensions()
                )
                table.insert(quads[dir], quad)
            end
        end
        return sheet, quads
    end

    local idleSheet, idleQuads = loadSheet(idlePath)
    local walkSheet, walkQuads = loadSheet(walkPath)

    return {
        idleSheet = idleSheet,
        idleQuads = idleQuads,
        walkSheet = walkSheet,
        walkQuads = walkQuads,
        frameW = frameW,
        frameH = frameH,
        frame = 1,
        timer = 0,
        interval = 0.15,
        dir = "down",
        state = "idle"  -- 新增：当前状态集（"idle" 或 "walk"）
    }
end


function PlayerAnimation.update(anim, dt, isMoving)
    anim.timer = anim.timer + dt

    local nextState = isMoving and "walk" or "idle"
    if anim.state ~= nextState then
        -- 切换帧集时重置帧和计时器，避免跨集索引越界或停顿
        anim.state = nextState
        anim.frame = 1
        anim.timer = 0
    end

    local quads = (anim.state == "walk") and anim.walkQuads or anim.idleQuads
    local dir = anim.dir

    -- 如果当前方向不存在（素材与映射不一致），回退到 "down"
    if not quads[dir] then
        dir = "down"
    end

    local maxFrame = #quads[dir]
    if maxFrame > 0 and anim.timer > anim.interval then
        anim.frame = (anim.frame % maxFrame) + 1
        anim.timer = 0
    end

    if anim.frame > maxFrame then
        anim.frame = 1
    end
end



function PlayerAnimation.draw(anim, x, y, isMoving)
    love.graphics.setColor(1, 1, 1)

    local quads = (anim.state == "walk") and anim.walkQuads or anim.idleQuads
    local sheet = (anim.state == "walk") and anim.walkSheet or anim.idleSheet
    local dir = anim.dir
    local frame = anim.frame

    -- 保底：方向缺失时用 "down"
    if not quads[dir] then
        dir = "down"
    end

    local quad
    if dir == "left" then
        -- 统一用右方向的帧镜像，原点使用帧宽，避免位移抖动或偶发消失
        quad = quads["right"] and quads["right"][frame]
        if quad then
            love.graphics.draw(sheet, quad, x, y, 0, -1, 1, anim.frameW, 0)
            return
        end
    else
        quad = quads[dir] and quads[dir][frame]
        if quad then
            love.graphics.draw(sheet, quad, x, y)
            return
        end
    end

    -- 一级回退：该方向的第一帧
    if quads[dir] and quads[dir][1] then
        if dir == "left" then
            local q = quads["right"] and quads["right"][1]
            if q then love.graphics.draw(sheet, q, x, y, 0, -1, 1, anim.frameW, 0); return end
        else
            love.graphics.draw(sheet, quads[dir][1], x, y); return
        end
    end

    -- 二级回退：任意方向的第一帧（确保永不空绘）
    for _, d in ipairs({"down","right","up","left"}) do
        if quads[d] and quads[d][1] then
            if d == "left" then
                local q = quads["right"] and quads["right"][1]
                if q then love.graphics.draw(sheet, q, x, y, 0, -1, 1, anim.frameW, 0); return end
            else
                love.graphics.draw(sheet, quads[d][1], x, y); return
            end
        end
    end
end

return PlayerAnimation
