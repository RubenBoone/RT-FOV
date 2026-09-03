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

local cameraSettingsPatched = false

local settingsHookRegistered = false

local weaponSliderWidget = nil

local lastSliderValue =
    WeaponFOV.Get()

local conversionRetryRunning = false

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

local function SetValueText(
    widget,
    value
)
    if not widget then
        return
    end

    local textWidget = nil

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

    if widget then
        local validOk, valid =
            pcall(function()
                return widget:IsValid()
            end)

        if validOk
            and valid
        then
            pcall(function()
                widget.SliderValue =
                    value
            end)

            local slider = nil

            pcall(function()
                slider =
                    widget.Slider_Value
            end)

            if slider then
                local sliderValidOk,
                sliderValid =
                    pcall(function()
                        return slider:IsValid()
                    end)

                if sliderValidOk
                    and sliderValid
                then
                    pcall(function()
                        slider:SetValue(
                            value
                        )
                    end)
                end
            end

            SetValueText(
                widget,
                value
            )
        end
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
    local fovSetting = nil

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
    -- Both entries must be Field Of View while PAYDAY
    -- constructs the menu, otherwise the second row is not
    -- created.
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

    local index = 0

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

                    setting.FloatIncrementValue =
                        STEP

                    ------------------------------------------------
                    -- WORLD FOV
                    ------------------------------------------------

                    if index == 1 then
                        setting.FloatMinValue =
                            WORLD_MIN

                        setting.FloatMaxValue =
                            WORLD_MAX

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
        local validOk, valid =
            pcall(function()
                return config
                    and config:IsValid()
            end)

        if validOk
            and valid
        then
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

local function ConfigureWeaponSlider(
    child
)
    if not child then
        return false
    end

    local childValidOk, childValid =
        pcall(function()
            return child:IsValid()
        end)

    if not childValidOk
        or not childValid
    then
        return false
    end

    local slider = nil

    local sliderOk =
        pcall(function()
            slider =
                child.Slider_Value
        end)

    if not sliderOk
        or not slider
    then
        print(
            "[RTFOV] Configure failed: no Slider_Value"
        )

        return false
    end

    local sliderValidOk, sliderValid =
        pcall(function()
            return slider:IsValid()
        end)

    if not sliderValidOk
        or not sliderValid
    then
        print(
            "[RTFOV] Configure failed: invalid Slider_Value"
        )

        return false
    end

    --------------------------------------------------------
    -- Remove PAYDAY's native world-FOV OnValueChanged.
    --------------------------------------------------------

    local delegate = nil

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
    -- Convert row
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
            -- Disable Starbreeze's native keyboard /
            -- controller setting increment.
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
    -- Actual UMG slider
    --------------------------------------------------------

    local umgOk =
        pcall(function()
            slider:SetMinValue(
                MIN_VALUE
            )

            slider:SetMaxValue(
                MAX_VALUE
            )

            slider:SetStepSize(
                STEP
            )

            slider:SetValue(
                WeaponFOV.Get()
            )
        end)

    if not umgOk then
        print(
            "[RTFOV] Configure failed: UMG slider"
        )

        return false
    end

    --------------------------------------------------------
    -- Visible name
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
    -- Visible value
    --------------------------------------------------------

    SetValueText(
        child,
        WeaponFOV.Get()
    )

    --------------------------------------------------------
    -- Cache
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
-- FIND CURRENT VIDEO SETTINGS SCREEN
------------------------------------------------------------

local function FindCurrentVideoSettingsScreen()
    local screens =
        FindAllOf(
            "WBP_Settings_Screen_Category_C"
        )

    if not screens then
        return nil
    end

    for _, screen in ipairs(screens) do
        if screen then
            local validOk, valid =
                pcall(function()
                    return screen:IsValid()
                end)

            if validOk
                and valid
            then
                local categoryOk,
                categoryName =
                    pcall(function()
                        return screen.SettingsCategoryName:
                        ToString()
                    end)

                if categoryOk
                    and categoryName == "Video"
                then
                    ------------------------------------------------
                    -- Do not return a screen whose ScrollBox has
                    -- already been destroyed.
                    ------------------------------------------------

                    local scrollBox = nil

                    local scrollOk =
                        pcall(function()
                            scrollBox =
                                screen.ScrollBox_SettingsItems

                            if not scrollBox then
                                error(
                                    "null scroll box"
                                )
                            end

                            if not scrollBox:IsValid() then
                                error(
                                    "invalid scroll box"
                                )
                            end
                        end)

                    if scrollOk
                        and scrollBox
                    then
                        return screen
                    end
                end
            end
        end
    end

    return nil
end

------------------------------------------------------------
-- FIND / CONVERT SECOND FOV ROW
------------------------------------------------------------

