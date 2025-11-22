local EntitySpawner = {}

function EntitySpawner.new(config)
    local spawner = {
        list = {},
        spawnTimer = 0,
        config = config
    }

    -- 判断某 tile 是否已有实体
    local function existsAt(tx, ty, tileSize)
        for _, e in ipairs(spawner.list) do
            if math.floor(e.x / tileSize) == tx and math.floor(e.y / tileSize) == ty then
                return true
            end
        end
        return false
    end

    -- 在玩家周围生成实体
    function spawner.generateAroundPlayer(player, tileSize, noiseScale, wallThreshold)
        local cfg = spawner.config
        local px, py = math.floor(player.x / tileSize), math.floor(player.y / tileSize)

        -- 限制周围数量
        local nearbyCount = 0
        for _, e in ipairs(spawner.list) do
            local dx, dy = math.floor(e.x / tileSize) - px, math.floor(e.y / tileSize) - py
            if dx*dx + dy*dy <= cfg.radius*cfg.radius then
                nearbyCount = nearbyCount + 1
            end
        end
        if nearbyCount >= cfg.maxNearby then return end

        -- 按概率生成
        for ty = py - cfg.radius, py + cfg.radius do
            for tx = px - cfg.radius, px + cfg.radius do
                local dx, dy = tx - px, ty - py
                if math.abs(dx * tileSize) > cfg.noSpawnRange or math.abs(dy * tileSize) > cfg.noSpawnRange then
                    if love.math.random() < cfg.density and not cfg.isSolid(tx, ty, noiseScale, wallThreshold) then
                        if not existsAt(tx, ty, tileSize) then
                            table.insert(spawner.list, cfg.spawnFunc(tx, ty, tileSize))
                        end
                    end
                end
            end
        end
    end

    -- 更新逻辑
    function spawner.update(dt, player, tileSize, noiseScale, wallThreshold, Core)
        spawner.spawnTimer = spawner.spawnTimer + dt
        if spawner.spawnTimer >= spawner.config.spawnInterval then
            spawner.spawnTimer = 0
            spawner.generateAroundPlayer(player, tileSize, noiseScale, wallThreshold)
        end

        for _, e in ipairs(spawner.list) do
            if spawner.config.updateFunc then
                -- 明确传递参数，不用 ...
                spawner.config.updateFunc(e, dt, player, tileSize, noiseScale, wallThreshold, Core)
            end
        end

        -- 清理远离玩家
        local maxDistSq = (spawner.config.maxDistance * tileSize)^2
        local px, py = player.x, player.y
        for i = #spawner.list, 1, -1 do
            local e = spawner.list[i]
            local dx, dy = e.x - px, e.y - py
            if dx*dx + dy*dy > maxDistSq then
                table.remove(spawner.list, i)
            end
        end
    end

    -- 绘制
    function spawner.draw(camX, camY)
        for _, e in ipairs(spawner.list) do
            spawner.config.drawFunc(e, camX, camY)
        end
    end

    -- 碰撞检测
    function spawner.checkCollision(player, aabbOverlap)
        for i, e in ipairs(spawner.list) do
            local px, py = player.x - player.w/2, player.y - player.h/2
            if aabbOverlap(px, py, player.w, player.h, e.x, e.y, e.w, e.h) then
                return i, e
            end
        end
        return nil, nil
    end

    return spawner
end

return EntitySpawner
