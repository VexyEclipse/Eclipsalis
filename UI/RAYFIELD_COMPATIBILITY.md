# Eclipse UI: Rayfield compatibility reference

Reviewed against the official documentation on **18–19 October 2026**. The standalone build is `Current/EclipseUI.lua`, assembled from `UI/Core.lua`, `UI/Atmosphere.lua`, `UI/Controls.lua` and `UI/Advanced.lua`. The 1.3.2 combined-layout redesign preserves the control/flag contracts below. This records the migration contract and the differences that matter when adapting other scripts. The current module source and its local validation results remain the authority for implemented behavior. This is not a claim that every service integration or every Rayfield Gen2 extension is reproduced.

## Eclipse Premium contract

Premium currently uses the legacy Rayfield interface. Its initialization order is library → window → HubRuntime wrappers → all tabs and controls → profile/session restoration. Keep the existing `Flags` control handles and callback timing: changing these would alter farms and profile loading even if the UI looked correct.

| Surface | Contract required by Premium and the supplied brief |
| --- | --- |
| Window | `CreateWindow(options)`, positional `CreateTab(name, icon)`, `Destroy`, visibility controls, loading labels and toggle key. |
| Section/text | `CreateSection`, `CreateDivider`, `CreateLabel`, `CreateParagraph`, and their update methods. Sections group following controls into Eclipse cards. |
| Values | Toggle, slider and input expose `CurrentValue`; dropdown exposes a copied `CurrentOption` table; keybind exposes `CurrentKeybind`; color picker exposes `Color`. |
| Flags | `library.Flags[flag]` holds the element handle. Premium reads handle properties directly; replacing handles with raw values would break it. |
| Updates | Value handles support `:Set(value)`; dropdown supports `:Refresh(options)`. Dropdown callbacks receive a selection table in both single and multiple mode. |
| Keybind | Changing the binding must not execute its action. `HoldToInteract` reports press/hold and release state. |
| Theme | `Window.ModifyTheme(theme)` works with dot syntax, as used by Premium. Eclipse themes contain exactly `Base`, `Primary`, `Accent`; all chrome colors derive from them. |
| Persistence | Standalone use provides JSON save/load through executor file functions. Premium disables library persistence and retains its own named profiles and session handoff. |
| Feedback | The library can provide notifications and dialogs. Premium status continues to use console output. |

