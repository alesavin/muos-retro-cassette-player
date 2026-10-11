dofile(os.getenv("GAME") .. "/conf.lua")
local c = love.conf
love.conf = function(t) c(t); t.identity = "rc-harness"; t.window.vsync = 0 end
