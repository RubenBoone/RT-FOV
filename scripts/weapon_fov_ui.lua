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

local FOCUS_HOOK =
    "/Game/UI/Widgets/Menus/Settings/"
    .. "WBP_Settings_SliderButton."
    .. "WBP_Settings_SliderButton_C:"
    .. "ButtonFocusedChanged"

local KEY_DOWN_HOOK =
"/Script/UMG.UserWidget:OnKeyDown"

local ANALOG_HOOK =
"/Script/UMG.UserWidget:OnAnalogValueChanged"
------------------------------------------------------------
-- STATE
------------------------------------------------------------

local cameraSettingsPatched = false

local settingsHookRegistered = false
local focusHookRegistered = false

local weaponSliderWidget = nil
local weaponSliderFocused = false

local lastSliderValue =
    WeaponFOV.Get()

local rawInputHooksRegistered = false
local analogDirection = 0

local INPUT_ACTION_HOOK =
    "/Script/UMG.UserWidget:"
    .. "ListenForInputAction"

local inputActionHookRegistered = false

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
    if not widget
        or not widget.Text_SettingTextValue
    then
        return
    end

    widget.Text_SettingTextValue:SetText(
        FText(
            tostring(
                math.floor(
                    value + 0.5
                )
            )
        )
    )
end

------------------------------------------------------------
-- INPUT ACTION DEBUG
------------------------------------------------------------

local function RegisterInputActionDebugHook()
    if inputActionHookRegistered then
        return true
    end

    local ok, err =
        pcall(function()
            RegisterHook(
                INPUT_ACTION_HOOK,

                function(
                    context,
                    actionNameParam,
                    eventTypeParam,
                    consumeParam,
                    callbackParam
                )
                    local widget =
                        context:get()

                    if not widget
                        or not widget:IsValid()
                    then
                        return
                    end

                    local fullName = ""

                    pcall(function()
                        fullName =
                            widget:GetFullName()
                    end)

                    ------------------------------------------------
                    -- Only care about PAYDAY settings screen.
                    ------------------------------------------------

                    if not string.find(
                            fullName,
                            "WBP_Settings_Screen_Category_C",
                            1,
                            true
                        )
                    then
                        return
                    end

                    local action = "<unknown>"
                    local eventType = "<unknown>"
                    local callbackName = "<unknown>"
                    local callbackObject = "<unknown>"

                    ------------------------------------------------
                    -- Action name
                    ------------------------------------------------

                    pcall(function()
                        local name =
                            actionNameParam:get()

                        if name then
                            action =
                                name:ToString()
                        end
                    end)

                    ------------------------------------------------
                    -- Input event
                    ------------------------------------------------

                    pcall(function()
                        eventType =
                            tostring(
                                eventTypeParam:get()
                            )
                    end)

                    ------------------------------------------------
                    -- Delegate target
                    ------------------------------------------------

                    local callbackOk, callback =
                        pcall(function()
                            return callbackParam:get()
                        end)

                    if callbackOk
                        and callback
                    then
                        pcall(function()
                            if callback.FunctionName then
                                callbackName =
                                    callback.FunctionName:
                                    ToString()
                            end
                        end)

                        pcall(function()
                            if callback.Object
                                and callback.Object:IsValid()
                            then
                                callbackObject =
                                    callback.Object:
                                    GetFullName()
                            end
                        end)
                    end

                    print(
                        "[RTFOV] Input binding:"
                        .. " action="
                        .. tostring(action)
                        .. " event="
                        .. tostring(eventType)
                        .. " callback="
                        .. tostring(callbackName)
                    )

                    print(
                        "[RTFOV] Input callback object: "
                        .. tostring(callbackObject)
                    )
                end
            )
        end)

    if not ok then
        print(
            "[RTFOV] Input action hook failed: "
            .. tostring(err)
        )

        return false
    end

    inputActionHookRegistered = true

    print(
        "[RTFOV] Input action debug hook registered"
    )

    return true
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

    if widget
        and widget:IsValid()
    then
        widget.SliderValue =
            value

        if widget.Slider_Value
            and widget.Slider_Value:IsValid()
        then
            widget.Slider_Value:SetValue(
                value
            )
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
-- RAW UMG INPUT
------------------------------------------------------------

