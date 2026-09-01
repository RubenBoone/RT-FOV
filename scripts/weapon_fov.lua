local WeaponFOV = {}

function WeaponFOV.Set(value)
    local players = FindAllOf("SBZPlayerCharacter")

    if not players or #players == 0 then
        return false
    end

    for _, player in ipairs(players) do
        if player and player:IsValid() then
            player.OnTopBaseFOV = value

            print(
                "[RTFOV] Weapon FOV set to "
                .. tostring(value)
            )
        end
    end

    return true
end

return WeaponFOV
