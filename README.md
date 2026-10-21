# Eclipse UI

A compact modern interface for Eclipse. Black, white and blue panels, rounded cards, subtle steady accents, sliding pill switches and the original Eclipse flame logo. Version **1.3.1** (21 October) arranges every feature in one full-width row within a single vertical scrolling stack. Built directly with Roblox GUI objects, with no external UI dependency.

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
- Fixed 520×320 window (40% less area than 660×420), 38px header, 20px footer, 112px navigation that collapses to a 44px icon rail, and a single full-width content column with 12px spacing between sections.
- Spaced L corner brackets matching the supplied SVG: 8px legs, 1px strokes, 3px outer offset; they track the window and hide with it.
- 34px toggles/buttons/dropdowns/keybinds/color pickers and 46px sliders/inputs. Inputs and selectors sit alongside their labels. Cards have 10px corners, feature rows and tabs 8px corners, and the window 12px corners.
- Solid-blue buttons and slider fills with faint static outlines; no section/sidebar hover shadows. A 40×22 pill switch with an 18px circular thumb and short eased switch/tab animations.
- Mouse/touch dragging, exact slider entry and color selection, plus a floating mobile reopen button. No UIScale or window resizing.
- Sections, dividers, labels, paragraphs, buttons, toggles, precise sliders, searchable single/multi dropdowns, text/numeric inputs, keyboard/mouse keybinds, HSV/hex/RGB picker, action notifications, and dialogs when explicitly requested by the caller. Tooltips are disabled.
- Explicit flags, JSON configuration, silent setters, owned task/signal/tween cleanup and held-key release.

The default theme uses Base #050505, Primary #FFFFFF and Accent #2563EB. Other presets remain available for saved profiles. All chrome colors derive from these three tokens.

Controls are added to the latest section in a tab. `Section:CreateToggle(...)` also works for explicit grouping. Search only filters visibility; it never changes values. The title region smoothly drags the window on rendered frames; the movement listener stops after settling. K toggles visibility and the 36px flame-icon control reopens it, with a faint steady glow. On screens smaller than 520×320 the window retains its pixel size: dragging pans it and reopening recenters the accessible title. `OnClose` can connect the header Close action to your application's cleanup; otherwise Close destroys the UI.

The ASCII renderer uses one shared RenderStepped connection, throttled to 18 updates per second, with bounded cell and ripple counts. Ambient glyphs remain at about 0.89–0.93 transparency; pointer-triggered ripples are disabled. The background and waveform stop while minimized, and their resources disconnect on unload. This bounds work; actual frame cost still requires measurement in Roblox.

The owner's original white flame logo is preserved, as requested on 21 October. Its exact transparent PNG is embedded in the module and loaded with executor `writefile` plus `getcustomasset`/`getsynasset`; an E monogram is the fallback. No generated logo is used. Supply `LogoId` for your own published image instead. The original vector trace is [UI/Assets/eclipse-logo.svg](UI/Assets/eclipse-logo.svg).

## API contract

The primary compatibility target is the legacy Rayfield API used by Eclipse Premium. Existing scripts can keep `CreateWindow`, `CreateTab`, component constructors, `Set`, dropdown `Refresh`, and handle-based `Flags` access. CamelCase option aliases and selected Gen2 conveniences are supported. [Compatibility notes](UI/RAYFIELD_COMPATIBILITY.md) describe the precise boundary and official references.

| Control | Value field | Setter behavior |
| --- | --- | --- |
| Toggle, slider, input | `CurrentValue` | `Set(value)` calls callback; `Set(value, true)` skips it. |
| Dropdown | `CurrentOption` array | Callback receives an array in single and multiple modes. Empty stays empty. |
| Keybind | `CurrentKeybind` string | `Set(key)` rebinds without executing the action. Hold reports true/false. |
| Color picker | `Color` Color3 | `Set(color)` updates silently for legacy compatibility; user gestures call the callback. |

`Eclipse.Flags[flag]` contains the handle. Controls do not call callbacks during construction. `Tooltip`, `Info` and `SetTooltip` retain metadata only and never display pop-ups. Handles have `SetVisible`, `SetDisabled`, `SetName`, `SetTooltip` and `Destroy`. Library/window visibility helpers include `SetVisibility`, `IsVisible`, `Toggle`, `Hide`/`Show` on the window and `Destroy`.

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

Edit `UI/Core.lua`, `UI/Atmosphere.lua`, `UI/Controls.lua` and `UI/Advanced.lua`, then run `python build_ui.py`. The generated `EclipseUI.lua` is the file to host/load. The original PNG is embedded; the builder reads UI/Assets/eclipse-logo.png when present or preserves the exact embedded bytes from the existing module when absent. No Python dependencies are required.

The 19 October v1.2.0 redesign compiled with official Luau 0.739 and passed 65 focused temporary mock checks for geometry, boot/native branding, field fit in both sidebar states, title/search hit areas, themes, selected-tab contrast, basic setters/callbacks, search, visibility and cleanup. Earlier 1.1.0 checks are historical. Local checks do not certify Roblox font metrics/rendering, phone input, executor behavior or live profile/teleport integration. Verify those in Roblox. Test files are not retained and no game/webhook calls were made.

The 21 October original-logo restoration compiles in the library, sample and Premium wrappers/extracted runtime. Embedded PNG bytes match the original supplied asset. The previous 65-check suite was not rerun; executor image rendering remains a live check.

### 21 October modern layout update

Historical v1.3.0 validation: it compiled in the library, example, both Premium wrappers and extracted runtime. 33 temporary focused checks pass for full-width section order/spacing, search/hiding/destroyed sections, expanded/collapsed widths, scroll bounds, rounded geometry, glow states/pulse settling, pill-switch positions/contrast and callback/silent-setter behavior. These checks use isolated real library functions and mocks, not Roblox rendering. The original logo and gameplay/profile contracts remain unchanged. No retained tests or game/webhook calls.


## 21 October minimal styling update

UI v1.3.1 uses black (#050505), white (#FFFFFF) and blue (#2563EB). Removed footer status text, duplicate version/FPS display and its sampling loop, all hover/long-press tooltips, section header accents, section/row/sidebar hover halos and ambient pointer ripples. Buttons and slider fills use solid blue with one faint static outline. Brackets have 8px legs, 1px lines and a 3px gap. Window dragging uses frame-rate-independent smoothing with a render listener only while dragging/settling; minimize, viewport changes and destruction cancel it. The reopen control is a 36px original-flame icon with a faint outline. Dropdown/color-picker menus and explicit notification/dialog APIs remain; the gallery no longer has popup-demo buttons. Original logo, fixed geometry, single-column order and gameplay/profile contracts are preserved.

Local compilation and focused drag lifecycle checks are recorded in the project UI notes. Actual Roblox appearance and perceived drag smoothness still require live verification.


Local validation: library/gallery, both Premium wrappers and extracted embedded runtime compile with Luau 0.739. Actual smooth-drag helper checks pass at 30/60/120 Hz for constrained approach, frame-rate independence, exact settling, release disconnection, hide cancellation and cleanup. Rebuild is reproducible, original PNG hash matches, and Premium entry files are identical. Temporary checks were removed. Live Roblox rendering and perceived smoothness remain unverified.
