-- Eclipse UI core. Authoring source; build_ui.py assembles a single loadstring module.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Library = {Flags = {}, Version = "1.6.7", Name = "Eclipse UI"}
local Tab = {}
Tab.__index = Tab
local WINDOW_WIDTH, WINDOW_HEIGHT = 660, 420
local MIN_WIDTH, MIN_HEIGHT = 400, 280
local NAV_HEIGHT = (UIS.TouchEnabled and not UIS.MouseEnabled) and 40 or 32
local NAV_ICON_Y = (NAV_HEIGHT - 16) / 2
local SIDEBAR_WIDTH, HEADER_HEIGHT = 148, 48
local ctx = {Tab = Tab, UIS = UIS, fontMono = Enum.Font.Code, font = Enum.Font.Gotham, pad = 12}
-- Bindings hold strong keys: Roblox may collect an Instance's Lua proxy from a weak table while the
-- Instance is still on screen, which silently dropped unreferenced parts (header, bracket glows) from theming.
local state = {alive = true, connections = {}, threads = {}, bindings = {}, bindingCount = 0,
    tweens = setmetatable({}, {__mode = "k"}), tabs = {}, controls = {}, cleanups = {}, query = "", loading = false}
local surfaceRoles = {"Sidebar", "Section", "Hover", "Input", "Secondary", "Border", "Shadow", "OnAccent"}
local function palette(base, primary, accent, surfaces)
    local result = {Base = Color3.fromHex(base), Primary = Color3.fromHex(primary), Accent = Color3.fromHex(accent)}
    for role, value in pairs(surfaces or {}) do result[role] = Color3.fromHex(value) end
    return result
end
local function resolveTheme(theme)
    local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local light = theme.Base.R * .2126 + theme.Base.G * .7152 + theme.Base.B * .0722 > .55
    local result = {Base = theme.Base, Primary = theme.Primary, Accent = theme.Accent,
        Sidebar = theme.Base:Lerp(theme.Primary, .04),
        Section = light and theme.Base:Lerp(white, .8) or theme.Base:Lerp(theme.Primary, .04),
        Hover = theme.Base:Lerp(theme.Primary, light and .08 or .1),
        Input = light and theme.Base:Lerp(white, .35) or theme.Base:Lerp(black, .3),
        Secondary = theme.Primary:Lerp(theme.Base, .32), Border = light and black or white,
        Shadow = black, OnAccent = light and white or theme.Primary}
    for _, role in ipairs(surfaceRoles) do
        if typeof(theme[role]) == "Color3" then result[role] = theme[role] end
    end
    return result
end
Library.ThemeNames = {"Absolute Dark", "Charcoal", "Matrix Green", "Crimson Eclipse", "Void", "Monochrome", "Sakura",
    "Synthwave", "Frost", "Cyber Yellow", "Amber Glow", "Neon Cyan", "Light"}
