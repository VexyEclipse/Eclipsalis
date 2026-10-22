-- Basic Eclipse controls. Installed into the shared, self-contained library build.
return function(Library, ctx)
    local Tab = ctx.Tab
    local new, text, bind, tween = ctx.new, ctx.text, ctx.bind, ctx.tween
    local mono = ctx.fontMono

    local function usable(control)
        return ctx.alive() and not control.Destroyed and not control.Disabled
            and control.Frame and control.Frame.Parent ~= nil
    end

    local function finite(value)
        return type(value) == "number" and value == value and math.abs(value) < math.huge
    end

    local function numberText(value)
        if value == 0 then return "0" end
        return string.format("%.12g", value)
    end

    local function setHeight(row, height)
        height = math.max(28, math.ceil(height))
        if row.Size.Y.Offset ~= height then row.Size = UDim2.new(1, 0, 0, height) end
    end

    local function fitLabel(control, label, minimum, padding)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.TextWrapped = true
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 0, 0)
        local function resize()
            if control.Destroyed or not label.Parent then return end
            setHeight(control.Frame, math.max(minimum or 28, ctx.unscale(label.AbsoluteSize.Y) + (padding or 20)))
        end
        ctx.connect(label:GetPropertyChangedSignal("AbsoluteSize"), resize)
        ctx.connect(label:GetPropertyChangedSignal("TextBounds"), resize)
        ctx.delay(0, resize)
        return resize
    end

    local function rename(control, value)
        if value == nil then return end
        control.Name = tostring(value)
        control.Options.Name = control.Name
        control:SetName(control.Name)
    end

    local function border(parent)
        local outline = ctx.stroke(parent, "Accent", 1)
        return outline
    end

    local function compactLabel(label, reservedWidth, height, y)
        label.AutomaticSize = Enum.AutomaticSize.None
        label.Position = UDim2.fromOffset(12, y or 0)
        label.Size = UDim2.new(1, -reservedWidth, 0, height or 34)
        label.TextSize = 14
        label.TextWrapped = false
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextYAlignment = Enum.TextYAlignment.Center
    end

    local function inputBox(parent, properties)
        properties = properties or {}
        properties.Font = properties.Font or ctx.font
        properties.TextSize = properties.TextSize or 13
        properties.BackgroundTransparency = properties.BackgroundTransparency or 1
        properties.BorderSizePixel = 0
        properties.TextWrapped = false
        properties.TextTruncate = Enum.TextTruncate.AtEnd
        properties.ClipsDescendants = true
        properties.ClearTextOnFocus = properties.ClearTextOnFocus == true
        local box = new("TextBox", properties, parent)
        bind(box, "TextColor3", "Primary")
        bind(box, "PlaceholderColor3", "Secondary")
        ctx.connect(box.Focused, function() box.TextTruncate = Enum.TextTruncate.None end)
        ctx.connect(box.FocusLost, function() box.TextTruncate = Enum.TextTruncate.AtEnd end)
        return box
    end

    function Tab:CreateButton(options)
        options = ctx.options(options)
        local control, row, label = ctx.row(self, options, 34)
        control.Type = "Button"
        control.SurfaceRole = "Input"
        bind(row, "BackgroundColor3", "Input")
        compactLabel(label, 56)
        local matrix = new("Frame", {Name = "ButtonMatrix", BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0),
            Size = UDim2.fromOffset(24, 24), Active = false, ZIndex = label.ZIndex}, row)
        local decoration = ctx.createAtmosphere(matrix, {Mode = "button", Columns = 3, Rows = 2,
            GlyphSize = 8, ZIndex = label.ZIndex})
        ctx.connect(row.Destroying, function() decoration:Destroy() end)
        bind(label, "TextColor3", "Primary")
        if control.Stroke then control.Stroke.Transparency = 1 end
        ctx.connect(row.Activated, function()
            if usable(control) then ctx.changed(control, nil, true) end
        end)
        function control.Set(first, second)
            if control.Destroyed or not ctx.alive() then return control end
            local value = first
            if first == control then value = second end
            rename(control, value)
            return control
        end
        control.Press = function()
            if usable(control) then ctx.changed(control, nil, true) end
            return control
        end
        ctx.register(control, options)
        return control
    end

    function Tab:CreateToggle(options)
        options = ctx.options(options)
        local control, row, label = ctx.row(self, options, 34)
        control.Type = "Toggle"
        control.CurrentValue = options.CurrentValue == true
        control.value = control.CurrentValue
        compactLabel(label, 76)
        local track = new("Frame", {
            Name = "ToggleTrack", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(40, 24), BorderSizePixel = 0,
        }, row)
        local function trackColor(t) return control.CurrentValue and t.Accent or ctx.colors.Input end
        bind(track, "BackgroundColor3", trackColor)
        ctx.round(track, 12)
        local block = new("Frame", {
            Name = "ToggleThumb", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0,
        }, track)
        local function thumbColor(t) return control.CurrentValue and t.OnAccent or t.Primary end
        bind(block, "BackgroundColor3", thumbColor)
        ctx.round(block, 8)
        local function render(animate)
            local enabled = control.CurrentValue
            bind(block, "BackgroundColor3", thumbColor, animate)
            local duration = animate and 0.15 or 0
            ctx.spring(block, {Position = UDim2.fromOffset(enabled and 20 or 4, 4)}, duration)
            tween(track, {BackgroundColor3 = trackColor(ctx.theme())}, animate and 0.15 or 0)
        end
        local function set(value, skipCallback)
            if control.Destroyed or not ctx.alive() then return control end
            control.CurrentValue = value == true
            control.value = control.CurrentValue
            render(true)
            ctx.changed(control, control.CurrentValue, skipCallback ~= true)
            return control
        end
        function control.Set(first, second, third)
            if first == control then return set(second, third) end
            return set(first, second)
        end
        ctx.connect(row.Activated, function()
            if usable(control) then set(not control.CurrentValue, false) end
        end)
        render(false)
        ctx.register(control, options)
        return control
    end

    function Tab:CreateSlider(options)
        options = ctx.options(options)
        local control, row, label = ctx.row(self, options, 34)
        control.Type = "Slider"
        local range = type(options.Range) == "table" and options.Range or {0, 100}
        local minimum = tonumber(range[1]) or 0
        local maximum = tonumber(range[2]) or 100
        if not finite(minimum) then minimum = 0 end
        if not finite(maximum) then maximum = 100 end
        if minimum > maximum then minimum, maximum = maximum, minimum end
        local increment = tonumber(options.Increment) or 1
        if not finite(increment) or increment <= 0 then increment = 1 end
        local suffix = tostring(options.Suffix or "")
        control.Range, control.Increment, control.Suffix = {minimum, maximum}, increment, suffix
        local function snap(value)
            value = tonumber(value)
            if not finite(value) then return nil end
            value = math.clamp(value, minimum, maximum)
            if value == minimum or value == maximum then return value end
            local stepped = minimum + math.floor((value - minimum) / increment + 0.5) * increment
            return math.clamp(tonumber(string.format("%.12g", stepped)), minimum, maximum)
        end
        control.CurrentValue = snap(options.CurrentValue) or minimum
        control.value = control.CurrentValue
        local valueWidth = 64
        compactLabel(label, valueWidth + 36, 16, 0)
        local field = new("Frame", {
            Name = "ValueBadge", ClipsDescendants = true, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0),
            Size = UDim2.fromOffset(valueWidth, 28), BorderSizePixel = 0,
        }, row)
        local focused = false
        local function fieldColor() return ctx.colors.Input end
        bind(field, "BackgroundColor3", fieldColor)
        ctx.round(field, 6)
        local focusedStroke = border(field)
        local valueBox = inputBox(field, {
            Name = "ExactValue", Font = mono, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 0, suffix == "" and 28 or 16), Text = "",
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        if suffix ~= "" then
            local unit = text(field, suffix, {Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 12),
                Font = ctx.font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center})
            bind(unit, "TextColor3", "Secondary")
        end
        local hit = new("TextButton", {
            Name = "SliderDrag", Position = UDim2.fromOffset(12, 16), Size = UDim2.new(1, -100, 0, 16), Text = "", BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Active = true,
        }, row)
        local track = new("Frame", {
            Name = "Track",
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 4), BorderSizePixel = 0,
        }, hit)
        bind(track, "BackgroundColor3", "Input")
        ctx.round(track, 2)
        local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, track)
        bind(fill, "BackgroundColor3", "Accent")
        ctx.round(fill, 2)
        local thumb = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
            Name = "SliderThumb", Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0,
        }, track)
        bind(thumb, "BackgroundColor3", "Primary")
        ctx.round(thumb, 8)
        local dragging, hovered = false, false
        local function sizeThumb()
            local size = dragging or hovered
            ctx.tween(thumb, {Size = UDim2.fromOffset(size and 16 or 12, size and 16 or 12)}, .15)
        end
        ctx.connect(hit.MouseEnter, function() hovered = true; sizeThumb() end)
        ctx.connect(hit.MouseLeave, function() hovered = false; sizeThumb() end)
        local function formatValue()
            local numeric = numberText(control.CurrentValue)
            valueBox.Text = numeric
        end
        local function render(animate)
            local ratio = maximum > minimum and (control.CurrentValue - minimum) / (maximum - minimum) or 0
            tween(fill, {Size = UDim2.new(ratio, 0, 1, 0)}, animate and 0.15 or 0)
            tween(thumb, {Position = UDim2.fromScale(ratio, 0.5)}, animate and 0.15 or 0)
            if not valueBox:IsFocused() then formatValue() end
        end
        local function set(value, skipCallback, animate)
            if control.Destroyed or not ctx.alive() then return control end
            local snapped = snap(value)
            if snapped == nil then formatValue(); return control end
            control.CurrentValue, control.value = snapped, snapped
            render(animate ~= false)
            ctx.changed(control, snapped, skipCallback ~= true)
            return control
        end
        function control.Set(first, second, third)
            if first == control then return set(second, third, true) end
            return set(first, second, true)
        end
        local function move(position)
            if not usable(control) or track.AbsoluteSize.X <= 0 then return end
            if not dragging then
                dragging = true
                sizeThumb()
            end
            local ratio = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local value = snap(minimum + (maximum - minimum) * ratio)
            if value ~= nil and value ~= control.CurrentValue then set(value, false, false) end
        end
        ctx.drag(hit, move, function()
            dragging = false
            if not control.Destroyed and ctx.alive() then sizeThumb() end
            if usable(control) then ctx.saveSoon() end
        end)
        ctx.connect(valueBox.Focused, function()
            if not usable(control) then valueBox:ReleaseFocus(); return end
            focused = true
            valueBox.Text = numberText(control.CurrentValue)
            tween(field, {BackgroundColor3 = fieldColor(ctx.theme())}, 0.12)
            tween(focusedStroke, {Transparency = 0.35}, 0.12)
        end)
        ctx.connect(valueBox.FocusLost, function()
            if control.Destroyed or not ctx.alive() then return end
            focused = false
            tween(field, {BackgroundColor3 = fieldColor(ctx.theme())}, 0.14)
            tween(focusedStroke, {Transparency = 1}, 0.14)
            if not usable(control) then return end
            set(valueBox.Text, false, true)
            formatValue()
        end)
        render(false)
        ctx.register(control, options)
        return control
    end

    function Tab:CreateInput(options)
        options = ctx.options(options)
        local control, row, label = ctx.row(self, options, 34)
        control.Type = "Input"
        local numeric = options.Numeric == true or options.NumbersOnly == true
        compactLabel(label, 100, 34)
        local field = new("Frame", {
            Name = "InputField", ClipsDescendants = true, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0),
            Size = UDim2.fromOffset(64, 28), BorderSizePixel = 0,
        }, row)
        local focused = false
        local function fieldColor() return ctx.colors.Input end
        bind(field, "BackgroundColor3", fieldColor)
        ctx.round(field, 6)
        local focusedStroke = border(field)
        local box = inputBox(field, {
            Font = numeric and mono or ctx.font, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0),
            Text = "", PlaceholderText = tostring(options.PlaceholderText or options.Placeholder or "Enter value..."),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = options.ClearOnFocus == true,
        })
        control.Input = box
        local function clean(value)
            local result = tostring(value == nil and "" or value)
            if not numeric then return result end
            local parsed = tonumber(result)
            if not finite(parsed) then return nil end
            return numberText(parsed)
        end
        control.CurrentValue = clean(options.CurrentValue) or ""
        control.value = control.CurrentValue
        box.Text = control.CurrentValue
        local function set(value, skipCallback)
            if control.Destroyed or not ctx.alive() then return control end
            local cleaned = clean(value)
            if cleaned == nil then box.Text = control.CurrentValue; return control end
            control.CurrentValue, control.value = cleaned, cleaned
            box.Text = cleaned
            ctx.changed(control, cleaned, skipCallback ~= true)
            return control
        end
        function control.Set(first, second, third)
            if first == control then return set(second, third) end
            return set(first, second)
        end
        ctx.connect(box.Focused, function()
            if not usable(control) then box:ReleaseFocus(); return end
            focused = true
            tween(field, {BackgroundColor3 = fieldColor(ctx.theme())}, 0.12)
            tween(focusedStroke, {Transparency = 0.32}, 0.12)
        end)
        ctx.connect(box.FocusLost, function()
            if control.Destroyed or not ctx.alive() then return end
            focused = false
            tween(field, {BackgroundColor3 = fieldColor(ctx.theme())}, 0.14)
            tween(focusedStroke, {Transparency = 1}, 0.14)
            if not usable(control) then return end
            set(box.Text, false)
            if options.RemoveTextAfterFocusLost then box.Text = "" end
        end)
        ctx.register(control, options)
        return control
    end

    function Tab:CreateLabel(value, icon, color, ignoreTheme)
        local options
        if type(value) == "table" then
            options = ctx.options(value)
            icon, color, ignoreTheme = options.Icon, options.Color, options.IgnoreTheme
            options.Name = options.Name or options.Text or "Label"
        else
            options = {Name = tostring(value or ""), Icon = icon, Color = color, IgnoreTheme = ignoreTheme}
        end
        local control, row, label = ctx.row(self, options, 34)
        control.Type = "Label"
        control.Color, control.IgnoreTheme, control.Icon = color, ignoreTheme == true, icon
        label.Position = UDim2.fromOffset(12, 8)
        label.Size = UDim2.new(1, -24, 0, 0)
        label.TextSize = 14
        local iconImage = new("ImageLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(16, 16),
            Image = "", Visible = false, ScaleType = Enum.ScaleType.Fit,
        }, row)
        bind(iconImage, "ImageColor3", "Primary")
        local iconGlyph, iconName
        local function labelColor(theme)
            if control.IgnoreTheme and typeof(control.Color) == "Color3" then return control.Color end
            return theme.Primary
        end
        bind(label, "TextColor3", labelColor)
        local function updateIcon()
            local id = control.Icon
            local asset = ctx.iconAsset and ctx.iconAsset(id) or nil
            if not asset then
                if type(id) == "number" then asset = "rbxassetid://" .. tostring(id)
                elseif type(id) == "string" and (id:match("^rbxasset") or id:match("^https?://")) then asset = id
                elseif type(id) == "string" and tonumber(id) then asset = "rbxassetid://" .. id end
            end
            iconImage.Visible = asset ~= nil
            iconImage.Image = asset or ""
            local showVector = id ~= nil and id ~= "" and asset == nil
            if showVector and iconName ~= tostring(id) then
                if iconGlyph then iconGlyph:Destroy() end
                iconName = tostring(id)
                iconGlyph = ctx.vectorIcon(row, iconName, {Position = UDim2.fromOffset(12, 8),
                    Size = UDim2.fromOffset(16, 16), Role = "Secondary"})
            end
            if iconGlyph then iconGlyph.Visible = showVector end
            local offset = (asset ~= nil or showVector) and 36 or 12
            control.LabelBaseX = offset
            label.Position = UDim2.fromOffset(offset, 8)
            label.Size = UDim2.new(1, -(offset + 12), 0, 0)
        end
        local resize = fitLabel(control, label, 34, 16)
        function control.Set(first, second, third, fourth, fifth)
            if control.Destroyed or not ctx.alive() then return control end
            local name, nextIcon, nextColor, nextIgnore
            if first == control then name, nextIcon, nextColor, nextIgnore = second, third, fourth, fifth
            else name, nextIcon, nextColor, nextIgnore = first, second, third, fourth end
            if type(name) == "table" then
                local updated = ctx.options(name)
                name, nextIcon, nextColor, nextIgnore = updated.Name or updated.Text, updated.Icon, updated.Color, updated.IgnoreTheme
            end
            rename(control, name)
            if nextIcon ~= nil then control.Icon = nextIcon end
            if nextColor ~= nil then control.Color = nextColor end
            if nextIgnore ~= nil then control.IgnoreTheme = nextIgnore == true end
            updateIcon()
            if ctx.theme then label.TextColor3 = labelColor(ctx.theme()) end
            resize()
            return control
        end
        updateIcon()
        ctx.register(control, options)
        return control
    end

    function Tab:CreateParagraph(options)
        options = ctx.options(options)
        options.Name = options.Title or options.Name or "Information"
        local control, row, title = ctx.row(self, options, 54)
        control.Type = "Paragraph"
        control.Title, control.Content = options.Name, tostring(options.Content or "")
        title.Position = UDim2.fromOffset(12, 8)
        title.Size = UDim2.new(1, -24, 0, 0)
        title.TextSize = 14
        title.AutomaticSize = Enum.AutomaticSize.Y
        title.TextYAlignment = Enum.TextYAlignment.Top
        title.TextWrapped = true
        local body = text(row, control.Content, {
            Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 14,
            TextTransparency = 0.3, TextYAlignment = Enum.TextYAlignment.Top,
        })
        control.Body = body
        local function resize()
            if control.Destroyed then return end
            local titleHeight = title.Text ~= "" and math.max(15, ctx.unscale(title.AbsoluteSize.Y)) or 0
            local gap = titleHeight > 0 and body.Text ~= "" and 4 or 0
            body.Position = UDim2.fromOffset(12, 8 + titleHeight + gap)
            setHeight(row, 16 + titleHeight + gap + ctx.unscale(body.AbsoluteSize.Y))
        end
        function control.Set(first, second)
            if control.Destroyed or not ctx.alive() then return control end
            local value = first
            if first == control then value = second end
            local updated = ctx.options(value)
            if updated.Title ~= nil or updated.Name ~= nil then
                control.Title = tostring(updated.Title or updated.Name)
                rename(control, control.Title)
            end
            if updated.Content ~= nil then control.Content = tostring(updated.Content); body.Text = control.Content end
            resize()
            return control
        end
        ctx.connect(title:GetPropertyChangedSignal("AbsoluteSize"), resize)
        ctx.connect(body:GetPropertyChangedSignal("AbsoluteSize"), resize)
        ctx.delay(0, resize)
        ctx.register(control, options)
        return control
    end

    function Tab:CreateDivider(value)
        local options = type(value) == "table" and ctx.options(value) or {Name = type(value) == "string" and value or ""}
        local control, row, label = ctx.row(self, options, 16)
        control.Type = "Divider"
        row.Size = UDim2.new(1, 0, 0, 16)
        row.BackgroundTransparency = 1
        if control.Stroke then control.Stroke.Transparency = 1 end
        label.Visible = false
        local rule = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.new(1, -24, 0, 1), BackgroundTransparency = 0.94, BorderSizePixel = 0,
        }, row)
        bind(rule, "BackgroundColor3", "Primary")
        function control.Set(first, second)
            if control.Destroyed or not ctx.alive() then return control end
            local visible = first
            if first == control then visible = second end
            control:SetVisible(visible ~= false)
            return control
        end
        ctx.register(control, options)
        return control
    end
end
