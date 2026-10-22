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
        ctx.wrapLabel(control, 48)
        label.Font = Enum.Font.GothamMedium
        -- Buttons read as buttons: outlined surface with the Matrix glyph block (or an arrow when Matrix is off).
        local outline = ctx.stroke(row, "Border", .9)
        if ctx.matrixEnabled() then
            local matrix = new("Frame", {Name = "ButtonMatrix", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0),
                Size = UDim2.fromOffset(24, 24), Active = false, ZIndex = label.ZIndex}, row)
            local decoration = ctx.createAtmosphere(matrix, {Mode = "button", Columns = 3, Rows = 2,
                GlyphSize = 8, ZIndex = label.ZIndex})
            ctx.connect(row.Destroying, function() decoration:Destroy() end)
        else
            ctx.vectorIcon(row, "arrow", {AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0),
                Size = UDim2.fromOffset(14, 14), Role = "Secondary", ZIndex = label.ZIndex})
        end
        ctx.connect(row.MouseEnter, function()
            if not control.Disabled then tween(outline, {Transparency = .8}, .12) end
        end)
        ctx.connect(row.MouseLeave, function() tween(outline, {Transparency = .9}, .12) end)
        bind(label, "TextColor3", "Primary")
        local neon = ctx.glow(row, 6, .62, nil, "Accent")
        ctx.connect(row.Activated, function()
            if not usable(control) then return end
            neon:Pulse()
            outline.Transparency = .6
            ctx.delay(.1, function() if outline.Parent then tween(outline, {Transparency = .9}, .2) end end)
            ctx.changed(control, nil, true)
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
        ctx.wrapLabel(control, 64)
        local track = new("Frame", {
            Name = "ToggleTrack", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(40, 22), BorderSizePixel = 0,
        }, row)
        -- The off track sits a step above the card with a hairline edge so it never disappears.
        local function trackColor(t) return control.CurrentValue and t.Accent or t.Hover end
        bind(track, "BackgroundColor3", trackColor)
        ctx.round(track, 11)
        local trackEdge = ctx.stroke(track, "Border", control.CurrentValue and 1 or .88)
        -- Neon bloom around the track while the switch is on.
        local neon = ctx.glow(track, 11, .7, nil, "Accent")
        local block = new("Frame", {
            Name = "ToggleThumb", AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 4, .5, 0),
            Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0,
        }, track)
        local function thumbColor(t) return control.CurrentValue and t.OnAccent or t.Secondary end
        bind(block, "BackgroundColor3", thumbColor)
        ctx.round(block, 8)
        local function render(animate)
            local enabled = control.CurrentValue
            bind(block, "BackgroundColor3", thumbColor, animate)
            local duration = animate and 0.18 or 0
            ctx.tween(block, {Position = UDim2.new(0, enabled and 21 or 4, .5, 0),
                Size = UDim2.fromOffset(enabled and 16 or 14, enabled and 16 or 14)}, duration, Enum.EasingStyle.Back)
            tween(track, {BackgroundColor3 = trackColor(ctx.theme())}, animate and 0.15 or 0)
            tween(trackEdge, {Transparency = enabled and 1 or .88}, animate and 0.15 or 0)
            neon:SetActive(enabled, animate)
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
        -- Label and exact value share the top line; a full-width track runs underneath.
        local valueWidth = 104
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.Position = UDim2.fromOffset(12, 8)
        label.Size = UDim2.new(1, -(valueWidth + 28), 0, 0)
        label.TextWrapped = true
        label.TextTruncate = Enum.TextTruncate.None
        label.TextYAlignment = Enum.TextYAlignment.Top
        local field = new("Frame", {
            Name = "ValueBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5),
            Size = UDim2.fromOffset(valueWidth, 22), BackgroundTransparency = 1, BorderSizePixel = 0,
        }, row)
        new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, field)
        new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, field)
        local focused = false
        local function fieldColor() return ctx.colors.Input end
        bind(field, "BackgroundColor3", fieldColor)
        ctx.round(field, 6)
        local focusedStroke = border(field)
        local valueBox = inputBox(field, {
            Name = "ExactValue", Font = mono, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
            Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 1,
        })
        valueBox.ClipsDescendants = false
        valueBox.TextTruncate = Enum.TextTruncate.None
        new("UISizeConstraint", {MinSize = Vector2.new(12, 0), MaxSize = Vector2.new(valueWidth - 8, math.huge)}, valueBox)
        if suffix ~= "" then
            local unit = text(field, suffix, {Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
                Font = ctx.font, TextSize = 12, LayoutOrder = 2})
            bind(unit, "TextColor3", "Secondary")
        end
        local hit = new("TextButton", {
            Name = "SliderDrag", Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 14), Text = "", BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Active = true,
        }, row)
        local function layout()
            if control.Destroyed or not label.Parent then return end
            local labelHeight = math.max(16, math.ceil(ctx.unscale(label.AbsoluteSize.Y)))
            hit.Position = UDim2.fromOffset(12, 8 + labelHeight + 4)
            local height = labelHeight + 34
            if row.Size.Y.Offset ~= height then row.Size = UDim2.new(1, 0, 0, height) end
        end
        ctx.connect(label:GetPropertyChangedSignal("AbsoluteSize"), layout)
        ctx.delay(0, layout)
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
        -- Neon: the filled span always glows softly; it and the thumb flare while hovered or dragged.
        local fillNeon = ctx.glow(fill, 2, .78, nil, "Accent")
        local thumbNeon = ctx.glow(thumb, 8, .68, nil, "Accent")
        local dragging, hovered = false, false
        local function sizeThumb()
            local size = dragging or hovered
            ctx.tween(thumb, {Size = UDim2.fromOffset(size and 16 or 12, size and 16 or 12)}, .15)
            thumbNeon:SetActive(size)
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
            if fillNeon.Active ~= (ratio > .01) then fillNeon:SetActive(ratio > .01, animate) end
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
            tween(field, {BackgroundTransparency = 0}, 0.12)
            tween(focusedStroke, {Transparency = 0.35}, 0.12)
        end)
        ctx.connect(valueBox.FocusLost, function()
            if control.Destroyed or not ctx.alive() then return end
            focused = false
            tween(field, {BackgroundTransparency = 1}, 0.14)
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
        ctx.wrapLabel(control, 88)
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