Library.Themes = {
    Charcoal = palette("0E0F12", "E6E8EC", "3B82F6", {Sidebar="121317", Section="16181D", Hover="1D2026", Input="0B0C0F", Secondary="8A8F98", Shadow="0B0C0F"}),
    ["Absolute Dark"] = palette("020304", "E6E8EC", "3B82F6", {Sidebar="050608", Section="090B0E", Hover="11151B", Input="010203", Secondary="8A8F98", Shadow="000000"}),
    ["Cyber Yellow"] = palette("101208", "F4F5DE", "FCEE09", {Sidebar="191C0D", Section="222615", Hover="30371B", Input="090C05", Secondary="B0B596", OnAccent="101208"}),
    ["Amber Glow"] = palette("191009", "FFF0DF", "FFAD42", {Sidebar="23170F", Section="302015", Hover="412D1D", Input="100A06", Secondary="C6A88A", OnAccent="191009"}),
    ["Neon Cyan"] = palette("06151C", "E1F8FF", "00E5FF", {Sidebar="09212B", Section="0D2C38", Hover="123F4E", Input="031016", Secondary="8DBAC7", OnAccent="06151C"}),
    Light = palette("EDF1F7", "192332", "2563EB", {Sidebar="E2E8F1", Section="FFFFFF", Hover="DCE5F2", Input="EAF0F7", Secondary="536174", Border="192332", Shadow="101827", OnAccent="FFFFFF"}),
    ["Matrix Green"] = palette("020603", "D7F5DD", "22C55E", {Sidebar="040A06", Section="07110A", Hover="0D1C11", Input="010402", Secondary="7FA88A", OnAccent="020603"}),
    ["Crimson Eclipse"] = palette("0D0607", "F3E4E5", "EF4444", {Sidebar="140A0B", Section="1B0E10", Hover="2A1518", Input="080304", Secondary="A88A8D"}),
    Void = palette("0B0912", "ECE8F5", "B57BF9", {Sidebar="110E1A", Section="171324", Hover="221C33", Input="07060C", Secondary="9189A8", OnAccent="0B0912"}),
    Monochrome = palette("0A0A0A", "EDEDED", "FFFFFF", {Sidebar="101010", Section="161616", Hover="222222", Input="050505", Secondary="8C8C8C", OnAccent="0A0A0A"}),
    Sakura = palette("120A0F", "F7E8EF", "F472B6", {Sidebar="1A0F16", Section="22131C", Hover="2F1A27", Input="0B0609", Secondary="B0919F", OnAccent="120A0F"}),
    Synthwave = palette("0E0A1F", "F3E8FF", "FF4FD8", {Sidebar="140F2A", Section="1B1536", Hover="271E4A", Input="080614", Secondary="9D8FC2", OnAccent="0E0A1F"}),
    Frost = palette("0A0F14", "E4EEF5", "7DD3FC", {Sidebar="0F161D", Section="141D26", Hover="1C2834", Input="05090C", Secondary="8A9BAA", OnAccent="0A0F14"}),
}
-- Absolute Dark is the default; "Default" stays a valid name for existing scripts.
Library.Themes.Default = Library.Themes["Absolute Dark"]
local aliases = {Eclipse = "Default", Amethyst = "Default", Bloom = "Default", Serenity = "Default",
    AbsoluteDark = "Absolute Dark", DarkBlue = "Neon Cyan", Ocean = "Neon Cyan", Green = "Neon Cyan",
    MatrixGreen = "Matrix Green", CrimsonEclipse = "Crimson Eclipse",
    -- Earlier unspaced preset names keep working.
    CyberYellow = "Cyber Yellow", AmberGlow = "Amber Glow", NeonCyan = "Neon Cyan"}
state.theme = resolveTheme(Library.Themes.Default)
state.effect = "Absolute Dark"
function ctx.effectName() return state.effect end
ctx.colors = state.theme
Library.Theme = Library.Themes
function ctx.alive() return state.alive end
function ctx.theme() return state.theme end
function ctx.unscale(value) return value / (state.scale or 1) end
function ctx.logicalPoint(position)
    return ctx.unscale(position - (state.stage and state.stage.AbsolutePosition or Vector2.zero))
end
-- Phones and tablets without a mouse get larger touch targets and no hover states.
ctx.touch = UIS.TouchEnabled and not UIS.MouseEnabled
function ctx.touchInput()
    return ctx.touch or UIS:GetLastInputType() == Enum.UserInputType.Touch
end
-- Fit the window to the screen before scaling it: it narrows and shortens down to 400x280 at full
-- text size, and only scales below that. `topInset` reserves the Roblox top bar on touch screens.
function ctx.viewportMetrics(size, topInset)
    local availableX, availableY = size.X, math.max(1, size.Y - (topInset or 0))
    local scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 1, 1.25)
    local width = math.min(WINDOW_WIDTH, availableX / scale - 24)
    local height = math.min(WINDOW_HEIGHT, availableY / scale - 24)
    if width < MIN_WIDTH or height < MIN_HEIGHT then
        scale = math.max(.1, math.min(scale, (availableX - 24) / MIN_WIDTH, (availableY - 24) / MIN_HEIGHT))
        width = math.clamp(availableX / scale - 24, MIN_WIDTH, WINDOW_WIDTH)
        height = math.clamp(availableY / scale - 24, MIN_HEIGHT, WINDOW_HEIGHT)
    end
    width, height = math.floor(width), math.floor(height)
    return scale, width, width < 600, height
end
function ctx.addCleanup(callback) table.insert(state.cleanups, callback) end
function ctx.ripple(position, strength)
    local atmosphere = state.bootDone and state.atmosphere or state.bootAtmosphere
    if atmosphere and not state.minimized then atmosphere:Ripple(position, strength or 1) end
