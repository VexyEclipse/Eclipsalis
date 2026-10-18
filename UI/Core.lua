-- Eclipse UI core. Authoring source; build_ui.py assembles a single loadstring module.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Library = {Flags = {}, Version = "1.0.0", Name = "Eclipse UI"}
local Tab = {}
Tab.__index = Tab
local ctx = {Tab = Tab, UIS = UIS, fontMono = Enum.Font.Code, pad = 12}
local state = {alive = true, connections = {}, threads = {}, bindings = setmetatable({}, {__mode = "k"}),
    tweens = setmetatable({}, {__mode = "k"}), tabs = {}, controls = {}, scale = 1, query = "", loading = false}
local function palette(base, primary, accent)
    return {Base = Color3.fromHex(base), Primary = Color3.fromHex(primary), Accent = Color3.fromHex(accent)}
end
Library.Themes = {
    Default = palette("0A0A0E", "EEEEF4", "A89AFF"),
    CyberYellow = palette("0B0C0B", "F2F2E8", "FCEE09"),
    AmberGlow = palette("100D09", "F2EEE6", "FF9E00"),
    NeonCyan = palette("080E11", "E5F1F3", "00F0FF"),
    Light = palette("ECECF1", "17171E", "6854D8"),
}
local aliases = {Eclipse = "Default", Amethyst = "Default", Bloom = "Default", Serenity = "Default",
    DarkBlue = "NeonCyan", Ocean = "NeonCyan", Green = "NeonCyan"}
state.theme = Library.Themes.Default
Library.Theme = Library.Themes
function ctx.alive() return state.alive end
function ctx.theme() return state.theme end
function ctx.unscale(value) return value / math.max(state.scale, 0.01) end
function ctx.screen() return state.screen end
function ctx.overlay() return state.overlay end
function ctx.options(raw)
    if type(raw) == "string" then return {Name = raw} end
    local result = {}
    for key, value in pairs(type(raw) == "table" and raw or {}) do
        if type(key) == "string" then
            local normalized = string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
            if result[normalized] == nil or key == normalized then result[normalized] = value end
        end
    end
    if result.Name == nil then result.Name = result.Label end
    if result.CurrentValue == nil then result.CurrentValue = result.Value end
    if result.CurrentValue == nil then result.CurrentValue = result.Default end
    if result.Color == nil then result.Color = result.CurrentColor or result.CurrentValue end
    if result.CurrentKeybind == nil then result.CurrentKeybind = result.Key or result.CurrentValue end
    if result.MultipleOptions == nil then result.MultipleOptions = result.MultiSelect end
    if result.CurrentOption == nil then result.CurrentOption = result.CurrentValue end
    if result.ConfigurationSaving == nil then result.ConfigurationSaving = result.Configuration end
    return result
end
function ctx.new(class, properties, parent)
    local object = Instance.new(class)
    if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
    for key, value in pairs(properties or {}) do object[key] = value end
    if parent then object.Parent = parent end
    return object
end
function ctx.connect(signal, callback)
    local connection = signal:Connect(function(...)
        if state.alive then callback(...) end
    end)
    table.insert(state.connections, connection)
    if #state.connections % 128 == 0 then
        for i = #state.connections, 1, -1 do
            if not state.connections[i].Connected then table.remove(state.connections, i) end
        end
    end
    return connection
end
local function schedule(delaySeconds, callback)
    if not state.alive then return nil end
    local thread = coroutine.create(function()
        if state.alive then callback() end
        state.threads[coroutine.running()] = nil
    end)
    state.threads[thread] = true
    if delaySeconds then task.delay(delaySeconds, thread) else task.spawn(thread) end
    return thread
end
function ctx.spawn(callback) return schedule(nil, callback) end
function ctx.delay(seconds, callback) return schedule(seconds, callback) end
function ctx.tween(object, goals, duration, easing)
    if not state.alive or not object or not object.Parent then return end
    local active = state.tweens[object] or {}
    for key in pairs(goals) do if active[key] then active[key]:Cancel() end end
    local animation = TweenService:Create(object, TweenInfo.new(duration or 0.18, easing or Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out), goals)
    for key in pairs(goals) do active[key] = animation end
    state.tweens[object] = active
    local completed
    completed = animation.Completed:Connect(function()
        for key in pairs(goals) do if active[key] == animation then active[key] = nil end end
        if next(active) == nil then state.tweens[object] = nil end
        if completed then completed:Disconnect() end
    end)
    animation:Play()
    return animation
end
local function color(role)
    return type(role) == "function" and role(state.theme) or state.theme[role]
end
function ctx.bind(object, property, role)
    local bindings = state.bindings[object] or {}
    bindings[property] = role
    state.bindings[object] = bindings
    object[property] = color(role)
