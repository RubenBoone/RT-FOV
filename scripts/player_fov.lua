local FOV = {}

local patched = false

local function PatchSettings(minValue, maxValue)
    if patched then
        return true
    end

    local configs = FindAllOf("SBZSettingsMenuConfig")

    if not configs then
        return false
    end

    for _, config in ipairs(configs) do
        if config and config:IsValid() then
            config.SettingsCategories:ForEach(
                function(_, categoryParam)
                    local category = categoryParam:get()

                    if not category
                        or category.CategoryName:ToString() ~= "Video"
                    then
                        return
                    end

                    category.SettingsGroups:ForEach(
                        function(_, groupParam)
                            local group = groupParam:get()

                            if not group
                                or group.GroupName:ToString() ~= "Camera"
                            then
                                return
                            end

                            group.Settings:ForEach(
                                function(_, settingParam)
                                    local setting = settingParam:get()

                                    if setting
                                        and setting.SettingName:ToString()
                                        == "Field Of View"
                                    then
                                        setting.FloatMinValue = minValue
                                        setting.FloatMaxValue = maxValue
                                        setting.FloatIncrementValue = 1.0

                                        settingParam:set(setting)

                                        patched = true

                                        print(
                                            "[RTFOV] FOV patched: "
                                            .. tostring(minValue)
                                            .. " - "
                                            .. tostring(maxValue)
                                        )

                                        return true
                                    end
                                end
                            )
                        end
                    )
                end
            )

            if patched then
                return true
            end
        end
    end

    return false
end

function FOV.Patch(minValue, maxValue)
    if PatchSettings(minValue, maxValue) then
        return
    end

    LoopAsync(
        250,
        function()
            return PatchSettings(minValue, maxValue)
        end
    )
end

return FOV
