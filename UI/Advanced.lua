-- Advanced Eclipse controls. Compiled into the standalone library by build_ui.py.
return function(Library, ctx)
    local function argument(handle, first, second, third)
        if first == handle then return second, third end
        return first, second
    end

    local function invoke(callback, ...)
        if type(callback) ~= "function" or not ctx.alive() then return end
        local ok = pcall(callback, ...)
        if not ok then warn("[Eclipse UI] Component callback failed.") end
    end

    local function active(control)
        return ctx.alive() and not control.Destroyed and not control.Disabled
            and control.Frame and control.Frame.Parent ~= nil
    end

    local function finite(value)
        return type(value) == "number" and value == value and math.abs(value) < math.huge
    end

    local function field(parent, properties)
        properties = properties or {}
        properties.ClearTextOnFocus = false
        properties.Font = properties.Font or ctx.font
        properties.TextSize = properties.TextSize or 13
        properties.BorderSizePixel = 0
        properties.TextWrapped = false
        properties.TextTruncate = Enum.TextTruncate.AtEnd
        properties.ClipsDescendants = true
        local box = ctx.new("TextBox", properties, parent)
        local focused = false
        ctx.round(box, 6)
        local focusBorder = ctx.stroke(box, "Primary", .88)
        ctx.bind(box, "BackgroundColor3", "Input")
        ctx.bind(box, "TextColor3", "Primary")
        ctx.bind(box, "PlaceholderColor3", "Secondary")
        ctx.connect(box.Focused, function()
            focused = true
            box.TextTruncate = Enum.TextTruncate.None
            ctx.tween(box, {BackgroundColor3 = ctx.colors.Input}, 0.14)
            ctx.tween(focusBorder, {Transparency = .45}, .14)
        end)
        ctx.connect(box.FocusLost, function()
            focused = false
            box.TextTruncate = Enum.TextTruncate.AtEnd
            ctx.tween(box, {BackgroundColor3 = ctx.colors.Input}, 0.14)
            ctx.tween(focusBorder, {Transparency = .88}, .14)
        end)
        return box
    end

    local function trigger(control, width)
        control.Frame.Size = UDim2.new(1, 0, 0, 34)
        control.Label.Size = UDim2.new(1, -(width + 36), 1, 0)
        control.Label.Position = UDim2.fromOffset(12, 0)
        control.Label.AutomaticSize = Enum.AutomaticSize.None
        control.Label.TextWrapped = false
        control.Label.TextTruncate = Enum.TextTruncate.AtEnd
        control.Label.TextYAlignment = Enum.TextYAlignment.Center
        control.Label.TextSize = 14
        local button = ctx.new("TextButton", {
            Name = "Control", AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0),
            Size = UDim2.fromOffset(width, 28), BackgroundTransparency = 0,
            AutoButtonColor = false, BorderSizePixel = 0, Font = ctx.font, TextSize = 13, Text = "",
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, control.Frame)
        ctx.round(button, 6)
        local badgeActive = false
        local outline = ctx.stroke(button, "Primary", .9)
        ctx.bind(button, "BackgroundColor3", "Input")
        ctx.bind(button, "TextColor3", "Primary")
        local function setActive(value, animate)
            badgeActive = value == true
            ctx.bind(outline, "Color", badgeActive and "Accent" or "Primary")
            ctx.tween(outline, {Transparency = badgeActive and .55 or .9}, animate == false and 0 or .14)
        end
        return button, nil, setActive
    end

    local function pulse() end -- No hover or click blooms on expanded controls.

    local function cleanOptions(values)
        local result, found = {}, {}
        if type(values) ~= "table" then return result end
        for _, value in ipairs(values) do
            value = tostring(value)
            if not found[value] then found[value] = true; table.insert(result, value) end
        end
        return result
    end

    function ctx.Tab:CreateDropdown(rawOptions)
        local options = ctx.options(rawOptions)
        local control = ctx.row(self, options, 34)
        control.Type = "Dropdown"
        control.Values = cleanOptions(options.Options)
        control.MultipleOptions = options.MultipleOptions == true
        local button, badgeGlow, setBadgeActive = trigger(control, 88)
        -- Separate siblings: text truncates before the arrow's reserved lane.
        local selectionLabel = ctx.text(button, "", {Name = "SelectedValue", Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -36, 1, 0), TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
            TextWrapped = false, ZIndex = button.ZIndex + 1})
        local chevron = ctx.vectorIcon(button, "chevron", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16),
        })
        local panel, closePanel, list, searchBox
        local rows, selected = {}, {}

        local function isOpen() return panel and panel.Parent ~= nil end
        local function close()
            if closePanel then closePanel() end
            panel, closePanel, list, searchBox = nil, nil, nil, nil
            rows = {}
            setBadgeActive(false, true)
            ctx.tween(chevron, {Rotation = 0}, 0.16)
        end

        local function sanitize(value)
            if type(value) ~= "table" then value = value ~= nil and {value} or {} end
            local available, seen, result = {}, {}, {}
            for _, name in ipairs(control.Values) do available[name] = true end
            for _, name in ipairs(value) do
                name = tostring(name)
                if type(options.OptionAliases) == "table" and options.OptionAliases[name] ~= nil then
                    name = tostring(options.OptionAliases[name])
                end
                if available[name] and not seen[name] then
                    seen[name] = true; table.insert(result, name)
                    if not control.MultipleOptions then break end
                end
            end
            return result
        end

        local function renderSelection()
            selected = {}
            for _, name in ipairs(control.CurrentOption) do selected[name] = true end
            local count = #control.CurrentOption
            local summary = count == 0 and tostring(options.Placeholder or "Select") or table.concat(control.CurrentOption, ", ")
            if count > 1 then summary = tostring(count) .. " selected" end
            selectionLabel.Text = summary
            for name, entry in pairs(rows) do
                entry.Marker.BackgroundTransparency = selected[name] and 0 or 1
                entry.Button.BackgroundTransparency = selected[name] and 0 or 1
                entry.Label.TextTransparency = selected[name] and 0 or 0.22
            end
        end

        local function set(value, silent)
            if control.Destroyed then return control end
            control.CurrentOption = sanitize(value)
            control.CurrentValue = control.CurrentOption
            control.value = control.CurrentOption
            renderSelection()
            ctx.changed(control, table.clone(control.CurrentOption), silent ~= true)
            return control
        end

        local function fillList()
            if not list then return end
            for _, entry in pairs(rows) do entry.Button:Destroy() end
            rows = {}
            local query = searchBox and string.lower(searchBox.Text) or ""
            for index, name in ipairs(control.Values) do
                local item = ctx.new("TextButton", {
                    Name = "Option", LayoutOrder = index, Size = UDim2.new(1, -4, 0, 34),
                    BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
                    Text = "", Visible = query == "" or string.find(string.lower(name), query, 1, true) ~= nil,
                    ZIndex = panel.ZIndex + 2,
                }, list)
                ctx.round(item, 6)
                ctx.bind(item, "BackgroundColor3", "Hover")
                local marker = ctx.new("Frame", {
                    Position = UDim2.new(1, -13, 0.5, -3), Size = UDim2.fromOffset(6, 6),
                    BorderSizePixel = 0, ZIndex = panel.ZIndex + 3,
                }, item)
                ctx.bind(marker, "BackgroundColor3", "Accent")
                ctx.round(marker, 3)
                local label = ctx.text(item, name, {
                    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -30, 1, 0),
                    TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = panel.ZIndex + 3,
                })
                rows[name] = {Button = item, Marker = marker, Label = label}
                ctx.connect(item.Activated, function(input)
                    if not active(control) then return end
                    pulse(item, badgeGlow, input)
                    if control.MultipleOptions then
                        local value = table.clone(control.CurrentOption)
                        local existing = table.find(value, name)
                        if existing then table.remove(value, existing) else table.insert(value, name) end
                        set(value)
                    else
                        set({name})
                        close()
                    end
                end)
            end
            renderSelection()
        end

        control.Set = function(first, second, third)
            local value, silent = argument(control, first, second, third)
            return set(value, silent)
        end
        control.Refresh = function(first, second)
            local values = argument(control, first, second)
            if control.Destroyed then return control end
            control.Values = cleanOptions(values)
            options.Options = control.Values
            local value = sanitize(control.CurrentOption)
            local changed = #value ~= #control.CurrentOption
            if not changed then
                for index, name in ipairs(value) do
                    if name ~= control.CurrentOption[index] then changed = true; break end
                end
            end
            control.CurrentOption = value
            control.CurrentValue = value
            control.value = value
            fillList()
            renderSelection()
            if changed then ctx.changed(control, table.clone(value), true) end
            return control
        end
        control.Add = function(first, second)
            local value = argument(control, first, second)
            if value == nil then return control end
            local values = table.clone(control.Values)
            if not table.find(values, tostring(value)) then table.insert(values, tostring(value)) end
            return control.Refresh(values)
        end
        control.Remove = function(first, second)
            local value = argument(control, first, second)
            local values = table.clone(control.Values)
            local index = table.find(values, tostring(value))
            if index then table.remove(values, index) end
            return control.Refresh(values)
        end
        ctx.connect(button.Activated, function(input)
            if not active(control) then return end
            if isOpen() then close(); return end
            pulse(button, badgeGlow, input)
            local height = math.min(268, 52 + math.max(1, #control.Values) * 36)
            panel, closePanel = ctx.popup(control, math.clamp(ctx.unscale(control.Frame.AbsoluteSize.X), 220, 280), height)
            setBadgeActive(true, true)
            ctx.tween(chevron, {Rotation = 180}, 0.16)
            local openedPanel = panel
            ctx.connect(openedPanel.Destroying, function()
                if panel == openedPanel then
                    panel, closePanel, list, searchBox = nil, nil, nil, nil
                    rows = {}
                    setBadgeActive(false, true)
                    ctx.tween(chevron, {Rotation = 0}, 0.16)
                end
            end)
            local caption = ctx.text(panel, control.Name, {Position = UDim2.fromOffset(14, 8),
                Size = UDim2.new(1, -58, 0, 26), TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = panel.ZIndex + 2})
            searchBox = field(panel, {Name = "Search", Text = "", PlaceholderText = "Filter options",
                Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -54, 0, 26), Visible = false,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = panel.ZIndex + 2})
            ctx.new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, searchBox)
            local searchToggle = ctx.new("TextButton", {Name = "SearchOptions", Text = "", AutoButtonColor = false,
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(26, 26),
                ZIndex = panel.ZIndex + 2}, panel)
            ctx.round(searchToggle, 7)
            ctx.bind(searchToggle, "BackgroundColor3", "Input")
            ctx.vectorIcon(searchToggle, "search", {Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(14, 14), ZIndex = panel.ZIndex + 3})
            ctx.connect(searchToggle.Activated, function()
                searchBox.Visible = not searchBox.Visible; caption.Visible = not searchBox.Visible
                if searchBox.Visible then searchBox:CaptureFocus() else searchBox.Text = ""; searchBox:ReleaseFocus() end
            end)
            list = ctx.new("ScrollingFrame", {
                Name = "Options", BackgroundTransparency = 1, BorderSizePixel = 0,
                Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 1, -52),
                ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
                ZIndex = panel.ZIndex + 1,
            }, panel)
            ctx.bind(list, "ScrollBarImageColor3", "Accent")
            ctx.new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, list)
            fillList()
            ctx.connect(searchBox:GetPropertyChangedSignal("Text"), function()
                if not isOpen() then return end
                local query = string.lower(searchBox.Text)
                for name, entry in pairs(rows) do
                    entry.Button.Visible = query == "" or string.find(string.lower(name), query, 1, true) ~= nil
                end
                list.CanvasPosition = Vector2.zero
            end)
        end)
        local originalDestroy = control.Destroy
        control.Destroy = function() close(); return originalDestroy(control) end
        local originalVisible, originalDisabled = control.SetVisible, control.SetDisabled
        control.SetVisible = function(first, second)
            local value = argument(control, first, second)
            if value == false then close() end
            return originalVisible(control, value)
        end
        control.SetDisabled = function(first, second)
            local value = argument(control, first, second)
            if value == true then close() end
            return originalDisabled(control, value)
        end
        control.CurrentOption = sanitize(options.CurrentOption or options.CurrentValue or {})
        control.CurrentValue = control.CurrentOption
        control.value = control.CurrentOption
        renderSelection()
        ctx.register(control, options)
        return control
    end

    local keyAliases = {RightCtrl = "RightControl", LeftCtrl = "LeftControl", ["R-SHIFT"] = "RightShift", ["L-SHIFT"] = "LeftShift"}
    local function keyName(value)
        if typeof(value) == "EnumItem" then value = value.Name end
        if value == nil or value == "" or value == "NONE" then return "None" end
        value = keyAliases[tostring(value)] or tostring(value)
        local ok, valid = pcall(function() return Enum.KeyCode[value] end)
        if ok and valid then return value end
        if value == "MouseButton1" or value == "MouseButton2" or value == "MouseButton3" then return value end
        return "None"
    end

    local function inputName(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name end
        local name = input.UserInputType.Name
        if name == "MouseButton1" or name == "MouseButton2" or name == "MouseButton3" then return name end
        return nil
    end

    local function enumKey(name)
        if name == "None" then return Enum.KeyCode.Unknown end
        if name == "MouseButton1" or name == "MouseButton2" or name == "MouseButton3" then return Enum.UserInputType[name] end
        local ok, value = pcall(function() return Enum.KeyCode[name] end)
        return ok and value or Enum.KeyCode.Unknown
    end

    function ctx.Tab:CreateKeybind(rawOptions)
        local options = ctx.options(rawOptions)
        local control = ctx.row(self, options, 34)
        control.Type = "Keybind"
        control.CurrentKeybind = keyName(options.CurrentKeybind or options.CurrentValue)
        control.HoldToInteract = options.HoldToInteract == true or options.Hold == true
        local threshold = tonumber(options.HoldThreshold)
        threshold = finite(threshold) and math.max(0, threshold) or (options.Hold == true and 0.2 or 0)
        local button, badgeGlow, setBadgeActive = trigger(control, 28)
        button.Font = ctx.fontMono
        button.TextXAlignment = Enum.TextXAlignment.Center
        local held, capturing, pressed, pressToken = false, false, false, 0
        local capturedActivation
        local owned = {}
        local function render()
            button.Text = capturing and "..." or string.upper(control.CurrentKeybind)
            button.TextTransparency = capturing and 0 or 0.10
            setBadgeActive(capturing or held, true)
        end
        local function release()
            pressed = false
            pressToken = pressToken + 1
            if held then held = false; invoke(options.Callback, false) end
            render()
        end
        local function stopCapture()
            capturing = false
            if ctx._keybindCapture == control then ctx._keybindCapture = nil end
            render()
        end
        control.Set = function(first, second, third)
            local value, skipChanged = argument(control, first, second, third)
            if control.Destroyed then return control end
            local previous = control.CurrentKeybind
            release()
            control.CurrentKeybind = keyName(value)
            control.CurrentValue = control.CurrentKeybind
            control.value = enumKey(control.CurrentKeybind)
            stopCapture()
            ctx.changed(control, control.CurrentKeybind, false)
            if previous ~= control.CurrentKeybind and skipChanged ~= true then invoke(options.OnChanged, control.value) end
            return control
        end
        ctx.connect(button.Activated, function(input)
            if not active(control) then return end
            -- A recorded mouse click can also activate this badge on release.
            -- Consume that activation so assigning MouseButton1 does not restart capture.
            if input and input == capturedActivation then capturedActivation = nil; return end
            pulse(button, badgeGlow, input)
            if capturing then stopCapture(); return end
            if ctx._keybindCapture and ctx._keybindCapture.CancelCapture then ctx._keybindCapture.CancelCapture() end
            release()
            capturing = true
            ctx._keybindCapture = control
            render()
        end)
        control.CancelCapture = stopCapture
        table.insert(owned, ctx.connect(ctx.UIS.InputBegan, function(input, processed)
            if not active(control) then return end
            if capturing then
                local name = inputName(input)
                if name == "MouseButton1" then capturedActivation = input end
                if name == "Escape" then stopCapture()
                elseif name == "Backspace" or name == "Delete" then control.Set("None")
                elseif name then control.Set(name) end
                if name then
                    -- Keep this input reserved until every global input listener has run.
                    ctx._keybindCapture = control
                    ctx.delay(0, function()
                        if ctx._keybindCapture == control and not capturing then ctx._keybindCapture = nil end
                    end)
                end
                return
            end
            if capturedActivation ~= input then capturedActivation = nil end
            if processed or ctx._keybindCapture or (ctx._modalOpen or 0) > 0 or ctx.UIS:GetFocusedTextBox() then return end
            if inputName(input) ~= control.CurrentKeybind or control.CurrentKeybind == "None" then return end
            if control.HoldToInteract then
                if pressed then return end
                pressed = true
                pressToken = pressToken + 1
                local token = pressToken
                if threshold <= 0 then held = true; render(); invoke(options.Callback, true)
                else
                    ctx.delay(threshold, function()
                        if active(control) and pressed and token == pressToken then held = true; render(); invoke(options.Callback, true) end
                    end)
                end
            else pulse(button, badgeGlow, input); invoke(options.Callback, enumKey(control.CurrentKeybind)) end
        end))
        table.insert(owned, ctx.connect(ctx.UIS.InputEnded, function(input)
            if pressed and inputName(input) == control.CurrentKeybind then release() end
        end))
        table.insert(owned, ctx.connect(ctx.UIS.WindowFocusReleased, release))
        local originalDisabled = control.SetDisabled
        control.SetDisabled = function(first, second)
            local value = argument(control, first, second)
            if value then release(); stopCapture() end
            return originalDisabled(control, value)
        end
        local originalDestroy = control.Destroy
        control.Destroy = function()
            release(); stopCapture()
            for _, connection in ipairs(owned) do if connection then connection:Disconnect() end end
            return originalDestroy(control)
        end
        control.CurrentValue = control.CurrentKeybind
        control.value = enumKey(control.CurrentKeybind)
        render()
        ctx.register(control, options)
        return control
    end

    local function hex(color)
        return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
    end

    local function toColor(value)
        if typeof(value) == "Color3" then return value end
        if type(value) == "string" then
            local digits = string.match(value, "^#?(%x%x%x%x%x%x)$")
            if digits then
                return Color3.fromRGB(tonumber(string.sub(digits, 1, 2), 16), tonumber(string.sub(digits, 3, 4), 16), tonumber(string.sub(digits, 5, 6), 16))
            end
        elseif type(value) == "table" then
            local r, g, b = tonumber(value.R or value.r), tonumber(value.G or value.g), tonumber(value.B or value.b)
            if finite(r) and finite(g) and finite(b) then
                if r > 1 or g > 1 or b > 1 then return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255)) end
                return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
            end
        end
        return nil
    end

    function ctx.Tab:CreateColorPicker(rawOptions)
        local options = ctx.options(rawOptions)
        local control = ctx.row(self, options, 34)
        control.Type = "ColorPicker"
        control.Color = toColor(options.Color or options.CurrentValue) or ctx.theme().Accent
        local button, badgeGlow, setBadgeActive = trigger(control, 96)
        -- Independent text and swatch lanes; parent padding must not shift the swatch.
        button.ClipsDescendants = true
        local hexLabel = ctx.text(button, "", {Name = "ColorValue", Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -36, 1, 0), Font = ctx.fontMono, TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, ZIndex = button.ZIndex + 1})
        local swatch = ctx.new("Frame", {
            Name = "ColorSwatch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, BackgroundColor3 = control.Color,
            ZIndex = button.ZIndex + 1,
        }, button)
        ctx.round(swatch, 3)
        local panel, closePanel, matrix, cursor, hueCursor, hexField
        local rgbFields = {}
        local h, s, v = control.Color:ToHSV()
        local function render()
            control.CurrentColor, control.CurrentValue = control.Color, control.Color
            control.value = control.Color
            hexLabel.Text = hex(control.Color)
            swatch.BackgroundColor3 = control.Color
            if matrix and matrix.Parent then
                matrix.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                cursor.Position = UDim2.fromScale(s, 1 - v)
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                hexField.Text = hex(control.Color)
                rgbFields[1].Text = tostring(math.floor(control.Color.R * 255 + 0.5))
                rgbFields[2].Text = tostring(math.floor(control.Color.G * 255 + 0.5))
                rgbFields[3].Text = tostring(math.floor(control.Color.B * 255 + 0.5))
            end
        end
        local function set(value, user)
            if control.Destroyed then return control end
            local color = toColor(value)
            if not color then render(); return control end
            local changed = color ~= control.Color
            control.Color = color
            h, s, v = color:ToHSV()
            render()
            if changed then ctx.changed(control, color, user == true) end
            return control
        end
        local function close()
            if closePanel then closePanel() end
            panel, closePanel, matrix, cursor, hueCursor, hexField = nil, nil, nil, nil, nil, nil
            rgbFields = {}
            setBadgeActive(false, true)
        end
        -- Legacy Rayfield changes the swatch without executing its feature callback.
        control.Set = function(first, second)
            return set(argument(control, first, second), false)
        end
        ctx.connect(button.Activated, function(input)
            if not active(control) then return end
            if panel and panel.Parent then close(); return end
            pulse(button, badgeGlow, input)
            panel, closePanel = ctx.popup(control, 268, 252)
            setBadgeActive(true, true)
            local openedPanel = panel
            ctx.connect(openedPanel.Destroying, function()
                if panel == openedPanel then
                    panel, closePanel, matrix, cursor, hueCursor, hexField = nil, nil, nil, nil, nil, nil
                    rgbFields = {}
                    setBadgeActive(false, true)
                end
            end)
            local z = panel.ZIndex + 1
            local matrixHeight = math.max(40, panel.Size.Y.Offset - 140)
            ctx.text(panel, "Color", {
                Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20),
                TextSize = 14, TextTransparency = 0.25, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z,
            })
            matrix = ctx.new("Frame", {
                Name = "SaturationValue", Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, matrixHeight),
                BorderSizePixel = 0, BackgroundColor3 = Color3.fromHSV(h, 1, 1), Active = true, ZIndex = z,
            }, panel)
            ctx.round(matrix, 4)
            local whiteLayer = ctx.new("Frame", {
                Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 1,
            }, matrix)
            ctx.round(whiteLayer, 4)
            ctx.new("UIGradient", {Transparency = NumberSequence.new(0, 1)}, whiteLayer)
            local blackLayer = ctx.new("Frame", {
                Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = z + 2,
            }, matrix)
            ctx.round(blackLayer, 4)
            ctx.new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, blackLayer)
            cursor = ctx.new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z + 3,
            }, matrix)
            ctx.stroke(cursor, "Primary", 0)
            ctx.round(cursor, 4)
            local matrixHitbox = ctx.new("TextButton", {
                Name = "TouchSurface", Size = UDim2.fromScale(1, 1), Text = "",
                BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = z + 4,
            }, matrix)
            local hue = ctx.new("Frame", {
                Name = "Hue", Position = UDim2.fromOffset(12, matrixHeight + 46), Size = UDim2.new(1, -24, 0, 10),
                BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Active = true, ZIndex = z,
            }, panel)
            ctx.round(hue, 4)
            local colors = {}
            for index = 0, 6 do table.insert(colors, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1))) end
            ctx.new("UIGradient", {Color = ColorSequence.new(colors)}, hue)
            local hueHitbox = ctx.new("TextButton", {
                Name = "TouchSurface", Position = UDim2.fromOffset(0, -9), Size = UDim2.new(1, 0, 1, 18),
                Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = z + 2,
            }, hue)
            hueCursor = ctx.new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 4, 1, 6),
                BorderSizePixel = 0, ZIndex = z + 1,
            }, hue)
            ctx.round(hueCursor, 2)
            ctx.bind(hueCursor, "BackgroundColor3", "Primary")
            ctx.stroke(hueCursor, "Base", 0)
            hexField = field(panel, {
                Name = "Hex", Font = ctx.fontMono, Text = "", Position = UDim2.fromOffset(12, matrixHeight + 90),
                Size = UDim2.new(0.37, -12, 0, 26), ZIndex = z,
            })
            ctx.text(panel, "HEX", {Position = UDim2.fromOffset(12, matrixHeight + 72), Size = UDim2.fromOffset(70, 16), Font = ctx.font, TextSize = 13, TextTransparency = 0.4, ZIndex = z})
            for index, name in ipairs({"R", "G", "B"}) do
                local x = 0.37 + (index - 1) * 0.21
                local box = field(panel, {Name = name, Font = ctx.fontMono, Text = "", Position = UDim2.new(x, 0, 0, matrixHeight + 90), Size = UDim2.new(0.21, -12, 0, 26), ZIndex = z})
                rgbFields[index] = box
                ctx.text(panel, name, {Position = UDim2.new(x, 0, 0, matrixHeight + 72), Size = UDim2.fromOffset(36, 16), Font = ctx.font, TextSize = 13, TextTransparency = 0.4, ZIndex = z})
                ctx.connect(box.FocusLost, function()
                    if not active(control) or not panel or not panel.Parent then return end
                    local value = tonumber(box.Text)
                    if not finite(value) then render(); return end
                    local channels = {control.Color.R * 255, control.Color.G * 255, control.Color.B * 255}
                    channels[index] = math.clamp(value, 0, 255)
                    set(Color3.fromRGB(channels[1], channels[2], channels[3]), true)
                end)
            end
            ctx.connect(hexField.FocusLost, function()
                if active(control) and panel and panel.Parent then set(hexField.Text, true) end
            end)
            ctx.drag(matrixHitbox, function(position)
                if not active(control) or not matrix or not matrix.Parent then return end
                local size, origin = matrix.AbsoluteSize, matrix.AbsolutePosition
                local saturation = math.clamp((position.X - origin.X) / math.max(1, size.X), 0, 1)
                local value = 1 - math.clamp((position.Y - origin.Y) / math.max(1, size.Y), 0, 1)
                local color = Color3.fromHSV(h, saturation, value)
                local changed = color ~= control.Color
                s, v, control.Color = saturation, value, color
                render()
                if changed then ctx.changed(control, color, true) end
            end)
            ctx.drag(hueHitbox, function(position)
                if not active(control) or not hue.Parent then return end
                h = math.clamp((position.X - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
                local color = Color3.fromHSV(h, s, v)
                local changed = color ~= control.Color
                control.Color = color
                render()
                if changed then ctx.changed(control, color, true) end
            end)
            render()
        end)
        local originalDestroy = control.Destroy
        control.Destroy = function() close(); return originalDestroy(control) end
        local originalVisible, originalDisabled = control.SetVisible, control.SetDisabled
        control.SetVisible = function(first, second)
            local value = argument(control, first, second)
            if value == false then close() end
            return originalVisible(control, value)
        end
        control.SetDisabled = function(first, second)
            local value = argument(control, first, second)
            if value == true then close() end
            return originalDisabled(control, value)
        end
        render()
        ctx.register(control, options)
        return control
    end

    local notificationStack, notificationCount = nil, 0
    local dialogStack = {}
    local dialogEscapeInput
    local function actionsFor(values)
        local result = {}
        if type(values) ~= "table" then return result end
        if #values > 0 then
            for _, value in ipairs(values) do table.insert(result, ctx.options(value)) end
        else
            local names = {}
            for name in pairs(values) do table.insert(names, name) end
            table.sort(names, function(a, b) return tostring(a) < tostring(b) end)
            for _, name in ipairs(names) do
                local value = values[name]
                if type(value) == "function" then value = {Name = tostring(name), Callback = value} end
                if type(value) == "table" then
                    value = ctx.options(value)
                    value.Name = value.Name or tostring(name)
                    table.insert(result, value)
                end
            end
        end
        return result
    end

    local function actionButton(parent, action, index, count, z, callback)
        local button = ctx.new("TextButton", {
            Name = "Action", LayoutOrder = index, Size = UDim2.new(1 / count, -6, 1, 0),
            BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamMedium, TextSize = 11,
            Text = tostring(action.Text or action.Name or action.Title or "Continue"), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = z,
        }, parent)
        ctx.round(button, 6)
        ctx.bind(button, "BackgroundColor3", "Input")
        ctx.bind(button, "TextColor3", "Primary")
        ctx.stroke(button, "Secondary", .94)
        ctx.connect(button.Activated, callback)
        return button
    end

    function Library:Notify(rawOptions)
        if not ctx.alive() then return nil end
        local options = ctx.options(rawOptions)
        local overlay = ctx.overlay()
        if not overlay then return nil end
        if not notificationStack or not notificationStack.Parent then
            notificationStack = ctx.new("Frame", {
                Name = "Notifications", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
                Size = UDim2.new(1, -32, 1, -32), BackgroundTransparency = 1, ZIndex = 150,
            }, overlay)
            ctx.new("UISizeConstraint", {MaxSize = Vector2.new(340, 100000)}, notificationStack)
            ctx.new("UIListLayout", {
                Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
                VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
            }, notificationStack)
        end
        notificationCount = notificationCount + 1
        local actions = actionsFor(options.Actions or options.Buttons)
        local content = tostring(options.Content or options.Description or "")
        local height = math.clamp(64 + math.ceil(#content / 43) * 16 + (#actions > 0 and 42 or 0), 94, 230)
        local toast = ctx.new("Frame", {
            Name = "Toast", LayoutOrder = notificationCount, Size = UDim2.new(1, 0, 0, height),
            BorderSizePixel = 0, BackgroundTransparency = 0.03, ClipsDescendants = true, ZIndex = 151,
        }, notificationStack)
        ctx.bind(toast, "BackgroundColor3", "Section")
        ctx.round(toast, 6)
        ctx.stroke(toast, "Primary", 0.92)
        local handle = {Frame = toast, Closed = false}
        local function close()
            if handle.Closed then return end
            handle.Closed = true
            if toast.Parent then
                ctx.tween(toast, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.16)
                ctx.delay(0.17, function() if toast.Parent then toast:Destroy() end end)
            end
        end
        handle.Close, handle.Dismiss, handle.Destroy = close, close, close
        local icon = options.Image or options.Icon
        local titleX = 14
        if type(icon) == "number" or (type(icon) == "string" and (string.match(icon, "^%d+$") or string.find(icon, "rbxasset", 1, true))) then
            local image = ctx.new("ImageLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(20, 20),
                Image = type(icon) == "number" and ("rbxassetid://" .. tostring(icon)) or (string.match(icon, "^%d+$") and "rbxassetid://" .. icon or icon),
                ZIndex = 152,
            }, toast)
            ctx.bind(image, "ImageColor3", "Accent")
            titleX = 44
        end
        ctx.text(toast, tostring(options.Title or "ECLIPSE"), {
            Position = UDim2.fromOffset(titleX, 10), Size = UDim2.new(1, -(titleX + 42), 0, 24),
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 152,
        })
        local dismiss = ctx.new("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
            Position = UDim2.new(1, -36, 0, 8), Size = UDim2.fromOffset(26, 26), ZIndex = 153,
        }, toast)
        ctx.round(dismiss, 4)
        ctx.vectorIcon(dismiss, "close", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 154})
        ctx.connect(dismiss.Activated, close)
        ctx.text(toast, content, {
            Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 1, -(#actions > 0 and 90 or 52)),
            TextSize = 14, TextTransparency = 0.25, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 152,
        })
        if #actions > 0 then
            local actionRow = ctx.new("Frame", {Position = UDim2.new(0, 14, 1, -52), Size = UDim2.new(1, -22, 0, 36), BackgroundTransparency = 1, ZIndex = 152}, toast)
            ctx.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, actionRow)
            for index, action in ipairs(actions) do
                actionButton(actionRow, action, index, #actions, 153, function()
                    if handle.Closed then return end
                    close()
                    invoke(action.Callback)
                end)
            end
        end
        local bar = ctx.new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, ZIndex = 153}, toast)
        ctx.bind(bar, "BackgroundColor3", "Accent")
        ctx.round(bar, 1)
        ctx.glow(bar, 1, 0.65):SetActive(true, false)
        local duration = tonumber(options.Duration)
        duration = finite(duration) and math.max(0.1, duration) or 6.5
        ctx.tween(bar, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear)
        ctx.delay(duration, close)
        return handle
    end

    function Library:CreateDialog(rawOptions)
        if not ctx.alive() then return nil end
        local options = ctx.options(rawOptions)
        local overlay = ctx.overlay()
        if not overlay then return nil end
        local actions = actionsFor(options.Buttons or options.Actions or options.Options)
        if #actions == 0 then actions = {{Name = "Dismiss"}} end
        local backdrop = ctx.new("TextButton", {
            Name = "DialogBackdrop", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Text = "",
            AutoButtonColor = false, BackgroundTransparency = 0.22, ZIndex = 240,
        }, overlay)
        ctx.bind(backdrop, "BackgroundColor3", "Base")
        local card = ctx.new("Frame", {
            Name = "Dialog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -36, 0, 278), BorderSizePixel = 0, ZIndex = 241, Active = true,
        }, overlay)
        ctx.new("UISizeConstraint", {MaxSize = Vector2.new(430, 278)}, card)
        ctx.bind(card, "BackgroundColor3", "Section")
        ctx.round(card, 6)
        ctx.stroke(card, "Border", .94)
        ctx._modalOpen = (ctx._modalOpen or 0) + 1
        if ctx._keybindCapture and ctx._keybindCapture.CancelCapture then ctx._keybindCapture.CancelCapture() end
        local handle, escapeConnection, sizeConnection = {Frame = card, Closed = false}, nil, nil
        table.insert(dialogStack, handle)
        local function removeDialog()
            local index = table.find(dialogStack, handle)
            if index then table.remove(dialogStack, index) end
        end
        local function fitDialog()
            if not card.Parent then return end
            local available = ctx.unscale(overlay.AbsoluteSize)
            local height = math.min(278, math.max(150, available.Y - 32))
            card.Size = UDim2.new(1, -36, 0, height)
        end
        fitDialog()
        sizeConnection = ctx.connect(overlay:GetPropertyChangedSignal("AbsoluteSize"), fitDialog)
        local function close()
            if handle.Closed then return end
            handle.Closed = true
            removeDialog()
            ctx._modalOpen = math.max(0, (ctx._modalOpen or 1) - 1)
            if escapeConnection then escapeConnection:Disconnect() end
            if sizeConnection then sizeConnection:Disconnect() end
            card:Destroy()
            backdrop:Destroy()
            invoke(options.OnClose)
        end
        handle.Close, handle.Dismiss, handle.Destroy = close, close, close
        local titleBar = ctx.new("Frame", {Position = UDim2.fromOffset(16, 22), Size = UDim2.fromOffset(2, 14), ZIndex = 242}, card)
        ctx.bind(titleBar, "BackgroundColor3", "Secondary")
        ctx.round(titleBar, 1)
        ctx.text(card, tostring(options.Title or "Eclipse"), {
            Position = UDim2.fromOffset(27, 15), Size = UDim2.new(1, -47, 0, 30),
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 242,
        })
        local line = ctx.new("Frame", {Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.8, ZIndex = 242}, card)
        ctx.bind(line, "BackgroundColor3", "Primary")
        local body = ctx.new("ScrollingFrame", {
            Position = UDim2.fromOffset(20, 66), Size = UDim2.new(1, -40, 1, -138),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 242,
        }, card)
        ctx.bind(body, "ScrollBarImageColor3", "Accent")
        local content = tostring(options.Content or options.Description or "")
        if options.Subtitle then content = tostring(options.Subtitle) .. "\n\n" .. content end
        if type(options.Boxes) == "table" then
            local boxes = {}
            for _, rawBox in ipairs(options.Boxes) do
                local box = ctx.options(rawBox)
                table.insert(boxes, tostring(box.Title or "") .. "\n" .. tostring(box.Description or box.Content or ""))
            end
            content = table.concat(boxes, "\n\n")
        end
        ctx.text(body, content, {
            Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12,
            TextTransparency = 0.20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 243,
        })
        local actionRow = ctx.new("ScrollingFrame", {
            Position = UDim2.new(0, 20, 1, -52), Size = UDim2.new(1, -34, 0, 36),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
            ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 242,
        }, card)
        ctx.bind(actionRow, "ScrollBarImageColor3", "Accent")
        ctx.new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, actionRow)
        for index, action in ipairs(actions) do
            local button = actionButton(actionRow, action, index, math.min(3, #actions), 243, function()
                if handle.Closed then return end
                close()
                invoke(action.Callback)
            end)
            button.Size = UDim2.new(1 / math.min(3, #actions), -6, 1, -2)
        end
        if options.Dismissable ~= false and options.Dismissible ~= false then
            ctx.connect(backdrop.Activated, function()
                close()
            end)
            escapeConnection = ctx.connect(ctx.UIS.InputBegan, function(input, processed)
                if not processed and dialogEscapeInput ~= input and dialogStack[#dialogStack] == handle
                    and input.KeyCode == Enum.KeyCode.Escape then
                    dialogEscapeInput = input
                    close()
                    ctx.delay(0, function() if dialogEscapeInput == input then dialogEscapeInput = nil end end)
                end
            end)
        end
        ctx.connect(backdrop.Destroying, function()
            if not handle.Closed then
                handle.Closed = true
                removeDialog()
                ctx._modalOpen = math.max(0, (ctx._modalOpen or 1) - 1)
                if escapeConnection then escapeConnection:Disconnect() end
                if sizeConnection then sizeConnection:Disconnect() end
                if card.Parent then card:Destroy() end
            end
        end)
        return handle
    end
    Library.Prompt = Library.CreateDialog
    Library.Popup = Library.CreateDialog
end
