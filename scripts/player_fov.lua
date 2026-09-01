local FOV = {}

function FOV.Patch(minValue, maxValue)
    local patched = false

    local function PatchPlayerFOV()
        if patched then
            return true
        end

        local configs = FindAllOf("SBZSettingsMenuConfig")

        if not configs or #configs == 0 then
            return false
        end

        for _, config in ipairs(configs) do
            if config and config:IsValid() then
                config.SettingsCategories:ForEach(function(_, categoryParam)
                    local category = categoryParam:get()

                    if category.CategoryName:ToString() == "Video" then
                        category.SettingsGroups:ForEach(function(_, groupParam)
                            local group = groupParam:get()

                            if group.GroupName:ToString() == "Camera" then
                                group.Settings:ForEach(function(_, settingParam)
                                    local setting = settingParam:get()

                                    if setting.SettingName:ToString() == "Field Of View" then
                                        setting.FloatMinValue = minValue
                                        setting.FloatMaxValue = maxValue

                                        settingParam:set(setting)

                                        print(
                                            "[RTFOV] FOV patched: "
                                            .. tostring(minValue)
                                            .. " - "
                                            .. tostring(maxValue)
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
        LoopAsync(250, function()
            return PatchPlayerFOV()
        end)
    end
end

return FOV