end
function ctx.stroke(parent, role, transparency)
    local stroke = ctx.new("UIStroke", {Thickness = 1, Transparency = transparency or 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
    ctx.bind(stroke, "Color", role or "Primary")
    return stroke
end
function ctx.text(parent, value, properties)
    local props = {Text = tostring(value or ""), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.fromScale(1, 1), RichText = false}
    for key, item in pairs(properties or {}) do props[key] = item end
    local label = ctx.new("TextLabel", props, parent)
    ctx.bind(label, "TextColor3", "Primary")
    return label
end
function ctx.iconAsset(value)
    if type(value) == "number" and value > 0 then return "rbxassetid://" .. tostring(value) end
    if type(value) == "string" then
        if tonumber(value) and tonumber(value) > 0 then return "rbxassetid://" .. value end
        if string.match(value, "^rbxasset") or string.match(value, "^rbxthumb://") then return value end
    end
    return nil
end
function ctx.isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
-- One shared pointer dispatcher, with pointer identity retained for multi-touch.
local dragTargets = setmetatable({}, {__mode = "k"})
local dragSession
local function point(input) return Vector2.new(input.Position.X, input.Position.Y) end
function ctx.drag(gui, onPosition, onEnd)
    dragTargets[gui] = {move = onPosition, finish = onEnd}
    ctx.connect(gui.InputBegan, function(input)
        if not ctx.isPointer(input) or dragSession then return end
        local target = dragTargets[gui]
        if not target then return end
        dragSession = {input = input, target = target, gui = gui}
        target.move(point(input), input)
    end)
    return function() dragTargets[gui] = nil end
end
ctx.connect(UIS.InputChanged, function(input)
    local drag = dragSession
    if not drag then return end
    if not drag.gui.Parent then dragSession = nil return end
    if input == drag.input or (drag.input.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement) then drag.target.move(point(input), input) end
end)
ctx.connect(UIS.InputEnded, function(input)
    local drag = dragSession
    if drag and input == drag.input then
        dragSession = nil
        if drag.target.finish then drag.target.finish(point(input), input) end
    end
end)
local function closePopup()
    if state.closePopup then state.closePopup() end
end
function ctx.popup(control, width, height)
    closePopup()
    if not state.overlay then error("CreateWindow must be called first", 2) end
    local blocker = ctx.new("TextButton", {Name = "DismissPopup", Text = "", AutoButtonColor = false,
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50}, state.overlay)
    local panel = ctx.new("Frame", {Name = "Popover", Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 0, ZIndex = 51, ClipsDescendants = true}, state.overlay)
    ctx.bind(panel, "BackgroundColor3", "Base")
    ctx.stroke(panel, "Accent", 0.35)
    local scale = ctx.new("UIScale", {Scale = state.scale}, panel)
    local function position()
        if not panel.Parent or not control.Frame.Parent then return end
        local size = state.overlay.AbsoluteSize
        local factor = math.min(state.scale, math.max(0.25, (size.X - 16) / width),
            math.max(0.25, (size.Y - 16) / height))
        scale.Scale = factor
        local anchor = control.Frame.AbsolutePosition
        local x = math.clamp(anchor.X, 8, math.max(8, size.X - width * factor - 8))
        local below = anchor.Y + control.Frame.AbsoluteSize.Y + 4
        local y = below + height * factor <= size.Y - 8 and below or anchor.Y - height * factor - 4
        panel.Position = UDim2.fromOffset(x, math.clamp(y, 8, math.max(8, size.Y - height * factor - 8)))
    end
    local sizeConnection = ctx.connect(state.overlay:GetPropertyChangedSignal("AbsoluteSize"), position)
    local function close()
        sizeConnection:Disconnect()
        if panel.Parent then panel:Destroy() end
        if blocker.Parent then blocker:Destroy() end
        if state.closePopup == close then state.closePopup = nil end
    end
    state.closePopup = close
    ctx.connect(blocker.Activated, close)
    -- A panel catches taps so touching blank panel padding does not dismiss it.
    panel.Active = true
    position()
    return panel, close
end
local function scramble(label, final)
    local generation = (label:GetAttribute("DecodeGeneration") or 0) + 1
    label:SetAttribute("DecodeGeneration", generation)
    local alphabet = "01/<>_"
    ctx.spawn(function()
        for step = 1, 5 do
            if not label.Parent or label:GetAttribute("DecodeGeneration") ~= generation then return end
            local length = #final
            local decoded = math.floor(length * step / 5)
            local pieces = {string.sub(final, 1, decoded)}
            for _ = decoded + 1, length do
                local index = math.random(1, #alphabet)
                table.insert(pieces, string.sub(alphabet, index, index))
            end
            label.Text = table.concat(pieces)
            task.wait(0.03)
        end
        if label.Parent and label:GetAttribute("DecodeGeneration") == generation then label.Text = final end
    end)
end
local tooltipGeneration = 0
local function hideTooltip()
    tooltipGeneration += 1
    if state.tooltip then state.tooltip:Destroy(); state.tooltip = nil end
end
function ctx.tooltip(control, value)
    control.Tooltip = value
    if control.TooltipBound then return end
    control.TooltipBound = true
    local function queue(delaySeconds)
        if not control.Tooltip or control.Tooltip == "" then return end
        hideTooltip()
        local generation = tooltipGeneration
        ctx.delay(delaySeconds, function()
            if generation ~= tooltipGeneration or control.Destroyed or state.minimized or not state.overlay then return end
            local label = ctx.text(state.overlay, tostring(control.Tooltip), {Name = "Tooltip", Font = ctx.fontMono,
                TextSize = 12, TextWrapped = true, Size = UDim2.fromOffset(260, 68), BackgroundTransparency = 0,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 90})
            ctx.bind(label, "BackgroundColor3", "Base")
            ctx.stroke(label, "Accent", 0.35)
            ctx.new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, label)
            local p = control.Frame.AbsolutePosition
            local size = state.overlay.AbsoluteSize
            label.Size = UDim2.fromOffset(math.min(260, size.X - 16), 68)
            label.Position = UDim2.fromOffset(math.clamp(p.X, 8, math.max(8, size.X - 268)),
                math.clamp(p.Y + control.Frame.AbsoluteSize.Y + 5, 8, math.max(8, size.Y - 76)))
            state.tooltip = label
        end)
    end
    ctx.connect(control.Frame.MouseEnter, function() queue(0.45) end)
    ctx.connect(control.Frame.MouseLeave, hideTooltip)
    ctx.connect(control.Frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local start = point(input)
            queue(0.6)
            local listener
            listener = ctx.connect(input.Changed, function()
                if (point(input) - start).Magnitude > 10 or input.UserInputState == Enum.UserInputState.End then
                    hideTooltip(); listener:Disconnect()
                end
            end)
        end
    end)
end
local function sectionCaption(name) return "// " .. string.upper(tostring(name)):gsub("%s+", "_") end
local function reflow(tab)
    if not state.alive or not tab.Page.Parent then return end
    local width = tab.Page.AbsoluteSize.X / math.max(state.scale, 0.01) - 28
    local columns = width >= 560 and 2 or 1
    local heights = {0, 0}
    local gap = 12
    local cardWidth = columns == 1 and width or (width - gap) / 2
    for _, section in ipairs(tab.Sections) do
        local count = 0
        local sectionMatch = state.query ~= "" and string.find(string.lower(section.Name), state.query, 1, true)
        for _, control in ipairs(section.Controls) do
            local match = state.query == "" or sectionMatch or string.find(string.lower(control.Name or ""), state.query, 1, true)
            local visible = not control.Destroyed and control.Visible ~= false and match ~= nil and match ~= false
            if control.Frame.Parent then control.Frame.Visible = visible end
            if visible then count += 1 end
            if control.Stroke and control.Stroke.Parent then
                ctx.bind(control.Stroke, "Color", state.query ~= "" and visible and "Accent" or "Primary")
                control.Stroke.Transparency = state.query ~= "" and visible and 0.48 or 0.92
            end
        end
        local visible = section.Visible ~= false and (count > 0 or (state.query == "" and section.Explicit))
        section.Frame.Visible = visible
        if visible then
            local column = columns == 1 and 1 or (heights[1] <= heights[2] and 1 or 2)
            local bodyHeight = ctx.unscale(section.Layout.AbsoluteContentSize.Y)
            local height = math.max(44, bodyHeight + 44)
            section.Frame.Position = UDim2.fromOffset(14 + (column - 1) * (cardWidth + gap), 14 + heights[column])
            section.Frame.Size = UDim2.fromOffset(math.max(80, cardWidth), height)
            heights[column] += height + gap
        end
    end
    local height = math.max(heights[1], heights[2])
    tab.Page.CanvasSize = UDim2.fromOffset(0, height + 28)
    if tab.Empty then tab.Empty.Visible = height == 0 end
end
local function queueReflow(tab)
    if tab.ReflowQueued then return end
    tab.ReflowQueued = true
    ctx.delay(0, function() tab.ReflowQueued = false; reflow(tab) end)
end
local function makeSection(tab, name, explicit)
    local frame = ctx.new("Frame", {Name = "Section", BackgroundTransparency = 0,
        Size = UDim2.fromOffset(280, 44), ClipsDescendants = false}, tab.Page)
    ctx.bind(frame, "BackgroundColor3", function(t) return t.Base:Lerp(t.Primary, 0.025) end)
    ctx.stroke(frame, "Primary", 0.84)
    local header = ctx.text(frame, sectionCaption(name), {Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 0, 36), Font = ctx.fontMono, TextSize = 11, TextTransparency = 0.2})
    ctx.bind(header, "TextColor3", "Accent")
    local rule = ctx.new("Frame", {Position = UDim2.fromOffset(0, 35), Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 0.9}, frame)
    ctx.bind(rule, "BackgroundColor3", "Primary")
    -- Tiny L-corners frame grouped controls without turning them into ASCII controls.
    for _, x in ipairs({0, 1}) do
        local corner = ctx.new("Frame", {AnchorPoint = Vector2.new(x, 0), Position = UDim2.fromScale(x, 0),
            Size = UDim2.fromOffset(10, 1), BackgroundTransparency = 0.32}, frame)
        ctx.bind(corner, "BackgroundColor3", "Accent")
        local vertical = ctx.new("Frame", {AnchorPoint = Vector2.new(x, 0), Position = UDim2.fromScale(x, 0),
            Size = UDim2.fromOffset(1, 9), BackgroundTransparency = 0.32}, frame)
        ctx.bind(vertical, "BackgroundColor3", "Accent")
    end
    local body = ctx.new("Frame", {Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 37),
        Size = UDim2.new(1, -2, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, frame)
    local layout = ctx.new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1)}, body)
    local section = {Name = tostring(name), Frame = frame, Header = header, Body = body, Layout = layout,
        Controls = {}, Visible = true, Explicit = explicit, Tab = tab}
    function section:Set(value)
        if type(value) == "boolean" then self.Visible = value
        elseif type(value) == "string" then self.Name = value; self.Header.Text = sectionCaption(value) end
        queueReflow(tab)
    end
    section.SetVisible = function(self, value) self:Set(value) end
    function section:Destroy()
        for _, control in ipairs(self.Controls) do control:Destroy() end
        self.Visible = false; self.Frame:Destroy(); queueReflow(tab)
    end
    -- Sections may be used as fluent containers in addition to the legacy Tab API.
    setmetatable(section, {__index = function(_, key)
        if type(Tab[key]) == "function" and string.sub(key, 1, 6) == "Create" then
            return function(_, ...)
                local previous = tab.CurrentSection
                tab.CurrentSection = section
                local result = Tab[key](tab, ...)
                tab.CurrentSection = previous
                return result
            end
        end
    end})
    table.insert(tab.Sections, section)
    ctx.connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() queueReflow(tab) end)
    queueReflow(tab)
    return section
