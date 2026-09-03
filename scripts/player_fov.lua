local FOV = {}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function IsUsableObject(object)
    if not object then
        return false
    end

    local ok, valid =
        pcall(function()
            return object:IsValid()
        end)

    return ok
        and valid == true
end

------------------------------------------------------------
-- PATCH NATIVE PLAYER FOV SETTING
------------------------------------------------------------

local function TryPatch(minValue, maxValue)
    local configs =
        FindAllOf(
            "SBZSettingsMenuConfig"
        )

    if not configs then
        return false
    end

    for _, config in ipairs(configs) do
        if IsUsableObject(config) then
            local patched = false

            local configOk =
                pcall(function()
                    config.SettingsCategories:
                        ForEach(
                            function(
                                _,
                                categoryParam
                            )
                                if patched then
                                    return true
                                end

                                local category =
                                    categoryParam:get()

                                if not category then
                                    return
                                end

                                local categoryOk,
                                    categoryName =
                                    pcall(function()
                                        return category.CategoryName:
                                            ToString()
                                    end)

                                if not categoryOk
                                    or categoryName ~= "Video"
                                then
                                    return
                                end

                                category.SettingsGroups:
                                    ForEach(
                                        function(
                                            _,
                                            groupParam
                                        )
                                            if patched then
                                                return true
                                            end

                                            local group =
                                                groupParam:get()

                                            if not group then
                                                return
                                            end

                                            group.Settings:
                                                ForEach(
                                                    function(
                                                        _,
                                                        settingParam
                                                    )
                                                        if patched then
                                                            return true
                                                        end

                                                        local setting =
                                                            settingParam:get()

                                                        if not setting then
                                                            return
                                                        end

                                                        local nameOk,
                                                            settingName =
                                                            pcall(function()
                                                                return setting.SettingName:
                                                                    ToString()
                                                            end)

                                                        if nameOk
                                                            and settingName == "Field Of View"
                                                        then
                                                            setting.FloatMinValue =
                                                                minValue

                                                            setting.FloatMaxValue =
                                                                maxValue

                                                            settingParam:set(
                                                                setting
                                                            )

                                                            patched = true

                                                            return true
                                                        end
                                                    end
                                                )
                                        end
                                    )
                            end
                        )
                end)

            if configOk
                and patched
            then
                print(
                    "[RTFOV] FOV patched: "
                    .. tostring(minValue)
                    .. " - "
                    .. tostring(maxValue)
                )

                return true
            end
        end
    end

    return false
end

------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------

function FOV.Patch(minValue, maxValue)
    minValue = tonumber(minValue)
    maxValue = tonumber(maxValue)

    if not minValue
        or not maxValue
        or minValue >= maxValue
    then
        return false
    end

    if TryPatch(
            minValue,
            maxValue
        )
    then
        return true
    end

    LoopAsync(
        250,
        function()
            return TryPatch(
                minValue,
                maxValue
            )
        end
    )

    return false
end

return FOV