The legacy [interactive element documentation](https://docs.sirius.menu/rayfield/elements/interactive) defines the current value fields, flags, table-shaped dropdown callbacks and `Set`/`Refresh`. [Window documentation](https://docs.sirius.menu/rayfield/windows), [text elements](https://docs.sirius.menu/rayfield/elements/text), [keybinds](https://docs.sirius.menu/rayfield/elements/keybinds) and [themes](https://docs.sirius.menu/rayfield/themes) establish the other calling forms above.

**Color restoration exception:** Premium's restoration code calls the color picker's `Set`, then explicitly calls its callback because the prior legacy implementation changes only the visual value. Preserve this for legacy controls; changing it requires changing that restoration path together, or callbacks will run twice. The legacy documentation shows the setter but does not specify this callback exception; the existing client source establishes it.

**Construction callbacks:** Creating a control must not start gameplay features before all controllers exist. Premium restores settings and positions before enabling feature toggles at the footer. Library configuration loading must remain after control creation, consistent with the legacy [loading guide](https://docs.sirius.menu/rayfield/getting-started).

## Supported additions and Gen2 differences

The implemented library also accepts table-style tab/section creation, common camelCase spellings of existing fields, `label` as a name alias, `value`/`default` for initial values, `multiSelect` for multiple dropdown selection, and `hold` for keybind hold mode. Controls expose `.value` alongside their legacy fields. Most value setters accept a silent second argument; the legacy color setter stays silent. Dropdowns add `Add` and `Remove`. Sections can create their own controls as fluent containers. These are convenience additions rather than an alternate raw-value flag mode.

The standalone feedback methods are `Notify`, `CreateDialog`, `Prompt`, and `Popup`. They provide custom buttons and callbacks. Their behavior is defined by Eclipse source; method aliases do not promise every Gen2 notification, toast or popup feature.

The [Gen2 introduction](https://docs.sirius.menu/rayfield-gen2) documents camelCase options with PascalCase aliases. Accepting these spellings is useful, but spelling aliases alone do not establish Gen2 parity:

| Documented Gen2 behavior | Difference from the Premium legacy contract |
| --- | --- |
| `window.Flags` reads/writes raw values; `window:Get` and `window:Set` address flags. | Premium's library-level `Flags` stores handles. Keep these interfaces distinct if both are offered. |
| Handles use `.value`; `Set(value, true)` suppresses callbacks. | Legacy property names must remain available. Keybind setters change bindings rather than pressing them. |
| Dropdown `.value` remains a table, but a single-selection callback receives a string. | Legacy single-selection callbacks receive a table. Callback shape requires an explicit mode; it cannot be inferred safely from key casing alone. |
| Value elements derive save keys from names and support `forgetState`. | Premium supplies stable explicit flags and owns restoration. |
| Gen2 includes groups, stat/progress/console elements, tags, localization, alpha colors, configuration management and platform integrations. | These are additional surfaces. Only methods actually present in Eclipse should be described as supported. |

These distinctions come from the Gen2 [element contract](https://docs.sirius.menu/rayfield-gen2/elements/overview), [saving contract](https://docs.sirius.menu/rayfield-gen2/saving), [dropdown contract](https://docs.sirius.menu/rayfield-gen2/elements/dropdowns), [keybind contract](https://docs.sirius.menu/rayfield-gen2/elements/keybinds), and [tabs/groups](https://docs.sirius.menu/rayfield-gen2/tabs). The requested modal controls correspond to Gen2 [popups](https://docs.sirius.menu/rayfield-gen2/popups); legacy notifications are documented [here](https://docs.sirius.menu/rayfield/notifications).

The Base/Primary/Accent customization interface and existing preset names remain available. The v1.4.0 default adds fixed neutral semantic surfaces for sidebar, cards, hover and inputs; arbitrary legacy Rayfield theme dictionaries remain unsupported. Logo assets and user-selected picker colors are content, independent from theme chrome.

No analytics, heartbeat requests, Discord joining, remote key checks, or claims of anti-cheat invisibility follow from UI compatibility. Premium currently has those integrations disabled. Unknown or unsupported external options must not silently create external requests.

## Logo and hosting

The owner selected the original white flame logo on 21 October. `Assets/eclipse-logo.png` is the original transparent 500×500 PNG, embedded in the module; the original two-path SVG trace remains in `Assets/eclipse-logo.svg`. The local custom-asset path uses `writefile` and `getcustomasset`/`getsynasset`, with an E monogram fallback. The original image crop at (168,52), size 162×372, removes canvas padding. Explicit `LogoId`/`Icon` assets remain uncropped. Generated concepts are not used.

The owner selected [VexyEclipse/Eclipsalis](https://github.com/VexyEclipse/Eclipsalis) for the standalone library. It is loaded with the familiar `loadstring(game:HttpGet(rawUrl))()` pattern. The final raw URL must match the entry file actually published in that repository; a local file path or an uncreated branch is not a working hosted loader. Keep this compatibility reference separate from any publication check until the remote file has been verified.

## Validation boundary

Version 1.4.0 uses the requested charcoal palette, a 660×420 logical window with a 48px header, 148px sidebar (44px collapsed), and two alternating section columns. A shared UIScale keeps the window, menus, dragging and reopen button in the same coordinate space; narrow screens use a 400px logical window, collapsed navigation and one section column. The window fits the available viewport without a resize handle. Sections have 16px internal padding, 12px column/section gaps, 4px row gaps, uppercase 13px secondary headings and a centered divider. Interactive rows are 34px high with 12px side padding, 14px sans labels and 64px value fields. Sections have an optional faint 1px white stroke; rows have no borders. Selected tabs use a 15% blue fill, blue icon/text and a 2px left marker. All switches share the same rounded style; sliders have a 4px track and 12px knob, growing to 16px during hover/drag. A soft window shadow, short fades and 0.15s Quad Out switch/slider motion replace decorative glow. External brackets, INDEX, header watermark, header divider, ECL/stripes and the status footer are absent. Search is a single rounded icon button; dropdown filters appear only when requested. No hover halos or tooltips.

Compile the standalone library, the Premium outer wrapper, and the extracted embedded Premium runtime. Useful temporary checks cover setter/callback order, flags, dropdown pruning, config serialization and missing executor functions, section filtering/reflow, and repeated cleanup. Keep temporary verification outside the project and remove it afterward; do not recreate `Current/tests`.

Local compilation and mocks cannot establish visual behavior in Roblox, phone touch gestures, executor image support, real viewport sizing, profile restoration during teleport, or active gameplay cleanup. Those remain live checks until observed in the owner's client. Never send a real webhook merely to validate UI work.


Tooltips are disabled as of v1.3.1: Tooltip/Info and SetTooltip only retain metadata. Buttons and toggles create no automatic pop-ups; explicit Notify/CreateDialog APIs remain available for callers.


Local validation for v1.4.0: library/gallery, both Premium wrappers and the extracted embedded runtime compile with Luau 0.739. 57 focused temporary checks cover real dropdown callbacks and silent restoration, Halloween selection/cooldown state, separate toggle/slider behavior, slider/input geometry, six viewport sizes and popup bounds, scaled/two-column/compact reflow, ESP font bounds and reversible No Fall cleanup. The build is reproducible, the original embedded PNG is unchanged, and the Premium entries are identical. Checks use isolated source functions with mocks, not Roblox rendering or game purchases; temporary files are removed. Live font fit, touch, viewport changes, animation cost, profile/teleport restoration and purchase acceptance still require the owner’s client.
