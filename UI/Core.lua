-- Eclipse UI core. Authoring source; build_ui.py assembles a single loadstring module.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Library = {Flags = {}, Version = "1.4.1", Name = "Eclipse UI"}
local Tab = {}
Tab.__index = Tab
local WINDOW_WIDTH, WINDOW_HEIGHT = 660, 420
local SIDEBAR_WIDTH, HEADER_HEIGHT = 148, 48
local ctx = {Tab = Tab, UIS = UIS, fontMono = Enum.Font.Code, font = Enum.Font.Gotham, pad = 12}
ctx.colors = {Sidebar = Color3.fromHex("121317"), Section = Color3.fromHex("16181D"),
    Hover = Color3.fromHex("1D2026"), Input = Color3.fromHex("0B0C0F"), Secondary = Color3.fromHex("8A8F98"),
    White = Color3.fromHex("FFFFFF")}
local state = {alive = true, connections = {}, threads = {}, bindings = setmetatable({}, {__mode = "k"}),
    tweens = setmetatable({}, {__mode = "k"}), tabs = {}, controls = {}, cleanups = {}, query = "", loading = false}
local function palette(base, primary, accent)
    return {Base = Color3.fromHex(base), Primary = Color3.fromHex(primary), Accent = Color3.fromHex(accent)}