local function ConvertSecondFOVWidget(
    screen
)
    if not screen then
        return false
    end

    --------------------------------------------------------
    -- Validate screen.
    --------------------------------------------------------

    local screenOk =
        pcall(function()
            if not screen:IsValid() then
                error(
                    "invalid screen"
                )
            end

            if screen.SettingsCategoryName:
                ToString() ~= "Video"
            then
                error(
                    "not video"
                )
            end
        end)

    if not screenOk then
        return false
    end

    --------------------------------------------------------
    -- Get ScrollBox safely.
    --------------------------------------------------------

    local scrollBox = nil

    local scrollOk =
        pcall(function()
            scrollBox =
                screen.ScrollBox_SettingsItems

            if not scrollBox then
                error(
                    "no scroll box"
                )
            end

            if not scrollBox:IsValid() then
                error(
                    "invalid scroll box"
                )
            end
        end)

    if not scrollOk
        or not scrollBox
    then
        return false
    end

    --------------------------------------------------------
    -- This was the actual crash for the affected user.
    --------------------------------------------------------

    local count = nil

    local countOk =
        pcall(function()
            count =
                scrollBox:
                GetChildrenCount()
        end)

    if not countOk
        or count == nil
    then
        return false
    end

    local fovCount = 0

    for i = 0, count - 1 do
        local child = nil

        local childOk =
            pcall(function()
                child =
                    scrollBox:
                    GetChildAt(i)
            end)

        if childOk
            and child
        then
            local validOk, valid =
                pcall(function()
                    return child:IsValid()
                end)

            if validOk
                and valid
            then
                local nameOk, name =
                    pcall(function()
                        if not child.SettingName then
                            error(
                                "no setting name"
                            )
                        end

                        return child.SettingName:
                        ToString()
                    end)

                if nameOk then
                    ------------------------------------------------
                    -- Already converted.
                    --
                    -- Reconfigure it anyway. PAYDAY may have
                    -- rebuilt/native-bound the widget again.
                    ------------------------------------------------

                    if name == "Weapon FOV" then
                        return ConfigureWeaponSlider(
                            child
                        )
                    end

                    ------------------------------------------------
                    -- Find second native FOV row.
                    ------------------------------------------------

                    if name == "Field Of View" then
                        fovCount =
                            fovCount + 1

                        if fovCount == 2 then
                            return ConfigureWeaponSlider(
                                child
                            )
                        end
                    end
                end
            end
        end
    end

    return false
end

------------------------------------------------------------
-- CONVERSION RETRY
--
-- IMPORTANT:
-- We deliberately do NOT capture the screen passed to
-- OnInitialized.
--
-- Every retry obtains the current live Video settings screen.
------------------------------------------------------------

local function StartConversionRetry()
    if conversionRetryRunning then
        return
    end

    conversionRetryRunning =
        true

    local attempts = 0

    LoopAsync(
        100,

        function()
            attempts =
                attempts + 1

            ------------------------------------------------
            -- Reacquire it every single attempt.
            ------------------------------------------------

            local screen =
                FindCurrentVideoSettingsScreen()

            if screen then
                local convertOk, converted =
                    pcall(function()
                        return ConvertSecondFOVWidget(
                            screen
                        )
                    end)

                if convertOk
                    and converted
                then
                    conversionRetryRunning =
                        false

                    return true
                end
            end

            ------------------------------------------------
            -- 50 * 100 ms = max 5 seconds.
            --
            -- No stale UObject is retained during this time.
            ------------------------------------------------

            if attempts >= 50 then
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

        local ok, err =
            pcall(function()
                RegisterHook(
                    SETTINGS_HOOK,

                    function(context)
                        ------------------------------------------------
                        -- Do NOT retain context:get() here.
                        --
                        -- OnInitialized only acts as a signal that
                        -- some settings screen was created.
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
-- MOUSE SLIDER WATCHER
------------------------------------------------------------

local function StartSliderWatcher()
    LoopAsync(
        16,

        function()
            local widget =
                weaponSliderWidget

            if not widget then
                return false
            end

            local widgetValidOk,
            widgetValid =
                pcall(function()
                    return widget:IsValid()
                end)

            if not widgetValidOk
                or not widgetValid
            then
                weaponSliderWidget =
                    nil

                return false
            end

            local slider = nil

            local sliderOk =
                pcall(function()
                    slider =
                        widget.Slider_Value
                end)

            if not sliderOk
                or not slider
            then
                return false
            end

            local sliderValidOk,
            sliderValid =
                pcall(function()
                    return slider:IsValid()
                end)

            if not sliderValidOk
                or not sliderValid
            then
                weaponSliderWidget =
                    nil

                return false
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

    StartSliderWatcher()
end

return WeaponFOVUI