end
function Tab:CreateSection(name)
    local opts = type(name) == "table" and ctx.options(name) or {Name = name}
    self.CurrentSection = makeSection(self, opts.Name or "Section", true)
    return self.CurrentSection
end
function ctx.row(tab, rawOptions, height)
    assert(state.alive and state.window, "CreateWindow must be called before adding controls")
    local options = ctx.options(rawOptions)
    local section = tab.CurrentSection
    if not section then section = makeSection(tab, "Overview", false); tab.CurrentSection = section end
    local frame = ctx.new("TextButton", {Name = "Row", Text = "", AutoButtonColor = false,
        BackgroundTransparency = 0.5, Size = UDim2.new(1, 0, 0, math.max(44, height or 48)),
        LayoutOrder = #section.Controls + 1, ClipsDescendants = false}, section.Body)
    ctx.bind(frame, "BackgroundColor3", function(t) return t.Base:Lerp(t.Primary, 0.045) end)
    local label = ctx.text(frame, options.Name or options.Title or "", {Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -165, 1, 0), TextWrapped = true})
    local stroke = ctx.stroke(frame, "Primary", 0.92)
    local control = {Frame = frame, Label = label, Stroke = stroke, Options = options, _options = options,
        Name = options.Name or options.Title or "", Tab = tab, Section = section, Visible = options.Visible ~= false,
        Disabled = options.Disabled == true, Destroyed = false}
    function control:SetVisible(value) self.Visible = value ~= false; queueReflow(tab) end
    function control:SetDisabled(value)
        self.Disabled = value == true
        self.Label.TextTransparency = self.Disabled and 0.65 or 0
        self.Frame.Active = not self.Disabled
    end
    function control:SetName(value)
        self.Name = tostring(value); self.Label.Text = self.Name; queueReflow(tab)
    end
    function control:SetTooltip(value) ctx.tooltip(self, value) end
    function control:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self.Flag and Library.Flags[self.Flag] == self then Library.Flags[self.Flag] = nil end
        self.Frame:Destroy(); queueReflow(tab)
    end
    local function hover(on)
        if control.Disabled then return end
        ctx.tween(frame, {BackgroundTransparency = on and 0.1 or 0.5})
        ctx.bind(stroke, "Color", on and "Accent" or "Primary")
        ctx.tween(stroke, {Transparency = on and 0.35 or 0.92})
        -- Preserve each component's label geometry; hover only shifts its X offset.
        local position = label.Position
        local base = control.LabelBaseX or position.X.Offset
        if not control.LabelBaseX then control.LabelBaseX = base end
        ctx.tween(label, {Position = UDim2.new(position.X.Scale, base + (on and 2 or 0), position.Y.Scale, position.Y.Offset)})
    end
    ctx.connect(frame.MouseEnter, function() hover(true) end)
    ctx.connect(frame.MouseLeave, function() hover(false) end)
    ctx.connect(frame.InputBegan, function(input) if ctx.isPointer(input) then hover(true) end end)
    ctx.connect(frame.InputEnded, function(input) if ctx.isPointer(input) then hover(false) end end)
    ctx.connect(frame:GetPropertyChangedSignal("Size"), function() queueReflow(tab) end)
    table.insert(section.Controls, control)
    table.insert(state.controls, control)
    ctx.tooltip(control, options.Tooltip or options.Info)
    queueReflow(tab)
    return control, frame, label, stroke
end
local function controlValue(control)
    if control.Type == "Dropdown" then return table.clone(control.CurrentOption or {}) end
    if control.Type == "Keybind" then return control.CurrentKeybind end
    if control.Type == "ColorPicker" then
        local c = control.Color
        return c and {__type = "Color3", R = c.R, G = c.G, B = c.B}
    end
    return control.CurrentValue
end
function ctx.register(control, rawOptions)
    local options = ctx.options(rawOptions)
    control._options = options
    control.Flag = options.Flag
    if type(control.Flag) == "string" and control.Flag ~= "" then Library.Flags[control.Flag] = control end
    control:SetDisabled(options.Disabled == true)
    return control
end
function ctx.changed(control, value, fireCallback, ...)
    if not state.alive or control.Destroyed then return end
    if control.Type ~= "Keybind" then control.value = value end
    if fireCallback ~= false and type(control._options.Callback) == "function" then
        local ok = pcall(control._options.Callback, value, ...)
        if not ok then warn("[Eclipse UI] Component callback failed.") end
    end
    ctx.saveSoon()
end
local function configPath()
    local config = state.configuration
    if not config or config.Enabled ~= true then return nil end
    local folder = tostring(config.FolderName or "EclipseUI")
    local filename = tostring(config.FileName or "default")
    -- Configuration values are filenames, never executable paths.
    if string.find(folder, "..", 1, true) or string.find(filename, "[/\\]") or string.find(filename, "..", 1, true) then
        return nil
    end
    return folder .. "/" .. filename .. ".json", folder
end
function Library:SaveConfiguration()
    local path, folder = configPath()
    if not path or not state.alive or state.loading or type(writefile) ~= "function" then return false end
    local flags = {}
    for flag, control in pairs(self.Flags) do
        if not control.Destroyed then flags[flag] = controlValue(control) end
    end
    local ok = pcall(function()
        if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(folder)) then makefolder(folder) end
        local encoded = HttpService:JSONEncode({Version = 1, Flags = flags})
        writefile(path, encoded)
        if type(readfile) == "function" then assert(readfile(path) == encoded, "Configuration verification failed") end
    end)
    if not ok then warn("[Eclipse UI] Configuration could not be saved.") end
    return ok
