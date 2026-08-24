--[[
    LiquidGlass UI
    Независимая UI-библиотека для Roblox/Luau в стиле Apple Liquid Glass.

    API:
        local lib = loadstring(game:HttpGetAsync(URL))()
        local win = lib:Window("Liquid Glass", "v1.0")
        local tab = win:Tab("Главная")

        tab:Section("Основное")
        tab:Button("Кнопка", function() end)
        tab:Toggle("Тогл", false, function(v) end)
        tab:Slider("Слайдер", 0, 100, 50, function(v) end)
        tab:Dropdown("Выбор", {"A", "B"}, "A", function(v) end)
        tab:TextBox("Имя", "Введите...", function(v) end)
        tab:Keybind("Клавиша", Enum.KeyCode.RightShift, function(key) end)
        tab:ColorPicker("Цвет", Color3.fromRGB(110, 170, 255), function(c) end)
        tab:Label("Текст")
        tab:Paragraph("Заголовок", "Описание")

    Особенности:
        * стеклянные многослойные панели
        * мягкие блики/градиенты
        * TweenService-анимации
        * drag + minimize
        * notifications снизу справа
        * конфиги через writefile/readfile в executor-средах
        * без внешних Lua-зависимостей
]]

local LiquidGlass = {}

--// Сервисы
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--// Безопасные ссылки на executor-функции.
local function getGlobal(name)
    local ok, value = pcall(function()
        return getgenv and getgenv()[name]
    end)
    if ok and value ~= nil then
        return value
    end
    local ok2, value2 = pcall(function()
        return _G[name]
    end)
    return ok2 and value2 or nil
end

local gethuiFn = getGlobal("gethui") or getGlobal("get_hidden_ui")
local protectFn = getGlobal("protect_gui") or getGlobal("protectgui")
local writefileFn = getGlobal("writefile")
local readfileFn = getGlobal("readfile")
local isfileFn = getGlobal("isfile")
local makefolderFn = getGlobal("makefolder")
local isfolderFn = getGlobal("isfolder")

--// Палитра.
local Theme = {
    Background = Color3.fromRGB(7, 9, 13),
    Panel = Color3.fromRGB(18, 21, 28),
    Panel2 = Color3.fromRGB(24, 27, 35),
    Panel3 = Color3.fromRGB(32, 35, 45),
    White = Color3.fromRGB(245, 247, 252),
    Text = Color3.fromRGB(235, 238, 246),
    Muted = Color3.fromRGB(145, 151, 165),
    Accent = Color3.fromRGB(112, 169, 255),
    Accent2 = Color3.fromRGB(158, 116, 255),
    Good = Color3.fromRGB(92, 221, 153),
    Bad = Color3.fromRGB(255, 100, 112),
    Stroke = Color3.fromRGB(255, 255, 255),
}

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function tween(obj, info, props)
    if not obj or not obj.Parent then
        return nil
    end
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function fastTween(obj, props, duration, style, direction)
    return tween(
        obj,
        TweenInfo.new(
            duration or 0.22,
            style or Enum.EasingStyle.Quart,
            direction or Enum.EasingDirection.Out
        ),
        props
    )
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 14)
    c.Parent = parent
    return c
end

local function stroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Transparency = transparency == nil and 0.78 or transparency
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function gradient(parent, colors, rotations, transparency)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(colors)
    g.Rotation = rotations or 0
    if transparency then
        g.Transparency = transparency
    end
    g.Parent = parent
    return g
end

local function padding(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
    return p
end

local function list(parent, gap, horizontal)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, gap or 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    l.HorizontalAlignment = horizontal and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
    l.VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top
    l.Parent = parent
    return l
end

local function textLabel(parent, text, size, color, font)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = tostring(text or "")
    t.TextColor3 = color or Theme.Text
    t.TextSize = size or 14
    t.Font = font or Enum.Font.GothamMedium
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.Parent = parent
    return t
end

local function buttonBase(parent)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Text = ""
    b.BackgroundColor3 = Theme.Panel2
    b.BackgroundTransparency = 0.18
    b.BorderSizePixel = 0
    b.Parent = parent
    corner(b, 13)
    stroke(b, Theme.White, 0.90, 1)
    return b
end

local function makeGlass(parent, size, position, z)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = position
    f.BackgroundColor3 = Theme.Panel
    f.BackgroundTransparency = 0.20
    f.BorderSizePixel = 0
    f.ZIndex = z or 1
    f.Parent = parent
    corner(f, 22)
    stroke(f, Theme.White, 0.82, 1)

    -- Световой слой: имитирует мягкое отражение на стекле.
    local shine = Instance.new("Frame")
    shine.Name = "GlassShine"
    shine.BackgroundTransparency = 0.80
    shine.BackgroundColor3 = Theme.White
    shine.BorderSizePixel = 0
    shine.Size = UDim2.new(1, -2, 0, 58)
    shine.Position = UDim2.fromOffset(1, 1)
    shine.ZIndex = f.ZIndex + 1
    shine.Parent = f
    corner(shine, 21)
    gradient(shine, {
        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
    }, 90, NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.85),
        NumberSequenceKeypoint.new(0.5, 0.98),
        NumberSequenceKeypoint.new(1, 1),
    }))

    local edge = stroke(f, Theme.White, 0.92, 1)
    local edgeGradient = Instance.new("UIGradient")
    edgeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(0.25, Theme.Accent),
        ColorSequenceKeypoint.new(0.55, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(0.80, Theme.Accent2),
        ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
    })
    edgeGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.70),
        NumberSequenceKeypoint.new(0.50, 0.92),
        NumberSequenceKeypoint.new(1, 0.70),
    })
    edgeGradient.Parent = edge

    return f
end

local function setCanvas(scroll, layout, extra)
    task.defer(function()
        if scroll and scroll.Parent and layout then
            scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (extra or 12))
        end
    end)
end

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

local function formatNumber(v)
    if math.abs(v - math.floor(v)) < 0.000001 then
        return tostring(math.floor(v))
    end
    return string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
end

--// Сериализация значений для конфигов.
local function encodeValue(v)
    local t = typeof(v)
    if t == "Color3" then
        return {__type = "Color3", r = v.R, g = v.G, b = v.B}
    elseif t == "EnumItem" then
        return {__type = "EnumItem", enum = tostring(v.EnumType), name = v.Name}
    elseif t == "number" or t == "string" or t == "boolean" then
        return v
    elseif t == "table" then
        local out = {}
        for k, x in pairs(v) do
            out[k] = encodeValue(x)
        end
        return out
    end
    return tostring(v)
