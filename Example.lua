-- Eclipse UI showcase. This is a visual/control demo; it never starts gameplay features.
local Eclipse = loadstring(game:HttpGet("https://raw.githubusercontent.com/VexyEclipse/Eclipsalis/main/EclipseUI.lua"))()

local Window = Eclipse:CreateWindow({
    Name = "Eclipse Hub",
    Subtitle = "TOTALITY / v1.6.2",
    LoadingTitle = "ECLIPSE",
    LoadingSubtitle = "INTERFACE INITIALIZATION",
    ShowText = "ECLIPSE",
    Theme = "Absolute Dark",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {Enabled = false},
})

local function report(name)
    return function(value)
        if type(value) == "table" then value = table.concat(value, ", ") end
        print("[Eclipse Demo] " .. name .. ": " .. tostring(value))
    end
end

local Main = Window:CreateTab("Main")
Main:CreateSection("Movement")
Main:CreateSlider({Name = "Walk Speed", Range = {16, 120}, Increment = 1, CurrentValue = 32,
    Suffix = "studs/s", Flag = "DemoWalkSpeed", Tooltip = "Demonstrates exact entry and mouse/touch slider dragging.",
    Callback = report("Walk Speed")})
Main:CreateToggle({Name = "Walk Speed", CurrentValue = false, Flag = "DemoSpeedEnabled",
    Info = "Showcase only. This switch does not change your character.", Callback = report("Speed switch")})
Main:CreateSlider({Name = "Jump Power", Range = {50, 200}, Increment = 5, CurrentValue = 75,
    Flag = "DemoJumpPower", Callback = report("Jump Power")})
Main:CreateToggle({Name = "Jump Power", CurrentValue = false, Flag = "DemoJumpEnabled", Callback = report("Jump switch")})
Main:CreateToggle({Name = "No Fall", CurrentValue = false, Flag = "DemoNoFall", Callback = report("No Fall")})
Main:CreateKeybind({Name = "Quick Action", CurrentKeybind = "P", HoldToInteract = false,
    Flag = "DemoQuickAction", Tooltip = "Click the key field and press a keyboard key or mouse button.",
    Callback = function() print("[Eclipse Demo] Quick Action pressed.") end})

Main:CreateSection("Player")
Main:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Flag = "DemoInfiniteJump", Callback = report("Infinite Jump")})
Main:CreateToggle({Name = "Walk on Water", CurrentValue = false, Flag = "DemoWater", Callback = report("Walk on Water")})
Main:CreateKeybind({Name = "Hold Action", CurrentKeybind = "LeftShift", HoldToInteract = true,
    Flag = "DemoHoldAction", Callback = report("Hold Action")})
local status = Main:CreateLabel("STATUS / WAITING FOR INPUT")
Main:CreateButton({Name = "Run Demo Action", Callback = function()
    status:Set("STATUS / ACTION RECEIVED")
    print("[Eclipse Demo] Action received; dynamic label updated.")
end})
Main:CreateDivider()
Main:CreateParagraph({Title = "Built for Eclipse", Content = "A quiet surface, precise controls, and a familiar API. Every feature in this showcase only prints to the console."})

local Farms = Window:CreateTab("Auto Farms")
Farms:CreateSection("Halloween Event")
Farms:CreateToggle({Name = "Auto Halloween", CurrentValue = false, Flag = "DemoHalloween",
    Tooltip = "Visual demo only. No doors, remotes or movement are triggered.", Callback = report("Auto Halloween")})
Farms:CreateDropdown({Name = "Event Priority", Options = {"Candy", "Chests", "Balanced"}, CurrentOption = {"Balanced"},
    MultipleOptions = false, Flag = "DemoEventPriority", Callback = report("Event Priority")})
Farms:CreateParagraph({Title = "Event Controls", Content = "Related settings share a framed section. Search by control name or by its section title."})

