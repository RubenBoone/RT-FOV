print("[RTFOV] Loaded")

local player_fov = require("player_fov")
local weapon_fov = require("weapon_fov")

player_fov.Patch(20.0, 170.0)

weapon_fov.Init()