end

local function decodeValue(v)
    if type(v) ~= "table" then
        return v
    end
    if v.__type == "Color3" then
        return Color3.new(v.r or 0, v.g or 0, v.b or 0)
    elseif v.__type == "EnumItem" then
        local enumName = tostring(v.enum or ""):match("Enum%.(.+)")
        if enumName and Enum[enumName] and v.name and Enum[enumName][v.name] then
            return Enum[enumName][v.name]
        end
        return Enum.KeyCode.Unknown
    end
    local out = {}
    for k, x in pairs(v) do
        out[k] = decodeValue(x)
    end
    return out
end

--// Получаем CoreGui/gethui/PlayerGui.
local function getGuiParent()
    if gethuiFn then
        local ok, ui = pcall(gethuiFn)
        if ok and ui then
            return ui
        end
    end

    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        return core
    end

    return LocalPlayer and LocalPlayer:WaitForChild("PlayerGui") or game:GetService("Players").LocalPlayer.PlayerGui
end

local guiParent = getGuiParent()

--// Очищаем только предыдущую версию нашей библиотеки.
pcall(function()
    local old = guiParent:FindFirstChild("LiquidGlassUI")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LiquidGlassUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = guiParent

if protectFn then
    pcall(protectFn, ScreenGui)
end

LiquidGlass.ScreenGui = ScreenGui
LiquidGlass.Theme = Theme
LiquidGlass.Version = "2.0.0"

--// Контейнер уведомлений.
local NotificationHolder = Instance.new("Frame")
NotificationHolder.Name = "Notifications"
NotificationHolder.AnchorPoint = Vector2.new(1, 1)
NotificationHolder.Position = UDim2.new(1, -18, 1, -18)
NotificationHolder.Size = UDim2.fromOffset(340, 520)
NotificationHolder.BackgroundTransparency = 1
NotificationHolder.ZIndex = 10000
NotificationHolder.Parent = ScreenGui
local notifList = list(NotificationHolder, 10, false)
notifList.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifList.VerticalAlignment = Enum.VerticalAlignment.Bottom

local function notification(title, content, duration)
    duration = duration == nil and 4 or duration

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(320, 76)
    card.BackgroundColor3 = Theme.Panel
    card.BackgroundTransparency = 0.10
    card.BorderSizePixel = 0
    card.LayoutOrder = os.clock() * 1000
    card.ZIndex = 10001
    card.Parent = NotificationHolder
    corner(card, 18)
    local s = stroke(card, Theme.White, 0.82, 1)
    local sg = Instance.new("UIGradient")
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Theme.Accent2),
    })
    sg.Transparency = NumberSequence.new(0.78)
    sg.Rotation = 15
    sg.Parent = s

    local accent = Instance.new("Frame")
    accent.Size = UDim2.fromOffset(3, 44)
    accent.Position = UDim2.fromOffset(10, 16)
    accent.BackgroundColor3 = Theme.Accent
    accent.BorderSizePixel = 0
    accent.ZIndex = 10002
    accent.Parent = card
    corner(accent, 3)

    local titleLabel = textLabel(card, title or "Уведомление", 14, Theme.Text, Enum.Font.GothamBold)
    titleLabel.Position = UDim2.fromOffset(24, 12)
    titleLabel.Size = UDim2.new(1, -36, 0, 20)
    titleLabel.ZIndex = 10002

    local body = textLabel(card, content or "", 12, Theme.Muted, Enum.Font.Gotham)
    body.Position = UDim2.fromOffset(24, 35)
    body.Size = UDim2.new(1, -36, 0, 30)
    body.TextWrapped = true
    body.ZIndex = 10002

    card.Position = UDim2.new(1, 40, 0, 0)
    card.BackgroundTransparency = 1
    titleLabel.TextTransparency = 1
    body.TextTransparency = 1
    accent.BackgroundTransparency = 1

    fastTween(card, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.10}, 0.42, Enum.EasingStyle.Back)
    fastTween(titleLabel, {TextTransparency = 0}, 0.24)
    fastTween(body, {TextTransparency = 0}, 0.30)
    fastTween(accent, {BackgroundTransparency = 0}, 0.24)

    if duration and duration > 0 then
        task.delay(duration, function()
            if not card.Parent then return end
            fastTween(card, {
                Position = UDim2.new(1, 35, 0, 0),
                BackgroundTransparency = 1,
            }, 0.30, Enum.EasingStyle.Quart)
            fastTween(titleLabel, {TextTransparency = 1}, 0.18)
            fastTween(body, {TextTransparency = 1}, 0.18)
            task.delay(0.34, function()
                if card then card:Destroy() end
            end)
        end)
    end

    return card
end

LiquidGlass.Notify = notification
LiquidGlass.Notification = notification

--// Forward declarations.
local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

--// Событие с безопасным callback.
local function fireCallback(fn, ...)
    if typeof(fn) == "function" then
        task.spawn(function(...)
            pcall(fn, ...)
        end, ...)
    end
end

--// Базовый объект элемента.
local function elementObject(kind, name, root, value)
    local e = {
        Type = kind,
        Name = name,
        Root = root,
        Value = value,
        Changed = {},
    }

    function e:OnChanged(fn)
        if typeof(fn) == "function" then
            table.insert(self.Changed, fn)
        end
        return self
    end

    function e:_emit(v)
        for _, fn in ipairs(self.Changed) do
            fireCallback(fn, v)
        end
    end

    function e:SetValue(v, silent)
        self.Value = v
        if not silent then
            self:_emit(v)
        end
    end

    function e:Destroy()
        if self.Root then self.Root:Destroy() end
    end

    function e:SetVisible(v)
        if self.Root then self.Root.Visible = v ~= false end
    end

    return e
end

--// Section
function Section:_newRow(height)
    self.Count += 1
    local row = Instance.new("Frame")
    row.Name = "Row"
    row.Size = UDim2.new(1, 0, 0, height or 42)
    row.BackgroundTransparency = 1
    row.LayoutOrder = self.Count
    row.Parent = self.Content
    return row
end

function Section:Label(text)
    local row = self:_newRow(28)
    local lbl = textLabel(row, text, 13, Theme.Muted, Enum.Font.GothamMedium)
    lbl.Size = UDim2.new(1, -4, 1, 0)

    local e = elementObject("Label", text, row, text)
    function e:Edit(v)
        self.Value = tostring(v)
        lbl.Text = self.Value
    end
    return e
end

