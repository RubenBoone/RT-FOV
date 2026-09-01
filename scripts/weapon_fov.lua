local WeaponFOV = {}

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local MIN_VALUE = 20.0
local MAX_VALUE = 90.0
local DEFAULT_VALUE = 55.0

-- Alleen relevant voor keyboard/controller.
-- Muis blijft continuous.
local STEP = 1.0

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local currentValue = DEFAULT_VALUE
local cachedPlayer = nil

------------------------------------------------------------
-- FIND / CACHE PLAYER
------------------------------------------------------------

local function GetPlayer()
    if cachedPlayer
        and cachedPlayer:IsValid()
    then
        return cachedPlayer
    end

    local players = FindAllOf("SBZPlayerCharacter")

    if not players or #players == 0 then
        cachedPlayer = nil
        return nil
    end

    for _, player in ipairs(players) do
        if player and player:IsValid() then
            cachedPlayer = player
            return player
        end
    end

    return nil
end

------------------------------------------------------------
-- APPLY WEAPON FOV
------------------------------------------------------------

function WeaponFOV.Set(value)
    value = tonumber(value)

    if not value then
        return false
    end

    value = math.max(
        MIN_VALUE,
        math.min(MAX_VALUE, value)
    )

    currentValue = value

    local player = GetPlayer()

    if not player then
        return false
    end

    player.OnTopBaseFOV = value

    return true
end

------------------------------------------------------------
-- CREATE SLIDER
------------------------------------------------------------

local function AddSlider(screen)
    if not screen or not screen:IsValid() then
        return
    end

    if not screen.SettingsCategoryName then
        return
    end

    if screen.SettingsCategoryName:ToString() ~= "Video" then
        return
    end

    local scrollBox = screen.ScrollBox_SettingsItems

    if not scrollBox or not scrollBox:IsValid() then
        return
    end

    --------------------------------------------------------
    -- DON'T CREATE TWICE
    --------------------------------------------------------

    local count = scrollBox:GetChildrenCount()

    for i = 0, count - 1 do
        local child = scrollBox:GetChildAt(i)

        if child and child:IsValid() then
            local ok, name = pcall(function()
                if child.SettingName then
                    return child.SettingName:ToString()
                end

                return nil
            end)

            if ok and name == "Weapon FOV" then
                return
            end
        end
    end

    --------------------------------------------------------
    -- FIND NORMAL FOV SLIDER AS TEMPLATE
    --------------------------------------------------------

    local fovWidget = nil

    for i = 0, count - 1 do
        local child = scrollBox:GetChildAt(i)

        if child and child:IsValid() then
            local ok, name = pcall(function()
                if child.SettingName then
                    return child.SettingName:ToString()
                end

                return nil
            end)

            if ok and name == "Field Of View" then
                fovWidget = child
                break
            end
        end
    end

    if not fovWidget then
        return
    end

    --------------------------------------------------------
    -- CREATE NATIVE PAYDAY SLIDER
    --------------------------------------------------------

    local widgetLibrary =
        StaticFindObject(
            "/Script/UMG.Default__WidgetBlueprintLibrary"
        )

    if not widgetLibrary
        or not widgetLibrary:IsValid()
    then
        return
    end

    local slider = widgetLibrary:Create(
        screen,
        fovWidget:GetClass(),
        nil
    )

    if not slider or not slider:IsValid() then
        return
    end

    slider.SettingName = FName("Weapon FOV")
    slider.SettingCategoryName = FName("Video")

    --------------------------------------------------------
    -- STARBREEZE SLIDER VALUES
    --------------------------------------------------------

    slider.SliderMinValue = MIN_VALUE
    slider.SliderMaxValue = MAX_VALUE
    slider.SliderIncrementValue = STEP
    slider.SliderValue = currentValue

    --------------------------------------------------------
    -- ACTUAL UMG SLIDER
    --------------------------------------------------------

    if slider.Slider_Value then
        slider.Slider_Value:SetMinValue(MIN_VALUE)
        slider.Slider_Value:SetMaxValue(MAX_VALUE)
        slider.Slider_Value:SetValue(currentValue)
    end

    --------------------------------------------------------
    -- TEXT
    --------------------------------------------------------

    if slider.Text_SettingName then
        slider.Text_SettingName:SetText(
            FText("Weapon FOV")
        )
    end

    if slider.Text_SettingTextValue then
        slider.Text_SettingTextValue:SetText(
            FText(
                tostring(
                    math.floor(currentValue + 0.5)
                )
            )
        )
    end

    scrollBox:AddChild(slider)

    print("[RTFOV] Weapon FOV slider created")
end

------------------------------------------------------------
-- SLIDER CHANGED
------------------------------------------------------------

local function RegisterSliderHook()
    RegisterHook(
        "/Game/UI/Widgets/Menus/Settings/"
        .. "WBP_Settings_SliderButton."
        .. "WBP_Settings_SliderButton_C:"
        .. "BndEvt__WBP_Settings_SliderButton_"
        .. "Slider_Value_K2Node_ComponentBoundEvent_0_"
        .. "OnFloatValueChangedEvent__DelegateSignature",

        function(context, value)
            local widget = context:get()

            if not widget
                or not widget:IsValid()
            then
                return
            end

            if not widget.SettingName then
                return
            end

            if widget.SettingName:ToString()
                ~= "Weapon FOV"
            then
                return
            end

            ------------------------------------------------
            -- IMPORTANT:
            -- DON'T ROUND THE ACTUAL SLIDER VALUE
            ------------------------------------------------

            local newValue = value:get()

            currentValue = newValue

            ------------------------------------------------
            -- DON'T CALL Slider_Value:SetValue() HERE
            --
            -- We're already inside OnValueChanged.
            ------------------------------------------------

            widget.SliderValue = newValue

            ------------------------------------------------
            -- Only round the DISPLAYED number
            ------------------------------------------------

            if widget.Text_SettingTextValue then
                widget.Text_SettingTextValue:SetText(
                    FText(
                        tostring(
                            math.floor(newValue + 0.5)
                        )
                    )
                )
            end

            ------------------------------------------------
            -- APPLY IMMEDIATELY
            ------------------------------------------------

            WeaponFOV.Set(newValue)
        end
    )
end

------------------------------------------------------------
-- SETTINGS SCREEN CREATION
------------------------------------------------------------

local function RegisterSettingsHook()
    RegisterHook(
        "/Game/UI/Widgets/Menus/Settings/"
        .. "WBP_Settings_Screen_Category."
        .. "WBP_Settings_Screen_Category_C:"
        .. "OnInitialized",

        function(context)
            local screen = context:get()

            ExecuteInGameThread(function()
                AddSlider(screen)
            end)
        end
    )
end

------------------------------------------------------------
-- KEEP WEAPON FOV APPLIED
------------------------------------------------------------

local function StartPlayerWatcher()
    LoopAsync(16, function()
        local player = GetPlayer()

        if player then
            player.OnTopBaseFOV = currentValue
        end

        return false
    end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function WeaponFOV.Init()
    RegisterSliderHook()
    RegisterSettingsHook()
    StartPlayerWatcher()

    WeaponFOV.Set(currentValue)

    print(
        "[RTFOV] Weapon FOV initialized at "
        .. tostring(currentValue)
    )
end

return WeaponFOV
