local EntitySpawner = {}

function EntitySpawner.new(config)
    local spawner = {
        list = {},
        spawnTimer = 0,
        config = config
    }

    local function existsAt(tx, ty, tileSize)
        for _, e in ipairs(spawner.list) do
            local ex = math.floor((e.x + e.w/2) / tileSize)
            local ey = math.floor((e.y + e.h/2) / tileSize)
            if ex == tx and ey == ty then return true end
        end
        return false
    end

    -- [关键点 1] 生成逻辑中的清理
    function spawner.generateAroundPlayer(player, tileSize)
        local cfg = spawner.config
        local pData = player.data or player
        local px = math.floor(pData.x / tileSize)
        local py = math.floor(pData.y / tileSize)
        
        local removalThresholdSq = (cfg.maxDistance * tileSize)^2

        -- 1. 清理远处实体
        for i = #spawner.list, 1, -1 do
            local e = spawner.list[i]
            local dx = e.x - pData.x
            local dy = e.y - pData.y
            local distSq = dx*dx + dy*dy

            -- [修复 A] 这里也必须保护 BOSS！
            if distSq > removalThresholdSq then
                if e.isBoss then
                    -- print("[Spawner] 保护 BOSS 免于生成前清理")
                else
                    -- print("[Spawner] 清理远处实体 (生成前): " .. (e.name or "???"))
                    table.remove(spawner.list, i)
                end
            end
        end

        -- 2. 统计数量 (BOSS 不应该占用普通怪的生成名额，这里看你需求，通常计入总数)
        local nearbyCount = #spawner.list
        if nearbyCount >= cfg.maxNearby then return end

        -- 3. 尝试生成
        local attempts = 10 
        while attempts > 0 and nearbyCount < cfg.maxNearby do
            attempts = attempts - 1
            local tx = px + love.math.random(-cfg.radius, cfg.radius)
            local ty = py + love.math.random(-cfg.radius, cfg.radius)
            local worldX = tx * tileSize
            local worldY = ty * tileSize
            local dx = math.abs(worldX - pData.x)
            local dy = math.abs(worldY - pData.y)

            if dx > cfg.noSpawnRange or dy > cfg.noSpawnRange then
                local isSolid = false
                if cfg.isSolid then isSolid = cfg.isSolid(tx, ty) end

                if not isSolid and not existsAt(tx, ty, tileSize) then
                    if love.math.random() < (cfg.density * 10) then 
                        table.insert(spawner.list, cfg.spawnFunc(tx, ty, tileSize))
                        nearbyCount = nearbyCount + 1
                    end
                end
            end
        end
    end

    -- [关键点 2] 更新逻辑中的清理
    function spawner.update(dt, player, tileSize, Core)
        spawner.spawnTimer = spawner.spawnTimer + dt
        
        if spawner.spawnTimer >= spawner.config.spawnInterval then
            spawner.spawnTimer = 0
            spawner.generateAroundPlayer(player, tileSize)
        end

        local pData = player.data or player
        local removalThresholdSq = (spawner.config.maxDistance * tileSize)^2 

        for i = #spawner.list, 1, -1 do
            local e = spawner.list[i]
            
            -- 更新逻辑
            if spawner.config.updateFunc then
                spawner.config.updateFunc(e, dt, player, tileSize, Core)
            end
            
            -- 距离检查
            local dx = e.x - pData.x
            local dy = e.y - pData.y
            local distSq = dx*dx + dy*dy

            -- [修复 B] 再次保护 BOSS
            if distSq > removalThresholdSq then
                if e.isBoss then
                    -- print("[Spawner] 保护 BOSS 免于距离清理")
                else
                    -- print("[Spawner] 距离过远移除: " .. (e.name or "???"))
                    table.remove(spawner.list, i)
                end
            else
                -- 死亡移除 (注意: BOSS 死亡通常由 Battle 模块移除，这里是兜底)
                -- 如果 BOSS 死了，这里可以移除
                if e.life and e.life < 0 then
                    print("[Spawner] 实体生命耗尽移除: " .. (e.name or "???"))
                    table.remove(spawner.list, i)
                end
            end
        end
    end

    function spawner.draw(camX, camY)
        for _, e in ipairs(spawner.list) do
            spawner.config.drawFunc(e, camX, camY)
        end
    end

    function spawner.checkCollision(player, aabbOverlap)
        for i, e in ipairs(spawner.list) do
            local pData = player.data or player
            if aabbOverlap(pData.x, pData.y, player.w or 32, player.h or 32, e.x, e.y, e.w, e.h) then
                return i, e
            end
        end
        return nil, nil
    end

    return spawner
end

return EntitySpawner