function Section:Paragraph(title, content)
    local h = math.max(68, 40 + math.ceil(#tostring(content or "") / 58) * 15)
    local row = self:_newRow(h)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3 = Theme.Panel2
    panel.BackgroundTransparency = 0.32
    panel.BorderSizePixel = 0
    panel.Parent = row
    corner(panel, 15)
    stroke(panel, Theme.White, 0.92, 1)
    padding(panel, 14, 14, 8, 8)

    local ttl = textLabel(panel, title, 13, Theme.Text, Enum.Font.GothamBold)
    ttl.Size = UDim2.new(1, 0, 0, 20)

    local body = textLabel(panel, content, 12, Theme.Muted, Enum.Font.Gotham)
    body.Position = UDim2.fromOffset(0, 23)
    body.Size = UDim2.new(1, 0, 1, -23)
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top

    local e = elementObject("Paragraph", title, row, content)
    function e:EditName(v)
        ttl.Text = tostring(v)
    end
    function e:EditContent(v)
        body.Text = tostring(v)
    end
    return e
end

function Section:Button(name, callback)
    local row = self:_newRow(44)
    local b = buttonBase(row)
    b.Size = UDim2.new(1, 0, 1, 0)

    local label = textLabel(b, name, 13, Theme.Text, Enum.Font.GothamMedium)
    label.Size = UDim2.new(1, -30, 1, 0)
    label.Position = UDim2.fromOffset(15, 0)

    local arrow = textLabel(b, "›", 22, Theme.Muted, Enum.Font.Gotham)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -12, 0.5, 0)
    arrow.Size = UDim2.fromOffset(16, 28)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local e = elementObject("Button", name, row, nil)
    function e:Fire(...)
        fireCallback(callback, ...)
    end

    b.MouseEnter:Connect(function()
        fastTween(b, {
            BackgroundColor3 = Theme.Panel3,
            BackgroundTransparency = 0.02,
            Size = UDim2.new(1, 2, 1, 0),
        }, 0.20, Enum.EasingStyle.Quart)
        fastTween(arrow, {TextColor3 = Theme.Accent}, 0.18)
    end)

    b.MouseLeave:Connect(function()
        fastTween(b, {
            BackgroundColor3 = Theme.Panel2,
            BackgroundTransparency = 0.18,
            Size = UDim2.new(1, 0, 1, 0),
        }, 0.24, Enum.EasingStyle.Quart)
        fastTween(arrow, {TextColor3 = Theme.Muted}, 0.18)
    end)

    b.MouseButton1Down:Connect(function()
        fastTween(b, {Size = UDim2.new(1, -2, 1, 0)}, 0.08, Enum.EasingStyle.Quad)
    end)

    b.MouseButton1Up:Connect(function()
        fastTween(b, {Size = UDim2.new(1, 2, 1, 0)}, 0.18, Enum.EasingStyle.Back)
    end)

    b.MouseButton1Click:Connect(function()
        e:Fire()
    end)

    return e
end

function Section:Toggle(name, default, callback)
    local value = default == true
    local row = self:_newRow(44)

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 1, 0)
    holder.BackgroundTransparency = 1
    holder.Parent = row

    local lbl = textLabel(holder, name, 13, Theme.Text, Enum.Font.GothamMedium)
    lbl.Size = UDim2.new(1, -68, 1, 0)
    lbl.Position = UDim2.fromOffset(12, 0)

    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(48, 28)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -10, 0.5, 0)
    track.BackgroundColor3 = rgb(62, 65, 74)
    track.BorderSizePixel = 0
    track.Parent = holder
    corner(track, 20)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(22, 22)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 15, 0.5, 0)
    knob.BackgroundColor3 = rgb(235, 237, 242)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 20)

    local e = elementObject("Toggle", name, row, value)

    local function render(fire)
        value = value == true
        e.Value = value
        if value then
            fastTween(track, {BackgroundColor3 = Theme.Accent}, 0.22, Enum.EasingStyle.Quart)
            fastTween(knob, {Position = UDim2.new(1, -15, 0.5, 0)}, 0.28, Enum.EasingStyle.Back)
        else
            fastTween(track, {BackgroundColor3 = rgb(62, 65, 74)}, 0.22, Enum.EasingStyle.Quart)
            fastTween(knob, {Position = UDim2.new(0, 15, 0.5, 0)}, 0.24, Enum.EasingStyle.Quart)
        end
        if fire then
            fireCallback(callback, value)
            e:_emit(value)
        end
    end

    function e:SetValue(v, silent)
        value = v == true
        render(not silent)
    end

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.Parent = holder
    hit.ZIndex = 5

    hit.MouseButton1Click:Connect(function()
        value = not value
        render(true)
    end)

    render(false)
    return e
end

function Section:Slider(name, min, max, default, callback)
    min, max = tonumber(min) or 0, tonumber(max) or 100
    if min > max then min, max = max, min end
    local value = clamp(tonumber(default) or min, min, max)

    local row = self:_newRow(60)

    local title = textLabel(row, name, 13, Theme.Text, Enum.Font.GothamMedium)
    title.Position = UDim2.fromOffset(12, 3)
    title.Size = UDim2.new(1, -90, 0, 22)

    local val = textLabel(row, formatNumber(value), 12, Theme.Muted, Enum.Font.GothamMedium)
    val.AnchorPoint = Vector2.new(1, 0)
    val.Position = UDim2.new(1, -10, 0, 3)
    val.Size = UDim2.fromOffset(70, 22)
    val.TextXAlignment = Enum.TextXAlignment.Right

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 7)
    bar.Position = UDim2.fromOffset(12, 38)
    bar.BackgroundColor3 = rgb(54, 57, 67)
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 8)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 8)
    gradient(fill, {
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Theme.Accent2),
    }, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Theme.White
    knob.BorderSizePixel = 0
    knob.Parent = bar
    corner(knob, 16)
    stroke(knob, Theme.Accent, 0.40, 1)

    local e = elementObject("Slider", name, row, value)
    e.Min, e.Max = min, max

    local dragging = false

    local function setFromX(x, fire)
        local pct = clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local nv = min + (max - min) * pct
        -- Для удобства сохраняем целые значения как целые.
        if math.abs(max - min) >= 10 then
            nv = math.floor(nv + 0.5)
        end
        value = nv
        e.Value = value

        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        val.Text = formatNumber(value)

        if fire then
            fireCallback(callback, value)
            e:_emit(value)
        end
    end

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.Parent = row
    hit.ZIndex = 5

    hit.MouseButton1Down:Connect(function()
        dragging = true
        setFromX(UserInputService:GetMouseLocation().X, true)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X, true)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    function e:SetValue(v, silent)
        value = clamp(tonumber(v) or min, min, max)
        local pct = (value - min) / math.max(max - min, 0.0001)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        val.Text = formatNumber(value)
        self.Value = value
        if not silent then
            fireCallback(callback, value)
            self:_emit(value)
        end
    end

    e:SetValue(value, true)
    return e