end
function ctx.matrixEnabled() return state.matrix ~= false end
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
    return type(role) == "function" and role(state.theme) or state.theme[role]
end
function ctx.bind(object, property, role, animate)
    local bindings = state.bindings[object]
    if not bindings then
        bindings = {}
        state.bindingCount += 1
        -- Periodically release bindings of destroyed objects (popups, dropdown rows, toasts).
        if state.bindingCount % 256 == 0 then
            for bound in pairs(state.bindings) do
                if bound.Parent == nil then state.bindings[bound] = nil end
            end
        end
    end
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
-- `single` keeps only the tight inner bloom, without the wider outer halo.
function ctx.glow(parent, radius, strength, idle, role, single)
    local layer = ctx.new("Frame", {Name = "AccentBloom", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(-1, -1), Size = UDim2.new(1, 2, 1, 2),
        Active = false, ZIndex = parent.ZIndex}, parent)
    ctx.round(layer, (radius or 8) + 1)
    local inner = ctx.stroke(layer, role or "Secondary", idle or 1); inner.Thickness = 3
    local outer
    if not single then
        local halo = ctx.new("Frame", {Name = "BloomHalo", BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Active = false, ZIndex = layer.ZIndex}, layer)
        ctx.round(halo, (radius or 8) + 1)
        outer = ctx.stroke(halo, role or "Secondary", idle and math.min(.985, idle + .04) or 1); outer.Thickness = 7
    end
    local glow = {Active = false, Frame = layer, Generation = 0}
    local alpha = math.clamp(tonumber(strength) or 0.76, 0.6, 0.9)
    function glow:SetActive(active, animate)
        self.Active = active == true
        ctx.tween(inner, {Transparency = self.Active and alpha or idle or 1}, animate == false and 0 or 0.16)
        if outer then
            ctx.tween(outer, {Transparency = self.Active and math.min(.96, alpha + .13) or (idle and math.min(.985, idle + .04) or 1)}, animate == false and 0 or .18)
        end
    end
    function glow:Pulse()
        self.Generation += 1
        local generation = self.Generation
        ctx.tween(inner, {Transparency = 0.55}, 0.07)
        if outer then ctx.tween(outer, {Transparency = 0.82}, 0.07) end
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
        thickness = thickness or 1.5
        -- Segments overshoot by most of their thickness so polyline joints close cleanly.
        local segment = ctx.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
            Size = UDim2.new(math.sqrt(dx * dx + dy * dy), thickness * .8, 0, thickness),
            Rotation = math.deg(math.atan2(dy, dx)), ZIndex = icon.ZIndex}, icon)
        ctx.bind(segment, "BackgroundColor3", role); ctx.round(segment, 1)
        return segment
    end
    local function ring(x, y, w, h)
        local frame = ctx.new("Frame", {Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h or w),
            BackgroundTransparency = 1, ZIndex = icon.ZIndex}, icon)
        ctx.round(frame, 100); ctx.stroke(frame, role, 0.05).Thickness = 1.5
        return frame
    end
    local function box(x, y, w, h, radius)
        local frame = ctx.new("Frame", {Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
            BackgroundTransparency = 1, ZIndex = icon.ZIndex}, icon)
        ctx.round(frame, radius or 3); ctx.stroke(frame, role, 0.05).Thickness = 1.5
        return frame
    end
    local function dot(x, y, size)
        local frame = ctx.new("Frame", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, y),
            Size = UDim2.fromScale(size, size), ZIndex = icon.ZIndex}, icon)
        ctx.bind(frame, "BackgroundColor3", role); ctx.round(frame, 100)
        return frame
    end
    name = string.lower(tostring(name or "grid"))
    local function named(...)
        for _, keyword in ipairs({...}) do if string.find(name, keyword, 1, true) then return true end end
        return false
    end
    if name == "close" or name == "x" then line(.25,.25,.75,.75); line(.75,.25,.25,.75)
    elseif name == "minimize" then line(.22,.65,.78,.65)
    elseif name == "chevron" or name == "chevron-down" then line(.25,.4,.5,.65); line(.5,.65,.75,.4)
    elseif name == "arrow" or name == "play" or name == "action" then
        line(.18,.5,.8,.5); line(.56,.25,.8,.5); line(.56,.75,.8,.5)
    elseif name == "check" then line(.2,.5,.42,.72); line(.42,.72,.82,.25)
    else
        -- Sidebar and header icons come from Lucide, matched by keyword so "Auto Farms" or "Player ESP" resolve too.
        local glyph = "layout-grid"
        if name == "search" then glyph = "search"
        elseif name == "sidebar" then glyph = "panel-left"
        elseif name == "chevron-left" then glyph = "chevron-left"
        elseif name == "keyboard" then glyph = "keyboard"
        elseif ctx.lucide and ctx.lucide[name] then glyph = name
        elseif named("setting", "config") then glyph = "settings"
        elseif named("esp", "eye", "visual") then glyph = "eye"
        elseif named("home", "main", "dashboard") then glyph = "house"
        elseif named("farm", "auto") then glyph = "zap"
        elseif named("player", "local", "user", "character", "profile") then glyph = "user"
        elseif named("teleport", "map", "world", "location") then glyph = "map-pin"
        elseif named("combat", "fight", "pvp", "aim", "kill") then glyph = "swords"
        elseif named("info", "credit", "about", "help") then glyph = "info"
        elseif named("misc", "other", "extra", "more") then glyph = "ellipsis" end
        for _, shape in ipairs(ctx.lucide and ctx.lucide[glyph] or {}) do
            if shape.circle then
                local x, y, r = shape.circle[1], shape.circle[2], shape.circle[3]
                if r < .06 then dot(x, y, r * 2 + .09) else ring(x - r, y - r, r * 2) end
            elseif shape.rect then
                local x, y, w, h, r = table.unpack(shape.rect)
                box(x, y, w, h, math.max(1, r * 16))
            else
                for i = 1, #shape - 3, 2 do
                    local x1, y1, x2, y2 = shape[i], shape[i + 1], shape[i + 2], shape[i + 3]
                    -- Lucide draws dots as zero-length strokes with round caps.
                    if math.abs(x2 - x1) + math.abs(y2 - y1) < .01 then dot(x1, y1, .09) else line(x1, y1, x2, y2) end
                end
            end
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
    ctx.stroke(panel, "Border", .94)
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
            local height = math.max(60, bodyHeight + 60)
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
    ctx.round(frame, 8); ctx.stroke(frame, "Border", .92)
    -- Header, rule and row content share one 16px inset; rows sit 4px in so their hover fill has room.
    local header = ctx.text(frame, sectionCaption(name), {Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 0, 16), Font = Enum.Font.GothamBold, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
    ctx.bind(header, "TextColor3", "Secondary")
    local rule = ctx.new("Frame", {Name = "SectionRule", Position = UDim2.fromOffset(16, 38),
        Size = UDim2.new(1, -32, 0, 1), BackgroundTransparency = .94, ZIndex = 4}, frame)
    ctx.bind(rule, "BackgroundColor3", "Primary")
    local body = ctx.new("Frame", {Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 46),
        Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 4}, frame)
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
        if control.Disabled or (on and ctx.touchInput()) then return end
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
-- Row labels wrap instead of truncating; the row grows so the whole name stays readable.
function ctx.wrapLabel(control, reserved, minimum)
    local label, row = control.Label, control.Frame
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.AnchorPoint = Vector2.new(0, .5)
    label.Position = UDim2.new(0, 12, .5, 0)
    label.Size = UDim2.new(1, -reserved, 0, 0)
    label.TextSize = 14
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.None
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.LineHeight = 1.1
    local function resize()
        if control.Destroyed or not label.Parent then return end
        local height = math.max(minimum or (ctx.touch and 44 or 36), math.ceil(ctx.unscale(label.AbsoluteSize.Y)) + 16)
        if row.Size.Y.Offset ~= height then row.Size = UDim2.new(1, 0, 0, height) end
    end
    ctx.connect(label:GetPropertyChangedSignal("AbsoluteSize"), resize)
    ctx.delay(0, resize)
    return resize
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
    -- Named presets also pick their glyph effect; custom tables may name one in `Effect`.
    local effect = type(theme) == "table" and theme.Effect or nil
    if type(theme) == "string" then
        effect = aliases[theme] or theme
        theme = self.Themes[effect]
    end
    if type(theme) ~= "table" or typeof(theme.Base) ~= "Color3" or typeof(theme.Primary) ~= "Color3"
        or typeof(theme.Accent) ~= "Color3" then return false end
    if effect then state.effect = effect == "Default" and "Absolute Dark" or tostring(effect) end
    -- Keep three-token custom themes compatible, with optional semantic surface overrides.
    state.theme = resolveTheme(theme)
    ctx.colors = state.theme
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
    local button = ctx.new("TextButton", {Name = name, Text = "", BackgroundTransparency = 1,
        AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 8),
        Size = UDim2.fromOffset(32, 32), ZIndex = 8}, parent)
    ctx.bind(button, "BackgroundColor3", name == "close" and function() return Color3.fromHex("E5484D") end or "Hover")
    ctx.round(button, 6)
    local icon = ctx.vectorIcon(button, name, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(16, 16),
        ZIndex = 9, Role = "Secondary"})
    local function iconRole(role)
        for _, part in ipairs(icon:GetDescendants()) do
            if part:IsA("Frame") then ctx.bind(part, "BackgroundColor3", role, true)
            elseif part:IsA("UIStroke") then ctx.bind(part, "Color", role, true) end
        end
    end
    -- Borderless icon buttons: a soft surface appears on hover only.
    ctx.connect(button.MouseEnter, function()
        if ctx.touchInput() then return end
        ctx.tween(button, {BackgroundTransparency = name == "close" and .2 or 0}, .12)
        iconRole(name == "close" and function() return Color3.new(1, 1, 1) end or "Primary")
    end)
    ctx.connect(button.MouseLeave, function()
        ctx.tween(button, {BackgroundTransparency = 1}, .12); iconRole("Secondary")
    end)
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
    -- Keep clear of notches and rounded corners; on touch screens also clear the Roblox top bar.
    pcall(function() screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
    local function topInset()
        if not ctx.touch then return 0 end
        local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
        return ok and typeof(inset) == "Vector2" and inset.Y or 0
    end
    local initialViewport = physicalViewport()
    state.scale, state.width, state.compact, state.height = ctx.viewportMetrics(initialViewport, topInset())
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
        ctx.bind(layer, "BackgroundColor3", "Shadow"); ctx.round(layer, 10 + spread)
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
        for _, edge in ipairs({horizontal, vertical}) do
            ctx.bind(edge, "BackgroundColor3", "Accent")
            edge.ZIndex = 4
            -- Static rectangular falloff preserves the sharp bracket silhouette.
            for spread = 3, 1, -1 do
                local glow = ctx.new("Frame", {Name = "BracketGlow", Active = false, ZIndex = 3,
                    Position = UDim2.fromOffset(edge.Position.X.Offset - spread, edge.Position.Y.Offset - spread),
                    Size = UDim2.fromOffset(edge.Size.X.Offset + spread * 2, edge.Size.Y.Offset + spread * 2),
                    BackgroundTransparency = .88 + spread * .03}, mark)
                ctx.bind(glow, "BackgroundColor3", "Accent")
            end
        end
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
    -- Matrix glyph field behind the cards; `Matrix = false` swaps it for a faint static wash.
    state.matrix = options.Matrix ~= false
    if state.matrix then
        local ambientFrame = ctx.new("Frame", {Name = "DigitalAtmosphere", BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, HEADER_HEIGHT), Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT), ClipsDescendants = true, ZIndex = 2}, canvas)
        state.atmosphere = ctx.createAtmosphere(ambientFrame, {Mode = "ambient", Running = false, ZIndex = 2})
    else
        local wash = ctx.new("Frame", {Name = "BackgroundWash", Position = UDim2.fromOffset(0, HEADER_HEIGHT),
            Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT), BackgroundTransparency = .97, Active = false, ZIndex = 2}, canvas)
        ctx.bind(wash, "BackgroundColor3", "Primary")
        ctx.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 1)}, wash)
    end
    -- The top bar shares the sidebar's tinted surface, so it follows theme changes visibly
    -- (Base is near-black in every dark preset). Rounded top corners match the window.
    local header = ctx.new("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_HEIGHT), ZIndex = 7}, canvas)
    ctx.bind(header, "BackgroundColor3", "Sidebar"); ctx.round(header, 10)
    local headerBase = ctx.new("Frame", {Name = "SquareBottom", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 10), Active = false, ZIndex = 7}, header)
    ctx.bind(headerBase, "BackgroundColor3", "Sidebar")
    local headerRule = ctx.new("Frame", {Name = "HeaderRule", AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = .94, ZIndex = 8}, header)
    ctx.bind(headerRule, "BackgroundColor3", "Border")
    logo(header, image, UDim2.fromOffset(12, 8), UDim2.fromOffset(32, 32))
    ctx.text(header, window.Name, {Position = UDim2.fromOffset(52, 7), Size = UDim2.new(1, -176, 0, 20),
        TextSize = 15, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
    -- "PREMIUM / v1.2" subtitles render the tier as a pill and the remainder as muted text.
    -- The pill takes `Badge` (text, false to hide, or {Text, Color, TextColor}), `BadgeColor` and
    -- `BadgeTextColor`. Colors are a Color3, "#RRGGBB" hex or a theme role name such as "Accent".
    local subtitleText = tostring(options.Subtitle or "v" .. Library.Version)
    local badgeOptions = type(options.Badge) == "table" and ctx.options(options.Badge) or {}
    local badgeText, restText = options.Badge, subtitleText
    if type(badgeText) == "table" then badgeText = badgeOptions.Text or badgeOptions.Name end
    if badgeText == nil then
        local tier, rest = string.match(subtitleText, "^%s*(%u[%u%d]+)%s*[/|·]%s*(.-)%s*$")
        if tier then badgeText, restText = tier, rest end
    end
    local function colorRole(value, fallback)
        if typeof(value) == "Color3" then return function() return value end end
        if type(value) == "string" then
            if state.theme[value] then return value end
            local hex = string.match(value, "^#?(%x%x%x%x%x%x)$")
            if hex then local parsed = Color3.fromHex(hex); return function() return parsed end end
        end
        return fallback
    end
    local subtitleRow = ctx.new("Frame", {Name = "Subtitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 27),
        Size = UDim2.new(1, -176, 0, 16), ClipsDescendants = true, ZIndex = 8}, header)
    ctx.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, subtitleRow)
    local badge = ctx.new("Frame", {Name = "TierBadge", Size = UDim2.fromOffset(0, 15),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = .84, LayoutOrder = 1, ZIndex = 8}, subtitleRow)
    ctx.round(badge, 8)
    ctx.new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, badge)
    local badgeLabel = ctx.text(badge, "", {Size = UDim2.fromOffset(0, 15),
        AutomaticSize = Enum.AutomaticSize.X, Font = Enum.Font.GothamBold, TextSize = 9, ZIndex = 9})
    local badgeColor, badgeTextColor = "Accent", nil
    -- Text follows the pill color unless a separate text color was given.
    local function paintBadge()
        ctx.bind(badge, "BackgroundColor3", badgeColor)
        ctx.bind(badgeLabel, "TextColor3", badgeTextColor or badgeColor)
    end
    function window:SetBadge(text, color, textColor)
        if type(text) == "table" then
            local updated = ctx.options(text)
            text, color, textColor = updated.Text or updated.Name, updated.Color, updated.TextColor
        end
        if text ~= nil then
            local value = text ~= false and tostring(text) or ""
            badgeLabel.Text = string.upper(value)
            badge.Visible = value ~= ""
        end
        if color ~= nil then badgeColor = colorRole(color, badgeColor) end
        if textColor ~= nil then badgeTextColor = colorRole(textColor, badgeTextColor) end
        paintBadge()
        return window
    end
    badge.Visible = false
    window:SetBadge(badgeText or false, badgeOptions.Color or options.BadgeColor,
        badgeOptions.TextColor or options.BadgeTextColor)
    local subtitle = ctx.text(subtitleRow, restText, {Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
        Font = ctx.font, TextSize = 12, LayoutOrder = 2, ZIndex = 8})
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
    -- Square top edge so the sidebar meets the top bar without corner notches.
    local sidebarJoin = ctx.new("Frame", {Name = "SquareTop", Size = UDim2.new(1, 0, 0, 10), Active = false, ZIndex = 6}, sidebar)
    ctx.bind(sidebarJoin, "BackgroundColor3", "Sidebar")
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
        if state.atmosphere then state.atmosphere:SetRunning(running) end
    end
    local function viewport() return ctx.unscale(physicalViewport()) end
    local function constrainWindow(position)
        local size = viewport()
        -- Leave a reachable title strip while permitting most of the body off-screen.
        local top = ctx.touch and ctx.unscale(topInset()) or -24
        return Vector2.new(math.clamp(position.X, 64 - (state.width - 120), math.max(0, size.X - 64)),
            math.clamp(position.Y, top, math.max(top, size.Y - 24)))
    end
    local function place(reset)
        local size = viewport()
        local top = ctx.unscale(topInset())
        local position = reset and Vector2.new((size.X - state.width) / 2, top + (size.Y - top - state.height) / 2)
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
    -- Panel icon, plus a collapse arrow beside it while the sidebar is expanded; the button widens to cover it.
    ctx.vectorIcon(collapse, "sidebar", {Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(16, 16), ZIndex = 8})
    local collapseArrow = ctx.vectorIcon(collapse, "chevron-left", {Position = UDim2.fromOffset(22, 2),
        Size = UDim2.fromOffset(20, 20), ZIndex = 8})
    local function drawCollapseIcon()
        collapseArrow.Visible = not state.collapsed
        collapse.Size = UDim2.fromOffset(state.collapsed and 24 or 44, 24)
    end
    drawCollapseIcon()
    function window:SetSidebarCollapsed(value)
        state.collapsed = value == true; closePopup()
        local width = state.collapsed and 44 or SIDEBAR_WIDTH
        ctx.tween(sidebar, {Size = UDim2.new(0, width, 1, -HEADER_HEIGHT)}, .18)
        ctx.tween(content, {Position = UDim2.fromOffset(width, HEADER_HEIGHT), Size = UDim2.new(1, -width, 1, -HEADER_HEIGHT)}, .18)
        nav.Position = UDim2.fromOffset(state.collapsed and 4 or 8, 40)
        nav.Size = UDim2.new(1, state.collapsed and -8 or -16, 1, -48)
        collapse.Position = UDim2.fromOffset(state.collapsed and 10 or 16, 8)
        drawCollapseIcon()
        for _, tab in ipairs(state.tabs) do
            tab.NavLabel.Visible = not state.collapsed
            tab.Icon.Position = state.collapsed and UDim2.new(.5, -8, 0, NAV_ICON_Y) or UDim2.fromOffset(12, NAV_ICON_Y)
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
            CanvasSize = UDim2.new(), ScrollBarThickness = 3, ScrollBarImageTransparency = .55,
            ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, ZIndex = 3}, content)
        ctx.bind(page, "ScrollBarImageColor3", "Accent"); tab.Page = page
        for _, columnName in ipairs({"LeftColumn", "RightColumn"}) do
            table.insert(tab.Columns, ctx.new("Frame", {Name = columnName, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), ZIndex = 3}, page))
        end
        tab.Empty = ctx.text(page, "No matching controls", {Position = UDim2.fromOffset(12, 12),
            Size = UDim2.new(1, -24, 0, 32), TextSize = 14, TextTransparency = 0, Visible = false, ZIndex = 4})
        local button = ctx.new("TextButton", {Name = name, Text = "", AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, NAV_HEIGHT), LayoutOrder = #state.tabs + 1, ZIndex = 7}, nav)
        ctx.bind(button, "BackgroundColor3", "Accent"); button.BackgroundTransparency = 1
        ctx.round(button, 6); tab.Button = button
        local asset = tabOptions.Icon ~= 4483362458 and ctx.iconAsset(tabOptions.Icon) or nil
        if asset then
            local iconImage = ctx.new("ImageLabel", {BackgroundTransparency = 1, Image = asset,
                Position = UDim2.fromOffset(12, NAV_ICON_Y), Size = UDim2.fromOffset(16, 16), ZIndex = 8}, button)
            ctx.bind(iconImage, "ImageColor3", "Primary"); tab.Icon = iconImage
        else tab.Icon = ctx.vectorIcon(button, type(tabOptions.Icon) == "string" and tabOptions.Icon or name,
            {Position = UDim2.fromOffset(12, NAV_ICON_Y), Size = UDim2.fromOffset(16, 16), ZIndex = 8}) end
        tab.Icon.Position = state.collapsed and UDim2.new(.5, -8, 0, NAV_ICON_Y) or UDim2.fromOffset(12, NAV_ICON_Y)
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
        state.scale, state.width, state.compact, state.height = ctx.viewportMetrics(physical, topInset())
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
    table.clear(state.bindings)
end
Library.Unload = Library.Destroy
return Library, ctx
