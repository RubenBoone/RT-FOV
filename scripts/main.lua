print("[RTFOV] Loaded")

local NEW_MAX = 170.0
local NEW_MIN = 20.0

local configs = FindAllOf("SBZSettingsMenuConfig")

if not configs or #configs == 0 then
    print("[RTFOV] SBZSettingsMenuConfig not found")
    return
end

for _, config in ipairs(configs) do
    if config and config:IsValid() then
        print("[RTFOV] Config: " .. config:GetFullName())

        config.SettingsCategories:ForEach(function(_, categoryParam)
            local category = categoryParam:get()

            if category.CategoryName:ToString() == "Video" then
                print("[RTFOV] Found Video category")

                category.SettingsGroups:ForEach(function(_, groupParam)
                    local group = groupParam:get()

                    if group.GroupName:ToString() == "Camera" then
                        print("[RTFOV] Found Camera group")

                        group.Settings:ForEach(function(_, settingParam)
                            local setting = settingParam:get()

                            if setting.SettingName:ToString() == "Field Of View" then
                                print(
                                    "[RTFOV] Found FOV: "
                                    .. tostring(setting.FloatMinValue)
                                    .. " - "
                                    .. tostring(setting.FloatMaxValue)
                                )

                                setting.FloatMinValue = NEW_MIN
                                setting.FloatMaxValue = NEW_MAX

                                print(
                                    "[RTFOV] Patched FOV: "
                                    .. tostring(setting.FloatMinValue)
                                    .. " - "
                                    .. tostring(setting.FloatMaxValue)
                                )
                            end
                        end)
                    end
                end)
            end
        end)
    end
end