end
Library.Themes = {
    Default = palette("0E0F12", "E6E8EC", "3B82F6"),
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
function ctx.unscale(value) return value / (state.scale or 1) end
function ctx.logicalPoint(position)
    return ctx.unscale(position - (state.stage and state.stage.AbsolutePosition or Vector2.zero))
end
function ctx.viewportMetrics(size)
    local compact = size.X < 600
    local width = compact and 400 or WINDOW_WIDTH
    local preferred = math.clamp(math.min(size.X / 1280, size.Y / 720), 1, 1.25)
    local scale = math.max(.1, math.min(preferred, (size.X - 24) / width, (size.Y - 24) / WINDOW_HEIGHT))
    return scale, width, compact
end
function ctx.addCleanup(callback) table.insert(state.cleanups, callback) end
function ctx.ripple(position, strength)
    local atmosphere = state.bootDone and state.atmosphere or state.bootAtmosphere
    if atmosphere and not state.minimized then atmosphere:Ripple(position, strength or 1) end
end
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
    if type(result.Name) == "string" then
        result.Name = result.Name:gsub("^Toggle%s+", ""):gsub("%s+Toggle$", ""):gsub("WalkSpeed", "Walk Speed"):gsub("PlayerESP", "Player ESP")
    end
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
    local animation = TweenService:Create(object, TweenInfo.new(duration or 0.15, easing or Enum.EasingStyle.Quad,
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
function ctx.spring(object, goals, duration) return ctx.tween(object, goals, duration or 0.15, Enum.EasingStyle.Quad) end
local function color(role)
    return type(role) == "function" and role(state.theme) or ctx.colors[role] or state.theme[role]
end
function ctx.bind(object, property, role, animate)
    local bindings = state.bindings[object] or {}
    bindings[property] = role
    state.bindings[object] = bindings
    if animate then ctx.tween(object, {[property] = color(role)}, .16) else object[property] = color(role) end
end
function ctx.stroke(parent, role, transparency)
    local stroke = ctx.new("UIStroke", {Thickness = 1, Transparency = transparency or 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
    ctx.bind(stroke, "Color", role or "Primary")
    return stroke
end
function ctx.round(parent, radius)
    local corner = parent:FindFirstChildOfClass("UICorner") or ctx.new("UICorner", {}, parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end
-- Layered translucent outlines give a soft halo without assets or animation loops.
function ctx.glow(parent, radius, strength, idle)
    local layer = ctx.new("Frame", {Name = "AccentBloom", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(-1, -1), Size = UDim2.new(1, 2, 1, 2),
        Active = false, ZIndex = parent.ZIndex}, parent)
    ctx.round(layer, (radius or 8) + 1)
    local inner = ctx.stroke(layer, "Secondary", idle or 1); inner.Thickness = 3
    local halo = ctx.new("Frame", {Name = "BloomHalo", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Active = false, ZIndex = layer.ZIndex}, layer)
    ctx.round(halo, (radius or 8) + 1)
    local outer = ctx.stroke(halo, "Secondary", idle and math.min(.985, idle + .04) or 1); outer.Thickness = 7
    local glow = {Active = false, Frame = layer, Generation = 0}
    local alpha = math.clamp(tonumber(strength) or 0.76, 0.6, 0.9)
    function glow:SetActive(active, animate)
        self.Active = active == true
        ctx.tween(inner, {Transparency = self.Active and alpha or idle or 1}, animate == false and 0 or 0.16)
        ctx.tween(outer, {Transparency = self.Active and math.min(.96, alpha + .13) or (idle and math.min(.985, idle + .04) or 1)}, animate == false and 0 or .18)
    end
    function glow:Pulse()
        self.Generation += 1
        local generation = self.Generation
        ctx.tween(inner, {Transparency = 0.55}, 0.07)
        ctx.tween(outer, {Transparency = 0.82}, 0.07)
        ctx.delay(0.12, function()
            if layer.Parent and self.Generation == generation then self:SetActive(self.Active) end
        end)
    end
    return glow
end
function ctx.softGlow(parent, radius)
    local outline = ctx.new("Frame", {Name = "SoftOutline", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Active = false, ZIndex = parent.ZIndex}, parent)
    ctx.round(outline, radius)
    local stroke = ctx.stroke(outline, "Secondary", .9)
    stroke.Thickness = 2
end
-- Small native vector icons: geometry rather than numbered or ASCII navigation.
function ctx.vectorIcon(parent, name, properties)
    properties = properties or {}
    local role = properties.Role or "Primary"
    local props = {Name = "VectorIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), Active = false}
    for key, value in pairs(properties) do if key ~= "Role" then props[key] = value end end
    local icon = ctx.new("Frame", props, parent)
    local function line(x1, y1, x2, y2, thickness)
        local dx, dy = x2 - x1, y2 - y1
        local segment = ctx.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
            Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 0, 0, thickness or 1.4),
            Rotation = math.deg(math.atan2(dy, dx)), ZIndex = icon.ZIndex}, icon)
        ctx.bind(segment, "BackgroundColor3", role); ctx.round(segment, 1)
        return segment
    end
    local function ring(x, y, w, h)
        local frame = ctx.new("Frame", {Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h or w),
            BackgroundTransparency = 1, ZIndex = icon.ZIndex}, icon)
        ctx.round(frame, 100); ctx.stroke(frame, role, 0.05)
        return frame
    end
    name = string.lower(tostring(name or "grid"))
    if name == "close" or name == "x" then line(.25,.25,.75,.75); line(.75,.25,.25,.75)
    elseif name == "minimize" then line(.22,.65,.78,.65)
    elseif name == "chevron" or name == "chevron-down" then line(.25,.4,.5,.65); line(.5,.65,.75,.4)
    elseif name == "arrow" or name == "play" or name == "action" then
        line(.18,.5,.8,.5); line(.56,.25,.8,.5); line(.56,.75,.8,.5)
    elseif name == "check" then line(.2,.5,.42,.72); line(.42,.72,.82,.25)
    elseif name == "search" then ring(.15,.12,.48); line(.56,.57,.84,.86)
    elseif name == "sidebar" then line(.25,.18,.25,.82); line(.45,.28,.8,.28); line(.45,.5,.8,.5); line(.45,.72,.8,.72)
    elseif name == "settings" then
        ring(.27,.27,.46); ring(.44,.44,.12)
        for i = 0, 7 do
            local angle = i * math.pi / 4
            line(.5 + math.cos(angle)*.26,.5 + math.sin(angle)*.26,.5 + math.cos(angle)*.4,.5 + math.sin(angle)*.4,2)
        end
    elseif name == "home" or name == "main" then
        line(.15,.43,.5,.15); line(.5,.15,.85,.43); line(.25,.4,.25,.82); line(.25,.82,.75,.82); line(.75,.82,.75,.4)
    elseif name == "eye" or name == "esp" then
        line(.08,.5,.3,.27); line(.3,.27,.7,.27); line(.7,.27,.92,.5)
        line(.08,.5,.3,.73); line(.3,.73,.7,.73); line(.7,.73,.92,.5); ring(.38,.38,.24)
    elseif name == "farms" or name == "auto farms" or name == "crosshair" then
        ring(.26,.26,.48); line(.5,.06,.5,.33); line(.5,.67,.5,.94); line(.06,.5,.33,.5); line(.67,.5,.94,.5)
    elseif name == "keyboard" then
        line(.1,.24,.9,.24); line(.9,.24,.9,.78); line(.9,.78,.1,.78); line(.1,.78,.1,.24); line(.28,.62,.72,.62)
        for i = 0, 2 do line(.28+i*.22,.42,.28+i*.22,.44,2) end
    else
        for _, position in ipairs({{.18,.18},{.58,.18},{.18,.58},{.58,.58}}) do
            local tile = ctx.new("Frame", {Position = UDim2.fromScale(position[1],position[2]),
                Size = UDim2.fromScale(.24,.24), ZIndex = icon.ZIndex}, icon)
            ctx.bind(tile, "BackgroundColor3", role); ctx.round(tile, 1)
        end
    end
    return icon
end
function ctx.text(parent, value, properties)
    local props = {Text = tostring(value or ""), BackgroundTransparency = 1, Font = ctx.font,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
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
-- Frame-rate-independent window movement; the render listener exists only while moving.
function ctx.smoothDrag(handle, target, constrain)
    local origin, pointer, destination, connection
    local held = false
    local function stop()
        held = false; origin = nil; pointer = nil; destination = nil
        if connection then connection:Disconnect(); connection = nil end
    end
    ctx.addCleanup(stop)
    ctx.drag(handle, function(position)
        if not target.Visible then return end
        position = ctx.logicalPoint(position)
        if not pointer then
            pointer = position; origin = ctx.logicalPoint(target.AbsolutePosition); held = true
        end
        destination = constrain(origin + position - pointer)
        if not connection then
            connection = ctx.connect(RunService.RenderStepped, function(dt)
                if not target.Parent or not target.Visible or not destination then stop(); return end
                local current = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
                local nextPosition = current:Lerp(destination, 1 - math.exp(-35 * math.max(0, dt)))
                if (destination - nextPosition).Magnitude < .25 then nextPosition = destination end
                target.Position = UDim2.fromOffset(nextPosition.X, nextPosition.Y)
                if not held and nextPosition == destination then stop() end
            end)
        end
    end, function() held = false; pointer = nil end)
    return stop
end
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
    ctx.bind(panel, "BackgroundColor3", "Section")
    ctx.round(panel, 6)
    ctx.stroke(panel, "White", .94)
    local function position()
        if not panel.Parent or not control.Frame.Parent then return end
        local size = ctx.unscale(state.overlay.AbsoluteSize)
        local actualWidth, actualHeight = math.min(width, math.max(1, size.X - 16)), math.min(height, math.max(1, size.Y - 16))
        panel.Size = UDim2.fromOffset(actualWidth, actualHeight)
        local anchor = ctx.unscale(control.Frame.AbsolutePosition - state.overlay.AbsolutePosition)
        local x = math.clamp(anchor.X, 8, math.max(8, size.X - actualWidth - 8))
        local below = anchor.Y + ctx.unscale(control.Frame.AbsoluteSize.Y) + 6
        local y = below + actualHeight <= size.Y - 8 and below or anchor.Y - actualHeight - 4
        panel.Position = UDim2.fromOffset(x, math.clamp(y, 8, math.max(8, size.Y - actualHeight - 8)))
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
-- Compatibility metadata only: controls never create hover or long-press pop-ups.
local function hideTooltip() end
function ctx.tooltip(control, value)
    control.Tooltip = value
end
local function sectionCaption(name) return string.upper(tostring(name)) end
local function reflow(tab)
    if not state.alive or not tab.Page.Parent then return end
    local width = math.max(160, ctx.unscale(tab.Page.AbsoluteSize.X) - 24)
    local heights = {0, 0}
    local gap = 12
    local cardWidth = state.compact and width or (width - gap) / 2
    for column, frame in ipairs(tab.Columns) do
        frame.Visible = not state.compact or column == 1
        frame.Position = UDim2.fromOffset(12 + (column - 1) * (cardWidth + gap), 12)
        frame.Size = UDim2.fromOffset(cardWidth, 0)
    end
    for _, section in ipairs(tab.Sections) do
        local count, bodyHeight = 0, 0
        local sectionMatch = state.query ~= "" and string.find(string.lower(section.Name), state.query, 1, true)
        for _, control in ipairs(section.Controls) do
            local match = state.query == "" or sectionMatch or string.find(string.lower(control.Name or ""), state.query, 1, true)
            local visible = not control.Destroyed and control.Visible ~= false and match ~= nil and match ~= false
            if control.Frame.Parent then control.Frame.Visible = visible end
            if visible then
                if count > 0 then bodyHeight += 4 end
                count += 1
                bodyHeight += control.Frame.Size.Y.Offset
            end
        end
        local visible = section.Visible ~= false and (count > 0 or (state.query == "" and section.Explicit))
        if not section.Frame.Parent then continue end
        section.Frame.Visible = visible
        if visible then
            local column = state.compact and 1 or section.Column
            section.Frame.Parent = tab.Columns[column]
            -- Rows own logical pixel heights; do not depend on UIScale layout measurements.
            local height = math.max(64, bodyHeight + 64)
            section.RestPosition = UDim2.fromOffset(0, heights[column])
            section.Frame.Position = section.RestPosition
            section.Frame.Size = UDim2.fromOffset(cardWidth, height)
            heights[column] += height + gap
        end
    end
    local height = math.max(heights[1], heights[2])
    for column, frame in ipairs(tab.Columns) do frame.Size = UDim2.fromOffset(cardWidth, heights[column]) end
    tab.Page.CanvasSize = UDim2.fromOffset(0, height + 24)
    if tab.Empty then tab.Empty.Visible = height == 0 end
end
local function queueReflow(tab)
    if tab.ReflowQueued then return end
    tab.ReflowQueued = true
    ctx.delay(0, function() tab.ReflowQueued = false; reflow(tab) end)
end
local function makeSection(tab, name, explicit)
    local column = #tab.Sections % 2 + 1 -- Original alternating section columns.
    local frame = ctx.new("CanvasGroup", {Name = "Section", BackgroundTransparency = 0,
        Size = UDim2.fromOffset(240, 34), ClipsDescendants = false, ZIndex = 3}, tab.Columns[column])
    ctx.bind(frame, "BackgroundColor3", "Section")
    ctx.round(frame, 8); ctx.stroke(frame, "White", .94)
    local header = ctx.text(frame, sectionCaption(name), {Position = UDim2.fromOffset(16, 16),
        Size = UDim2.new(1, -32, 0, 16), Font = Enum.Font.GothamMedium, TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
    ctx.bind(header, "TextColor3", "Secondary")
    local rule = ctx.new("Frame", {Name = "SectionRule", Position = UDim2.fromOffset(16, 40),
        Size = UDim2.new(1, -32, 0, 1), BackgroundTransparency = .94, ZIndex = 4}, frame)
    ctx.bind(rule, "BackgroundColor3", "Primary")
    local body = ctx.new("Frame", {Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 48),
        Size = UDim2.new(1, -32, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 4}, frame)
    local layout = ctx.new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, body)
    local section = {Name = tostring(name), Frame = frame, Header = header, Body = body, Layout = layout,
        Controls = {}, Visible = true, Explicit = explicit, Tab = tab, Column = column}
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
        BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, math.max(12, height or 34)),
        LayoutOrder = #section.Controls + 1, ClipsDescendants = false, ZIndex = 5}, section.Body)
    ctx.bind(frame, "BackgroundColor3", "Section")
    ctx.round(frame, 6)
    local label = ctx.text(frame, options.Name or options.Title or "", {Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -115, 1, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6})
    local stroke = nil -- Rows deliberately have no outline.
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
        ctx.bind(frame, "BackgroundColor3", on and "Hover" or control.SurfaceRole or "Section", true)
    end
    ctx.connect(frame.MouseEnter, function() hover(true) end)
    ctx.connect(frame.MouseLeave, function() hover(false) end)
    ctx.connect(frame:GetPropertyChangedSignal("Size"), function() queueReflow(tab) end)
    table.insert(section.Controls, control)
    table.insert(state.controls, control)
    ctx.tooltip(control, options.Tooltip or options.Info or control.Name)
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
local function topButton(parent, name, x, callback)
    local button = ctx.new("TextButton", {Name = name, Text = "", BackgroundTransparency = 0,
        AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 8),
        Size = UDim2.fromOffset(32, 32), ZIndex = 8}, parent)
    ctx.bind(button, "BackgroundColor3", "Input")
    ctx.round(button, 6)
    ctx.vectorIcon(button, name, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(16, 16), ZIndex = 9})
    ctx.connect(button.Activated, callback)
    return button
end
function Library:CreateWindow(rawOptions)
    assert(not state.window, "An Eclipse library instance owns one window.")
    assert(state.alive, "This Eclipse library instance has been destroyed.")
    local options = ctx.options(rawOptions)
    assert(options.KeySystem ~= true, "Eclipse UI does not implement Rayfield's external key system.")
    state.configuration = ctx.options(options.ConfigurationSaving or {})
    local screen = ctx.new("ScreenGui", {Name = "EclipseUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 120, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    state.screen = screen
    assert(Players.LocalPlayer, "Eclipse UI requires a LocalPlayer")
    local parent
    if type(gethui) == "function" then local ok, root = pcall(gethui); if ok then parent = root end end
    if not parent then local ok, root = pcall(function() return game:GetService("CoreGui") end); if ok then parent = root end end
    if parent then pcall(function() screen.Parent = parent end) end
    if not screen.Parent then screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
    local function physicalViewport()
        local size = screen.AbsoluteSize
        return size.X > 0 and size.Y > 0 and size or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720))
    end
    local initialViewport = physicalViewport()
    state.scale, state.width, state.compact = ctx.viewportMetrics(initialViewport)
    state.height = WINDOW_HEIGHT
    local stage = ctx.new("Frame", {Name = "ScaledInterface", BackgroundTransparency = 1,
        Size = UDim2.fromOffset(initialViewport.X / state.scale, initialViewport.Y / state.scale)}, screen)
    state.stage = stage
    local uiScale = ctx.new("UIScale", {Scale = state.scale}, stage)
    local overlay = ctx.new("Frame", {Name = "Overlays", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 20}, stage)
    state.overlay = overlay
    local root = ctx.new("Frame", {Name = "Window", Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(state.width, state.height), ClipsDescendants = true, ZIndex = 2}, stage)
    state.root = root
    ctx.bind(root, "BackgroundColor3", "Base"); ctx.round(root, 10)
    local shadow = ctx.new("Frame", {Name = "WindowShadow", BackgroundTransparency = 1,
        Size = root.Size, Position = root.Position, Active = false, ZIndex = 1}, stage)
    -- Fine falloff layers form a downward shadow without outlined rings.
    for spread = 12, 0, -1 do
        local layer = ctx.new("Frame", {Name = "ShadowFalloff", Position = UDim2.fromOffset(-spread, 6 - spread),
            Size = UDim2.new(1, spread * 2, 1, spread * 2), BackgroundTransparency = .975 - (12 - spread) * .0015,
            Active = false, ZIndex = 1}, shadow)
        ctx.bind(layer, "BackgroundColor3", "Input"); ctx.round(layer, 10 + spread)
    end
    local brackets = ctx.new("Frame", {Name = "CornerBrackets", BackgroundTransparency = 1,
        Size = root.Size, Position = root.Position, Active = false, ZIndex = 3}, stage)
    for _, corner in ipairs({{0, 0}, {1, 0}, {0, 1}, {1, 1}}) do
        local x, y = corner[1], corner[2]
        local mark = ctx.new("Frame", {Name = "Bracket", BackgroundTransparency = 1, Active = false,
            AnchorPoint = Vector2.new(x, y), Position = UDim2.new(x, x == 0 and -3 or 3, y, y == 0 and -3 or 3),
            Size = UDim2.fromOffset(8, 8), ZIndex = 3}, brackets)
        local horizontal = ctx.new("Frame", {Size = UDim2.fromOffset(8, 1),
            Position = UDim2.fromOffset(0, y * 7), Active = false, ZIndex = 3}, mark)
        local vertical = ctx.new("Frame", {Size = UDim2.fromOffset(1, 8),
            Position = UDim2.fromOffset(x * 7, 0), Active = false, ZIndex = 3}, mark)
        ctx.bind(horizontal, "BackgroundColor3", "Secondary")
        ctx.bind(vertical, "BackgroundColor3", "Secondary")
    end
    local function syncChrome()
        for _, frame in ipairs({shadow, brackets}) do
            frame.Position = root.Position; frame.Size = root.Size; frame.Visible = root.Visible
        end
    end
    ctx.connect(root:GetPropertyChangedSignal("Position"), syncChrome)
    ctx.connect(root:GetPropertyChangedSignal("Size"), syncChrome)
    ctx.connect(root:GetPropertyChangedSignal("Visible"), syncChrome)
    local window = {Flags = self.Flags, Tabs = state.tabs, Name = options.Name or "Eclipse", Frame = root}
    state.window = window; self.Window = window
    window.ModifyTheme = function(first, second) return self:ModifyTheme(first == window and second or first) end
    window.ChangeTheme = window.ModifyTheme
    window.Destroy = function() return self:Destroy() end; window.Unload = window.Destroy
    window.SaveConfiguration = function() return self:SaveConfiguration() end
    window.LoadConfiguration = function() return self:LoadConfiguration() end
    if options.Theme then self:ModifyTheme(options.Theme) end
    local image = resolveLogo(options)
    local canvas = ctx.new("Frame", {Name = "Interface", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2}, root)
    state.canvas = canvas
    local ambientFrame = ctx.new("Frame", {Name = "DigitalAtmosphere", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, HEADER_HEIGHT), Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT), ClipsDescendants = true, ZIndex = 2}, canvas)
    state.atmosphere = ctx.createAtmosphere(ambientFrame, {Mode = "ambient", Running = false, ZIndex = 2})
    local header = ctx.new("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_HEIGHT), ZIndex = 7}, canvas)
    ctx.bind(header, "BackgroundColor3", "Base")
    logo(header, image, UDim2.fromOffset(12, 8), UDim2.fromOffset(32, 32))
    ctx.text(header, window.Name, {Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -176, 0, 20),
        TextSize = 14, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
    local subtitle = ctx.text(header, options.Subtitle or "v" .. Library.Version,
        {Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -176, 0, 16), Font = ctx.font,
        TextSize = 12, TextColor3 = ctx.colors.Secondary, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
    ctx.bind(subtitle, "TextColor3", "Secondary")
    local searchButton = topButton(header, "search", -84, function() end)
    searchButton.Name = "SearchButton"
    local searchControl = {Frame = searchButton}
    local searchField, dismissSearch
    ctx.connect(searchButton.Activated, function()
        if searchField and searchField.Parent then dismissSearch(); searchField = nil; return end
        local panel, dismiss = ctx.popup(searchControl, 240, 48)
        dismissSearch = dismiss
        searchField = ctx.new("TextBox", {Name = "Search", Text = state.query, PlaceholderText = "Search controls",
            Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 1, -16), BackgroundTransparency = 1,
            ClearTextOnFocus = false, Font = ctx.font, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53}, panel)
        ctx.bind(searchField, "TextColor3", "Primary"); ctx.bind(searchField, "PlaceholderColor3", "Primary")
        ctx.connect(searchField:GetPropertyChangedSignal("Text"), function()
            state.query = string.lower(searchField.Text):match("^%s*(.-)%s*$") or ""
            ctx.bind(searchButton, "BackgroundColor3", "Input")
            for _, tab in ipairs(state.tabs) do queueReflow(tab) end
        end)
        ctx.connect(searchField.FocusLost, function(entered) if entered then dismiss() end end)
        searchField:CaptureFocus()
    end)
    state.collapsed = options.SidebarCollapsed == true or UIS.TouchEnabled or state.compact
    local sideWidth = state.collapsed and 44 or SIDEBAR_WIDTH
    local sidebar = ctx.new("Frame", {Name = "Sidebar", Position = UDim2.fromOffset(0, HEADER_HEIGHT),
        Size = UDim2.new(0, sideWidth, 1, -HEADER_HEIGHT), ZIndex = 6}, canvas)
    ctx.bind(sidebar, "BackgroundColor3", "Sidebar")
    state.sidebar = sidebar
    ctx.round(sidebar, 8)
    local nav = ctx.new("ScrollingFrame", {Name = "Tabs", Position = UDim2.fromOffset(state.collapsed and 4 or 8, 40),
        Size = UDim2.new(1, state.collapsed and -8 or -16, 1, -48), BackgroundTransparency = 1, ScrollBarThickness = 1,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 7}, sidebar)
    ctx.bind(nav, "ScrollBarImageColor3", "Accent")
    ctx.new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, nav)
    local content = ctx.new("Frame", {Name = "Content", Position = UDim2.fromOffset(sideWidth, HEADER_HEIGHT),
        Size = UDim2.new(1, -sideWidth, 1, -HEADER_HEIGHT), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3}, canvas)
    state.content = content
    local function visualRunning(running)
        state.atmosphere:SetRunning(running)
    end
    local function viewport() return ctx.unscale(physicalViewport()) end
    local function constrainWindow(position)
        local size = viewport()
        -- Leave a reachable title strip while permitting most of the body off-screen.
        return Vector2.new(math.clamp(position.X, 64 - (state.width - 120), math.max(0, size.X - 64)),
            math.clamp(position.Y, -24, math.max(0, size.Y - 24)))
    end
    local function place(reset)
        local size = viewport()
        local position = reset and Vector2.new((size.X - state.width) / 2, (size.Y - state.height) / 2)
            or Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
        position = constrainWindow(position)
        root.Position = UDim2.fromOffset(position.X, position.Y)
    end
    local floating = ctx.new("TextButton", {Name = "Reopen", Text = "",
        Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, Position = UDim2.new(.5, -18, 0, 12),
        Size = UDim2.fromOffset(36, 36), ZIndex = 19, Visible = UIS.TouchEnabled}, stage)
    ctx.bind(floating, "BackgroundColor3", "Input")
    ctx.round(floating, 10); ctx.softGlow(floating, 10)
    local reopenLogo = logo(floating, image, UDim2.fromOffset(7, 5), UDim2.fromOffset(22, 26))
    reopenLogo.ZIndex = 20
    local floatingStart, floatingPosition, floatingMoved
    ctx.drag(floating, function(position)
        position = ctx.logicalPoint(position)
        if not floatingStart then floatingStart = position; floatingPosition = ctx.logicalPoint(floating.AbsolutePosition); floatingMoved = false end
        local delta = position - floatingStart
        if delta.Magnitude > 6 then floatingMoved = true end
        if floatingMoved then
            local size = viewport()
            floating.Position = UDim2.fromOffset(math.clamp(floatingPosition.X + delta.X, 0, math.max(0, size.X - 36)),
                math.clamp(floatingPosition.Y + delta.Y, 0, math.max(0, size.Y - 36)))
        end
    end, function() floatingStart = nil end)
    local stopWindowDrag
    function window:SetMinimized(value)
        if stopWindowDrag then stopWindowDrag() end
        state.minimized = value == true
        closePopup(); hideTooltip(); root.Visible = not state.minimized
        if not state.minimized then place(true)
        else floating.Position = UDim2.new(.5, -18, 0, 12); floatingStart = nil; floatingMoved = false end
        visualRunning(not state.minimized and canvas.Visible)
        if state.bootAtmosphere then state.bootAtmosphere:SetRunning(not state.minimized and not state.bootDone) end
        floating.Visible = UIS.TouchEnabled or state.minimized
    end
    window.Minimize = function(_, value) if value == nil then value = not state.minimized end; window:SetMinimized(value) end
    window.Toggle = function() window:SetMinimized(not state.minimized) end
    window.Hide = function() window:SetMinimized(true) end; window.Show = function() window:SetMinimized(false) end
    window.SetVisibility = function(first, second) local value = first; if first == window then value = second end; self:SetVisibility(value) end
    window.IsVisible = function() return self:IsVisible() end
    ctx.connect(floating.Activated, function() if not floatingMoved then window:Toggle() end; floatingMoved = false end)
    topButton(header, "minimize", -48, function() window:SetMinimized(true) end)
    topButton(header, "close", -12, function() if type(options.OnClose) == "function" then options.OnClose() else self:Destroy() end end)
    local toggleOption = options.ToggleUIKeybind or "K"
    local toggleKey = typeof(toggleOption) == "EnumItem" and toggleOption.Name or tostring(toggleOption)
    ctx.connect(UIS.InputBegan, function(input, processed)
        if not processed and not UIS:GetFocusedTextBox() and not ctx._keybindCapture and (ctx._modalOpen or 0) == 0
            and input.KeyCode.Name == toggleKey then window:Toggle() end
    end)
    local collapse = ctx.new("TextButton", {Name = "Collapse", Text = "", Position = UDim2.fromOffset(state.collapsed and 10 or 16, 8),
        Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 7}, sidebar)
    ctx.vectorIcon(collapse, "sidebar", {Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(16, 16), ZIndex = 8})
    function window:SetSidebarCollapsed(value)
        state.collapsed = value == true; closePopup()
        local width = state.collapsed and 44 or SIDEBAR_WIDTH
        ctx.tween(sidebar, {Size = UDim2.new(0, width, 1, -HEADER_HEIGHT)}, .18)
        ctx.tween(content, {Position = UDim2.fromOffset(width, HEADER_HEIGHT), Size = UDim2.new(1, -width, 1, -HEADER_HEIGHT)}, .18)
        nav.Position = UDim2.fromOffset(state.collapsed and 4 or 8, 40)
        nav.Size = UDim2.new(1, state.collapsed and -8 or -16, 1, -48)
        collapse.Position = UDim2.fromOffset(state.collapsed and 10 or 16, 8)
        for _, tab in ipairs(state.tabs) do
            tab.NavLabel.Visible = not state.collapsed
            tab.Icon.Position = state.collapsed and UDim2.new(.5, -8, 0, 8) or UDim2.fromOffset(12, 8)
            queueReflow(tab)
        end
    end
    ctx.connect(collapse.Activated, function() window:SetSidebarCollapsed(not state.collapsed) end)
    function window:SelectTab(tabOrName)
        local selected
        for _, tab in ipairs(state.tabs) do if tab == tabOrName or tab.Name == tabOrName then selected = tab; break end end
        if not selected or selected.Destroyed then return false end
        closePopup(); hideTooltip(); state.activeTab = selected
        state.revealGeneration = (state.revealGeneration or 0) + 1
        local generation = state.revealGeneration
        for _, tab in ipairs(state.tabs) do
            local active = tab == selected
            tab.Page.Visible = active; tab.Indicator.Visible = active
            ctx.bind(tab.Button, "BackgroundColor3", "Accent")
            ctx.tween(tab.Button, {BackgroundTransparency = active and .85 or 1}, .15)
            ctx.bind(tab.NavLabel, "TextColor3", active and "Accent" or "Secondary", true)
            ctx.bind(tab.Indicator, "BackgroundColor3", "Accent")
            if tab.Icon:IsA("ImageLabel") then
                ctx.bind(tab.Icon, "ImageColor3", active and "Accent" or "Secondary")
            else
                for _, part in ipairs(tab.Icon:GetDescendants()) do
                    if part:IsA("Frame") then ctx.bind(part, "BackgroundColor3", active and "Accent" or "Secondary")
                    elseif part:IsA("UIStroke") then ctx.bind(part, "Color", active and "Accent" or "Secondary") end
                end
            end
            tab.NavLabel.TextTransparency = 0
        end
        selected.Page.CanvasPosition = Vector2.zero; reflow(selected)
        for index, section in ipairs(selected.Sections) do
            if section.Frame.Visible then
                section.Frame.Position = section.RestPosition + UDim2.fromOffset(0, 5)
                section.Frame.GroupTransparency = .6
                ctx.delay(math.min(.1, (index - 1) * .018), function()
                    if generation ~= state.revealGeneration or not section.Frame.Parent then return end
                    ctx.tween(section.Frame, {Position = section.RestPosition}, .18)
                    ctx.tween(section.Frame, {GroupTransparency = 0}, .15)
                end)
            end
        end
        return true
    end
    function window:CreateTab(rawName, icon)
        local tabOptions = type(rawName) == "table" and ctx.options(rawName) or {Name = rawName, Icon = icon}
        local name = tostring(tabOptions.Name or "Tab")
        local tab = setmetatable({Name = name, Sections = {}, Window = window, Columns = {}}, Tab)
        local page = ctx.new("ScrollingFrame", {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            CanvasSize = UDim2.new(), ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ZIndex = 3}, content)
        ctx.bind(page, "ScrollBarImageColor3", "Accent"); tab.Page = page
        for _, columnName in ipairs({"LeftColumn", "RightColumn"}) do
            table.insert(tab.Columns, ctx.new("Frame", {Name = columnName, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), ZIndex = 3}, page))
        end
        tab.Empty = ctx.text(page, "No matching controls", {Position = UDim2.fromOffset(12, 12),
            Size = UDim2.new(1, -24, 0, 32), TextSize = 14, TextTransparency = 0, Visible = false, ZIndex = 4})
        local button = ctx.new("TextButton", {Name = name, Text = "", AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 32), LayoutOrder = #state.tabs + 1, ZIndex = 7}, nav)
        ctx.bind(button, "BackgroundColor3", "Accent"); button.BackgroundTransparency = 1
        ctx.round(button, 6); tab.Button = button
        local asset = tabOptions.Icon ~= 4483362458 and ctx.iconAsset(tabOptions.Icon) or nil
        if asset then
            local iconImage = ctx.new("ImageLabel", {BackgroundTransparency = 1, Image = asset,
                Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(16, 16), ZIndex = 8}, button)
            ctx.bind(iconImage, "ImageColor3", "Primary"); tab.Icon = iconImage
        else tab.Icon = ctx.vectorIcon(button, type(tabOptions.Icon) == "string" and tabOptions.Icon or name,
            {Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(16, 16), ZIndex = 8}) end
        tab.Icon.Position = state.collapsed and UDim2.new(.5, -8, 0, 8) or UDim2.fromOffset(12, 8)
        tab.NavLabel = ctx.text(button, name, {Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0),
            Font = ctx.font, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Visible = not state.collapsed, ZIndex = 8})
        tab.Indicator = ctx.new("Frame", {Name = "ActiveIndicator", Size = UDim2.fromOffset(2, 16),
            Position = UDim2.new(0, 0, .5, -8), Visible = false, ZIndex = 8}, button)
        ctx.bind(tab.Indicator, "BackgroundColor3", "Accent"); ctx.round(tab.Indicator, 1)
        table.insert(state.tabs, tab)
        ctx.connect(button.Activated, function() window:SelectTab(tab) end)
        ctx.connect(page:GetPropertyChangedSignal("AbsoluteSize"), function() queueReflow(tab) end)
        ctx.connect(page:GetPropertyChangedSignal("CanvasPosition"), closePopup)
        if not state.activeTab then window:SelectTab(tab) end
        return tab
    end
    local dragHandle = ctx.new("Frame", {Name = "DragTitle", BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 0, HEADER_HEIGHT), Active = true, ZIndex = 10}, header)
    stopWindowDrag = ctx.smoothDrag(dragHandle, root, constrainWindow)
    local function resizeInterface()
        stopWindowDrag(); closePopup()
        local physical = physicalViewport()
        local wasCompact = state.compact
        state.scale, state.width, state.compact = ctx.viewportMetrics(physical)
        uiScale.Scale = state.scale
        stage.Size = UDim2.fromOffset(physical.X / state.scale, physical.Y / state.scale)
        root.Size = UDim2.fromOffset(state.width, state.height)
        if wasCompact ~= state.compact then window:SetSidebarCollapsed(state.compact or UIS.TouchEnabled) end
        for _, tab in ipairs(state.tabs) do queueReflow(tab) end
        place(false)
        local size = viewport()
        if state.minimized then floating.Position = UDim2.new(.5, -18, 0, 12) else
        floating.Position = UDim2.fromOffset(math.clamp(floating.Position.X.Scale * size.X + floating.Position.X.Offset, 0, math.max(0, size.X - 36)),
            math.clamp(floating.Position.Y.Scale * size.Y + floating.Position.Y.Offset, 0, math.max(0, size.Y - 36)))
        end
    end
    ctx.connect(screen:GetPropertyChangedSignal("AbsoluteSize"), resizeInterface)
    place(true)
    local boot = ctx.new("Frame", {Name = "Boot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3}, root)
    state.bootAtmosphere = ctx.createAtmosphere(boot, {Mode = "boot", Running = true, Center = Vector2.new(.5, .34), HollowCenter = true, ZIndex = 3})
    local bootLogo = logo(boot, image, UDim2.new(.5, -48, 0, 48), UDim2.fromOffset(96, 96))
    bootLogo.ZIndex = 5
    local bootTitle = ctx.text(boot, options.LoadingTitle or "ECLIPSE", {Position = UDim2.fromOffset(30, 164),
        Size = UDim2.new(1, -60, 0, 26), TextXAlignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 5})
    ctx.text(boot, options.LoadingSubtitle or ("v" .. Library.Version), {Position = UDim2.fromOffset(30, 197),
        Size = UDim2.new(1, -60, 0, 16), Font = ctx.font, TextSize = 13, TextTransparency = .45,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5})
    local track = ctx.new("Frame", {Position = UDim2.new(.5, -125, 0, 234), Size = UDim2.fromOffset(250, 4), ZIndex = 5}, boot)
    ctx.bind(track, "BackgroundColor3", "Input"); ctx.round(track, 2)
    local progress = ctx.new("Frame", {Size = UDim2.fromScale(0, 1), ZIndex = 6}, track)
    ctx.bind(progress, "BackgroundColor3", "Accent"); ctx.round(progress, 2); ctx.glow(progress, 2):SetActive(true, false)
    local bootStatus = ctx.text(boot, "INITIALIZING INTERFACE  00%", {Position = UDim2.new(.5, -125, 0, 248),
        Size = UDim2.fromOffset(250, 18), Font = ctx.font, TextSize = 12, TextTransparency = .35, ZIndex = 5})
    local pulseTarget = bootLogo
    local pulseProperty = bootLogo:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
    local pulse = TweenService:Create(pulseTarget, TweenInfo.new(.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {[pulseProperty] = .45})
    pulse:Play(); state.bootPulse = pulse
    ctx.spawn(function()
        scramble(bootTitle, options.LoadingTitle or "ECLIPSE")
        for _, percent in ipairs({18, 43, 71, 100}) do
            if not state.alive then return end
            ctx.tween(progress, {Size = UDim2.fromScale(percent / 100, 1)}, .14)
            scramble(bootStatus, string.format("INITIALIZING INTERFACE  %02d%%", percent))
            task.wait(options.DisableLoading and 0 or .18)
        end
        pulse:Cancel(); state.bootAtmosphere:Destroy(); state.bootAtmosphere = nil
        boot:Destroy(); state.bootDone = true; canvas.Visible = true
        visualRunning(not state.minimized)
        if state.activeTab then window:SelectTab(state.activeTab) end
    end)
    return window
end

function Library:Destroy()
    if not state.alive or state.destroying then return end
    state.destroying = true
    self:SaveConfiguration()
    for _, cleanup in ipairs(state.cleanups) do pcall(cleanup) end
    table.clear(state.cleanups)
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
