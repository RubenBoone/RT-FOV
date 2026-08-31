print("[RTFOV] Loaded")

local NEW_MAX = 170.0
local NEW_MIN = 20.0

local patched = false

local function PatchPlayerFOV()
    if patched then
        return true
    end

    local configs = FindAllOf("SBZSettingsMenuConfig")

    if not configs or #configs == 0 then
        print("[RTFOV] SBZSettingsMenuConfig not found")
        return false
    end

    for _, config in ipairs(configs) do
        if config and config:IsValid() then
            print("[RTFOV] Config: " .. config:GetFullName())

            config.SettingsCategories:ForEach(function(_, categoryParam)
                local category = categoryParam:get()

                if category.CategoryName:ToString() == "Video" then

                    category.SettingsGroups:ForEach(function(_, groupParam)
                        local group = groupParam:get()

                        if group.GroupName:ToString() == "Camera" then

                            group.Settings:ForEach(function(_, settingParam)
                                local setting = settingParam:get()

                                if setting.SettingName:ToString() == "Field Of View" then

                                    setting.FloatMinValue = NEW_MIN
                                    setting.FloatMaxValue = NEW_MAX

                                    print(
                                        "[RTFOV] Patched FOV: "
                                        .. tostring(setting.FloatMinValue)
                                        .. " - "
                                        .. tostring(setting.FloatMaxValue)
                                    )
                                    patched = true
                                end
                            end)
                        end
                    end)
                end
            end)
        end
    end

    return patched
end

if not PatchPlayerFOV() then
    LoopAsync(250, function ()
        return PatchPlayerFOV()
    end)
end

local OFFSET = 10.0

local players = FindAllOf("SBZPlayerCharacter")

for _, player in ipairs(players or {}) do
    if player and player:IsValid() and player.FPCameraAttachment then
        local fp = player.FPCameraAttachment

        if fp.EquippedWeaponData then
            local weaponData = fp.EquippedWeaponData

            local hip = weaponData.DefaultHandRigTransform
            hip.Translation.X = hip.Translation.X + OFFSET
            weaponData.DefaultHandRigTransform = hip

            print("[RTFOV] Hip offset applied: +" .. tostring(OFFSET))
        end

        if fp.EquippedTargetingData then
            local targeting = fp.EquippedTargetingData

            print(
                "[RTFOV] TargetingXAxisOffset before: "
                .. tostring(targeting.TargetingXAxisOffset)
            )

            targeting.TargetingXAxisOffset =
                targeting.TargetingXAxisOffset + OFFSET

            print(
                "[RTFOV] TargetingXAxisOffset after: "
                .. tostring(targeting.TargetingXAxisOffset)
            )
        end
    end
end