end

function Section:Dropdown(name, options, default, callback)
    options = type(options) == "table" and options or {}
    local value = default
    if value == nil then value = options[1] end

    local row = self:_newRow(46)
    local b = buttonBase(row)
    b.Size = UDim2.new(1, 0, 1, 0)

    local title = textLabel(b, name, 13, Theme.Text, Enum.Font.GothamMedium)
    title.Position = UDim2.fromOffset(12, 0)
    title.Size = UDim2.new(0.48, 0, 1, 0)

    local valueText = textLabel(b, tostring(value or "Выбрать"), 12, Theme.Muted, Enum.Font.GothamMedium)
    valueText.AnchorPoint = Vector2.new(1, 0.5)
    valueText.Position = UDim2.new(1, -30, 0.5, 0)
    valueText.Size = UDim2.new(0.45, 0, 0, 24)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    valueText.TextTruncate = Enum.TextTruncate.AtEnd

    local chevron = textLabel(b, "⌄", 18, Theme.Muted, Enum.Font.GothamMedium)
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -9, 0.5, -1)
    chevron.Size = UDim2.fromOffset(16, 22)
    chevron.TextXAlignment = Enum.TextXAlignment.Center

    local popup = Instance.new("Frame")
    popup.Visible = false
    popup.Size = UDim2.new(1, 0, 0, 0)
    popup.Position = UDim2.new(0, 0, 1, 6)
    popup.BackgroundColor3 = Theme.Panel
    popup.BackgroundTransparency = 0.06
    popup.BorderSizePixel = 0
    popup.ZIndex = 40
    popup.Parent = row
    corner(popup, 15)
    stroke(popup, Theme.White, 0.82, 1)
    padding(popup, 6, 6, 6, 6)

    local pList = list(popup, 4, false)
    local pButtons = {}

    local e = elementObject("Dropdown", name, row, value)
    e.Options = options

    local open = false

    local function rebuild()
        for _, child in ipairs(popup:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        pButtons = {}

        for i, option in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 34)
            item.BackgroundColor3 = Theme.Panel2
            item.BackgroundTransparency = 0.45
            item.BorderSizePixel = 0
            item.Text = tostring(option)
            item.TextColor3 = Theme.Text
            item.TextSize = 12
            item.Font = Enum.Font.GothamMedium
            item.AutoButtonColor = false
            item.LayoutOrder = i
            item.ZIndex = 41
            item.Parent = popup
            corner(item, 10)

            item.MouseEnter:Connect(function()
                fastTween(item, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.18}, 0.15)
            end)
            item.MouseLeave:Connect(function()
                fastTween(item, {BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.45}, 0.18)
            end)
            item.MouseButton1Click:Connect(function()
                value = option
                e.Value = value
                valueText.Text = tostring(value)
                fireCallback(callback, value)
                e:_emit(value)
                open = false
                fastTween(popup, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.20)
                fastTween(chevron, {Rotation = 0}, 0.20)
                task.delay(0.22, function()
                    if not open then popup.Visible = false end
                end)
            end)

            table.insert(pButtons, item)
        end

        popup.Size = UDim2.new(1, 0, 0, 6 + (#options * 38))
    end

    local function togglePopup()
        open = not open
        if open then
            rebuild()
            popup.Visible = true
            popup.Size = UDim2.new(1, 0, 0, 0)
            popup.BackgroundTransparency = 1
            fastTween(popup, {
                Size = UDim2.new(1, 0, 0, 6 + (#options * 38)),
                BackgroundTransparency = 0.06,
            }, 0.28, Enum.EasingStyle.Back)
            fastTween(chevron, {Rotation = 180, TextColor3 = Theme.Accent}, 0.22)
        else
            fastTween(popup, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.20)
            fastTween(chevron, {Rotation = 0, TextColor3 = Theme.Muted}, 0.20)
            task.delay(0.22, function()
                if not open then popup.Visible = false end
            end)
        end
    end

    b.MouseButton1Click:Connect(togglePopup)

    function e:SetValues(newOptions)
        options = type(newOptions) == "table" and newOptions or {}
        self.Options = options
        if open then rebuild() end
    end

    function e:SetValue(v, silent)
        value = v
        self.Value = v
        valueText.Text = tostring(v)
        if not silent then
            fireCallback(callback, v)
            self:_emit(v)
        end
    end

    return e
end

function Section:TextBox(name, placeholder, callback)
    local row = self:_newRow(48)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 1, 0)
    box.BackgroundColor3 = Theme.Panel2
    box.BackgroundTransparency = 0.20
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = placeholder or "Введите текст..."
    box.PlaceholderColor3 = Theme.Muted
    box.TextColor3 = Theme.Text
    box.TextSize = 12
    box.Font = Enum.Font.GothamMedium
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Parent = row
    corner(box, 14)
    stroke(box, Theme.White, 0.90, 1)
    padding(box, 13, 13, 0, 0)

    local floating = textLabel(row, name, 10, Theme.Muted, Enum.Font.GothamMedium)
    floating.Position = UDim2.fromOffset(14, 3)
    floating.Size = UDim2.new(1, -28, 0, 14)
    floating.ZIndex = 2

    local e = elementObject("TextBox", name, row, "")
    function e:SetValue(v, silent)
        box.Text = tostring(v or "")
        self.Value = box.Text
        if not silent then
            fireCallback(callback, box.Text)
            self:_emit(box.Text)
        end
    end

    box.Focused:Connect(function()
        fastTween(box, {BackgroundColor3 = Theme.Panel3, BackgroundTransparency = 0.02}, 0.18)
        fastTween(floating, {TextColor3 = Theme.Accent}, 0.18)
    end)
    box.FocusLost:Connect(function()
        fastTween(box, {BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.20}, 0.18)
        fastTween(floating, {TextColor3 = Theme.Muted}, 0.18)
        e.Value = box.Text
        fireCallback(callback, box.Text)
        e:_emit(box.Text)
    end)

    return e
end

function Section:Keybind(name, default, callback)
    default = default or Enum.KeyCode.RightShift
    local current = default
    local listening = false

    local row = self:_newRow(44)
    local lbl = textLabel(row, name, 13, Theme.Text, Enum.Font.GothamMedium)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.Size = UDim2.new(1, -100, 1, 0)

    local keyButton = buttonBase(row)
    keyButton.AnchorPoint = Vector2.new(1, 0.5)
    keyButton.Position = UDim2.new(1, -8, 0.5, 0)
    keyButton.Size = UDim2.fromOffset(82, 30)

    local keyText = textLabel(keyButton, current.Name, 11, Theme.Muted, Enum.Font.GothamBold)
    keyText.Size = UDim2.new(1, 0, 1, 0)
    keyText.TextXAlignment = Enum.TextXAlignment.Center

    local e = elementObject("Keybind", name, row, current)

    local function setKey(key)
        current = key
        e.Value = key
        keyText.Text = listening and "Нажми..." or key.Name
        if not listening then
            fireCallback(callback, key)
            e:_emit(key)
        end
    end

    keyButton.MouseButton1Click:Connect(function()
        listening = true
        keyText.Text = "Нажми..."
        fastTween(keyButton, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.12}, 0.18)
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if listening and not processed then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                setKey(input.KeyCode)
                fastTween(keyButton, {BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.18}, 0.18)
            end
        elseif not processed and input.KeyCode == current then
            fireCallback(callback, current)
            e:_emit(current)
        end
    end)

    function e:SetValue(v, silent)
        if typeof(v) == "EnumItem" then
            current = v
            self.Value = v
            keyText.Text = v.Name
            if not silent then
                fireCallback(callback, v)
                self:_emit(v)
            end
        end
    end

    return e
end

function Section:ColorPicker(name, default, callback)
    local current = typeof(default) == "Color3" and default or Theme.Accent
    local open = false

    local row = self:_newRow(48)
    local lbl = textLabel(row, name, 13, Theme.Text, Enum.Font.GothamMedium)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.Size = UDim2.new(1, -72, 1, 0)

    local swatch = Instance.new("TextButton")
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, -10, 0.5, 0)
    swatch.Size = UDim2.fromOffset(44, 28)
    swatch.Text = ""
    swatch.AutoButtonColor = false
    swatch.BackgroundColor3 = current
    swatch.BorderSizePixel = 0
    swatch.Parent = row
    corner(swatch, 12)
    stroke(swatch, Theme.White, 0.72, 1)

    local panel = Instance.new("Frame")
    panel.Visible = false
    panel.Position = UDim2.new(0, 0, 1, 6)
    panel.Size = UDim2.new(1, 0, 0, 0)
    panel.BackgroundColor3 = Theme.Panel
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.ZIndex = 50
    panel.Parent = row
    corner(panel, 16)
    stroke(panel, Theme.White, 0.82, 1)
    padding(panel, 10, 10, 10, 10)

    local palette = Instance.new("Frame")
    palette.Size = UDim2.new(1, 0, 0, 100)
    palette.BackgroundColor3 = current
    palette.BorderSizePixel = 0
    palette.Parent = panel
    corner(palette, 12)

    -- Белая/чёрная вертикаль + цветовой слой.
    local sv = Instance.new("Frame")
    sv.Size = UDim2.fromScale(1, 1)
    sv.BackgroundColor3 = Color3.new(1,1,1)
    sv.BorderSizePixel = 0
    sv.Parent = palette
    corner(sv, 12)
    gradient(sv, {
        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
    }, 0, NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 1),
    }))

    local dark = Instance.new("Frame")
    dark.Size = UDim2.fromScale(1, 1)
    dark.BackgroundColor3 = Color3.new(0,0,0)
    dark.BackgroundTransparency = 0
    dark.BorderSizePixel = 0
    dark.Parent = palette
    corner(dark, 12)
    gradient(dark, {
        ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
        ColorSequenceKeypoint.new(1, Color3.new(0,0,0)),
    }, 0, NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    }))

    local hueBar = Instance.new("Frame")
    hueBar.Size = UDim2.new(1, 0, 0, 12)
    hueBar.Position = UDim2.fromOffset(0, 106)
    hueBar.BorderSizePixel = 0
    hueBar.Parent = panel
    corner(hueBar, 7)
    gradient(hueBar, {
        ColorSequenceKeypoint.new(0, rgb(255, 0, 0)),
        ColorSequenceKeypoint.new(0.16, rgb(255, 0, 255)),
        ColorSequenceKeypoint.new(0.33, rgb(0, 0, 255)),
        ColorSequenceKeypoint.new(0.50, rgb(0, 255, 255)),
        ColorSequenceKeypoint.new(0.66, rgb(0, 255, 0)),
        ColorSequenceKeypoint.new(0.83, rgb(255, 255, 0)),
        ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
    }, 0)

    local hex = Instance.new("TextBox")
    hex.Size = UDim2.new(1, 0, 0, 30)
    hex.Position = UDim2.fromOffset(0, 126)
    hex.BackgroundColor3 = Theme.Panel2
    hex.BackgroundTransparency = 0.12
    hex.BorderSizePixel = 0
    hex.TextColor3 = Theme.Text
    hex.PlaceholderText = "#RRGGBB"
    hex.PlaceholderColor3 = Theme.Muted
    hex.TextSize = 12
    hex.Font = Enum.Font.GothamMedium
    hex.TextXAlignment = Enum.TextXAlignment.Center
    hex.ClearTextOnFocus = false
    hex.Parent = panel
    corner(hex, 10)

    local e = elementObject("ColorPicker", name, row, current)

    -- В HSV работаем без внешних библиотек.
    local h, s, v = current:ToHSV()

    local function render(c, fire)
        current = c
        h, s, v = current:ToHSV()
        swatch.BackgroundColor3 = current
        palette.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        hex.Text = string.format("#%02X%02X%02X",
            math.floor(current.R * 255 + 0.5),
            math.floor(current.G * 255 + 0.5),
            math.floor(current.B * 255 + 0.5)
        )
        e.Value = current
        if fire then
            fireCallback(callback, current)
            e:_emit(current)
        end
    end

    local function updateFromPoint(gui, input)
        local x = clamp((input.Position.X - gui.AbsolutePosition.X) / math.max(gui.AbsoluteSize.X, 1), 0, 1)
        local y = clamp((input.Position.Y - gui.AbsolutePosition.Y) / math.max(gui.AbsoluteSize.Y, 1), 0, 1)
        if gui == palette then
            s = x
            v = 1 - y
            render(Color3.fromHSV(h, s, v), true)
        elseif gui == hueBar then
            h = x
            render(Color3.fromHSV(h, s, v), true)
        end
    end

    local draggingPalette, draggingHue = false, false

    local function bindDrag(gui, mode)
        local hit = Instance.new("TextButton")
        hit.Size = UDim2.fromScale(1, 1)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.ZIndex = 60
        hit.Parent = gui
        hit.MouseButton1Down:Connect(function()
            if mode == "palette" then draggingPalette = true else draggingHue = true end
            updateFromPoint(gui, {Position = UserInputService:GetMouseLocation()})
        end)
    end

    bindDrag(palette, "palette")
    bindDrag(hueBar, "hue")

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if draggingPalette then
                updateFromPoint(palette, input)
            elseif draggingHue then
                updateFromPoint(hueBar, input)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingPalette = false
            draggingHue = false
        end
    end)

    hex.FocusLost:Connect(function()
        local str = hex.Text:gsub("#", "")
        if #str == 6 then
            local r = tonumber(str:sub(1,2), 16)
            local g = tonumber(str:sub(3,4), 16)
            local b = tonumber(str:sub(5,6), 16)
            if r and g and b then
                render(Color3.fromRGB(r,g,b), true)
            end
        end
    end)

    local function toggle()
        open = not open
        if open then
            panel.Visible = true
            panel.BackgroundTransparency = 1
            panel.Size = UDim2.new(1, 0, 0, 0)
            fastTween(panel, {
                Size = UDim2.new(1, 0, 0, 166),
                BackgroundTransparency = 0.05,
            }, 0.30, Enum.EasingStyle.Back)
        else
            fastTween(panel, {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
            }, 0.22)
            task.delay(0.24, function()
                if not open then panel.Visible = false end
            end)
        end
    end

    swatch.MouseButton1Click:Connect(toggle)

    function e:SetValue(c, silent)
        if typeof(c) == "Color3" then
            render(c, not silent)
        end
    end

    render(current, false)
    return e
