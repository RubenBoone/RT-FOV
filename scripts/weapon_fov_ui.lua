local WeaponFOVUI = {}

local WeaponFOV =
    require("weapon_fov")

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local MIN_VALUE =
    WeaponFOV.GetMin()

local MAX_VALUE =
    WeaponFOV.GetMax()

local STEP = 1.0

local WORLD_MIN = 20.0
local WORLD_MAX = 170.0

-- Temporary marker used to identify our cloned FOV row.
local WEAPON_MARKER_INCREMENT =
    0.123456

------------------------------------------------------------
-- HOOK PATHS
------------------------------------------------------------

local SETTINGS_HOOK =
    "/Game/UI/Widgets/Menus/Settings/"
    .. "WBP_Settings_Screen_Category."
    .. "WBP_Settings_Screen_Category_C:"
    .. "OnInitialized"

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local cameraSettingsPatched =
    false

local settingsHookRegistered =
    false

local conversionRetryRunning =
    false

local weaponSliderWidget =
    nil
local sliderWatcherRunning = false
local StartSliderWatcher

local lastSliderValue =
    WeaponFOV.Get()

local umgFailurePrinted =
    false

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function Clamp(value)
    return math.max(
        MIN_VALUE,
        math.min(
            MAX_VALUE,
            value
        )
    )
end

local function RoundToStep(value)
    return math.floor(
        value / STEP + 0.5
    ) * STEP
end

local function IsUsableWidget(widget)
    if not widget then
        return false
    end

    local ok, valid =
        pcall(function()
            return widget:IsValid()
        end)

    return ok
        and valid == true
end

local function GetSettingName(widget)
    if not widget then
        return nil
    end

    local ok, name =
        pcall(function()
            if not widget.SettingName then
                return nil
            end

            return widget.SettingName:
                ToString()
        end)

    if not ok then
        return nil
    end

    return name
end

local function SetValueText(
    widget,
    value
)
    if not widget then
        return
    end

    local textWidget =
        nil

    local ok =
        pcall(function()
            textWidget =
                widget.Text_SettingTextValue
        end)

    if not ok
        or not textWidget
    then
        return
    end

    pcall(function()
        textWidget:SetText(
            FText(
                tostring(
                    math.floor(
                        value + 0.5
                    )
                )
            )
        )
    end)
end

------------------------------------------------------------
-- SET WEAPON FOV
------------------------------------------------------------

local function SetWeaponSliderValue(
    value,
    save
)
    value =
        RoundToStep(
            Clamp(value)
        )

    lastSliderValue =
        value

    local widget =
        weaponSliderWidget

    if IsUsableWidget(widget) then
        pcall(function()
            widget.SliderValue =
                value
        end)

        local slider =
            nil

        pcall(function()
            slider =
                widget.Slider_Value
        end)

        if IsUsableWidget(slider) then
            pcall(function()
                slider:SetValue(
                    value
                )
            end)
        end

        SetValueText(
            widget,
            value
        )
    end

    WeaponFOV.Set(
        value,
        save
    )
end

------------------------------------------------------------
-- PATCH CAMERA DATA
------------------------------------------------------------

