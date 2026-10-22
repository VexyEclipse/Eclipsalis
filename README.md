# Eclipse UI

A polished, compact Roblox interface for Eclipse. Version **1.6.2** uses near-black Absolute Dark surfaces, restrained blue active states, rounded switches and the original white flame logo. Built directly with Roblox GUI objects, with no external UI dependency.

```lua
local Eclipse = loadstring(game:HttpGet("https://raw.githubusercontent.com/VexyEclipse/Eclipsalis/main/EclipseUI.lua"))()
local Window = Eclipse:CreateWindow({
    Name = "Eclipse Hub",
    LoadingTitle = "ECLIPSE",
    LoadingSubtitle = "v1.4.1",
    Theme = "Absolute Dark",
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

- Responsive 660×420 logical desktop window; compact screens use one section column. No manual resizing.
- 148px sidebar with a 44px collapsed rail, rounded icon search, thin 3px content scrollbar and soft window shadow.
- 36px interactive rows on one 16px card inset; 64px value fields, 88px dropdown selectors, 28px keycaps and fully rounded switches. Row labels wrap and grow the row instead of truncating.
- Neutral buttons, borderless row hover, 4px slider tracks with 12px knobs and 0.15s Quad Out motion.
- Sans labels (14px), bold uppercase secondary section titles (11px) and monospace only for numeric values/keybinds.
- Sections, dividers, labels, paragraphs, buttons, toggles, exact-value sliders, searchable single/multi dropdowns, text/numeric inputs, keyboard/mouse keybinds, HSV/hex/RGB picker, explicit notifications and dialogs.
- Compatible flags, silent setters, JSON configuration and owned cleanup. Existing custom theme APIs and named presets remain available for callers.

The default palette is Absolute Dark: window #020304, sidebar #050608, sections #090B0E, row hover #11151B, inputs #010203, active accent #3B82F6, text #E6E8EC and secondary text #8A8F98. Sections use a faint white stroke at 94% transparency. The original Base/Primary/Accent customization API remains; each preset now supplies its own semantic surface colors.

Controls are added to the latest section in a tab. `Section:CreateToggle(...)` also works for explicit grouping. Search only filters visibility; it never changes values. The title region smoothly drags the window on rendered frames; the movement listener stops after settling. K toggles visibility and the 36px flame-icon control reopens it, with a faint steady glow. Scaling and compact layout fit smaller viewports initially; dragging can move the body off-screen while leaving a reachable title strip. Popovers use the same logical coordinates. `OnClose` can connect the header Close action to your application's cleanup; otherwise Close destroys the UI.

The ASCII renderer uses one shared RenderStepped connection, throttled to 18 updates per second, with bounded cell and ripple counts. The Matrix look is on by default: ambient glyphs fall behind the cards at about 0.70–0.82 transparency, and buttons carry a small glyph block. Pass `Matrix = false` to `CreateWindow` for a faint static wash and arrow buttons instead. The background stops while minimized, and its resources disconnect on unload.

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


## Historical: 21 October minimal styling update

UI v1.3.1 uses black (#050505), white (#FFFFFF) and blue (#2563EB). Removed footer status text, duplicate version/FPS display and its sampling loop, all hover/long-press tooltips, section header accents, section/row/sidebar hover halos and ambient pointer ripples. Buttons and slider fills use solid blue with one faint static outline. Brackets have 8px legs, 1px lines and a 3px gap. Window dragging uses frame-rate-independent smoothing with a render listener only while dragging/settling; minimize, viewport changes and destruction cancel it. The reopen control is a 36px original-flame icon with a faint outline. Dropdown/color-picker menus and explicit notification/dialog APIs remain; the gallery no longer has popup-demo buttons. Original logo, fixed geometry, single-column order and gameplay/profile contracts are preserved.

Local compilation and focused drag lifecycle checks are recorded in the project UI notes. Actual Roblox appearance and perceived drag smoothness still require live verification.


Local validation: library/gallery, both Premium wrappers and extracted embedded runtime compile with Luau 0.739. Actual smooth-drag helper checks pass at 30/60/120 Hz for constrained approach, frame-rate independence, exact settling, release disconnection, hide cancellation and cleanup. Rebuild is reproducible, original PNG hash matches, and Premium entry files are identical. Temporary checks were removed. Live Roblox rendering and perceived smoothness remain unverified.


## Historical: 22 October combined layout

Version 1.3.2 restored the original 660×420 window and two section columns, removed the ECL/stripe/status footer decorations, and preserved the original flame logo. The v1.4.0 section below supersedes its styling and fixed-pixel sizing.

Local validation: library and demo compile with Luau 0.739; 11 focused actual-reflow checks pass for expanded/collapsed widths, ordering, canvas bounds, filtering, empty results and hidden/destroyed sections. Build is reproducible and embedded original-logo bytes match. Temporary checks were removed. Gameplay was not changed; live Roblox appearance/input remains unverified.


## 22 October v1.4.0 polish

Version 1.4.0 uses the requested charcoal palette, a 660×420 logical window with a 48px header, 148px sidebar (44px collapsed), and two alternating section columns. A shared UIScale keeps the window, menus, dragging and reopen button in the same coordinate space; narrow screens use a 400px logical window, collapsed navigation and one section column. The window fits the available viewport without a resize handle. Sections have 16px internal padding, 12px column/section gaps, 4px row gaps, uppercase 13px secondary headings and a centered divider. Interactive rows are 34px high with 12px side padding, 14px sans labels and 64px value fields. Sections have an optional faint 1px white stroke; rows have no borders. Selected tabs use a 15% blue fill, blue icon/text and a 2px left marker. All switches share the same rounded style; sliders have a 4px track and 12px knob, growing to 16px during hover/drag. A soft window shadow, short fades and 0.15s Quad Out switch/slider motion replace decorative glow. External brackets, INDEX, header watermark, header divider, ECL/stripes and the status footer are absent. Search is a single rounded icon button; dropdown filters appear only when requested. No hover halos or tooltips.

Local validation for v1.4.0: library/gallery, both Premium wrappers and the extracted embedded runtime compile with Luau 0.739. 57 focused temporary checks cover real dropdown callbacks and silent restoration, Halloween selection/cooldown state, separate toggle/slider behavior, slider/input geometry, six viewport sizes and popup bounds, scaled/two-column/compact reflow, ESP font bounds and reversible No Fall cleanup. The build is reproducible, the original embedded PNG is unchanged, and the Premium entries are identical. Checks use isolated source functions with mocks, not Roblox rendering or game purchases; temporary files are removed. Live font fit, touch, viewport changes, animation cost, profile/teleport restoration and purchase acceptance still require the owner’s client.


## Current v1.4.1 Matrix and layout follow-up

UI v1.4.1 follow-up (22 October): dragging now permits the window to extend beyond every screen edge while retaining a reachable title strip; reopening recenters it. K/minimize resets the 36px flame reopen button to the top center, including after viewport changes. Collapsed navigation icons and the collapse control are centered on the 44px rail, with aligned expanded positions. Dropdowns use an 88px selector with separate truncated text and arrow lanes, preserving full selection values and callback shapes. Action buttons use a distinct neutral input surface and a six-cell falling-code detail; the ambient background has stronger monochrome Matrix streams. Both share the existing bounded 18Hz decoration worker and hidden/unload cleanup. A finely feathered downward shadow replaces the three coarse layers. Sharp 8px brackets with 1px strokes sit 3px from the window and follow movement/visibility. The existing charcoal/blue palette, 34px rows, separate movement switches/sliders, tooltips-off behavior and feature contracts remain.

Validation: Luau compilation of the generated library and gallery; 31 focused temporary geometry/selection checks passed for off-screen limits and reachable dragging, top-center reopen positioning, non-overlapping selector lanes, unchanged single/multi/empty selection summaries, sidebar centering and chrome following/hiding. Temporary checks were removed. These are local checks, not a Roblox rendering or touch test. Matrix motion, shadow appearance, long labels and live dragging remain in-game checks. Premium gameplay source is unchanged by v1.4.1.


### 22 October input overflow follow-up

v1.4.2 input overflow fix: input placeholders and unfocused values use end ellipsis instead of drawing outside the field. Focus removes truncation so the full value remains editable; blur restores ellipsis. Input/value containers clip their contents, and advanced text fields use the same truncation behavior. Stored values and callbacks are unchanged. Library/gallery compilation passed; actual Roblox placeholder rendering remains a live check.


v1.4.3: corner brackets now use the shared Accent color (#3B82F6 by default), with a subtle static three-layer blue falloff behind their sharp 1px edges. Glow follows bracket positioning, hiding and theme changes; no animation worker was added. Library/gallery compile locally; glow appearance remains a live Roblox check.


v1.4.4: fixed color-picker badge overlap by removing parent UIPadding and placing the hex label and 16px swatch in separate lanes inside a 96px badge. The hex label has end ellipsis and the badge clips contents; picker/setter/callback behavior is unchanged. Library/gallery compilation passed. Live Roblox rendering remains to be checked.


## 22 October full theme palettes — v1.5.0

v1.5.0 theme update: every preset now owns Sidebar, Section, Hover, Input, Secondary, Border, Shadow and OnAccent colors as well as Base/Primary/Accent. Light uses pale surfaces, dark readable labels, blue active states and a dark drop shadow; theme changes update existing controls and focus states. CyberYellow uses olive-black surfaces and acid yellow, AmberGlow uses warm brown/copper surfaces and amber, and NeonCyan uses deep blue-teal surfaces and cyan. Absolute Dark only deepens Default backgrounds while preserving its text, secondary text and blue accent. Three-token custom palettes still work through derived surface colors; optional semantic overrides are supported. Library.ThemeNames exposes the ordered preset list; the gallery and local Premium selector use it, with a six-name fallback. Existing saved theme aliases remain supported. No gameplay behavior changes.

Validation: 96 temporary checks passed for all six presets, live card/input bindings, primary and secondary text contrast (at least 4.5:1 on the five main surfaces), switch contrast, darker Absolute Dark surfaces, retained foreground colors, legacy aliases, three-token custom themes, and invalid palette rejection. Library/gallery, both Premium wrappers and the extracted runtime compile; Premium entry files match. Temporary verification files were removed. Roblox rendering and profile/teleport theme restoration remain live checks.


## 22 October premium polish — v1.6.0

v1.6.0 layout and polish pass: row labels wrap onto a second line and grow the row instead of ending in an ellipsis. The ambient glyph field and the button glyph decorations are removed; a faint static wash replaces them. Section headers, rules and row content share one 16px inset. Sliders put the label and exact value (with a dimmer unit) on one line above a full-width track; the value is still editable on click. Off switches use a raised track with a hairline edge and a muted knob; the knob grows with a slight overshoot when turned on. Buttons are outlined, use a medium-weight label and an action arrow that turns accent and nudges on hover. Header icon buttons are borderless with hover surfaces (close hovers red), a hairline separates the header, and a "TIER / version" subtitle renders the tier as an accent pill. API, callbacks and saved values are unchanged.

v1.6.1: the Matrix look is back by default: the ambient glyph field behind the cards and the glyph block on buttons, alongside the v1.6.0 layout and control polish. `Matrix = false` in `CreateWindow` keeps the plain wash and arrow buttons. Absolute Dark is now the default theme; `Theme = "Default"` (and the old aliases) resolve to it, and the previous charcoal palette is available as `"Charcoal"`. Sidebar icons are redrawn with rounded strokes and curves: house, eye, lightning bolt (farms) and gear, plus player, teleport pin, combat sword, info and misc icons matched by keyword in the tab name (for example "Auto Farms" or "Player ESP"); other tabs get a four-tile grid.

v1.6.2: sidebar and header icons use [Lucide](https://lucide.dev) (v0.460.0, ISC license) geometry: house, eye, zap, settings, user, map-pin, swords, info, ellipsis, layout-grid, search, panel-left and keyboard. `tools/lucide_icons.py` downloads the SVGs and flattens them into `UI/Icons.lua`, so icons stay theme-colored vector strokes with no image uploads. Tabs are matched by keyword ("Auto Farms" gets zap, "Player ESP" gets eye), and a tab's `Icon` may name one of these directly. The top bar now uses the theme's Sidebar surface instead of Base, so it visibly changes with the theme; its top corners are rounded to the window and it meets the sidebar without notches. Theme changes now also recolor the corner brackets and their glow (the glow keeps its falloff transparency), plus any other part only the UI tree referenced: theme bindings no longer sit in a weak table, where Roblox could drop an on-screen Instance's entry.