end
function ctx.saveSoon()
    if state.loading or state.saveQueued or not configPath() then return end
    state.saveQueued = true
    ctx.delay(0.35, function() state.saveQueued = false; Library:SaveConfiguration() end)
end
function Library:LoadConfiguration()
    local path = configPath()
    if not path or type(readfile) ~= "function" then return false end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(decoded) ~= "table" or type(decoded.Flags) ~= "table" then return false end
    state.loading = true
    -- Set data before enabling switches, matching Premium's own restoration policy.
    for _, toggles in ipairs({false, true}) do
        for flag, value in pairs(decoded.Flags) do
            local control = self.Flags[flag]
            if control and not control.Destroyed and (control.Type == "Toggle") == toggles then
                local restored = value
                local valid = false
                if control.Type == "ColorPicker" and type(value) == "table" and value.__type == "Color3" then
                    local r, g, b = tonumber(value.R), tonumber(value.G), tonumber(value.B)
                    if r and g and b then restored = Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1)); valid = true end
                elseif control.Type == "Dropdown" then valid = type(value) == "table"
                elseif control.Type == "Toggle" then valid = type(value) == "boolean"
                elseif control.Type == "Slider" then valid = type(value) == "number" and value == value and math.abs(value) < math.huge
                elseif control.Type == "Input" or control.Type == "Keybind" then valid = type(value) == "string" end
                if valid then
                    local success = pcall(control.Set, control, restored)
                    if success and control.Type == "ColorPicker" then ctx.changed(control, restored, true) end
                end
            end
        end
    end
    state.loading = false
    return true
end
function Library:ModifyTheme(theme)
    if type(theme) == "string" then theme = self.Themes[aliases[theme] or theme] end
    if type(theme) ~= "table" or typeof(theme.Base) ~= "Color3" or typeof(theme.Primary) ~= "Color3"
        or typeof(theme.Accent) ~= "Color3" then return false end
    -- Clone only the three public tokens; every surface resolves from these.
    state.theme = {Base = theme.Base, Primary = theme.Primary, Accent = theme.Accent}
    for object, properties in pairs(state.bindings) do
        if object.Parent then
            local goals = {}
            for property, role in pairs(properties) do goals[property] = color(role) end
            ctx.tween(object, goals, 0.25)
        else state.bindings[object] = nil end
    end
    return true
end
Library.ChangeTheme = Library.ModifyTheme
function Library:SetVisibility(visible)
    if state.window then state.window:SetMinimized(visible ~= true) end
end
function Library:IsVisible() return state.alive and state.window ~= nil and not state.minimized end
function Library:Toggle() if state.window then state.window:Toggle() end end
function Tab:Select() return state.window:SelectTab(self) end
function Tab:SetVisible(value) self.Button.Visible = value ~= false end
function Tab:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, section in ipairs(self.Sections) do section:Destroy() end
    self.Page:Destroy(); self.Button:Destroy()
    for i, tab in ipairs(state.tabs) do if tab == self then table.remove(state.tabs, i); break end end
    if state.activeTab == self then state.activeTab = nil; if state.tabs[1] then state.tabs[1]:Select() end end
