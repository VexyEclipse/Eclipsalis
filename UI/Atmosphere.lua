-- Bounded procedural ASCII decoration. Installed before controls in the standalone build.
return function(Library, ctx)
    local RunService = game:GetService("RunService")
    local glyphs = {".", "+", ":", "|", "-", ".", "/"}
    local handles, slices = {}, {}
    local connection, accumulated, disposed = nil, 0, false
    local interval, rippleLifetime = 1 / 18, 1.2
    local refreshWorker

    local function finite(value)
        return type(value) == "number" and value == value and math.abs(value) < math.huge
    end

    local function number(value, fallback)
        local parsed = tonumber(value)
        return finite(parsed) and parsed or fallback
    end

    local function visible(handle)
        if handle.Destroyed or not handle.Running or not handle.Visible or not handle.Frame.Parent then return false end
        local ancestor = handle.Frame
        while ancestor do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
            if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
            ancestor = ancestor.Parent
        end
        return true
    end

    local function assign(object, property, value)
        if object[property] ~= value then object[property] = value end
    end

    local function quantize(value)
        return math.floor(value * 100 + 0.5) / 100
    end

    local function render(handle, now)
        local frame = handle.Frame
        local size = frame.AbsoluteSize
        local width = size.X > 0 and size.X or handle.Width
        local height = size.Y > 0 and size.Y or handle.Height
        local elapsed = now - handle.Started
        local ripples = handle.Ripples
        for index = #ripples, 1, -1 do
            if now - ripples[index].Time > rippleLifetime then table.remove(ripples, index) end
        end
        local isBoot, isWatermark = handle.Mode == "boot", handle.Mode == "watermark"
        for _, cell in ipairs(handle.Cells) do
            local x, y = cell.X * width, cell.Y * height
            local wave = math.sin(now * 0.72 + cell.Column * 0.31 + cell.Row * 0.44)
            local energy, present = 0, true
            if isBoot then
                local dx = (cell.X - handle.Center.X) / 0.35
                local dy = (cell.Y - handle.Center.Y) / 0.28
                local radius = math.sqrt(dx * dx + dy * dy)
                local boundary = 1.08 + math.sin(now * 1.8 + cell.Column * 0.40 + cell.Row * 0.21) * 0.10
                local inner = math.sqrt(((cell.X - handle.Center.X) / 0.105) ^ 2
                    + ((cell.Y - handle.Center.Y) / 0.19) ^ 2)
                present = radius < boundary and (not handle.HollowCenter or inner > 1)
                    and elapsed >= cell.RevealAt
                energy = math.max(0, 1 - math.abs(radius - 0.82) / 0.24)
                    * (0.18 + math.sin(elapsed * 3.5 + cell.Column * 0.25) * 0.08)
                -- Sparse short pulses around the aura, rather than flashing the full boot screen.
                if math.sin(now * 8 + cell.Column * 0.63 + cell.Row * 0.29) > 0.985 then energy += 0.22 end
            elseif isWatermark then
                energy = math.max(0, math.sin(now * 1.3 - cell.Column * 0.42)) * 0.13
            end
            for _, ripple in ipairs(ripples) do
                local age = now - ripple.Time
                local dx, dy = x - ripple.X, y - ripple.Y
                local distance = math.sqrt(dx * dx + dy * dy)
                local band = (distance - age * 145) / 25
                energy += ripple.Strength * math.max(0, 1 - age / rippleLifetime) * math.exp(-band * band)
            end
            energy = math.clamp(energy, 0, 1)
            local phase = math.floor(now * (energy > 0.2 and 13 or 2.4)
                + cell.Column * 0.71 + cell.Row * 1.31 + wave * 1.5)
            local glyph = present and glyphs[phase % #glyphs + 1] or ""
            local transparency = quantize(math.clamp(0.76 + wave * 0.055 - energy * 0.38, 0.32, 0.84))
            assign(cell.Label, "Text", glyph)
            assign(cell.Label, "TextTransparency", transparency)
            assign(cell.Label, "TextStrokeTransparency", quantize(1 - energy * 0.25))
        end
    end

    local function update(delta)
        if disposed or not ctx.alive() then
            if connection then connection:Disconnect(); connection = nil end
            return
        end
        accumulated += delta
        if accumulated < interval then return end
        accumulated %= interval
        local now, running = os.clock(), false
        for handle in pairs(handles) do
            if visible(handle) then running = true; render(handle, now) end
        end
        if not running and connection then connection:Disconnect(); connection = nil end
    end

    refreshWorker = function()
        local running = false
        if not disposed and ctx.alive() then
            for handle in pairs(handles) do if visible(handle) then running = true; break end end
        end
        if running and (not connection or not connection.Connected) then
            accumulated = 0
            connection = ctx.connect(RunService.RenderStepped, update)
        elseif not running and connection then connection:Disconnect(); connection = nil end
    end

    function ctx.createAtmosphere(parent, rawOptions)
        assert(not disposed and ctx.alive(), "Cannot create decoration after Eclipse UI is destroyed.")
        local options = ctx.options(rawOptions)
        local mode = string.lower(tostring(options.Mode or "ambient"))
        if mode ~= "boot" and mode ~= "watermark" then mode = "ambient" end
        local glyphSize = math.clamp(number(options.GlyphSize, mode == "watermark" and 9 or 12), 8, 16)
        local width = parent.AbsoluteSize.X > 0 and parent.AbsoluteSize.X or (mode == "boot" and 300 or 520)
        local height = parent.AbsoluteSize.Y > 0 and parent.AbsoluteSize.Y or (mode == "boot" and 240 or 262)
        local cap = mode == "ambient" and 240 or (mode == "boot" and 160 or 32)
        local columns = mode == "watermark" and 24 or math.floor(width / (glyphSize * 1.65))
        local rows = mode == "watermark" and 1 or math.floor(height / (glyphSize * 1.8))
        columns = math.clamp(math.floor(number(options.Columns, columns)), 1, cap)
        rows = math.clamp(math.floor(number(options.Rows, rows)), 1, cap)
        if columns * rows > cap then
            local factor = math.sqrt(cap / (columns * rows))
            columns = math.max(1, math.floor(columns * factor))
            rows = math.max(1, math.floor(rows * factor))
        end
        local z = math.max(1, math.floor(number(options.ZIndex, parent.ZIndex or 1)))
        local frame = ctx.new("Frame", {Name = "Ascii_" .. mode, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
            Active = false, ZIndex = z, Visible = options.Visible ~= false}, parent)
        local center = typeof(options.Center) == "Vector2" and options.Center or Vector2.new(0.5, 0.30)
        local handle = {Frame = frame, Mode = mode, Running = options.Running ~= false, Visible = options.Visible ~= false,
            Destroyed = false, Cells = {}, Ripples = {}, Started = os.clock(), Center = center,
            Width = width, Height = height, HollowCenter = options.HollowCenter ~= false,
            Columns = columns, Rows = rows, CellCount = columns * rows, UpdateRate = 18}
        for row = 1, rows do
            for column = 1, columns do
                local x, y = (column - 0.5) / columns, (row - 0.5) / rows
                local label = ctx.text(frame, "", {Name = "Glyph", Font = ctx.fontMono, TextSize = glyphSize,
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
                    Size = UDim2.fromOffset(glyphSize + 3, glyphSize + 6), TextWrapped = false,
                    TextTransparency = 0.76, TextStrokeTransparency = 1,
                    TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
                    ZIndex = z, Active = false})
                ctx.bind(label, "TextColor3", "Secondary")
                ctx.bind(label, "TextStrokeColor3", "Secondary")
                table.insert(handle.Cells, {Label = label, X = x, Y = y, Column = column, Row = row,
                    RevealAt = ((row - 1) * columns + column) / (columns * rows) * 0.65})
            end
        end
        function handle:SetRunning(value)
            if self.Destroyed then return self end
            self.Running = value == true
            refreshWorker()
            return self
        end
        function handle:SetVisible(value)
            if self.Destroyed then return self end
            self.Visible = value == true
            self.Frame.Visible = self.Visible
            refreshWorker()
            return self
        end
        function handle:Ripple(screenPosition, strength)
            if not visible(self) or typeof(screenPosition) ~= "Vector2" then return self end
            local origin, size = self.Frame.AbsolutePosition, self.Frame.AbsoluteSize
            local x, y = screenPosition.X - origin.X, screenPosition.Y - origin.Y
            if x < 0 or y < 0 or x > size.X or y > size.Y then return self end
            if #self.Ripples >= 6 then table.remove(self.Ripples, 1) end
            table.insert(self.Ripples, {X = x, Y = y, Time = os.clock(), Strength = math.clamp(number(strength, 0.65), 0, 1.4)})
            return self
        end
        function handle:Destroy()
            if self.Destroyed then return end
            self.Destroyed, self.Running = true, false
            handles[self] = nil
            table.clear(self.Ripples)
            self.Frame:Destroy()
            table.clear(self.Cells)
            refreshWorker()
        end
        handles[handle] = true
        render(handle, handle.Started)
        refreshWorker()
        return handle
    end

    function ctx.createWatermark(parent, rawOptions)
        local options = ctx.options(rawOptions)
        options.Mode = "watermark"
        return ctx.createAtmosphere(parent, options)
    end

    function ctx.digitalSlice(parent)
        if disposed or not ctx.alive() or not parent or not parent.Parent then return nil end
        local z = math.max(2, (parent.ZIndex or 1) + 8)
        local frame = ctx.new("Frame", {Name = "DigitalSlice", BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Active = false, ClipsDescendants = true, ZIndex = z}, parent)
        local handle = {Frame = frame, Destroyed = false}
        function handle:Destroy()
            if self.Destroyed then return end
            self.Destroyed = true
            slices[self] = nil
            self.Frame:Destroy()
        end
        slices[handle] = true
        for index, y in ipairs({0.23, 0.51, 0.76}) do
            local strip = ctx.new("Frame", {Name = "Slice", BorderSizePixel = 0, Active = false,
                Position = UDim2.fromScale(-0.55 + index * 0.12, y),
                Size = UDim2.new(0.32 + index * 0.09, 0, 0, index),
                BackgroundTransparency = 0.66 + index * 0.05, ZIndex = z}, frame)
            ctx.bind(strip, "BackgroundColor3", "Accent")
            ctx.new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.25, 0.15), NumberSequenceKeypoint.new(0.75, 0.15),
                NumberSequenceKeypoint.new(1, 1)})}, strip)
            ctx.tween(strip, {Position = UDim2.fromScale(1.05 + index * 0.10, y), BackgroundTransparency = 1}, 0.18)
        end
        ctx.delay(0.20, function() handle:Destroy() end)
        return handle
    end

    ctx.addCleanup(function()
        disposed = true
        if connection then connection:Disconnect(); connection = nil end
        local owned = {}
        for handle in pairs(handles) do table.insert(owned, handle) end
        for handle in pairs(slices) do table.insert(owned, handle) end
        for _, handle in ipairs(owned) do handle:Destroy() end
        table.clear(handles)
        table.clear(slices)
    end)
end
