local WeaponFOV = {}

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local MIN_VALUE = 20.0
local MAX_VALUE = 90.0
local DEFAULT_VALUE = 55.0

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local currentValue = DEFAULT_VALUE
local cachedPlayer = nil

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function Clamp(value)
    return math.max(
        MIN_VALUE,
        math.min(MAX_VALUE, value)
    )
end

local function GetConfigPath()
    local source = debug.getinfo(1, "S").source

    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    local scriptsDir =
        source:match(
            "^(.*)[/\\][^/\\]+$"
        )

    if not scriptsDir then
        return "weapon_fov.cfg"
    end

    local modDir =
        scriptsDir:match(
            "^(.*)[/\\]Scripts$"
        )

    if not modDir then
        modDir = scriptsDir
    end

    return modDir .. "\\weapon_fov.cfg"
end

------------------------------------------------------------
-- SAVE / LOAD
------------------------------------------------------------

local function LoadValue()
    local file = io.open(
        GetConfigPath(),
        "r"
    )

    if not file then
        return DEFAULT_VALUE
    end

    local value =
        tonumber(
            file:read("*a")
        )

    file:close()

    if not value then
        return DEFAULT_VALUE
    end

    return Clamp(value)
end

local function SaveValue()
    local file = io.open(
        GetConfigPath(),
        "w"
    )

    if not file then
        print(
            "[RTFOV] Could not save Weapon FOV"
        )

        return false
    end

    file:write(
        tostring(currentValue)
    )

    file:close()

    return true
end

------------------------------------------------------------
-- PLAYER
------------------------------------------------------------

local function GetPlayer()
    local controllers = FindAllOf("BP_PlayerController_C")

    if controllers then
        for _, controller in ipairs(controllers) do
            if controller
                and controller:IsValid()
                and controller.AcknowledgedPawn
                and controller.AcknowledgedPawn:IsValid()
            then
                local pawn = controller.AcknowledgedPawn

                return pawn
            end
        end
    end

    return nil
end

------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------

function WeaponFOV.Get()
    return currentValue
end

function WeaponFOV.GetMin()
    return MIN_VALUE
end

function WeaponFOV.GetMax()
    return MAX_VALUE
end

function WeaponFOV.Set(value, save)
    value = tonumber(value)

    if not value then
        return false
    end

    value = Clamp(value)

    local changed =
        math.abs(
            value - currentValue
        ) > 0.001

    currentValue = value

    local player = GetPlayer()

    if player then
        player.OnTopBaseFOV =
            currentValue
    end

    if save and changed then
        SaveValue()
    end

    return player ~= nil
end

------------------------------------------------------------
-- KEEP WEAPON FOV APPLIED
------------------------------------------------------------

local function StartWatcher()
    LoopAsync(
        16,

        function()
            local player = GetPlayer()

            if player then
                player.OnTopBaseFOV =
                    currentValue
            end

            return false
        end
    )
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function WeaponFOV.Init()
    currentValue = LoadValue()

    StartWatcher()

    WeaponFOV.Set(
        currentValue,
        false
    )

    print(
        "[RTFOV] Weapon FOV initialized at "
        .. tostring(currentValue)
    )
end

return WeaponFOV