local function RegisterRawInputHooks()
    if rawInputHooksRegistered then
        return true
    end

    local kismetInput =
        StaticFindObject(
            "/Script/Engine.Default__KismetInputLibrary"
        )

    if not kismetInput
        or not kismetInput:IsValid()
    then
        print(
            "[RTFOV] KismetInputLibrary not found"
        )

        return false
    end

    --------------------------------------------------------
    -- KEYBOARD / DPAD / DIGITAL STICK KEYS
    --------------------------------------------------------

    local keyOk, keyErr =
        pcall(function()
            RegisterHook(
                KEY_DOWN_HOOK,

                function(
                    context,
                    geometryParam,
                    keyEventParam
                )
                    if not weaponSliderFocused then
                        return
                    end

                    local eventOk, keyEvent =
                        pcall(function()
                            return keyEventParam:get()
                        end)

                    if not eventOk
                        or not keyEvent
                    then
                        return
                    end

                    local getKeyOk, key =
                        pcall(function()
                            return kismetInput:
                            GetKey(keyEvent)
                        end)

                    if not getKeyOk
                        or not key
                    then
                        return
                    end

                    local nameOk, keyName =
                        pcall(function()
                            return key.KeyName:
                            ToString()
                        end)

                    if not nameOk then
                        return
                    end

                    print(
                        "[RTFOV] KeyDown: "
                        .. tostring(keyName)
                    )

                    ------------------------------------------------
                    -- LEFT
                    ------------------------------------------------

                    if keyName == "Left"
                        or keyName == "Gamepad_DPad_Left"
                        or keyName == "Gamepad_LeftStick_Left"
                    then
                        SetWeaponSliderValue(
                            WeaponFOV.Get() - STEP,
                            true
                        )

                        return
                    end

                    ------------------------------------------------
                    -- RIGHT
                    ------------------------------------------------

                    if keyName == "Right"
                        or keyName == "Gamepad_DPad_Right"
                        or keyName == "Gamepad_LeftStick_Right"
                    then
                        SetWeaponSliderValue(
                            WeaponFOV.Get() + STEP,
                            true
                        )

                        return
                    end
                end
            )
        end)

    if not keyOk then
        print(
            "[RTFOV] KeyDown hook failed: "
            .. tostring(keyErr)
        )

        return false
    end

    --------------------------------------------------------
    -- ANALOG STICK
    --------------------------------------------------------

    local analogOk, analogErr =
        pcall(function()
            RegisterHook(
                ANALOG_HOOK,

                function(
                    context,
                    geometryParam,
                    analogEventParam
                )
                    if not weaponSliderFocused then
                        analogDirection = 0
                        return
                    end

                    local eventOk, analogEvent =
                        pcall(function()
                            return analogEventParam:get()
                        end)

                    if not eventOk
                        or not analogEvent
                    then
                        return
                    end

                    local keyOk2, key =
                        pcall(function()
                            return kismetInput:
                            GetKey(analogEvent)
                        end)

                    if not keyOk2
                        or not key
                    then
                        return
                    end

                    local nameOk, keyName =
                        pcall(function()
                            return key.KeyName:
                            ToString()
                        end)

                    if not nameOk
                        or keyName ~= "Gamepad_LeftX"
                    then
                        return
                    end

                    local valueOk, value =
                        pcall(function()
                            return kismetInput:
                            GetAnalogValue(
                                analogEvent
                            )
                        end)

                    if not valueOk
                        or value == nil
                    then
                        return
                    end

                    ------------------------------------------------
                    -- Reset latch near stick centre.
                    ------------------------------------------------

                    if math.abs(value) < 0.4 then
                        analogDirection = 0
                        return
                    end

                    ------------------------------------------------
                    -- One step per stick movement.
                    ------------------------------------------------

                    if value <= -0.7 then
                        if analogDirection ~= -1 then
                            analogDirection = -1

                            print(
                                "[RTFOV] Analog LEFT"
                            )

                            SetWeaponSliderValue(
                                WeaponFOV.Get() - STEP,
                                true
                            )
                        end

                        return
                    end

                    if value >= 0.7 then
                        if analogDirection ~= 1 then
                            analogDirection = 1

                            print(
                                "[RTFOV] Analog RIGHT"
                            )

                            SetWeaponSliderValue(
                                WeaponFOV.Get() + STEP,
                                true
                            )
                        end

                        return
                    end
                end
            )
        end)

    if not analogOk then
        print(
            "[RTFOV] Analog hook failed: "
            .. tostring(analogErr)
        )

        return false
    end

    rawInputHooksRegistered = true

    print(
        "[RTFOV] Raw input hooks registered"
    )

    return true
end

------------------------------------------------------------
-- FOCUS HOOK
------------------------------------------------------------

local function RegisterFocusHook()
    if focusHookRegistered then
        return true
    end

    local ok, err =
        pcall(function()
            RegisterHook(
                FOCUS_HOOK,

                function(
                    context,
                    focusedParam
                )
                    local widget =
                        context:get()

                    if not widget
                        or not widget:IsValid()
                        or not widget.SettingName
                    then
                        return
                    end

                    local nameOk, name =
                        pcall(function()
                            return widget.SettingName:
                            ToString()
                        end)

                    if not nameOk
                        or name ~= "Weapon FOV"
                    then
                        return
                    end

                    local focusOk, focused =
                        pcall(function()
                            return focusedParam:get()
                        end)

                    if not focusOk then
                        return
                    end

                    weaponSliderFocused =
                        focused == true

                    )
                end
            )
        end)

    if not ok then
        return false
    end

    focusHookRegistered =
        true

    print(
        "[RTFOV] Focus hook registered"
    )

    return true
end

