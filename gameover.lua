-- gameover.lua
local Layout = require("layout")
local Config = require("config")
local Player = require("player")

local GameOver = {}
GameOver.buttons = {}

function GameOver.load()
    local btnW, btnH = 200, 50
    local startX = (Layout.virtualWidth - btnW) / 2
    local startY = Layout.virtualHeight - 150

    GameOver.buttons = {
        {
            x = startX, y = startY, w = btnW, h = btnH,
            text = "重生 (回到标题)",
            onClick = function()
                -- 1. 恢复状态
                Player.data.hp = Player.data.maxHp
                Player.data.mp = Player.data.maxMp
                -- 回到出生点 (假设为 0,0 或读取 respawnX)
                Player.data.x = Player.data.respawnX or 0
                Player.data.y = Player.data.respawnY or 0
                
                -- 2. 保存并返回标题
                Config.save()
                currentScene = "title"
            end
        }
    }
end

function GameOver.draw()
    local w, h = love.graphics.getDimensions()
    
    -- 1. 红色半透明背景
    love.graphics.setColor(0.2, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- 2. 大标题 "YOU DIED"
    local vCx, vCy = Layout.virtualWidth / 2, Layout.virtualHeight / 3
    local sCx, sCy = Layout.toScreen(vCx, vCy)
    
    love.graphics.setFont(Fonts.title)
    love.graphics.setColor(0.8, 0, 0)
    love.graphics.printf("胜 败 乃 兵 家 常 事", 0, sCy, w, "center")
    
    -- 3. 显示死亡次数
    love.graphics.setFont(Fonts.medium)
    love.graphics.setColor(1, 1, 1)
    local deathCount = Player.data.deathCount or 0
    love.graphics.printf("当前轮回次数: " .. deathCount, 0, sCy + 60, w, "center")
    
    -- 4. 惩罚提示
    love.graphics.setFont(Fonts.normal)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("由于世界线的变动，怪物变强了，物价也上涨了...", 0, sCy + 100, w, "center")

    -- 5. 按钮
    local hovered = Layout.mousemoved(love.mouse.getX(), love.mouse.getY(), GameOver.buttons)
    for i, btn in ipairs(GameOver.buttons) do
        local bx, by = Layout.toScreen(btn.x, btn.y)
        local bw, bh = Layout.toScreen(btn.w, btn.h)
        
        if i == hovered then
            love.graphics.setColor(0.8, 0.2, 0.2)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", bx, by, bw, bh, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bx, by, bw, bh, 8)
        
        -- 文字居中
        local font = love.graphics.getFont()
        love.graphics.printf(btn.text, bx, by + (bh - font:getHeight())/2, bw, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function GameOver.mousepressed(x, y, button)
    Layout.mousepressed(x, y, button, GameOver.buttons)
end

return GameOver