local function PatchCameraGroup(group)
    local fovSetting =
        nil

    local iterateOk =
        pcall(function()
            group.Settings:ForEach(
                function(
                    _,
                    settingParam
                )
                    local setting =
                        settingParam:get()

                    if not setting then
                        return
                    end

                    local nameOk, name =
                        pcall(function()
                            return setting.SettingName:
                                ToString()
                        end)

                    if nameOk
                        and name == "Field Of View"
                    then
                        fovSetting =
                            setting

                        return true
                    end
                end
            )
        end)

    if not iterateOk
        or not fovSetting
    then
        return false
    end

    --------------------------------------------------------
    -- Both entries must remain Field Of View while PAYDAY
    -- builds the menu, otherwise the second row is not made.
    --------------------------------------------------------

    local assignOk =
        pcall(function()
            group.Settings = {
                fovSetting,
                fovSetting
            }
        end)

    if not assignOk then
        return false
    end

    local countOk, count =
        pcall(function()
            return group.Settings:
                GetArrayNum()
        end)

    if not countOk
        or not count
        or count < 2
    then
        return false
    end

    local index =
        0

    local patchOk =
        pcall(function()
            group.Settings:ForEach(
                function(
                    _,
                    settingParam
                )
                    index =
                        index + 1

                    local setting =
                        settingParam:get()

                    if not setting then
                        return
                    end

                    setting.SettingName =
                        FName(
                            "Field Of View"
                        )

                    ------------------------------------------------
                    -- WORLD FOV
                    ------------------------------------------------

                    if index == 1 then
                        setting.FloatMinValue =
                            WORLD_MIN

                        setting.FloatMaxValue =
                            WORLD_MAX

                        setting.FloatIncrementValue =
                            STEP

                    ------------------------------------------------
                    -- WEAPON FOV TEMPLATE
                    ------------------------------------------------

                    elseif index == 2 then
                        setting.FloatMinValue =
                            MIN_VALUE

                        setting.FloatMaxValue =
                            MAX_VALUE

                        setting.FloatValue =
                            WeaponFOV.Get()

                        -- Unique marker used after widget creation.
                        setting.FloatIncrementValue =
                            WEAPON_MARKER_INCREMENT
                    end

                    settingParam:set(
                        setting
                    )
                end
            )
        end)

    return patchOk
end

local function PatchCameraSettings()
    if cameraSettingsPatched then
        return true
    end

    local configs =
        FindAllOf(
            "SBZSettingsMenuConfig"
        )

    if not configs then
        return false
    end

    for _, config in ipairs(configs) do
        if IsUsableWidget(config) then
            local configOk =
                pcall(function()
                    config.SettingsCategories:
                        ForEach(
                            function(
                                _,
                                categoryParam
                            )
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
                                            local group =
                                                groupParam:get()

                                            if not group then
                                                return
                                            end

                                            local groupOk,
                                                groupName =
                                                pcall(function()
                                                    return group.GroupName:
                                                        ToString()
                                                end)

                                            if not groupOk
                                                or groupName ~= "Camera"
                                            then
                                                return
                                            end

                                            if PatchCameraGroup(
                                                    group
                                                )
                                            then
                                                cameraSettingsPatched =
                                                    true

                                                print(
                                                    "[RTFOV] Camera settings patched"
                                                )

                                                return true
                                            end
                                        end
                                    )
                            end
                        )
                end)

            if configOk
                and cameraSettingsPatched
            then
                return true
            end
        end
    end

    return false
end

------------------------------------------------------------
-- CONFIGURE WEAPON FOV WIDGET
------------------------------------------------------------

