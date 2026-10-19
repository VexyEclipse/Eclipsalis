# Eclipse UI

A custom Luau interface for Eclipse: compact filled controls, rounded matte cards, neon accents, living procedural ASCII and the original Eclipse flame. Built directly with Roblox GUI objects. The runtime is one file and does not load Rayfield or any other UI dependency. Version 1.1.0 implements the 19 October visual overhaul.

```lua
local Eclipse = loadstring(game:HttpGet("https://raw.githubusercontent.com/VexyEclipse/Eclipsalis/main/EclipseUI.lua"))()
local Window = Eclipse:CreateWindow({
    Name = "Eclipse Hub",
    LoadingTitle = "ECLIPSE",
    LoadingSubtitle = "CONTROL INTERFACE",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {Enabled = false},
})

local Main = Window:CreateTab("Main")
Main:CreateSection("Movement")
local speed = Main:CreateSlider({
    Name = "Movement Speed", Range = {0, 150}, Increment = 1,
    CurrentValue = 75, Suffix = "studs/s", Flag = "Speed",
    Callback = function(value) print("Speed:", value) end,
})
speed:Set(90)
```

Run the [component gallery](Example.lua) to try the controls without gameplay automation:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/VexyEclipse/Eclipsalis/main/Example.lua"))()
```

## Features

- Five live themes defined by exactly three colors: `Base`, `Primary`, `Accent`.
- Fixed 660×420 window, 38px header, 20px footer, 145px navigation that collapses to a 44px icon rail, and two stable equal-width columns with a 12px gap.
- Spaced L corner brackets matching the supplied SVG: 16px legs, 2px strokes, 8px outer offset; they track the window and hide with it.
- Compact 34px controls, 46px sliders/inputs, filled 4–6px rounded surfaces, native vector icons, soft Accent bloom, focus glows and spring motion.
- Procedural ASCII background with cursor/click ripples, logo boot aura, header waveform, digital tab slices and staggered card reveals.
- Mouse/touch dragging, exact slider entry and color selection, plus a floating mobile reopen button. No UIScale or window resizing.
- Sections, dividers, labels, paragraphs, buttons, toggles, precise sliders, searchable single/multi dropdowns, text/numeric inputs, keyboard/mouse keybinds, HSV/hex/RGB picker, action notifications, dialogs and tooltips.
- Explicit flags, JSON configuration, silent setters, owned task/signal/tween cleanup and held-key release.

Default uses charcoal, white and violet. Other presets are `CyberYellow`, `AmberGlow`, `NeonCyan`, `Light`. Use `Window.ModifyTheme("NeonCyan")` or `Eclipse:ModifyTheme({Base = ..., Primary = ..., Accent = ...})`. Every chrome color derives from these three tokens. User-selected colors and supplied images are content.

Controls are added to the latest section in a tab. `Section:CreateToggle(...)` also works for explicit grouping. Search only filters visibility; it never changes values. The title region drags the window. K toggles visibility and the floating control reopens it on touch devices. On screens smaller than 660×420 the window retains its pixel size: dragging pans it and reopening recenters the accessible title. `OnClose` can connect the header Close action to your application's cleanup; otherwise Close destroys the UI.

The ASCII renderer uses one shared RenderStepped connection, throttled to 18 updates per second, with bounded cell and ripple counts. Ambient glyphs remain at about 0.89–0.93 transparency; local ripples brighten briefly. The background and waveform stop while minimized, and their resources disconnect on unload. This bounds work; actual frame cost still requires measurement in Roblox.

The original logo PNG is embedded. Executors with `writefile` and `getcustomasset`/`getsynasset` can render it without a separate network download. Otherwise the header shows an E monogram. Supply `LogoId` to use your own published Roblox image. The optional SVG source is in [UI/Assets/eclipse-logo.svg](UI/Assets/eclipse-logo.svg).

## API contract

The primary compatibility target is the legacy Rayfield API used by Eclipse Premium. Existing scripts can keep `CreateWindow`, `CreateTab`, component constructors, `Set`, dropdown `Refresh`, and handle-based `Flags` access. CamelCase option aliases and selected Gen2 conveniences are supported. [Compatibility notes](UI/RAYFIELD_COMPATIBILITY.md) describe the precise boundary and official references.

| Control | Value field | Setter behavior |
| --- | --- | --- |
| Toggle, slider, input | `CurrentValue` | `Set(value)` calls callback; `Set(value, true)` skips it. |
| Dropdown | `CurrentOption` array | Callback receives an array in single and multiple modes. Empty stays empty. |
| Keybind | `CurrentKeybind` string | `Set(key)` rebinds without executing the action. Hold reports true/false. |
| Color picker | `Color` Color3 | `Set(color)` updates silently for legacy compatibility; user gestures call the callback. |

`Eclipse.Flags[flag]` contains the handle. Controls do not call callbacks during construction. Use `Tooltip` or `Info` on any row. Handles have `SetVisible`, `SetDisabled`, `SetName`, `SetTooltip` and `Destroy`. Library/window visibility helpers include `SetVisibility`, `IsVisible`, `Toggle`, `Hide`/`Show` on the window and `Destroy`.

```lua
Eclipse:Notify({Title = "Saved", Content = "Setup updated", Duration = 4,
    Actions = {{Name = "OK", Callback = function() print("Acknowledged") end}}})
Eclipse:CreateDialog({Title = "Confirm", Content = "Apply this setup?",
    Buttons = {{Name = "Apply", Callback = function() print("Apply") end}, {Name = "Cancel"}}})
```

Configuration is opt-in:

```lua
ConfigurationSaving = {Enabled = true, FolderName = "EclipseUI", FileName = "my-setup"}
-- After creating every flagged control:
Eclipse:LoadConfiguration()
-- Changes save automatically; explicit writes are available:
Eclipse:SaveConfiguration()
```

Saved data is JSON and is never executed. Settings restore before toggles. Missing file APIs or invalid files fail safely. Eclipse Premium disables this layer and keeps its account-specific named profile and teleport handling.

This is not a complete reproduction of every Gen2 extension. Raw-value Gen2 flags, alpha colors, localization, stat/progress/console controls, arbitrary legacy theme dictionaries and external key/Discord/heartbeat integrations are outside this module. `KeySystem = true` is explicitly rejected. Numeric and asset-URI icons work; named external icon catalogs are not fetched.

## Source and checks

Edit `UI/Core.lua`, `UI/Atmosphere.lua`, `UI/Controls.lua` and `UI/Advanced.lua`, then run `python build_ui.py`. The generated `EclipseUI.lua` is the file to host/load. The optional authoring PNG can be omitted because the builder preserves the exact embedded PNG from the existing module. No Python dependencies are required.

Version 1.1.0 compiles with official Luau 0.739 and passes 220 temporary mock checks with no runtime errors or unexpected warnings. Coverage includes compact geometry, callbacks/flags/configuration, pointer identity, corner tracking, popup bloom cleanup, 18 Hz batching/pausing and complete unload. Those checks do not certify actual executor capabilities, game rendering, phone input or live teleport integration. The owner will test it in Roblox. No browser, gameplay or webhook requests are used for this overhaul's verification, and test files are not retained.