end

--// Алиасы с более "линорией"-подобными именами.
Section.AddButton = Section.Button
Section.AddToggle = Section.Toggle
Section.AddSlider = Section.Slider
Section.AddDropdown = Section.Dropdown
Section.AddTextbox = Section.TextBox
Section.AddTextBox = Section.TextBox
Section.AddKeybind = Section.Keybind
Section.AddColorPicker = Section.ColorPicker
Section.AddLabel = Section.Label
Section.AddParagraph = Section.Paragraph

--// Tab
function Tab:Section(name)
    local s = setmetatable({
        Window = self.Window,
        Tab = self,
        Name = name or "Section",
        Count = 0,
    }, Section)

    s.Frame = Instance.new("Frame")
    s.Frame.Name = "Section_" .. tostring(name)
    s.Frame.Size = UDim2.new(1, 0, 0, 0)
    s.Frame.AutomaticSize = Enum.AutomaticSize.Y
    s.Frame.BackgroundColor3 = Theme.Panel
    s.Frame.BackgroundTransparency = 0.34
    s.Frame.BorderSizePixel = 0
    s.Frame.LayoutOrder = #self.Sections + 1
    s.Frame.Parent = self.Content
    corner(s.Frame, 18)
    stroke(s.Frame, Theme.White, 0.90, 1)
    padding(s.Frame, 10, 10, 10, 10)

    local header = textLabel(s.Frame, name or "Section", 12, Theme.Muted, Enum.Font.GothamBold)
    header.Size = UDim2.new(1, 0, 0, 22)
    header.LayoutOrder = 0
    header.Parent = s.Frame

    s.Content = Instance.new("Frame")
    s.Content.Name = "Content"
    s.Content.Size = UDim2.new(1, 0, 0, 0)
    s.Content.AutomaticSize = Enum.AutomaticSize.Y
    s.Content.BackgroundTransparency = 1
    s.Content.LayoutOrder = 1
    s.Content.Parent = s.Frame
    list(s.Content, 6, false)

    table.insert(self.Sections, s)
    return s
