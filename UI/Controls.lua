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
        height = math.max(44, math.ceil(height))
        if row.Size.Y.Offset ~= height then row.Size = UDim2.new(1, 0, 0, height) end
    end

    local function fitLabel(control, label, minimum, padding)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.TextWrapped = true
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 0, 0)
        local function resize()
            if control.Destroyed or not label.Parent then return end
            setHeight(control.Frame, math.max(minimum or 44, ctx.unscale(label.AbsoluteSize.Y) + (padding or 24)))
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
        properties.Font = mono
        properties.TextSize = properties.TextSize or 13
        properties.BackgroundTransparency = properties.BackgroundTransparency or 1
        properties.BorderSizePixel = 0
        properties.ClearTextOnFocus = properties.ClearTextOnFocus == true
        local box = new("TextBox", properties, parent)
        bind(box, "TextColor3", "Primary")
        bind(box, "PlaceholderColor3", "Primary")
        return box
    end

    function Tab:CreateButton(options)
        options = ctx.options(options)
        local control, row, label = ctx.row(self, options, 48)
        control.Type = "Button"
        label.Size = UDim2.new(1, -106, 0, 0)
        label.Position = UDim2.fromOffset(12, 13)
        fitLabel(control, label, 48, 26)
        local indicator = text(row, "EXEC >", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(76, 28), Font = mono, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        bind(indicator, "TextColor3", "Accent")
        local flash = border(row)
        local generation = 0
        ctx.connect(row.Activated, function()
            if not usable(control) then return end
            generation += 1
            local current = generation
            indicator.Text = "DONE >"
            tween(flash, {Transparency = 0.1}, 0.08)
            ctx.delay(0.3, function()
                if control.Destroyed or not ctx.alive() or generation ~= current then return end
                indicator.Text = "EXEC >"
                tween(flash, {Transparency = 1}, 0.22)
            end)
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
        local control, row, label = ctx.row(self, options, 48)
        control.Type = "Toggle"
        control.CurrentValue = options.CurrentValue == true
        control.value = control.CurrentValue
        label.Position = UDim2.fromOffset(12, 13)
        label.Size = UDim2.new(1, -92, 0, 0)
        fitLabel(control, label, 48, 26)
        local track = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(46, 22), BorderSizePixel = 0, BackgroundTransparency = 0.9,
        }, row)
        bind(track, "BackgroundColor3", "Primary")
        ctx.stroke(track, "Primary", 0.75)
        local activeTrack = new("Frame", {Size = UDim2.fromScale(1, 1), BorderSizePixel = 0}, track)
        bind(activeTrack, "BackgroundColor3", "Accent")
        local block = new("Frame", {
            Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0,
        }, track)
        bind(block, "BackgroundColor3", "Primary")
        local activeBlock = new("Frame", {Size = UDim2.fromScale(1, 1), BorderSizePixel = 0}, block)
        bind(activeBlock, "BackgroundColor3", "Accent")
        local function render(animate)
            local enabled = control.CurrentValue
            local duration = animate and 0.18 or 0
            tween(block, {Position = UDim2.fromOffset(enabled and 27 or 3, 3)}, duration)
            tween(activeBlock, {BackgroundTransparency = enabled and 0 or 1}, duration)
            tween(activeTrack, {BackgroundTransparency = enabled and 0.85 or 1}, duration)
            tween(block, {BackgroundTransparency = enabled and 0 or 0.5}, duration)
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
        local control, row, label = ctx.row(self, options, 80)
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
        label.Position = UDim2.fromOffset(12, 12)
        label.Size = UDim2.new(1, -24, 0, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.TextWrapped = true
        label.TextYAlignment = Enum.TextYAlignment.Top

        local line = new("Frame", {Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 38), BackgroundTransparency = 1}, row)
        local valueWidth = suffix == "" and 84 or 110
        local field = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
            Size = UDim2.fromOffset(valueWidth, 36), BorderSizePixel = 0, BackgroundTransparency = 0.55,
        }, line)
        bind(field, "BackgroundColor3", "Base")
        ctx.stroke(field, "Primary", 0.8)
        local focusedStroke = border(field)
        local bracketLeft = text(field, "[", {Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 10, 1, 0), Font = mono, TextSize = 13})
        local bracketRight = text(field, "]", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0, 10, 1, 0), Font = mono, TextSize = 13})
        bind(bracketLeft, "TextColor3", "Accent")
        bind(bracketRight, "TextColor3", "Accent")
        local valueBox = inputBox(field, {
            Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -36, 1, 0), Text = "",
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local hit = new("TextButton", {
            Size = UDim2.new(1, -(valueWidth + 14), 1, 0), Text = "", BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Active = true,
        }, line)
        local track = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0, BackgroundTransparency = 0.82,
        }, hit)
        bind(track, "BackgroundColor3", "Primary")
        local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, track)
        bind(fill, "BackgroundColor3", "Accent")
        local thumb = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(8, 14), BorderSizePixel = 0,
        }, track)
        bind(thumb, "BackgroundColor3", "Accent")
        local function formatValue()
            local numeric = numberText(control.CurrentValue)
            valueBox.Text = suffix == "" and numeric or numeric .. " " .. suffix
        end
        local function render(animate)
            local ratio = maximum > minimum and (control.CurrentValue - minimum) / (maximum - minimum) or 0
            tween(fill, {Size = UDim2.new(ratio, 0, 1, 0)}, animate and 0.08 or 0)
            tween(thumb, {Position = UDim2.fromScale(ratio, 0.5)}, animate and 0.08 or 0)
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
            local ratio = math.clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local value = snap(minimum + (maximum - minimum) * ratio)
            if value ~= nil and value ~= control.CurrentValue then set(value, false, false) end
        end
        ctx.drag(hit, move, function()
            if usable(control) then ctx.saveSoon() end
        end)
        ctx.connect(valueBox.Focused, function()
            if not usable(control) then valueBox:ReleaseFocus(); return end
            valueBox.Text = numberText(control.CurrentValue)
            tween(focusedStroke, {Transparency = 0.25}, 0.12)
        end)
        ctx.connect(valueBox.FocusLost, function()
            if control.Destroyed or not ctx.alive() then return end
            tween(focusedStroke, {Transparency = 1}, 0.14)
            if not usable(control) then return end
            set(valueBox.Text, false, true)
            formatValue()
        end)
        local function resize()
            if control.Destroyed then return end
            local titleHeight = math.max(18, ctx.unscale(label.AbsoluteSize.Y))
            line.Position = UDim2.fromOffset(12, 12 + titleHeight + 6)
            setHeight(row, 12 + titleHeight + 6 + 44 + 10)
        end
        ctx.connect(label:GetPropertyChangedSignal("AbsoluteSize"), resize)
        ctx.delay(0, resize)
        render(false)
        ctx.register(control, options)
        return control
    end

    function Tab:CreateInput(options)
        options = ctx.options(options)
        local control, row, label = ctx.row(self, options, 80)
        control.Type = "Input"
        local numeric = options.Numeric == true or options.NumbersOnly == true
        label.Position = UDim2.fromOffset(12, 12)
        label.Size = UDim2.new(1, -24, 0, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.TextWrapped = true
        label.TextYAlignment = Enum.TextYAlignment.Top
        local field = new("Frame", {
            Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 40),
            BorderSizePixel = 0, BackgroundTransparency = 0.45,
        }, row)
        bind(field, "BackgroundColor3", "Base")
        ctx.stroke(field, "Primary", 0.8)
        local focusedStroke = border(field)
        local box = inputBox(field, {
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
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
            tween(focusedStroke, {Transparency = 0.2}, 0.12)
        end)
        ctx.connect(box.FocusLost, function()
            if control.Destroyed or not ctx.alive() then return end
            tween(focusedStroke, {Transparency = 1}, 0.14)
            if not usable(control) then return end
            set(box.Text, false)
            if options.RemoveTextAfterFocusLost then box.Text = "" end
        end)
        local function resize()
            if control.Destroyed then return end
            local titleHeight = math.max(18, ctx.unscale(label.AbsoluteSize.Y))
            field.Position = UDim2.fromOffset(12, 12 + titleHeight + 8)
            setHeight(row, 12 + titleHeight + 8 + 40 + 12)
        end
        ctx.connect(label:GetPropertyChangedSignal("AbsoluteSize"), resize)
        ctx.delay(0, resize)
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
        local control, row, label = ctx.row(self, options, 44)
        control.Type = "Label"
        control.Color, control.IgnoreTheme, control.Icon = color, ignoreTheme == true, icon
        label.Position = UDim2.fromOffset(12, 12)
        label.Size = UDim2.new(1, -24, 0, 0)
        local iconImage = new("ImageLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(18, 18),
            Image = "", Visible = false, ScaleType = Enum.ScaleType.Fit,
        }, row)
        bind(iconImage, "ImageColor3", "Primary")
        local iconGlyph = text(row, ">", {
            Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(18, 22), Font = mono,
            TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
        })
        bind(iconGlyph, "TextColor3", "Accent")
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
            iconGlyph.Visible = id ~= nil and id ~= "" and asset == nil
            local offset = (asset ~= nil or iconGlyph.Visible) and 40 or 12
            label.Position = UDim2.fromOffset(offset, 12)
            label.Size = UDim2.new(1, -(offset + 12), 0, 0)
        end
        local resize = fitLabel(control, label, 44, 24)
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
        local control, row, title = ctx.row(self, options, 84)
        control.Type = "Paragraph"
        control.Title, control.Content = options.Name, tostring(options.Content or "")
        title.Position = UDim2.fromOffset(12, 12)
        title.Size = UDim2.new(1, -24, 0, 0)
        title.AutomaticSize = Enum.AutomaticSize.Y
        title.TextYAlignment = Enum.TextYAlignment.Top
        title.TextWrapped = true
        local body = text(row, control.Content, {
            Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 12,
            TextTransparency = 0.3, TextYAlignment = Enum.TextYAlignment.Top,
        })
        control.Body = body
        local function resize()
            if control.Destroyed then return end
            local titleHeight = title.Text ~= "" and math.max(18, ctx.unscale(title.AbsoluteSize.Y)) or 0
            local gap = titleHeight > 0 and body.Text ~= "" and 7 or 0
            body.Position = UDim2.fromOffset(12, 12 + titleHeight + gap)
            setHeight(row, 24 + titleHeight + gap + ctx.unscale(body.AbsoluteSize.Y))
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
        local control, row, label = ctx.row(self, options, 44)
        control.Type = "Divider"
        label.Visible = false
        local rule = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.new(1, -24, 0, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0,
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
