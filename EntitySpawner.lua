local EntitySpawner = {}

function EntitySpawner.new(config)
    local spawner = {
        list = {},
        spawnTimer = 0,
        config = config
    }

    -- 判断某 tile 是否已有实体（防止重叠生成）
    local function existsAt(tx, ty, tileSize)
        for _, e in ipairs(spawner.list) do
            -- 简单的网格坐标对比
            local ex = math.floor((e.x + e.w/2) / tileSize)
            local ey = math.floor((e.y + e.h/2) / tileSize)
            if ex == tx and ey == ty then
                return true
            end
        end
        return false
    end

    -- [核心修改] 在玩家周围尝试生成实体
    function spawner.generateAroundPlayer(player, tileSize)
        local cfg = spawner.config
        
        -- 获取玩家所在的网格坐标
        local px = math.floor(player.x / tileSize)
        local py = math.floor(player.y / tileSize)

        -- 1. 统计当前视野内的实体数量
        local nearbyCount = 0
        local removalThresholdSq = (cfg.maxDistance * tileSize)^2 -- 预计算距离平方

        for i = #spawner.list, 1, -1 do
            local e = spawner.list[i]
            local dx = e.x - player.x
            local dy = e.y - player.y
            local distSq = dx*dx + dy*dy

            -- [优化] 同时在这里做清理工作，减少遍历次数
            if distSq > removalThresholdSq then
                table.remove(spawner.list, i)
            else
                -- 如果在生成半径内，计入数量
                if distSq <= (cfg.radius * tileSize)^2 then
                    nearbyCount = nearbyCount + 1
                end
            end
        end

        -- 如果周围怪太多，这就停止生成
        if nearbyCount >= cfg.maxNearby then return end

        -- 2. [核心优化] 随机尝试 N 次，而不是遍历所有格子
        -- 尝试次数越多，生成越快；尝试次数少，生成越稀疏
        local attempts = 10 
        
        while attempts > 0 and nearbyCount < cfg.maxNearby do
            attempts = attempts - 1

            -- 在 radius 范围内随机选一个点
            local tx = px + love.math.random(-cfg.radius, cfg.radius)
            local ty = py + love.math.random(-cfg.radius, cfg.radius)

            -- 计算该点距离玩家的像素距离
            local worldX = tx * tileSize
            local worldY = ty * tileSize
            local dx = math.abs(worldX - player.x)
            local dy = math.abs(worldY - player.y)

            -- [解决屏幕内生成] 检查是否在安全区(屏幕)外
            -- 逻辑：X轴距离 > 安全区 OR Y轴距离 > 安全区
            if dx > cfg.noSpawnRange or dy > cfg.noSpawnRange then
                
                -- [解决碰撞生成] 检查是否是实心方块
                -- 优先使用 config 里的 isSolid，如果没有则假设为空
                local isSolid = false
                if cfg.isSolid then
                    isSolid = cfg.isSolid(tx, ty)
                end

                if not isSolid and not existsAt(tx, ty, tileSize) then
                    -- 再次进行概率判定 (控制稀有度)
                    if love.math.random() < (cfg.density * 10) then 
                        -- 注意：因为我们从遍历改为了随机尝试，density的含义变了
                        -- 这里乘以10是为了补偿尝试次数减少带来的概率降低
                        
                        table.insert(spawner.list, cfg.spawnFunc(tx, ty, tileSize))
                        nearbyCount = nearbyCount + 1
                    end
                end
            end
        end
    end

    -- 更新逻辑
    function spawner.update(dt, player, tileSize, Core) -- Core 参数其实这里没用到，主要看 spawnFunc 需不需要
        spawner.spawnTimer = spawner.spawnTimer + dt
        
        -- 生成逻辑
        if spawner.spawnTimer >= spawner.config.spawnInterval then
            spawner.spawnTimer = 0
            -- 注意：generateAroundPlayer 内部现在处理了清理逻辑，所以不需要外部再清理
            spawner.generateAroundPlayer(player, tileSize)
        end

        -- 更新所有实体的行为
        for _, e in ipairs(spawner.list) do
            if spawner.config.updateFunc then
                spawner.config.updateFunc(e, dt, player, tileSize, Core)
            end
            if e.life and e.life < 0 then
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

    -- 碰撞检测 (保持不变)
    function spawner.checkCollision(player, aabbOverlap)
        for i, e in ipairs(spawner.list) do
            -- 确保 player 有数据，防止报错
            local pData = player.data or player
            local px, py = pData.x, pData.y
            -- 有些怪物中心点在脚下，有些在左上角，这里假设都是左上角
            if aabbOverlap(px, py, player.w or 32, player.h or 32, e.x, e.y, e.w, e.h) then
                return i, e
            end
        end
        return nil, nil
    end
    return spawner
end

return EntitySpawner