local function ConfigureWeaponSlider(child)
    if not IsUsableWidget(child) then
        return false
    end

    local slider =
        nil

    local sliderOk =
        pcall(function()
            slider =
                child.Slider_Value
        end)

    if not sliderOk
        or not IsUsableWidget(slider)
    then
        return false
    end

    --------------------------------------------------------
    -- Remove PAYDAY's native world-FOV callback.
    --------------------------------------------------------

    local delegate =
        nil

    local delegateOk =
        pcall(function()
            delegate =
                slider.OnValueChanged
        end)

    if not delegateOk
        or not delegate
    then
        print(
            "[RTFOV] Configure failed: no OnValueChanged delegate"
        )

        return false
    end

    local cleared =
        pcall(function()
            delegate:Clear()
        end)

    if not cleared then
        print(
            "[RTFOV] Configure failed: could not clear delegate"
        )

        return false
    end

    --------------------------------------------------------
    -- Convert native clone into our Weapon FOV row.
    --------------------------------------------------------

    local convertOk =
        pcall(function()
            child.SettingName =
                FName(
                    "Weapon FOV"
                )

            child.SettingCategoryName =
                FName(
                    "Video"
                )

            child.SliderMinValue =
                MIN_VALUE

            child.SliderMaxValue =
                MAX_VALUE

            ------------------------------------------------
            -- Disable Starbreeze's native setting increment.
            ------------------------------------------------

            child.SliderIncrementValue =
                0.0

            pcall(function()
                child:SetIncrementValue(
                    0.0
                )
            end)

            child.SliderValue =
                WeaponFOV.Get()
        end)

    if not convertOk then
        print(
            "[RTFOV] Configure failed: row properties"
        )

        return false
    end

    --------------------------------------------------------
    -- Configure actual UMG Slider.
    --------------------------------------------------------

    local minOk, minErr =
        pcall(function()
            slider:SetMinValue(
                MIN_VALUE
            )
        end)

    local maxOk, maxErr =
        pcall(function()
            slider:SetMaxValue(
                MAX_VALUE
            )
        end)

    local stepOk, stepErr =
        pcall(function()
            slider:SetStepSize(
                STEP
            )
        end)

    local valueOk, valueErr =
        pcall(function()
            slider:SetValue(
                WeaponFOV.Get()
            )
        end)

    if not minOk
        or not maxOk
        or not stepOk
        or not valueOk
    then
        if not umgFailurePrinted then
            if not minOk then
                print(
                    "[RTFOV] UMG SetMinValue failed: "
                    .. tostring(minErr)
                )
            end

            if not maxOk then
                print(
                    "[RTFOV] UMG SetMaxValue failed: "
                    .. tostring(maxErr)
                )
            end

            if not stepOk then
                print(
                    "[RTFOV] UMG SetStepSize failed: "
                    .. tostring(stepErr)
                )
            end

            if not valueOk then
                print(
                    "[RTFOV] UMG SetValue failed: "
                    .. tostring(valueErr)
                )
            end

            umgFailurePrinted =
                true
        end

        return false
    end

    --------------------------------------------------------
    -- Visible name.
    --------------------------------------------------------

    pcall(function()
        if child.Text_SettingName then
            child.Text_SettingName:
                SetText(
                    FText(
                        "Weapon FOV"
                    )
                )
        end
    end)

    --------------------------------------------------------
    -- Visible value.
    --------------------------------------------------------

    SetValueText(
        child,
        WeaponFOV.Get()
    )

    --------------------------------------------------------
    -- Cache active widget.
    --------------------------------------------------------

    weaponSliderWidget =
        child

    lastSliderValue =
        WeaponFOV.Get()

    print(
        "[RTFOV] Weapon FOV slider ready"
    )

    return true
end

------------------------------------------------------------
-- IDENTIFY WEAPON FOV CLONE
------------------------------------------------------------

local function IsWeaponSliderCandidate(widget)
    local name =
        GetSettingName(widget)

    --------------------------------------------------------
    -- Already converted.
    --------------------------------------------------------

    if name == "Weapon FOV" then
        return true
    end

    if name ~= "Field Of View" then
        return false
    end

    --------------------------------------------------------
    -- Primary identification:
    -- unique temporary increment marker.
    --------------------------------------------------------

    local markerOk, increment =
        pcall(function()
            return tonumber(
                widget.SliderIncrementValue
            )
        end)

    if markerOk
        and increment
        and math.abs(
            increment
            - WEAPON_MARKER_INCREMENT
        ) < 0.0001
    then
        return true
    end

    --------------------------------------------------------
    -- Fallback:
    -- Weapon FOV has the unique 20-90 range.
    --------------------------------------------------------

    local rangeOk,
        minValue,
        maxValue =
        pcall(function()
            return tonumber(
                    widget.SliderMinValue
                ),
                tonumber(
                    widget.SliderMaxValue
                )
        end)

    if not rangeOk
        or not minValue
        or not maxValue
    then
        return false
    end

    return math.abs(
            minValue - MIN_VALUE
        ) < 0.01
        and math.abs(
            maxValue - MAX_VALUE
        ) < 0.01
end

