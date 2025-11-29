function love.conf(t)
    t.window.title = "My RPG Game"
    t.window.icon = "assets/gameicon.png"
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = true -- 允许调整大小
    t.window.minwidth = 800
    t.window.minheight = 600
    t.window.vsync = true     -- 垂直同步，防止画面撕裂
    t.console = true          -- 开启控制台（方便调试，发布时可关）
end