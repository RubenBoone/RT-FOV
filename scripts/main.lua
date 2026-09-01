print("[RTFOV] Loaded")

local FOV = require("player_fov")
local W_FOV = require("weapon_fov")

FOV.Patch(20.0, 170.0)

LoopAsync(250, function()
    return W_FOV.Set(85.0)
end)