Farms:CreateSection("Kraken Farm")
Farms:CreateToggle({Name = "Auto Kraken", CurrentValue = false, Flag = "DemoKraken", Callback = report("Auto Kraken")})
Farms:CreateDropdown({Name = "Kraken Farm Mode", Options = {"Auto", "Anchor", "Summoning", "Attack"}, CurrentOption = {"Auto"},
    MultipleOptions = false, Flag = "DemoKrakenMode", Callback = report("Kraken Mode")})
Farms:CreateSlider({Name = "Kraken Flight Speed", Range = {25, 150}, Increment = 5, CurrentValue = 75,
    Suffix = "studs/s", Flag = "DemoKrakenSpeed", Callback = report("Kraken Speed")})
Farms:CreateSlider({Name = "Kraken Attack Hold", Range = {1, 11}, Increment = 1, CurrentValue = 10,
    Suffix = "s", Flag = "DemoKrakenHold", Callback = report("Kraken Hold")})

Farms:CreateSection("Fishing")
Farms:CreateToggle({Name = "Auto Fish", CurrentValue = false, Flag = "DemoFishing", Callback = report("Auto Fish")})
local fishList = Farms:CreateDropdown({Name = "Allowed Fishes", Options = {"All", "Common", "Uncommon", "Rare", "Legendary", "Mythical"},
    CurrentOption = {}, MultipleOptions = true, Flag = "DemoFishAllowlist",
    Tooltip = "The allowlist starts empty. All is an explicit choice.", Callback = report("Allowed Fishes")})
Farms:CreateButton({Name = "Refresh Demo List", Callback = function()
    fishList:Refresh({"All", "Common", "Uncommon", "Rare", "Legendary", "Mythical", "Event"})
    print("[Eclipse Demo] Dropdown refreshed locally.")
end})

Farms:CreateSection("Whole Cake Farm")
Farms:CreateToggle({Name = "Auto Whole Cake", CurrentValue = false, Flag = "DemoWholeCake", Callback = report("Whole Cake")})
Farms:CreateToggle({Name = "Cake Stun", CurrentValue = false, Flag = "DemoCakeStun",
    Info = "Optional and off by default in this showcase.", Callback = report("Cake Stun")})

local Settings = Window:CreateTab("Settings")
Settings:CreateSection("Appearance")
Settings:CreateDropdown({Name = "Theme", Options = Eclipse.ThemeNames or {"Absolute Dark", "Charcoal", "CyberYellow", "AmberGlow", "NeonCyan", "Light"},
    CurrentOption = {"Absolute Dark"}, MultipleOptions = false, Flag = "DemoTheme", Callback = function(selected)
        if selected[1] then Window.ModifyTheme(selected[1]) end
    end})
Settings:CreateColorPicker({Name = "Demo Highlight", Color = Color3.fromRGB(59, 130, 246), Flag = "DemoColor",
    Tooltip = "Open the HSV map, hue slider, hex and RGB fields.", Callback = report("Highlight")})
Settings:CreateInput({Name = "Profile Name", CurrentValue = "", PlaceholderText = "Choose a custom name",
    RemoveTextAfterFocusLost = false, Flag = "DemoProfileName", Callback = report("Profile Name")})
Settings:CreateInput({Name = "Number Entry", CurrentValue = "75", Numeric = true, PlaceholderText = "Enter a number",
    RemoveTextAfterFocusLost = false, Flag = "DemoNumber", Callback = report("Number Entry")})

Settings:CreateSection("Feedback")
Settings:CreateButton({Name = "Print Status", Callback = function()
    print("[Eclipse Demo] Interface ready.")
end})
Settings:CreateParagraph({Title = "Persistence", Content = "Configuration saving is disabled in this demo. The standalone library can save flagged controls; Eclipse Premium keeps its own profile system."})
Settings:CreateButton({Name = "Close Interface", Callback = function() Eclipse:Destroy() end})

-- All controls exist before a caller optionally restores configuration.
-- Eclipse:LoadConfiguration() is unnecessary because this demo has saving disabled.
Farms:Select()