end

Tab.AddSection = Tab.Section

--// Прокси методов Tab -> первая секция.
function Tab:_defaultSection()
    if not self.DefaultSection then
        self.DefaultSection = self:Section("Основное")
    end
    return self.DefaultSection
end

for _, method in ipairs({
    "Label", "Paragraph", "Button", "Toggle", "Slider",
    "Dropdown", "TextBox", "Keybind", "ColorPicker"
}) do
    Tab[method] = function(self, ...)
        return self:_defaultSection()[method](self:_defaultSection(), ...)
    end
end

Tab.AddButton = Tab.Button
Tab.AddToggle = Tab.Toggle
Tab.AddSlider = Tab.Slider
Tab.AddDropdown = Tab.Dropdown
Tab.AddTextbox = Tab.TextBox
Tab.AddTextBox = Tab.TextBox
Tab.AddKeybind = Tab.Keybind
Tab.AddColorPicker = Tab.ColorPicker
Tab.AddLabel = Tab.Label
Tab.AddParagraph = Tab.Paragraph

--// Window
function Window:Tab(name)
    local tab = setmetatable({
        Window = self,
        Name = name or ("Tab " .. tostring(#self.Tabs + 1)),
        Sections = {},
        Active = false,
    }, Tab)

    tab.Button = nil -- создаётся через прокси ниже после metatable
    tab.Frame = Instance.new("Frame")
    tab.Frame.Name = "Tab_" .. tab.Name
    tab.Frame.Size = UDim2.fromScale(1, 1)
    tab.Frame.BackgroundTransparency = 1
    tab.Frame.Visible = false
    tab.Frame.Parent = self.Pages

    tab.Content = Instance.new("ScrollingFrame")
    tab.Content.Name = "Content"
    tab.Content.Size = UDim2.new(1, -18, 1, -18)
    tab.Content.Position = UDim2.fromOffset(9, 9)
    tab.Content.BackgroundTransparency = 1
    tab.Content.BorderSizePixel = 0
    tab.Content.ScrollBarThickness = 2
    tab.Content.ScrollBarImageColor3 = Theme.Accent
    tab.Content.CanvasSize = UDim2.new(0, 0, 0, 0)
    tab.Content.Parent = tab.Frame
    padding(tab.Content, 2, 2, 2, 2)
    local tabList = list(tab.Content, 10, false)
    tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

    tabList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        setCanvas(tab.Content, tabList, 10)
    end)

    local tabButton = Instance.new("TextButton")
    tabButton.Name = "TabButton"
    tabButton.Size = UDim2.new(1, 0, 0, 40)
    tabButton.BackgroundColor3 = Theme.Panel2
    tabButton.BackgroundTransparency = 0.42
    tabButton.BorderSizePixel = 0
    tabButton.Text = ""
    tabButton.AutoButtonColor = false
    tabButton.LayoutOrder = #self.Tabs + 1
    tabButton.Parent = self.Sidebar
    corner(tabButton, 13)

    local icon = Instance.new("Frame")
    icon.Size = UDim2.fromOffset(5, 20)
    icon.AnchorPoint = Vector2.new(0, 0.5)
    icon.Position = UDim2.new(0, 7, 0.5, 0)
    icon.BackgroundColor3 = Theme.Accent
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel = 0
    icon.Parent = tabButton
    corner(icon, 4)

    local tabLabel = textLabel(tabButton, tab.Name, 12, Theme.Muted, Enum.Font.GothamMedium)
    tabLabel.Position = UDim2.fromOffset(22, 0)
    tabLabel.Size = UDim2.new(1, -26, 1, 0)

    tab.Button = tabButton
    tab.Icon = icon
    tab.Label = tabLabel

    local function activate()
        for _, other in ipairs(self.Tabs) do
            other.Active = false
            other.Frame.Visible = false
            fastTween(other.Button, {
                BackgroundColor3 = Theme.Panel2,
                BackgroundTransparency = 0.42,
            }, 0.18)
            fastTween(other.Label, {TextColor3 = Theme.Muted}, 0.18)
            fastTween(other.Icon, {BackgroundTransparency = 1}, 0.18)
        end

        tab.Active = true
        tab.Frame.Visible = true
        fastTween(tab.Button, {
            BackgroundColor3 = Theme.Panel3,
            BackgroundTransparency = 0.12,
        }, 0.24, Enum.EasingStyle.Quart)
        fastTween(tab.Label, {TextColor3 = Theme.Text}, 0.22)
        fastTween(tab.Icon, {BackgroundTransparency = 0}, 0.22)

        -- Лёгкая "текучая" прокрутка страницы.
        tab.Frame.Position = UDim2.fromOffset(8, 0)
        fastTween(tab.Frame, {Position = UDim2.fromOffset(0, 0)}, 0.32, Enum.EasingStyle.Quart)
    end

    tabButton.MouseEnter:Connect(function()
        if not tab.Active then
            fastTween(tabButton, {BackgroundTransparency = 0.24}, 0.16)
            fastTween(tabLabel, {TextColor3 = Theme.Text}, 0.16)
        end
    end)

    tabButton.MouseLeave:Connect(function()
        if not tab.Active then
            fastTween(tabButton, {BackgroundTransparency = 0.42}, 0.16)
            fastTween(tabLabel, {TextColor3 = Theme.Muted}, 0.16)
        end
    end)

    tabButton.MouseButton1Click:Connect(activate)

    table.insert(self.Tabs, tab)

    if #self.Tabs == 1 then
        task.defer(activate)
    end

    return tab
end

Window.AddTab = Window.Tab

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:SetVisible(visible)
    visible = visible ~= false
    self.Visible = visible

    if visible then
        self.Root.Visible = true
        self.Root.BackgroundTransparency = 1
        self.Panel.Size = UDim2.fromOffset(self.BaseSize.X.Offset - 36, self.BaseSize.Y.Offset - 36)
        self.Panel.Position = UDim2.new(0.5, 0, 0.5, 20)
        self.Panel.AnchorPoint = Vector2.new(0.5, 0.5)
        fastTween(self.Root, {BackgroundTransparency = 1}, 0.20)
        fastTween(self.Panel, {
            Size = self.BaseSize,
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, 0.48, Enum.EasingStyle.Back)
    else
        fastTween(self.Panel, {
            Size = UDim2.fromOffset(self.BaseSize.X.Offset - 42, self.BaseSize.Y.Offset - 42),
            Position = UDim2.new(0.5, 0, 0.5, 18),
        }, 0.28, Enum.EasingStyle.Quart)
        task.delay(0.29, function()
            if not self.Visible then
                self.Root.Visible = false
            end
        end)
    end
end

function Window:Minimize()
    if self.Minimized then
        self.Minimized = false
        self.Body.Visible = true
        fastTween(self.Panel, {Size = self.BaseSize}, 0.38, Enum.EasingStyle.Back)
    else
        self.Minimized = true
        self.Body.Visible = false
        fastTween(self.Panel, {
            Size = UDim2.fromOffset(self.BaseSize.X.Offset, 68)
        }, 0.36, Enum.EasingStyle.Back)
    end
end

function Window:Destroy()
    if self.Root then
        self.Root:Destroy()
    end
end

--// Dragging окна.
local function enableDrag(win, handle)
    local dragging = false
    local dragStart
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Panel.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Panel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--// Конфиги.
function LiquidGlass:SaveConfig(name, data)
    if not writefileFn then
        return false, "writefile недоступен в этой среде"
    end

    local folder = "LiquidGlass"
    if makefolderFn and isfolderFn then
        pcall(function()
            if not isfolderFn(folder) then
                makefolderFn(folder)
            end
        end)
    end

    local path = folder .. "/" .. tostring(name) .. ".json"
    local payload = encodeValue(data or self._ConfigData or {})
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        return false, encoded
    end

    local success, err = pcall(writefileFn, path, encoded)
    if not success then
        return false, err
    end
    return true, path
end

function LiquidGlass:LoadConfig(name)
    if not readfileFn then
        return nil, "readfile недоступен в этой среде"
    end

    local folder = "LiquidGlass"
    local path = folder .. "/" .. tostring(name) .. ".json"
    if isfileFn then
        local okFile, exists = pcall(isfileFn, path)
        if okFile and not exists then
            return nil, "Конфиг не найден: " .. path
        end
    end

    local okRead, raw = pcall(readfileFn, path)
    if not okRead then
        return nil, raw
    end

    local okDecode, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        return nil, data
    end

    return decodeValue(data)
end

--// Удобная привязка элементов к конфигу.
function Window:Register(key, element)
    self.ConfigElements[key] = element
    self.ConfigDefaults[key] = element.Value
    return element
end

function Window:GetConfig()
    local data = {}
    for key, element in pairs(self.ConfigElements) do
        if element and element.Value ~= nil then
            data[key] = encodeValue(element.Value)
        end
    end
    return data
end

function Window:ApplyConfig(data)
    if type(data) ~= "table" then return end

    for key, encoded in pairs(data) do
        local element = self.ConfigElements[key]
        if element and element.SetValue then
            local value = decodeValue(encoded)
            pcall(function()
                element:SetValue(value, false)
            end)
        end
    end
end

function Window:SaveConfig(name)
    return LiquidGlass:SaveConfig(name, self:GetConfig())
end

function Window:LoadConfig(name)
    local data, err = LiquidGlass:LoadConfig(name)
    if not data then
        return false, err
    end
    self:ApplyConfig(data)
    return true
end

--// Создание окна.
function LiquidGlass:Window(title, version)
    local win = setmetatable({
        Title = title or "Liquid Glass",
        VersionText = version or "",
        Tabs = {},
        Visible = true,
        Minimized = false,
        ConfigElements = {},
        ConfigDefaults = {},
    }, Window)

    local root = Instance.new("Frame")
    root.Name = "WindowRoot"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Parent = ScreenGui
    win.Root = root

    local panel = makeGlass(
        root,
        UDim2.fromOffset(650, 455),
        UDim2.new(0.5, 0, 0.5, 0),
        10
    )
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    win.Panel = panel
    win.BaseSize = UDim2.fromOffset(650, 455)

    -- Тень/ореол из нескольких прозрачных слоёв.
    local shadow1 = Instance.new("Frame")
    shadow1.Size = UDim2.new(1, 28, 1, 28)
    shadow1.Position = UDim2.fromOffset(-14, -14)
    shadow1.BackgroundColor3 = Theme.Accent
    shadow1.BackgroundTransparency = 0.96
    shadow1.BorderSizePixel = 0
    shadow1.ZIndex = 8
    shadow1.Parent = root
    corner(shadow1, 32)

    local shadow2 = Instance.new("Frame")
    shadow2.Size = UDim2.new(1, 14, 1, 14)
    shadow2.Position = UDim2.fromOffset(-7, -7)
    shadow2.BackgroundColor3 = Theme.Accent2
    shadow2.BackgroundTransparency = 0.975
    shadow2.BorderSizePixel = 0
    shadow2.ZIndex = 9
    shadow2.Parent = root
    corner(shadow2, 27)

    panel.ZIndex = 10

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 64)
    header.BackgroundTransparency = 1
    header.BorderSizePixel = 0
    header.ZIndex = 20
    header.Parent = panel
    padding(header, 20, 12, 9, 8)

    local titleLabel = textLabel(header, win.Title, 17, Theme.White, Enum.Font.GothamBold)
    titleLabel.Size = UDim2.new(1, -170, 0, 25)
    titleLabel.Position = UDim2.fromOffset(0, 2)
    titleLabel.ZIndex = 21

    local versionLabel = textLabel(header, win.VersionText, 10, Theme.Muted, Enum.Font.GothamMedium)
    versionLabel.Size = UDim2.new(1, -170, 0, 18)
    versionLabel.Position = UDim2.fromOffset(0, 28)
    versionLabel.ZIndex = 21

    local controls = Instance.new("Frame")
    controls.AnchorPoint = Vector2.new(1, 0)
    controls.Position = UDim2.new(1, -10, 0, 10)
    controls.Size = UDim2.fromOffset(88, 34)
    controls.BackgroundTransparency = 1
    controls.ZIndex = 30
    controls.Parent = header
    list(controls, 6, true)

    local function control(text, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(38, 30)
        b.BackgroundColor3 = color or Theme.Panel2
        b.BackgroundTransparency = 0.25
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Theme.Muted
        b.TextSize = 14
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.ZIndex = 31
        b.Parent = controls
        corner(b, 11)
        stroke(b, Theme.White, 0.91, 1)
        return b
    end

    local minimize = control("—")
    local close = control("×", rgb(62, 37, 44))

    minimize.MouseEnter:Connect(function()
        fastTween(minimize, {BackgroundColor3 = Theme.Accent, TextColor3 = Theme.White}, 0.15)
    end)
    minimize.MouseLeave:Connect(function()
        fastTween(minimize, {BackgroundColor3 = Theme.Panel2, TextColor3 = Theme.Muted}, 0.15)
    end)
    minimize.MouseButton1Click:Connect(function()
        win:Minimize()
    end)

    close.MouseEnter:Connect(function()
        fastTween(close, {BackgroundColor3 = Theme.Bad, TextColor3 = Theme.White}, 0.15)
    end)
    close.MouseLeave:Connect(function()
        fastTween(close, {BackgroundColor3 = rgb(62, 37, 44), TextColor3 = Theme.Muted}, 0.15)
    end)
    close.MouseButton1Click:Connect(function()
        win:SetVisible(false)
    end)

    enableDrag(win, header)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, -20, 1, -76)
    body.Position = UDim2.fromOffset(10, 68)
    body.BackgroundTransparency = 1
    body.ZIndex = 15
    body.Parent = panel
    win.Body = body

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 146, 1, 0)
    sidebar.BackgroundColor3 = Theme.Panel2
    sidebar.BackgroundTransparency = 0.40
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 16
    sidebar.Parent = body
    corner(sidebar, 17)
    stroke(sidebar, Theme.White, 0.92, 1)
    padding(sidebar, 7, 7, 7, 7)
    list(sidebar, 6, false)
    win.Sidebar = sidebar

    local pages = Instance.new("Frame")
    pages.Name = "Pages"
    pages.Size = UDim2.new(1, -156, 1, 0)
    pages.Position = UDim2.fromOffset(156, 0)
    pages.BackgroundTransparency = 1
    pages.ZIndex = 17
    pages.ClipsDescendants = true
    pages.Parent = body
    win.Pages = pages

    -- Начальная анимация.
    root.BackgroundTransparency = 1
    panel.Size = UDim2.fromOffset(590, 395)
    panel.Position = UDim2.new(0.5, 0, 0.5, 18)

    task.defer(function()
        fastTween(panel, {
            Size = win.BaseSize,
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, 0.52, Enum.EasingStyle.Back)
    end)

    -- Переключение UI по правому Shift.
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            win:Toggle()
        end
    end)

    return win
end

LiquidGlass.CreateWindow = LiquidGlass.Window

--// Если blur доступен в Lighting, пользователь может включить его вручную через:
--// LiquidGlass:EnableBlur(8)
function LiquidGlass:EnableBlur(size)
    local Lighting = game:GetService("Lighting")
    local existing = Lighting:FindFirstChild("LiquidGlassBlur")
    if existing then existing:Destroy() end

    local blur = Instance.new("BlurEffect")
    blur.Name = "LiquidGlassBlur"
    blur.Size = clamp(tonumber(size) or 8, 0, 24)
    blur.Parent = Lighting
    self._Blur = blur
    return blur
end

function LiquidGlass:DisableBlur()
    if self._Blur then
        self._Blur:Destroy()
        self._Blur = nil
    end
end

return LiquidGlass