------------------------------------------------------------
-- PATCH CAMERA DATA
------------------------------------------------------------

local function PatchCameraGroup(group)
    local fovSetting = nil

    group.Settings:ForEach(
        function(
            _,
            settingParam
        )
            local setting =
                settingParam:get()

            if setting
                and setting.SettingName:
                ToString()
                == "Field Of View"
            then
                fovSetting =
                    setting

                return true
            end
        end
    )

    if not fovSetting then
        return false
    end

    --------------------------------------------------------
    -- Both entries must remain Field Of View during menu
    -- construction, otherwise PAYDAY refuses to render the
    -- second row.
    --------------------------------------------------------

    group.Settings = {
        fovSetting,
        fovSetting
    }

    if group.Settings:
        GetArrayNum() < 2
    then
        return false
    end

    local index = 0

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

    return true
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
        if config
            and config:IsValid()
        then
            config.SettingsCategories:
                ForEach(
                    function(
                        _,
                        categoryParam
                    )
                        local category =
                            categoryParam:get()

                        if not category
                            or category.CategoryName:
                            ToString()
                            ~= "Video"
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

                                    if not group
                                        or group.GroupName:
                                        ToString()
                                        ~= "Camera"
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

            if cameraSettingsPatched then
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
    local slider =
        child.Slider_Value

    if not slider
        or not slider:IsValid()
    then
        return false
    end

    --------------------------------------------------------
    -- Remove PAYDAY's native world-FOV OnValueChanged.
    --------------------------------------------------------

    local ok, delegate =
        pcall(function()
            return slider.OnValueChanged
        end)

    if not ok
        or not delegate
    then
        return false
    end

    local cleared =
        pcall(function()
            delegate:Clear()
        end)

    if not cleared then
        return false
    end

    --------------------------------------------------------
    -- Convert row
    --------------------------------------------------------

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

    --------------------------------------------------------
    -- Disable PAYDAY native keyboard/controller increment.
    --
    -- This is the part that stopped world FOV from jumping
    -- to the weapon FOV value.
    --------------------------------------------------------

    child.SliderIncrementValue =
        0.0

    pcall(function()
        child:SetIncrementValue(
            0.0
        )
    end)

    --------------------------------------------------------
    -- Current value
    --------------------------------------------------------

    child.SliderValue =
        WeaponFOV.Get()

    --------------------------------------------------------
    -- Actual UMG slider
    --------------------------------------------------------

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

    --------------------------------------------------------
    -- Visible name
    --------------------------------------------------------

    if child.Text_SettingName then
        child.Text_SettingName:
            SetText(
                FText(
                    "Weapon FOV"
                )
            )
    end

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
-- FIND SECOND FOV ROW
------------------------------------------------------------

local function ConvertSecondFOVWidget(
    screen
)
    if not screen
        or not screen:IsValid()
        or not screen.SettingsCategoryName
        or screen.SettingsCategoryName:
        ToString()
        ~= "Video"
    then
        return false
    end

    local scrollBox =
        screen.ScrollBox_SettingsItems

    if not scrollBox
        or not scrollBox:IsValid()
    then
        return false
    end

    local fovCount = 0

    for i = 0,
    scrollBox:
    GetChildrenCount() - 1
    do
        local child =
            scrollBox:
            GetChildAt(i)

        if child
            and child:IsValid()
            and child.SettingName
        then
            local ok, name =
                pcall(function()
                    return child.SettingName:
                    ToString()
                end)

            ------------------------------------------------
            -- Already converted
            ------------------------------------------------

            if ok
                and name == "Weapon FOV"
            then
                weaponSliderWidget =
                    child

                return true
            end

            ------------------------------------------------
            -- Find second native FOV row
            ------------------------------------------------

            if ok
                and name == "Field Of View"
            then
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

    return false
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
                        local screen =
                            context:get()

                        if not screen
                            or not screen:IsValid()
                        then
                            return
                        end

                        ExecuteInGameThread(
                            function()
                                local attempts = 0

                                LoopAsync(
                                    100,

                                    function()
                                        attempts =
                                            attempts + 1

                                        if not screen
                                            or not screen:IsValid()
                                        then
                                            return true
                                        end

                                        if ConvertSecondFOVWidget(
                                                screen
                                            )
                                        then
                                            return true
                                        end

                                        return attempts >= 30
                                    end
                                )
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

            if not widget
                or not widget:IsValid()
                or not widget.Slider_Value
                or not widget.Slider_Value:
                IsValid()
            then
                return false
            end

            local ok, value =
                pcall(function()
                    return widget.Slider_Value:
                    GetValue()
                end)

            if not ok
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

    if not RegisterFocusHook() then
        LoopAsync(
            250,
            function()
                return RegisterFocusHook()
            end
        )
    end

    if not RegisterRawInputHooks() then
        LoopAsync(
            250,
            function()
                return RegisterRawInputHooks()
            end
        )
    end

    StartSliderWatcher()
end

return WeaponFOVUI
