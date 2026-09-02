print("[RTFOV] Loaded")

local FOV = require("player_fov")
local WeaponFOV = require("weapon_fov")
local WeaponFOVUI = require("weapon_fov_ui")

FOV.Patch(20.0, 170.0)

WeaponFOV.Init()
WeaponFOVUI.Init()