------------------------------------------------------------
-- FIND AND CONVERT WEAPON FOV WIDGET
------------------------------------------------------------

local function TryConvertWeaponSlider()
    local widgets =
        FindAllOf(
            "WBP_Settings_SliderButton_C"
        )

    if not widgets then
        return false
    end

    for _, widget in ipairs(widgets) do
        if IsUsableWidget(widget)
            and IsWeaponSliderCandidate(widget)
        then
            local oldName =
                GetSettingName(widget)

            if ConfigureWeaponSlider(
                    widget
                )
            then
                if oldName == "Field Of View" then
                    print(
                        "[RTFOV] Weapon FOV row identified"
                    )
                end

                return true
            end
        end
    end

    return false
end

------------------------------------------------------------
-- CONVERSION RETRY
------------------------------------------------------------

local function StartConversionRetry()
    if conversionRetryRunning then
        return
    end

    conversionRetryRunning =
        true

    local attempts =
        0

    LoopAsync(
        100,

        function()
            attempts =
                attempts + 1

            local convertOk,
                converted =
                pcall(function()
                    return TryConvertWeaponSlider()
                end)

            if not convertOk
                and attempts == 1
            then
                print(
                    "[RTFOV] Weapon FOV conversion retry encountered an error"
                )
            end

            if convertOk
                and converted
            then
                conversionRetryRunning =
                    false

                StartSliderWatcher()

                return true
            end

            if attempts >= 100 then
                conversionRetryRunning =
                    false

                print(
                    "[RTFOV] Weapon FOV widget conversion timed out"
                )

                return true
            end

            return false
        end
    )
end

------------------------------------------------------------
-- SETTINGS SCREEN HOOK
------------------------------------------------------------

local function RegisterSettingsHook()
    if settingsHookRegistered then
        return true
    end

    local function TryRegister()
        if settingsHookRegistered then
            return true
        end

        local ok =
            pcall(function()
                RegisterHook(
                    SETTINGS_HOOK,

                    function(context)
                        ------------------------------------------------
                        -- OnInitialized is only a signal.
                        -- Do not retain the settings screen UObject.
                        ------------------------------------------------

                        ExecuteInGameThread(
                            function()
                                StartConversionRetry()
                            end
                        )
                    end
                )
            end)

        if not ok then
            return false
        end

        settingsHookRegistered =
            true

        print(
            "[RTFOV] Settings hook registered"
        )

        return true
    end

    if TryRegister() then
        return true
    end

    print(
        "[RTFOV] Settings screen not loaded yet, waiting..."
    )

    LoopAsync(
        250,

        function()
            return TryRegister()
        end
    )

    return false
end

------------------------------------------------------------
-- SLIDER WATCHER
------------------------------------------------------------

StartSliderWatcher = function()
    if sliderWatcherRunning then
        return
    end

    sliderWatcherRunning = true

    LoopAsync(
        100,

        function()
            local widget =
                weaponSliderWidget

            if not IsUsableWidget(widget) then
                weaponSliderWidget =
                    nil

                sliderWatcherRunning = false

                return true
            end

            local slider =
                nil

            local sliderOk =
                pcall(function()
                    slider =
                        widget.Slider_Value
                end)

            if not sliderOk
                or not IsUsableWidget(slider)
            then
                weaponSliderWidget =
                    nil

                sliderWatcherRunning = false

                return true
            end

            local valueOk, value =
                pcall(function()
                    return slider:
                        GetValue()
                end)

            if not valueOk
                or value == nil
            then
                return false
            end

            value =
                RoundToStep(
                    Clamp(value)
                )

            if math.abs(
                    value
                    - lastSliderValue
                ) < 0.001
            then
                return false
            end

            SetWeaponSliderValue(
                value,
                true
            )

            return false
        end
    )
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function WeaponFOVUI.Init()
    if not PatchCameraSettings() then
        LoopAsync(
            250,

            function()
                return PatchCameraSettings()
            end
        )
    end

    RegisterSettingsHook()

end

return WeaponFOVUI