end
local function resolveLogo(options)
    local explicit = ctx.iconAsset(options.LogoId or options.Icon)
    if explicit then return explicit end
    local asset = getcustomasset or getsynasset
    if type(asset) == "function" and type(writefile) == "function" then
        local ok, result = pcall(function()
            if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder("Eclipse")) then makefolder("Eclipse") end
            local path = "Eclipse/eclipse-ui-logo-v1.png"
            local bytes = (ctx.logoHex or ""):gsub("..", function(byte) return string.char(tonumber(byte, 16)) end)
            if bytes == "" then return nil end
            if type(readfile) ~= "function" or not pcall(function() assert(readfile(path) == bytes) end) then writefile(path, bytes) end
            return asset(path)
        end)
        if ok and result then state.bundledLogo = result; return result end
    end
    return nil
end
local function logo(parent, image, position, size)
    if image then
        local label = ctx.new("ImageLabel", {Name = "EclipseMark", BackgroundTransparency = 1,
            Image = image, Position = position, Size = size, ScaleType = Enum.ScaleType.Fit}, parent)
        if image == state.bundledLogo then
            label.ImageRectOffset = Vector2.new(168, 52)
            label.ImageRectSize = Vector2.new(162, 372)
        end
        ctx.bind(label, "ImageColor3", "Primary")
        return label
    end
    return ctx.text(parent, "E", {Name = "EclipseMonogram", Position = position, Size = size,
        Font = Enum.Font.GothamBold, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center})
end
local function topButton(parent, value, x, callback)
    local button = ctx.new("TextButton", {Text = value, Font = ctx.fontMono, TextSize = 17,
        BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, x, 0, 7), Size = UDim2.fromOffset(38, 40)}, parent)
    ctx.bind(button, "TextColor3", "Primary")
    ctx.connect(button.Activated, callback)
    return button
