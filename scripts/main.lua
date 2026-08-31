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

local WEAPON_MIN = -10.0
local WEAPON_MAX = 20.0
local WEAPON_VALUE = 5.0

local function AddWeaponSlider(screen)
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
        print("[RTFOV] Video initialized, but ScrollBox not ready")
        return
    end

    ------------------------------------------------
    -- Voorkom duplicates
    ------------------------------------------------

    local count = scrollBox:GetChildrenCount()

    for i = 0, count - 1 do
        local child = scrollBox:GetChildAt(i)

        if child and child:IsValid() then
            local ok, name = pcall(function()
                return child.SettingName:ToString()
            end)

            if ok and name == "Weapon Position" then
                print("[RTFOV] Weapon Position already exists")
                return
            end
        end
    end

    ------------------------------------------------
    -- Zoek FOV widget als template
    ------------------------------------------------

    local fovWidget = nil

    for i = 0, count - 1 do
        local child = scrollBox:GetChildAt(i)

        if child and child:IsValid() then
            local ok, name = pcall(function()
                return child.SettingName:ToString()
            end)

            if ok and name == "Field Of View" then
                fovWidget = child
                break
            end
        end
    end

    if not fovWidget then
        print("[RTFOV] FOV widget not found yet")
        return
    end

    ------------------------------------------------
    -- Widget library
    ------------------------------------------------

    local widgetLibrary =
        StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")

    if not widgetLibrary or not widgetLibrary:IsValid() then
        print("[RTFOV] WidgetBlueprintLibrary missing")
        return
    end

    ------------------------------------------------
    -- Create
    ------------------------------------------------

    local newSlider = widgetLibrary:Create(
        screen,
        fovWidget:GetClass(),
        nil
    )

    if not newSlider or not newSlider:IsValid() then
        print("[RTFOV] Failed to create Weapon Position slider")
        return
    end

    newSlider.SliderMinValue = WEAPON_MIN
    newSlider.SliderMaxValue = WEAPON_MAX
    newSlider.SliderIncrementValue = 1.0
    newSlider.SliderValue = WEAPON_VALUE

    if newSlider.Slider_Value then
        newSlider.Slider_Value:SetMinValue(WEAPON_MIN)
        newSlider.Slider_Value:SetMaxValue(WEAPON_MAX)
        newSlider.Slider_Value:SetStepSize(1.0)
        newSlider.Slider_Value:SetValue(WEAPON_VALUE)
    end

    if newSlider.Text_SettingName then
        newSlider.Text_SettingName:SetText(FText("Weapon Position"))
    end

    if newSlider.Text_SettingTextValue then
        newSlider.Text_SettingTextValue:SetText(FText("5"))
    end

    ------------------------------------------------
    -- Label
    ------------------------------------------------

    if newSlider.Text_SettingName then
        newSlider.Text_SettingName:SetText(
            FText("Weapon Position")
        )
    end

    ------------------------------------------------
    -- Voorlopig gewoon onderaan
    ------------------------------------------------

    scrollBox:AddChild(newSlider)

    print("[RTFOV] Weapon Position slider created")
end


RegisterHook(
    "/Game/UI/Widgets/Menus/Settings/WBP_Settings_Screen_Category.WBP_Settings_Screen_Category_C:OnInitialized",
    function(context)
        local screen = context:get()

        ExecuteInGameThread(function()
            AddWeaponSlider(screen)
        end)
    end
)

print("[RTFOV] Settings screen hook registered")