end
function Library:CreateWindow(rawOptions)
    assert(not state.window, "An Eclipse library instance owns one window. Destroy it before creating another library instance.")
    assert(state.alive, "This Eclipse library instance has been destroyed.")
    local options = ctx.options(rawOptions)
    -- External key validation/Discord/heartbeat are deliberately explicit unsupported integrations.
    assert(options.KeySystem ~= true, "Eclipse UI does not implement Rayfield's external key system.")
    state.configuration = ctx.options(options.ConfigurationSaving or {})
    local screen = ctx.new("ScreenGui", {Name = "EclipseUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 120, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    state.screen = screen
    local localPlayer = Players.LocalPlayer
    assert(localPlayer, "Eclipse UI requires a LocalPlayer")
    local parent
    if type(gethui) == "function" then local ok, root = pcall(gethui); if ok then parent = root end end
    if not parent then local ok, root = pcall(function() return game:GetService("CoreGui") end); if ok then parent = root end end
    if parent then pcall(function() screen.Parent = parent end) end
    if not screen.Parent then screen.Parent = localPlayer:WaitForChild("PlayerGui") end
    local overlay = ctx.new("Frame", {Name = "Overlays", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        ZIndex = 20}, screen)
    state.overlay = overlay
    local root = ctx.new("Frame", {Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 270), ClipsDescendants = true}, screen)
    ctx.bind(root, "BackgroundColor3", "Base")
    ctx.stroke(root, "Primary", 0.68)
    local rootScale = ctx.new("UIScale", {Scale = 1}, root)
    state.root = root
    state.rootScale = rootScale
    local window = {Flags = self.Flags, Tabs = state.tabs, Name = options.Name or "Eclipse", Frame = root}
    state.window = window
    self.Window = window
    window.ModifyTheme = function(first, second) return self:ModifyTheme(first == window and second or first) end
    window.ChangeTheme = window.ModifyTheme
    window.Destroy = function() return self:Destroy() end
    window.Unload = window.Destroy
    window.SaveConfiguration = function() return self:SaveConfiguration() end
    window.LoadConfiguration = function() return self:LoadConfiguration() end
    if options.Theme then self:ModifyTheme(options.Theme) end
    local logoImage = resolveLogo(options)
    local canvas = ctx.new("Frame", {Name = "Interface", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Visible = false}, root)
    state.canvas = canvas
    local ambient = ctx.new("Frame", {Name = "Ambient", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, canvas)
    for i = 0, 14 do
        local line = ctx.new("Frame", {Position = UDim2.new(0, 0, 0, 36 * i), Size = UDim2.new(1, 0, 0, 1),
            BackgroundTransparency = 0.975}, ambient)
        ctx.bind(line, "BackgroundColor3", "Accent")
    end
    local scan = ctx.new("Frame", {Name = "Scan", BackgroundTransparency = 0.985, Size = UDim2.fromScale(1, 1)}, ambient)
    ctx.bind(scan, "BackgroundColor3", "Accent")
    local gradient = ctx.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.48, 1),
        NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.52, 1), NumberSequenceKeypoint.new(1, 1)})}, scan)
    local ambientTween = TweenService:Create(gradient, TweenInfo.new(8, Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut, -1, true), {Offset = Vector2.new(0, 0.8)})
    state.ambient = ambientTween
    local header = ctx.new("Frame", {Name = "Header", BackgroundTransparency = 0,
        Size = UDim2.new(1, 0, 0, 58)}, canvas)
    ctx.bind(header, "BackgroundColor3", function(t) return t.Base:Lerp(t.Primary, 0.02) end)
    logo(header, logoImage, UDim2.fromOffset(19, 10), UDim2.fromOffset(18, 36))
    local title = ctx.text(header, window.Name, {Position = UDim2.fromOffset(49, 9), Size = UDim2.fromOffset(205, 24),
        TextSize = 17, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd})
    local subtitle = ctx.text(header, options.Subtitle or "CONTROL INTERFACE / v" .. Library.Version,
        {Position = UDim2.fromOffset(50, 33), Size = UDim2.fromOffset(240, 15), Font = ctx.fontMono,
            TextSize = 9, TextTransparency = 0.5})
    local border = ctx.new("Frame", {Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 0.84}, header)
    ctx.bind(border, "BackgroundColor3", "Primary")
    local search = ctx.new("TextBox", {Name = "Search", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -94, 0.5, 0), Size = UDim2.fromOffset(180, 32), PlaceholderText = "/ search controls",
        Text = "", ClearTextOnFocus = false, Font = ctx.fontMono, TextSize = 11, BackgroundTransparency = 0.5}, header)
    ctx.bind(search, "BackgroundColor3", function(t) return t.Base:Lerp(t.Primary, 0.05) end)
    ctx.bind(search, "TextColor3", "Primary"); ctx.bind(search, "PlaceholderColor3", "Primary")
    ctx.stroke(search, "Primary", 0.85)
    ctx.connect(search:GetPropertyChangedSignal("Text"), function()
        state.query = string.lower(search.Text):match("^%s*(.-)%s*$") or ""
        hideTooltip(); closePopup()
        for _, tab in ipairs(state.tabs) do queueReflow(tab) end
    end)
    local sidebar = ctx.new("Frame", {Name = "Sidebar", Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(0, 170, 1, -88), BackgroundTransparency = 0.05}, canvas)
    ctx.bind(sidebar, "BackgroundColor3", function(t) return t.Base:Lerp(t.Primary, 0.015) end)
    ctx.stroke(sidebar, "Primary", 0.91)
    state.sidebar = sidebar
    local nav = ctx.new("ScrollingFrame", {Name = "Tabs", Position = UDim2.fromOffset(7, 42),
        Size = UDim2.new(1, -14, 1, -50), BackgroundTransparency = 1, ScrollBarThickness = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y}, sidebar)
    ctx.bind(nav, "ScrollBarImageColor3", "Accent")
    ctx.new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}, nav)
    local content = ctx.new("Frame", {Name = "Content", Position = UDim2.fromOffset(170, 58),
        Size = UDim2.new(1, -170, 1, -88), BackgroundTransparency = 1, ClipsDescendants = true}, canvas)
    state.content = content
    local footer = ctx.new("Frame", {Name = "Telemetry", Position = UDim2.new(0, 0, 1, -30),
        Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 0.2}, canvas)
    ctx.bind(footer, "BackgroundColor3", "Base")
    local status = ctx.text(footer, "SYS.ONLINE", {Position = UDim2.fromOffset(15, 0), Size = UDim2.fromOffset(180, 30),
        Font = ctx.fontMono, TextSize = 10})
    ctx.bind(status, "TextColor3", "Accent")
    local telemetry = ctx.text(footer, "ECLIPSE // READY", {AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(240, 30), Font = ctx.fontMono,
        TextSize = 9, TextTransparency = 0.55, TextXAlignment = Enum.TextXAlignment.Right})
    -- One lightweight sample per second while visible; no RenderStepped loop.
    local sampleConnection, sampleFrames, sampleStart = nil, 0, os.clock()
    local function sampling(enabled)
        if sampleConnection then sampleConnection:Disconnect(); sampleConnection = nil end
        if not enabled then return end
        sampleStart = os.clock(); sampleFrames = 0
        sampleConnection = ctx.connect(RunService.Heartbeat, function()
            sampleFrames += 1
            local elapsed = os.clock() - sampleStart
            if elapsed >= 1 then
                telemetry.Text = string.format("FPS %02d  //  ECLIPSE v%s", math.floor(sampleFrames / elapsed + 0.5), Library.Version)
                sampleFrames = 0; sampleStart = os.clock()
            end
        end)
    end
    state.sampling = sampling
    local floating = ctx.new("TextButton", {Name = "Reopen", Text = "[ ECLIPSE ]", Font = ctx.fontMono,
        TextSize = 11, AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(112, 44), ZIndex = 19,
        Visible = UIS.TouchEnabled}, screen)
    ctx.bind(floating, "BackgroundColor3", "Base"); ctx.bind(floating, "TextColor3", "Primary")
    ctx.stroke(floating, "Accent", 0.3)
    local floatingStart, floatingPosition, floatingMoved
    ctx.drag(floating, function(position)
        if not floatingStart then floatingStart = position; floatingPosition = floating.AbsolutePosition; floatingMoved = false end
        local delta = position - floatingStart
        if delta.Magnitude > 6 then floatingMoved = true end
        if floatingMoved then
            local size = overlay.AbsoluteSize
            floating.AnchorPoint = Vector2.zero
            floating.Position = UDim2.fromOffset(math.clamp(floatingPosition.X + delta.X, 0, math.max(0, size.X - 112)),
                math.clamp(floatingPosition.Y + delta.Y, 0, math.max(0, size.Y - 44)))
        end
    end, function() floatingStart = nil end)
    function window:SetMinimized(value)
        state.minimized = value == true
        closePopup(); hideTooltip()
        sampling(not state.minimized and canvas.Visible)
        if state.minimized then ambientTween:Pause() else ambientTween:Play() end
        if state.minimized then
            ctx.tween(root, {Size = UDim2.fromOffset(state.width, 58)}, 0.18)
            ctx.delay(0.19, function() if state.minimized then root.Visible = false end end)
        else
            root.Visible = true
            ctx.tween(root, {Size = UDim2.fromOffset(state.width, state.height)}, 0.22)
        end
        floating.Visible = UIS.TouchEnabled or state.minimized
    end
    window.Minimize = function(_, value) window:SetMinimized(value == nil and not state.minimized or value) end
    window.Toggle = function() window:SetMinimized(not state.minimized) end
    window.Hide = function() window:SetMinimized(true) end
    window.Show = function() window:SetMinimized(false) end
    window.SetVisibility = function(first, second) self:SetVisibility(first == window and second or first) end
    window.IsVisible = function() return self:IsVisible() end
    ctx.connect(floating.Activated, function() if not floatingMoved then window:Toggle() end; floatingMoved = false end)
    topButton(header, "_", -48, function() window:SetMinimized(true) end)
    topButton(header, "x", -7, function()
        if type(options.OnClose) == "function" then options.OnClose() else self:Destroy() end
    end)
    local toggleOption = options.ToggleUIKeybind or "K"
    local toggleKey = typeof(toggleOption) == "EnumItem" and toggleOption.Name or tostring(toggleOption)
    ctx.connect(UIS.InputBegan, function(input, processed)
        if not processed and not UIS:GetFocusedTextBox() and not ctx._keybindCapture and (ctx._modalOpen or 0) == 0
            and input.KeyCode.Name == toggleKey then window:Toggle() end
    end)
    local function sidebarLayout()
        local width = state.collapsed and 48 or 170
        ctx.tween(sidebar, {Size = UDim2.new(0, width, 1, -88)}, 0.2)
        ctx.tween(content, {Position = UDim2.fromOffset(width, 58), Size = UDim2.new(1, -width, 1, -88)}, 0.2)
        for _, tab in ipairs(state.tabs) do
            tab.NavLabel.Visible = not state.collapsed
            tab.Button.Size = UDim2.new(1, 0, 0, 44)
            queueReflow(tab)
        end
    end
    function window:SetSidebarCollapsed(value)
        state.collapsed = value == true
        closePopup(); sidebarLayout()
    end
    local collapse = ctx.new("TextButton", {Name = "Collapse", Text = "<> / NAV", Font = ctx.fontMono, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 0, 39),
        BackgroundTransparency = 1, AutoButtonColor = false}, sidebar)
    ctx.bind(collapse, "TextColor3", "Primary")
    ctx.connect(collapse.Activated, function() window:SetSidebarCollapsed(not state.collapsed) end)
    ctx.connect(sidebar:GetPropertyChangedSignal("Size"), function() collapse.Text = state.collapsed and "<>" or "<> / NAV" end)
    function window:SelectTab(tabOrName)
        local selected
        for _, tab in ipairs(state.tabs) do
            if tab == tabOrName or tab.Name == tabOrName then selected = tab; break end
        end
        if not selected or selected.Destroyed then return false end
        closePopup(); hideTooltip()
        state.activeTab = selected
        for _, tab in ipairs(state.tabs) do
            local active = tab == selected
            tab.Page.Visible = active
            tab.Indicator.Visible = active
            tab.Button.BackgroundTransparency = active and 0.87 or 1
            tab.NavLabel.TextTransparency = active and 0 or 0.5
        end
        selected.Page.CanvasPosition = Vector2.zero
        selected.Page.Position = UDim2.fromOffset(0, 7)
        ctx.tween(selected.Page, {Position = UDim2.fromOffset(0, 0)}, 0.18)
        for _, section in ipairs(selected.Sections) do
            scramble(section.Header, sectionCaption(section.Name))
            section.Frame.BackgroundTransparency = 0.75
            ctx.tween(section.Frame, {BackgroundTransparency = 0}, 0.18)
            section.Header.TextTransparency = 0.85
            ctx.tween(section.Header, {TextTransparency = 0.2}, 0.18)
            for _, control in ipairs(section.Controls) do
                if not control.Destroyed then
                    control.Label.TextTransparency = 0.85
                    ctx.tween(control.Label, {TextTransparency = control.Disabled and 0.65 or 0}, 0.18)
                end
            end
        end
        queueReflow(selected)
        return true
    end
    function window:CreateTab(rawName, icon)
        local tabOptions = type(rawName) == "table" and ctx.options(rawName) or {Name = rawName, Icon = icon}
        local name = tostring(tabOptions.Name or "Tab")
        local tab = setmetatable({Name = name, Sections = {}, Window = window}, Tab)
        local page = ctx.new("ScrollingFrame", {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            CanvasSize = UDim2.new(), ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false}, content)
        ctx.bind(page, "ScrollBarImageColor3", "Accent")
        tab.Page = page
        tab.Empty = ctx.text(page, "// NO MATCHING CONTROLS", {Position = UDim2.fromOffset(20, 24),
            Size = UDim2.new(1, -40, 0, 42), Font = ctx.fontMono, TextSize = 11, TextTransparency = 0.5, Visible = false})
        local button = ctx.new("TextButton", {Name = name, Text = "", AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = #state.tabs + 1}, nav)
        ctx.bind(button, "BackgroundColor3", "Accent")
        tab.Button = button
        local asset = ctx.iconAsset(tabOptions.Icon)
        if asset then
            local image = ctx.new("ImageLabel", {BackgroundTransparency = 1, Image = asset,
                Position = UDim2.fromOffset(9, 14), Size = UDim2.fromOffset(16, 16)}, button)
            ctx.bind(image, "ImageColor3", "Primary")
        else
            ctx.text(button, string.format("%02d", #state.tabs + 1), {Position = UDim2.fromOffset(8, 0),
                Size = UDim2.fromOffset(20, 44), Font = ctx.fontMono, TextSize = 11})
        end
        tab.NavLabel = ctx.text(button, name, {Position = UDim2.fromOffset(37, 0), Size = UDim2.new(1, -43, 1, 0),
            TextSize = 12, Visible = not state.collapsed})
        tab.Indicator = ctx.new("Frame", {Size = UDim2.fromOffset(2, 22), Position = UDim2.new(0, 0, 0.5, -11), Visible = false}, button)
        ctx.bind(tab.Indicator, "BackgroundColor3", "Accent")
        table.insert(state.tabs, tab)
        ctx.connect(button.Activated, function() window:SelectTab(tab) end)
        ctx.connect(page:GetPropertyChangedSignal("AbsoluteSize"), function() queueReflow(tab) end)
        ctx.connect(page:GetPropertyChangedSignal("CanvasPosition"), closePopup)
        if not state.activeTab then window:SelectTab(tab) end
        return tab
    end
    local dragStart, rootStart
    -- Dragging is restricted to this title hit region, excluding search/window controls.
    local dragHandle = ctx.new("Frame", {Name = "DragTitle", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(260, 58), Active = true}, header)
    ctx.drag(dragHandle, function(position)
        if not dragStart then dragStart = position; rootStart = root.AbsolutePosition end
        local delta = position - dragStart
        local size, actual = overlay.AbsoluteSize, root.AbsoluteSize
        root.AnchorPoint = Vector2.zero
        root.Position = UDim2.fromOffset(math.clamp(rootStart.X + delta.X, 0, math.max(0, size.X - actual.X)),
            math.clamp(rootStart.Y + delta.Y, 0, math.max(0, size.Y - actual.Y)))
    end, function() dragStart = nil end)
    local resizeGrip = ctx.new("TextButton", {Name = "Resize", Text = "/", TextSize = 18, Font = ctx.fontMono,
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(28, 28), AutoButtonColor = false}, canvas)
    ctx.bind(resizeGrip, "TextColor3", "Accent")
    local resizeStart, resizeWidth, resizeHeight
    local function viewport()
        local camera = workspace.CurrentCamera
        return camera and camera.ViewportSize or overlay.AbsoluteSize
    end
    local function fit(requestedWidth, requestedHeight)
        local view = viewport()
        if view.X <= 0 or view.Y <= 0 then return end
        local mobile = UIS.TouchEnabled and (not UIS.KeyboardEnabled or view.X < 850)
        local width = requestedWidth or (mobile and math.max(360, math.min(view.X - 20, 1000)) or 1000)
        local height = requestedHeight or (mobile and math.max(300, math.min(view.Y - 20, 720)) or 660)
        state.scale = math.min(1, (view.X - 20) / width, (view.Y - 20) / height)
        state.scale = math.max(0.2, state.scale)
        state.width, state.height = width, height
        rootScale.Scale = state.scale
        if state.bootDone then root.Size = UDim2.fromOffset(width, state.minimized and 58 or height) end
        if root.AnchorPoint == Vector2.zero then
            root.Position = UDim2.fromOffset(math.clamp(root.Position.X.Offset, 0, math.max(0, view.X - width * state.scale)),
                math.clamp(root.Position.Y.Offset, 0, math.max(0, view.Y - height * state.scale)))
        end
        local narrow = width < 650
        search.Size = UDim2.fromOffset(narrow and 88 or 180, 32)
        local searchLeft = width - 94 - search.Size.X.Offset
        title.Size = UDim2.fromOffset(math.min(205, math.max(60, searchLeft - 57)), 24)
        dragHandle.Size = UDim2.fromOffset(math.min(260, searchLeft - 4), 58)
        subtitle.Visible = not narrow
        if state.collapsed == nil then state.collapsed = mobile end
        sidebarLayout()
        closePopup(); hideTooltip()
        for _, tab in ipairs(state.tabs) do queueReflow(tab) end
    end
    ctx.drag(resizeGrip, function(position)
        if not resizeStart then resizeStart = position; resizeWidth = state.width; resizeHeight = state.height end
        local delta = (position - resizeStart) / state.scale
        fit(math.clamp(resizeWidth + delta.X, 360, 1400), math.clamp(resizeHeight + delta.Y, 360, 1000))
    end, function() resizeStart = nil end)
    window.Resize = function(_, width, height) fit(math.clamp(width, 360, 1400), math.clamp(height, 360, 1000)) end
    ctx.connect(overlay:GetPropertyChangedSignal("AbsoluteSize"), function() fit() end)
    fit()
    -- Startup is visual only. No progress claims about game features or network requests.
    local boot = ctx.new("Frame", {Name = "Boot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, root)
    local bootLogo = logo(boot, logoImage, UDim2.new(0.5, -17, 0, 28), UDim2.fromOffset(34, 80))
    ctx.text(boot, options.LoadingTitle or "ECLIPSE", {Position = UDim2.fromOffset(20, 128),
        Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 17})
    ctx.text(boot, options.LoadingSubtitle or "CONTROL INTERFACE", {Position = UDim2.fromOffset(20, 154),
        Size = UDim2.new(1, -40, 0, 20), Font = ctx.fontMono, TextSize = 10, TextTransparency = 0.5,
        TextXAlignment = Enum.TextXAlignment.Center})
    local progressTrack = ctx.new("Frame", {Position = UDim2.fromOffset(30, 203), Size = UDim2.new(1, -60, 0, 2),
        BackgroundTransparency = 0.88}, boot)
    ctx.bind(progressTrack, "BackgroundColor3", "Primary")
    local progress = ctx.new("Frame", {Size = UDim2.fromScale(0, 1)}, progressTrack)
    ctx.bind(progress, "BackgroundColor3", "Accent")
    local bootStatus = ctx.text(boot, "> INITIALIZING INTERFACE [00%]", {Position = UDim2.fromOffset(30, 215),
        Size = UDim2.new(1, -60, 0, 22), Font = ctx.fontMono, TextSize = 9, TextTransparency = 0.3})
    local pulseProperty = bootLogo:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
    local pulse = TweenService:Create(bootLogo, TweenInfo.new(0.55, Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut, -1, true), {[pulseProperty] = 0.55})
    pulse:Play()
    state.bootPulse = pulse
    ctx.spawn(function()
        for _, percent in ipairs({18, 43, 71, 100}) do
            if not state.alive then return end
            ctx.tween(progress, {Size = UDim2.fromScale(percent / 100, 1)}, 0.12)
            scramble(bootStatus, string.format("> INITIALIZING INTERFACE [%02d%%]", percent))
            task.wait(options.DisableLoading and 0 or 0.17)
        end
        pulse:Cancel(); boot:Destroy(); state.bootDone = true
        ctx.tween(root, {Size = UDim2.fromOffset(state.width, state.height)}, options.DisableLoading and 0 or 0.32)
        task.wait(options.DisableLoading and 0 or 0.15)
        if not state.alive then return end
        canvas.Visible = true
        ambientTween:Play(); sampling(not state.minimized)
        for _, tab in ipairs(state.tabs) do queueReflow(tab) end
        if state.minimized then window:SetMinimized(true) end
    end)
    return window
end
function Library:Destroy()
    if not state.alive or state.destroying then return end
    state.destroying = true
    self:SaveConfiguration()
    -- Release held interaction callbacks while callbacks are still permitted.
    for _, control in ipairs(state.controls) do
        if not control.Destroyed then pcall(control.Destroy, control) end
    end
    state.alive = false
    closePopup(); hideTooltip()
    dragSession = nil
    if state.ambient then state.ambient:Cancel() end
    if state.bootPulse then state.bootPulse:Cancel() end
    for _, properties in pairs(state.tweens) do for _, tween in pairs(properties) do tween:Cancel() end end
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    table.clear(state.connections)
    local current = coroutine.running()
    for thread in pairs(state.threads) do if thread ~= current then pcall(task.cancel, thread) end end
    table.clear(state.threads)
    for _, control in ipairs(state.controls) do control.Destroyed = true end
    if state.screen then state.screen:Destroy() end
    table.clear(self.Flags)
end
Library.Unload = Library.Destroy
return Library, ctx
