local OxLib = {}
OxLib.Version = "1.0.0"
OxLib.Flags = {}

local Players = game:GetService("Players")
local UserInput = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local HttpSvc = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Theme = {
	Accent = Color3.fromRGB(255, 138, 40),
	Bg = Color3.fromRGB(255, 255, 255),
	BgSoft = Color3.fromRGB(244, 246, 250),
	BgSofter = Color3.fromRGB(250, 251, 253),
	Stroke = Color3.fromRGB(226, 229, 238),
	StrokeStrong = Color3.fromRGB(198, 204, 218),
	Text = Color3.fromRGB(28, 30, 38),
	TextSub = Color3.fromRGB(120, 126, 142),
	TextDim = Color3.fromRGB(150, 156, 172),
	Fill = Color3.fromRGB(240, 242, 247),
	White = Color3.fromRGB(255, 255, 255),
	Danger = Color3.fromRGB(255, 86, 94),
	GlassTrans = 0.42,
	GlowTrans = 0.55,
}
OxLib.Theme = Theme

local Connections = {}
local AccentRefs = {}
local FlagSetters = {}
local Unloaded = false
local NotifyHolder = nil
local NotifyCards = {}

local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Connections, c)
	return c
end

local function New(class, props, kids)
	local inst = Instance.new(class)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if kids then
		for _, kid in ipairs(kids) do
			kid.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Tween(inst, dur, props, style, dir)
	local info = TweenInfo.new(dur or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
	local tw = TweenSvc:Create(inst, info, props)
	tw:Play()
	return tw
end

local function Corner(radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function GlassSheen(frame)
	local base = frame.BackgroundColor3
	local g = New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(base:Lerp(Theme.White, 0.2), base:Lerp(Color3.fromRGB(225, 230, 242), 0.08)),
	})
	g.Parent = frame
	return g
end

local function Glassify(frame, opts)
	opts = opts or {}
	local radius = opts.Radius or 18
	local hasCorner = false
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("UICorner") then
			hasCorner = true
		end
	end
	if not hasCorner then
		Corner(radius).Parent = frame
	end
	if frame:FindFirstChildOfClass("UIStroke") == nil then
		New("UIStroke", {
			Color = opts.StrokeColor or Theme.Stroke,
			Thickness = opts.StrokeThick or 1,
			Transparency = opts.GlowTrans or 0.4,
		}).Parent = frame
	end
	GlassSheen(frame)
	if opts.Transparency then
		frame.BackgroundTransparency = opts.Transparency
	end
	return frame
end

local function HookHoverLift(frame, hoverColor, baseColor, opts)
	opts = opts or {}
	local sc = New("UIScale", { Scale = 1, Parent = frame })
	local st = frame:FindFirstChildOfClass("UIStroke")
	frame.MouseEnter:Connect(function()
		Tween(frame, 0.18, { BackgroundColor3 = hoverColor, BackgroundTransparency = opts.hoverTrans or 0.28 })
		Tween(sc, 0.22, { Scale = opts.scale or 1.045 }, Enum.EasingStyle.Back)
		if st then
			Tween(st, 0.2, { Transparency = 0.42, Color = opts.glow or Theme.White })
		end
	end)
	frame.MouseLeave:Connect(function()
		Tween(frame, 0.22, { BackgroundColor3 = baseColor, BackgroundTransparency = opts.baseTrans or 0.42 })
		Tween(sc, 0.26, { Scale = 1 })
		if st then
			Tween(st, 0.24, { Transparency = opts.glowTrans or Theme.GlowTrans, Color = opts.StrokeColor or Theme.White })
		end
	end)
end

local function RegAccent(inst, prop, mode, amount)
	table.insert(AccentRefs, { Inst = inst, Prop = prop, Mode = mode or "raw", Amount = amount or 0.1 })
end

local function UnregAccent(inst)
	for i = #AccentRefs, 1, -1 do
		if AccentRefs[i].Inst == inst then
			table.remove(AccentRefs, i)
		end
	end
end

function OxLib:SetAccent(color)
	Theme.Accent = color
	for _, ref in ipairs(AccentRefs) do
		local inst = ref.Inst
		if inst and inst.Parent then
			if ref.Mode == "soft" then
				inst[ref.Prop] = Theme.White:Lerp(color, ref.Amount)
			else
				inst[ref.Prop] = color
			end
		end
	end
end

local Gui = New("ScreenGui", {
	Name = "OxAlphaLibrary",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder = 9999,
})

local mounted = false
pcall(function()
	local hookUi = gethui and gethui()
	Gui.Parent = hookUi or game:GetService("CoreGui")
	mounted = true
end)
if not mounted or not Gui.Parent then
	Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

pcall(function()
	local protector = protectgui or (syn and syn.protect_gui)
	if protector then
		protector(Gui)
	end
end)

local function TrimNumber(n)
	local s = tostring(n)
	if string.find(s, ".", 1, true) then
		s = s:gsub("0+$", "")
		s = s:gsub("%.$", "")
	end
	return s
end

local function SnapValue(v, min, max, step, precision)
	v = math.clamp(v, min, max)
	if step and step > 0 then
		local inv = 1 / step
		v = math.floor(v * inv + 0.5) / inv
	elseif precision and precision > 0 then
		local mult = 10 ^ precision
		v = math.floor(v * mult + 0.5) / mult
	else
		v = math.floor(v + 0.5)
	end
	v = tonumber(string.format("%.6f", v))
	return math.clamp(v, min, max)
end

local Icons = {}

function Icons.Draw(name, parent, sizePx, color)
	sizePx = sizePx or 18
	color = color or Theme.TextDim
	local holder = New("Frame", {
		Name = "Icon_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(sizePx, sizePx),
		Parent = parent,
	})
	local u = sizePx / 24

	local function part(x, y, w, h, opts)
		opts = opts or {}
		local fr = New("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = opts.stroke and 1 or 0,
			Position = UDim2.fromOffset(x * u, y * u),
			Size = UDim2.fromOffset(w * u, h * u),
			Rotation = opts.rot or 0,
			Parent = holder,
		})
		local rad = opts.radius
		if rad == nil then
			rad = math.min(w, h) * u / 2
		end
		Corner(rad).Parent = fr
		if opts.stroke then
			New("UIStroke", { Color = color, Thickness = opts.thick or 1.5 }).Parent = fr
		end
		return fr
	end

	if name == "grid" then
		part(4, 4, 6.5, 6.5, { radius = 2 })
		part(13.5, 4, 6.5, 6.5, { radius = 2 })
		part(4, 13.5, 6.5, 6.5, { radius = 2 })
		part(13.5, 13.5, 6.5, 6.5, { radius = 2 })
	elseif name == "user" then
		part(8, 3.5, 8, 8, { stroke = true, thick = 1.6 })
		part(5.5, 14.5, 13, 6.5, { radius = 3.2 })
	elseif name == "target" then
		part(5, 5, 14, 14, { stroke = true, thick = 1.6 })
		part(10.75, 10.75, 2.5, 2.5)
		part(11, 1, 2, 3, { radius = 1 })
		part(11, 20, 2, 3, { radius = 1 })
		part(1, 11, 3, 2, { radius = 1 })
		part(20, 11, 3, 2, { radius = 1 })
	elseif name == "eye" then
		part(3, 8, 18, 8, { stroke = true, thick = 1.6, radius = 4 })
		part(10, 10, 4, 4)
	elseif name == "sliders" then
		part(3, 6.4, 18, 2.4, { radius = 1.2 })
		part(13.5, 4.6, 6, 6)
		part(3, 15.2, 18, 2.4, { radius = 1.2 })
		part(4.5, 13.4, 6, 6)
	elseif name == "spark" then
		part(6.5, 6.5, 11, 11, { stroke = true, thick = 1.6, radius = 2.5, rot = 45 })
		part(15, 2.5, 5.5, 5.5, { radius = 1.6, rot = 45 })
	elseif name == "cloud" then
		part(4.5, 9.5, 8.5, 8.5)
		part(9, 6.5, 9.5, 9.5)
		part(12.5, 9.5, 7.5, 7.5)
		part(6, 11, 13, 6, { radius = 3 })
	elseif name == "link" then
		part(3.5, 9, 17, 6, { stroke = true, thick = 1.6, radius = 3 })
		part(9.5, 9, 5, 6)
	elseif name == "search" then
		part(4.5, 4.5, 11.5, 11.5, { stroke = true, thick = 1.6 })
		part(14.6, 14.6, 6.5, 2.4, { radius = 1.2, rot = 45 })
	elseif name == "bell" then
		part(6, 4.5, 12, 13, { stroke = true, thick = 1.6, radius = 6 })
		part(10.4, 1.8, 3.2, 3.2)
		part(9.9, 19.4, 4.2, 2.8, { radius = 1.4 })
	elseif name == "check" then
		part(4, 11.5, 6.5, 2.4, { radius = 1.2, rot = 45 })
		part(8, 9, 10, 2.4, { radius = 1.2, rot = -45 })
	elseif name == "bolt" then
		part(9, 2.5, 5.5, 5.5, { radius = 1.4, rot = 45 })
		part(9.5, 9, 5, 12, { radius = 2.2 })
		part(7, 17.5, 9.5, 4.5, { radius = 2 })
	end

	return holder
end

function Icons.Recolor(holder, color)
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("Frame") then
			d.BackgroundColor3 = color
		elseif d:IsA("UIStroke") then
			d.Color = color
		end
	end
end

local function Chevron(parent, sizePx, color)
	sizePx = sizePx or 12
	local holder = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(sizePx, sizePx),
		Parent = parent,
	})
	local th = math.max(1.6, sizePx / 7)
	local len = sizePx * 0.48
	local leftBar = New("Frame", {
		BackgroundColor3 = color,
		Position = UDim2.new(0, sizePx * 0.14, 0, sizePx * 0.32),
		Size = UDim2.fromOffset(len, th),
		Rotation = 45,
		Parent = holder,
	})
	Corner(th).Parent = leftBar
	local rightBar = New("Frame", {
		BackgroundColor3 = color,
		Position = UDim2.new(0, sizePx * 0.4, 0, sizePx * 0.32),
		Size = UDim2.fromOffset(len, th),
		Rotation = -45,
		Parent = holder,
	})
	Corner(th).Parent = rightBar
	return holder
end

local function PlayRipple(button, inputObject, color)
	local absPos = button.AbsolutePosition
	local absSize = button.AbsoluteSize
	local cx = math.clamp(inputObject.Position.X - absPos.X, 0, absSize.X)
	local cy = math.clamp(inputObject.Position.Y - absPos.Y, 0, absSize.Y)
	local d = math.max(absSize.X, absSize.Y) * 2.3
	local circle = New("Frame", {
		BackgroundColor3 = color or Theme.Accent,
		BackgroundTransparency = 0.88,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(2, 2),
		ZIndex = 5,
		Parent = button,
	})
	Corner(d).Parent = circle
	button.ClipsDescendants = true
	Tween(circle, 0.55, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	task.delay(0.6, function()
		circle:Destroy()
	end)
end

local function HookRipple(button, color)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			PlayRipple(button, input, color)
		end
	end)
end

local function HookHover(frame, enterColor, leaveColor)
	frame.MouseEnter:Connect(function()
		Tween(frame, 0.16, { BackgroundColor3 = enterColor })
	end)
	frame.MouseLeave:Connect(function()
		Tween(frame, 0.22, { BackgroundColor3 = leaveColor })
	end)
end

local function EnsureNotifyHolder()
	if NotifyHolder then
		return NotifyHolder
	end
	NotifyHolder = New("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.new(0, 330, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
		Parent = Gui,
	})
	New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = NotifyHolder
	return NotifyHolder
end

function OxLib:Notify(cfg)
	cfg = cfg or {}
	local holder = EnsureNotifyHolder()
	local dur = cfg.Duration or 4

	local wrapper = New("Frame", {
		Name = "NotifyWrap",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 78),
		LayoutOrder = #NotifyCards + 1,
		Parent = holder,
	})

	local card = New("Frame", {
		Name = "NotifyCard",
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 1, 0),
		ClipsDescendants = true,
		Position = UDim2.new(0, 350, 0, 0),
		Parent = wrapper,
	}, { Corner(15) })
	Glassify(card, { Radius = 15, Transparency = 0.3, GlowTrans = 0.4 })

	local badge = New("Frame", {
		BackgroundColor3 = Theme.White:Lerp(Theme.Accent, 0.12),
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		Parent = card,
	}, { Corner(12) })
	RegAccent(badge, "BackgroundColor3", "soft", 0.12)

	local iconHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = badge })
	local icon = Icons.Draw(cfg.Icon or "spark", iconHolder, 18, Theme.Accent)
	icon.Position = UDim2.new(0.5, -9, 0.5, -9)

	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 58, 0, 12),
		Size = UDim2.new(1, -118, 0, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = cfg.Title or "Уведомление",
		Parent = card,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 58, 0, 31),
		Size = UDim2.new(1, -74, 0, 38),
		Font = Enum.Font.Gotham,
		TextSize = 11.5,
		TextColor3 = Theme.TextSub,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = cfg.Message or "",
		Parent = card,
	})

	local closeBtn = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.BgSoft,
		Position = UDim2.new(1, -34, 0, 10),
		Size = UDim2.fromOffset(22, 22),
		Parent = card,
	}, { Corner(7) })
	HookHoverLift(closeBtn, Theme.Fill, Theme.BgSoft, { baseTrans = 0, hoverTrans = 0.2, scale = 1.1 })
	local x1 = New("Frame", {
		BackgroundColor3 = Theme.TextSub,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(9, 1.7),
		Rotation = 45,
		Parent = closeBtn,
	})
	Corner(1).Parent = x1
	local x2 = New("Frame", {
		BackgroundColor3 = Theme.TextSub,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(9, 1.7),
		Rotation = -45,
		Parent = closeBtn,
	})
	Corner(1).Parent = x2

	local progress = New("Frame", {
		BackgroundColor3 = Theme.Accent,
		Position = UDim2.new(0, 0, 1, -3),
		Size = UDim2.new(1, 0, 0, 3),
		Parent = card,
	})
	RegAccent(progress, "BackgroundColor3", "raw")

	table.insert(NotifyCards, wrapper)
	if #NotifyCards > 4 then
		local oldest = table.remove(NotifyCards, 1)
		oldest:Destroy()
	end

	local dismissed = false
	local function dismiss()
		if dismissed then
			return end
		dismissed = true
		Tween(card, 0.3, { Position = UDim2.new(0, 360, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.32, function()
			wrapper:Destroy()
			for i, w in ipairs(NotifyCards) do
				if w == wrapper then
					table.remove(NotifyCards, i)
					break
				end
			end
		end)
	end

	closeBtn.Activated:Connect(dismiss)

	Tween(card, 0.45, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
	local shrink = Tween(progress, dur, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
	shrink.Completed:Connect(dismiss)
end

local CONFIG_DIR = "OxAlpha"

local function FsAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function OxLib:GetConfigs()
	if not FsAvailable() then
		return {}
	end
	local out = {}
	local ok, files = pcall(listfiles, CONFIG_DIR)
	if ok and files then
		for _, f in ipairs(files) do
			local name = string.match(f, "[\\/]+([^\\/]*)%.oxa$")
			if name then
				table.insert(out, name)
			end
		end
	end
	return out
end

function OxLib:SaveConfig(name)
	assert(type(name) == "string" and #name > 0, "Имя конфига обязательно")
	if not FsAvailable() then
		error("[OxLib] Файловая система недоступна в этом инжекторе")
	end
	pcall(function()
		makefolder(CONFIG_DIR)
	end)
	writefile(CONFIG_DIR .. "/" .. name .. ".oxa", HttpSvc:JSONEncode(OxLib.Flags))
end

function OxLib:LoadConfig(name)
	if not FsAvailable() then
		error("[OxLib] Файловая система недоступна в этом инжекторе")
	end
	local path = CONFIG_DIR .. "/" .. name .. ".oxa"
	if not isfile(path) then
		error("[OxLib] Конфиг не найден: " .. tostring(name))
	end
	local data = HttpSvc:JSONDecode(readfile(path))
	for k, v in pairs(data) do
		local setter = FlagSetters[k]
		if setter then
			setter(v)
		end
	end
end

function OxLib:DeleteConfig(name)
	pcall(function()
		delfile(CONFIG_DIR .. "/" .. name .. ".oxa")
	end)
end

function OxLib:Unload()
	if Unloaded then
		return
	end
	Unloaded = true
	for _, c in ipairs(Connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	Gui:Destroy()
end

function OxLib:CreateWindow(cfg)
	cfg = cfg or {}

	local Window = {}
	local Tabs = {}
	local CurrentTab = nil
	local minimized = false
	local visible = true

	local width = cfg.Size and cfg.Size.X.Offset or 660
	local height = cfg.Size and cfg.Size.Y.Offset or 440

	local RootClass = "Frame"

	local Shell = New("Frame", {
		Name = "Shell",
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		Parent = Gui,
	})

	local Halo = New("Frame", {
		Name = "Halo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(width + 14, height + 14),
		Parent = Shell,
	}, { Corner(30) })
	New("UIStroke", { Color = Theme.Accent, Thickness = 2, Transparency = 0.85 }).Parent = Halo

	local Root = New(RootClass, {
		Name = "OxWindow",
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.32,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		ClipsDescendants = true,
		Parent = Shell,
	}, { Corner(22) })
	New("UIStroke", { Color = Theme.White, Thickness = 1.5, Transparency = 0.22 }).Parent = Root
	GlassSheen(Root)

	local Gloss = New("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 0.8,
		Size = UDim2.new(1, 0, 0.46, 0),
		Parent = Root,
	}, { Corner(22) })
	local glossGrad = New("UIGradient", {
		Rotation = 62,
		Color = ColorSequence.new(Theme.White, Color3.fromRGB(222, 230, 245)),
	})
	glossGrad.Parent = Gloss

	local Shade = New("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.fromRGB(206, 210, 224),
		BackgroundTransparency = 0.82,
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Parent = Root,
	}, { Corner(22) })
	local shadeGrad = New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Theme.Bg, Color3.fromRGB(206, 210, 224)),
	})
	shadeGrad.Parent = Shade

	task.spawn(function()
		while not Unloaded and Gloss.Parent do
			Tween(glossGrad, 4, { Offset = Vector2.new(0.35, 0.12) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(4.1)
			Tween(glossGrad, 4, { Offset = Vector2.new(-0.35, -0.12) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(4.1)
		end
	end)

	local Scale = New("UIScale", { Scale = 1, Parent = Root })

	local TitleBar = New("Frame", {
		Name = "TitleBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Parent = Root,
	})

	local logoBadge = New("Frame", {
		BackgroundColor3 = Theme.White:Lerp(Theme.Accent, 0.1),
		Position = UDim2.new(0, 16, 0.5, -17),
		Size = UDim2.fromOffset(34, 34),
		Parent = TitleBar,
	}, { Corner(11) })
	RegAccent(logoBadge, "BackgroundColor3", "soft", 0.1)
	local logoIconHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = logoBadge })
	local logoIcon = Icons.Draw(cfg.Icon or "spark", logoIconHolder, 18, Theme.Accent)
	logoIcon.Position = UDim2.new(0.5, -9, 0.5, -9)

	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 62, 0, 12),
		Size = UDim2.new(1, -180, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = cfg.Title or "Ox Alpha",
		Parent = TitleBar,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 62, 0, 31),
		Size = UDim2.new(1, -180, 0, 13),
		Font = Enum.Font.GothamMedium,
		TextSize = 10.5,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = cfg.Subtitle or "",
		Parent = TitleBar,
	})

	local function TitleBarButton(xOff, symbol)
		local b = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.BgSoft,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			Parent = TitleBar,
		}, { Corner(9) })
		HookHoverLift(b, Theme.Fill, Theme.BgSoft, { baseTrans = 0, hoverTrans = 0.2, scale = 1.1 })
		if symbol == "min" then
			local bar = New("Frame", {
				BackgroundColor3 = Theme.TextSub,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 1.8),
				Parent = b,
			})
			Corner(1).Parent = bar
		else
			local x1 = New("Frame", {
				BackgroundColor3 = Theme.TextSub,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 1.8),
				Rotation = 45,
				Parent = b,
			})
			Corner(1).Parent = x1
			local x2 = New("Frame", {
				BackgroundColor3 = Theme.TextSub,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 1.8),
				Rotation = -45,
				Parent = b,
			})
			Corner(1).Parent = x2
		end
		return b
	end

	local minBtn = TitleBarButton(-88, "min")
	local closeBtn = TitleBarButton(-52, "close")

	local CornerIcon = New("ImageLabel", {
		Name = "CornerIcon",
		BackgroundTransparency = 1,
		Image = cfg.CornerIconImage or "rbxassetid://105839011064173",
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = cfg.CornerIconPos or UDim2.new(1, -16, 0.5, 0),
		Size = cfg.CornerIconSize or UDim2.fromOffset(26, 26),
		Parent = TitleBar,
	})
	New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = CornerIcon })

	Window.CornerIcon = CornerIcon

	local Body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		Parent = Root,
	}, { Corner(22) })

	local Sidebar = New("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Theme.BgSofter,
		BackgroundTransparency = 0.45,
		Size = UDim2.new(0, 176, 1, 0),
		Parent = Body,
	})
	Glassify(Sidebar, { Radius = 0, Transparency = 0.4, GlowTrans = 0.45 })
	New("Frame", {
		BackgroundColor3 = Theme.Stroke,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = Sidebar,
	})

	local TabList = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 1, -20),
		Parent = Sidebar,
	})
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = TabList

	local ContentPad = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 176, 0, 0),
		Size = UDim2.new(1, -176, 1, 0),
		Parent = Body,
	})

	function Window.SelectTab(selectedName)
		CurrentTab = selectedName
		for tabName, tab in pairs(Tabs) do
			local active = tabName == selectedName
			tab.Page.Visible = active
			Tween(tab.Button, 0.25, { BackgroundColor3 = active and Theme.Accent:Lerp(Theme.Bg, 0.82) or Theme.BgSofter, BackgroundTransparency = active and 0.35 or 0.5 }, Enum.EasingStyle.Quart)
			tab.Indicator.BackgroundTransparency = active and 0 or 1
			tab.Label.TextColor3 = active and Theme.Text or Theme.TextSub
			Icons.Recolor(tab.IconInner, active and Theme.Accent or Theme.TextDim)
			local ps = tab.Page:FindFirstChildOfClass("UIScale") or New("UIScale", { Scale = 1, Parent = tab.Page })
			if active then
				ps.Scale = 0.97
				Tween(ps, 0.3, { Scale = 1 }, Enum.EasingStyle.Quart)
			end
		end
	end

	function Window:AddTab(tabCfg)
		tabCfg = tabCfg or {}
		local name = tabCfg.Name or "Tab"

		local Tab = {}
		Tab.Order = #Tabs + 1

		local TabBtn = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.BgSofter,
			BackgroundTransparency = 0.5,
			Size = UDim2.new(1, 0, 0, 38),
			LayoutOrder = Tab.Order,
			Parent = TabList,
		}, { Corner(12) })
		Glassify(TabBtn, { Radius = 12, Transparency = 0.5, GlowTrans = 0.45 })

		local Indicator = New("Frame", {
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0.5, -9),
			Size = UDim2.new(0, 3, 0, 18),
			Parent = TabBtn,
		}, { Corner(2) })
		RegAccent(Indicator, "BackgroundColor3", "raw")

		local IconHolder = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 13, 0.5, -9),
			Size = UDim2.fromOffset(18, 18),
			Parent = TabBtn,
		})
		local IconInner = Icons.Draw(tabCfg.Icon or "grid", IconHolder, 18, Theme.TextDim)

		local Label = New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 42, 0, 0),
			Size = UDim2.new(1, -50, 1, 0),
			Font = Enum.Font.GothamMedium,
			TextSize = 12.5,
			TextColor3 = Theme.TextSub,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = name,
			Parent = TabBtn,
		})

		local Page = New("ScrollingFrame", {
			Name = "Page_" .. name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.StrokeStrong,
			Parent = ContentPad,
		})
		New("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 22),
			PaddingBottom = UDim.new(0, 16),
		}).Parent = Page
		New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = Page

		Tab.Button = TabBtn
		Tab.Label = Label
		Tab.IconInner = IconInner
		Tab.Indicator = Indicator
		Tab.Page = Page
		Tab.Name = name

		Tabs[name] = Tab

		TabBtn.MouseEnter:Connect(function()
			if CurrentTab ~= name then
				Tween(TabBtn, 0.15, { BackgroundColor3 = Theme.Fill, BackgroundTransparency = 0.4 })
			end
		end)
		TabBtn.MouseLeave:Connect(function()
			if CurrentTab ~= name then
				Tween(TabBtn, 0.2, { BackgroundColor3 = Theme.BgSofter, BackgroundTransparency = 0.5 })
			end
		end)
		TabBtn.Activated:Connect(function()
			Window.SelectTab(name)
		end)

		function Tab:AddSection(title)
			Tab.SecCounter = (Tab.SecCounter or 0) + 1
			local Card = New("Frame", {
				Name = "Section",
				BackgroundColor3 = Theme.Bg,
				BackgroundTransparency = Theme.GlassTrans,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = Tab.SecCounter,
				Parent = Page,
			}, { Corner(16) })
			Glassify(Card, { Radius = 16, Transparency = Theme.GlassTrans })
			New("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}).Parent = Card
			New("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = Card

			if title and title ~= "" then
				New("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = Enum.Font.GothamBold,
					TextSize = 10.5,
					TextColor3 = Theme.TextSub,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = string.upper(title),
					Parent = Card,
				})
			end

			local SecBody = New("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = Card,
			})
			New("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = SecBody

			local Section = { _order = 0 }

			local function TakeOrder()
				local o = Section._order
				Section._order = Section._order + 1
				return o
			end

			local function NewRow(h)
				local r = New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, h or 30),
					LayoutOrder = TakeOrder(),
					Parent = SecBody,
				})
				return r
			end

			local function MakeLabel(row, text, reserveRight)
				return New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 2, 0, 0),
					Size = UDim2.new(1, -(reserveRight or 0) - 6, 1, 0),
					Font = Enum.Font.GothamMedium,
					TextSize = 12.5,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = text or "",
					Parent = row,
				})
			end

			function Section:AddToggle(t)
				t = t or {}
				local row = NewRow(30)
				MakeLabel(row, t.Name, 64)

				local state = t.Default == true

				local sw = New("Frame", {
					BackgroundColor3 = state and Theme.Accent or Theme.Fill,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -4, 0.5, 0),
					Size = UDim2.fromOffset(40, 21),
					Parent = row,
				}, { Corner(11) })

				local thumb = New("Frame", {
					BackgroundColor3 = Theme.White,
					Position = UDim2.new(0, state and 22 or 3, 0.5, -7.5),
					Size = UDim2.fromOffset(15, 15),
					Parent = sw,
				}, { Corner(8) })
				local thumbStroke = New("UIStroke", { Color = Theme.StrokeStrong, Thickness = 1, Transparency = state and 1 or 0.2 })
				thumbStroke.Parent = thumb

				local accRef = nil
				local function bindAccent(on)
					if on and not accRef then
						accRef = { Inst = sw, Prop = "BackgroundColor3", Mode = "raw" }
						table.insert(AccentRefs, accRef)
					elseif not on and accRef then
						for i = #AccentRefs, 1, -1 do
							if AccentRefs[i] == accRef then
								table.remove(AccentRefs, i)
							end
						end
						accRef = nil
					end
				end
				bindAccent(state)

				local btn = New("TextButton", {
					Text = "",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Parent = row,
				})
				HookRipple(btn, Theme.Accent)

				local function SetState(v, fire)
					state = v
					bindAccent(v)
					Tween(sw, 0.28, { BackgroundColor3 = v and Theme.Accent or Theme.Fill }, Enum.EasingStyle.Back)
					Tween(thumb, 0.32, { Position = UDim2.new(0, v and 22 or 3, 0.5, -7.5) }, Enum.EasingStyle.Back)
					Tween(thumbStroke, 0.2, { Transparency = v and 1 or 0.2 })
					if t.Flag then
						OxLib.Flags[t.Flag] = v
					end
					if fire and t.Callback then
						task.spawn(t.Callback, v)
					end
				end

				btn.Activated:Connect(function()
					SetState(not state, true)
				end)

				SetState(state, false)

				if t.Flag then
					FlagSetters[t.Flag] = function(v)
						SetState(v == true, true)
					end
				end

				local api = {}
				function api:Set(v)
					SetState(v == true, true)
				end
				function api:Get()
					return state
				end
				return api
			end

			function Section:AddSlider(t)
				t = t or {}
				local minV = t.Min or 0
				local maxV = t.Max or 100
				local step = t.Step
				local precision = t.Precision
				local suffix = t.Suffix or ""
				local row = NewRow(46)

				local head = New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					Parent = row,
				})
				MakeLabel(head, t.Name, 84)

				local chip = New("TextLabel", {
					BackgroundColor3 = Theme.White:Lerp(Theme.Accent, 0.09),
					TextColor3 = Theme.Accent,
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(70, 20),
					Text = "",
					Parent = head,
				}, { Corner(7) })
				RegAccent(chip, "BackgroundColor3", "soft", 0.09)
				RegAccent(chip, "TextColor3", "raw")

				local trackWrap = New("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 0, 26),
					Size = UDim2.new(1, 0, 0, 16),
					Parent = row,
				})
				local track = New("Frame", {
					BackgroundColor3 = Theme.Fill,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 2, 0.5, 0),
					Size = UDim2.new(1, -4, 0, 5),
					Parent = trackWrap,
				}, { Corner(3) })
				local fill = New("Frame", {
					BackgroundColor3 = Theme.Accent,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = track,
				}, { Corner(3) })
				RegAccent(fill, "BackgroundColor3", "raw")

				local knob = New("Frame", {
					BackgroundColor3 = Theme.White,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					ZIndex = 2,
					Parent = track,
				}, { Corner(7) })
				local knobStroke = New("UIStroke", { Color = Theme.Accent, Thickness = 2 })
				knobStroke.Parent = knob
				RegAccent(knobStroke, "Color", "raw")

				local value = SnapValue(t.Default or minV, minV, maxV, step, precision)

				local function Render(fire)
					local pct = 0
					if maxV ~= minV then
						pct = (value - minV) / (maxV - minV)
					end
					fill.Size = UDim2.new(pct, 0, 1, 0)
					knob.Position = UDim2.new(pct, 0, 0.5, 0)
					chip.Text = TrimNumber(value) .. suffix
					if t.Flag then
						OxLib.Flags[t.Flag] = value
					end
					if fire and t.Callback then
						task.spawn(t.Callback, value)
					end
				end

				local dragging = false
				local function FromInput(input)
					local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
					value = SnapValue(minV + (maxV - minV) * math.clamp(rel, 0, 1), minV, maxV, step, precision)
					Render(true)
				end

				local grab = New("TextButton", {
					Text = "",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Parent = trackWrap,
				})
				grab.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
						FromInput(input)
					end
				end)
				Connect(UserInput.InputChanged, function(input)
					if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						FromInput(input)
					end
				end)
				Connect(UserInput.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = false
					end
				end)

				grab.MouseEnter:Connect(function()
					Tween(knob, 0.15, { Size = UDim2.fromOffset(17, 17) }, Enum.EasingStyle.Back)
				end)
				grab.MouseLeave:Connect(function()
					Tween(knob, 0.2, { Size = UDim2.fromOffset(14, 14) })
				end)

				Render(false)

				if t.Flag then
					FlagSetters[t.Flag] = function(v)
						value = SnapValue(tonumber(v) or minV, minV, maxV, step, precision)
						Render(true)
					end
				end

				local api = {}
				function api:Set(v)
					value = SnapValue(tonumber(v) or minV, minV, maxV, step, precision)
					Render(true)
				end
				function api:Get()
					return value
				end
				return api
			end

			function Section:AddDropdown(t)
				t = t or {}
				local multi = t.Multi == true
				local options = t.Options or {}
				local itemCount = #options
				local single = ""
				if not multi and t.Default then
					single = tostring(t.Default)
				end
				local selected = {}
				if multi and type(t.Default) == "table" then
					for _, v in ipairs(t.Default) do
						selected[tostring(v)] = true
					end
				end

				local row = NewRow(32)
				MakeLabel(row, t.Name, 172)

				local ctl = New("TextButton", {
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = Theme.BgSoft,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(160, 28),
					Parent = row,
				}, { Corner(9) })
				HookHoverLift(ctl, Theme.Fill, Theme.BgSoft, { baseTrans = 0.35, hoverTrans = 0.22, scale = 1.02 })

				local cur = New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 10, 0, 0),
					Size = UDim2.new(1, -36, 1, 0),
					Font = Enum.Font.GothamMedium,
					TextSize = 11.5,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = "",
					Parent = ctl,
				})
				local chevWrap = New("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -9, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					Parent = ctl,
				})
				local chev = Chevron(chevWrap, 12, Theme.TextSub)

				local listWrap = New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					ClipsDescendants = true,
					LayoutOrder = TakeOrder(),
					Parent = SecBody,
				})
			local listBox = New("Frame", {
				BackgroundColor3 = Theme.BgSoft,
				BackgroundTransparency = 0.32,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = listWrap,
			}, { Corner(12) })
			Glassify(listBox, { Radius = 12, Transparency = 0.32, GlowTrans = 0.4 })
				New("UIPadding", {
					PaddingTop = UDim.new(0, 4),
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				}).Parent = listBox
				New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = listBox

				local open = false
				local itemRows = {}

				local function CollectMulti()
					local out = {}
					for _, opt in ipairs(options) do
						local nm = tostring(opt)
						if selected[nm] then
							table.insert(out, nm)
						end
					end
					return out
				end

				local function CurrentValue()
					if multi then
						return CollectMulti()
					end
					return single ~= "" and single or nil
				end

				local function Emit(val)
					if t.Flag then
						OxLib.Flags[t.Flag] = val
					end
					if t.Callback then
						task.spawn(t.Callback, val)
					end
				end

				local function UpdateHeaderText()
					if multi then
						local n = 0
						for _ in pairs(selected) do
							n = n + 1
						end
						if n == 0 then
							cur.Text = t.Placeholder or "Ничего"
						elseif n == 1 then
							local only
							for k in pairs(selected) do
								only = k
							end
							cur.Text = only
						else
							cur.Text = tostring(n) .. " выбрано"
						end
					else
						if single ~= "" then
							cur.Text = single
						else
							cur.Text = t.Placeholder or "Выбрать"
						end
					end
				end

				local function SetOpen(v)
					open = v
					Tween(chev, 0.3, { Rotation = v and 180 or 0 }, Enum.EasingStyle.Back)
					Tween(listWrap, 0.32, { Size = UDim2.new(1, 0, 0, v and (itemCount * 28 + 8) or 0) }, Enum.EasingStyle.Quint)
				end

				local function RefreshVisuals()
					for label, ui in pairs(itemRows) do
						local isSel = false
						if multi then
							isSel = selected[label] == true
						else
							isSel = label == single
						end
						Tween(ui.Dot, 0.18, { BackgroundTransparency = isSel and 0 or 1 })
						ui.Label.TextColor3 = isSel and Theme.Text or Theme.TextSub
					end
					UpdateHeaderText()
				end

				local function MakeOption(rawOpt)
					local label = tostring(rawOpt)
					local opt = New("TextButton", {
						Text = "",
						AutoButtonColor = false,
						BackgroundColor3 = Theme.BgSoft,
						BackgroundTransparency = 0.2,
						Size = UDim2.new(1, 0, 0, 26),
						Parent = listBox,
					})
					HookHoverLift(opt, Theme.Accent:Lerp(Theme.BgSoft, 0.55), Theme.BgSoft, { baseTrans = 0.2, hoverTrans = 0.08, scale = 1.015 })
					local dot = New("Frame", {
						BackgroundColor3 = Theme.Accent,
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 9, 0.5, 0),
						Size = UDim2.fromOffset(7, 7),
						Parent = opt,
					}, { Corner(4) })
					RegAccent(dot, "BackgroundColor3", "raw")
					local olbl = New("TextLabel", {
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 24, 0, 0),
						Size = UDim2.new(1, -30, 1, 0),
						Font = Enum.Font.GothamMedium,
						TextSize = 11.5,
						TextColor3 = Theme.TextSub,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Text = label,
						Parent = opt,
					})
					itemRows[label] = { Dot = dot, Label = olbl }

					opt.Activated:Connect(function()
						if multi then
							if selected[label] then
								selected[label] = nil
							else
								selected[label] = true
							end
							RefreshVisuals()
							Emit(CollectMulti())
						else
							single = label
							RefreshVisuals()
							SetOpen(false)
							Emit(label)
						end
					end)
				end

				for _, opt in ipairs(options) do
					MakeOption(opt)
				end

				ctl.Activated:Connect(function()
					SetOpen(not open)
				end)

				RefreshVisuals()

				if t.Flag then
					OxLib.Flags[t.Flag] = CurrentValue()
					FlagSetters[t.Flag] = function(v)
						if multi then
							selected = {}
							if type(v) == "table" then
								for _, nm in ipairs(v) do
									selected[tostring(nm)] = true
								end
							end
						else
							single = v and tostring(v) or ""
						end
						RefreshVisuals()
						Emit(CurrentValue())
					end
				end

				local api = {}
				function api:Set(val)
					local setter = t.Flag and FlagSetters[t.Flag]
					if setter then
						setter(val)
					elseif multi and type(val) == "table" then
						selected = {}
						for _, nm in ipairs(val) do
							selected[tostring(nm)] = true
						end
						RefreshVisuals()
					elseif not multi then
						single = val and tostring(val) or ""
						RefreshVisuals()
					end
				end
				function api:Get()
					return CurrentValue()
				end
				return api
			end

			function Section:AddKeybind(t)
				t = t or {}
				local row = NewRow(30)
				MakeLabel(row, t.Name, 112)

				local current = nil
				if t.Default then
					current = tostring(t.Default)
				end

				local btn = New("TextButton", {
					Text = current or "None",
					Font = Enum.Font.GothamBold,
					TextSize = 10.5,
					TextColor3 = Theme.TextSub,
					AutoButtonColor = false,
					BackgroundColor3 = Theme.BgSoft,
					BackgroundTransparency = 0.35,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(100, 26),
					Parent = row,
				}, { Corner(8) })
				HookHoverLift(btn, Theme.Fill, Theme.BgSoft, { baseTrans = 0.35, hoverTrans = 0.2, scale = 1.04 })

				local listening = false

				local function SetBind(name, fire)
					current = name
					btn.Text = name or "None"
					if t.Flag then
						OxLib.Flags[t.Flag] = name or ""
					end
					if fire and t.Callback and name then
						task.spawn(t.Callback)
					end
				end

				btn.Activated:Connect(function()
					if listening then
						return
					end
					listening = true
					btn.Text = "..."
					btn.BackgroundColor3 = Theme.White:Lerp(Theme.Accent, 0.12)
					local conn
					conn = Connect(UserInput.InputBegan, function(input, processed)
						if processed then
							return
						end
						conn:Disconnect()
						listening = false
						btn.BackgroundColor3 = Theme.BgSoft
						if input.KeyCode == Enum.KeyCode.Escape then
							SetBind(nil, false)
							return
						end
						if input.UserInputType == Enum.UserInputType.Keyboard then
							SetBind(input.KeyCode.Name, true)
						elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
							SetBind("MouseButton3", true)
						else
							btn.Text = current or "None"
						end
					end)
				end)

				if t.Callback then
					Connect(UserInput.InputBegan, function(input, processed)
						if processed or listening then
							return
						end
						if current and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == current then
							task.spawn(t.Callback)
						end
					end)
				end

				if t.Flag then
					OxLib.Flags[t.Flag] = current or ""
					FlagSetters[t.Flag] = function(v)
						local s = v and tostring(v) or ""
						SetBind(s ~= "" and s or nil, false)
					end
				end

				local api = {}
				function api:Set(keyName)
					SetBind(keyName and tostring(keyName) or nil, false)
				end
				function api:Get()
					return current
				end
				return api
			end

			function Section:AddTextbox(t)
				t = t or {}
				local row = NewRow(30)
				MakeLabel(row, t.Name, 184)

				local boxStroke = New("UIStroke", { Color = Theme.StrokeStrong, Thickness = 1 })
				local box = New("TextBox", {
					BackgroundColor3 = Theme.BgSoft,
					BackgroundTransparency = 0.3,
					Text = t.Default and tostring(t.Default) or "",
					PlaceholderText = t.Placeholder or "...",
					PlaceholderColor3 = Theme.TextDim,
					ClearTextOnFocus = false,
					Font = Enum.Font.GothamMedium,
					TextSize = 11.5,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(172, 27),
					Parent = row,
				}, { Corner(8), boxStroke })
				New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }).Parent = box

				box.Focused:Connect(function()
					Tween(boxStroke, 0.18, { Color = Theme.Accent })
				end)

				box.FocusLost:Connect(function(enterPressed)
					Tween(boxStroke, 0.25, { Color = Theme.StrokeStrong })
					local txt = box.Text
					if t.Numeric then
						local num = tonumber(txt)
						txt = num or txt
					end
					if t.Flag then
						OxLib.Flags[t.Flag] = txt
					end
					if t.Callback then
						task.spawn(t.Callback, txt, enterPressed)
					end
				end)

				if t.Flag then
					OxLib.Flags[t.Flag] = box.Text
					FlagSetters[t.Flag] = function(v)
						box.Text = v and tostring(v) or ""
					end
				end

				local api = {}
				function api:Set(v)
					box.Text = v and tostring(v) or ""
				end
				function api:Get()
					return box.Text
				end
				return api
			end

			function Section:AddButton(t)
				t = t or {}
				local row = NewRow(34)
				local variant = string.lower(t.Variant or "default")

				local bgColor = Theme.BgSoft
				local txtColor = Theme.Text
				local hoverColor = Theme.White
				local baseTrans = 0.35
				local hoverTrans = 0.15
				local strokeColor = Theme.Stroke
				local strokeTrans = 0.35
				if variant == "primary" then
					bgColor = Theme.Accent
					txtColor = Theme.White
					hoverColor = Theme.Accent:Lerp(Theme.White, 0.16)
					baseTrans = 0.12
					hoverTrans = 0.04
					strokeColor = Theme.Accent
					strokeTrans = 0.4
				elseif variant == "danger" then
					bgColor = Theme.Danger
					txtColor = Theme.White
					hoverColor = Theme.Danger:Lerp(Theme.White, 0.14)
					baseTrans = 0.16
					hoverTrans = 0.06
					strokeColor = Theme.Danger
					strokeTrans = 0.4
				end

				local btn = New("TextButton", {
					Text = t.Name or "Кнопка",
					Font = Enum.Font.GothamSemibold,
					TextSize = 12,
					TextColor3 = txtColor,
					AutoButtonColor = false,
					BackgroundColor3 = bgColor,
					BackgroundTransparency = baseTrans,
					Size = UDim2.fromScale(1, 1),
					Parent = row,
				}, { Corner(12) })
				New("UIStroke", { Color = strokeColor, Thickness = 1, Transparency = strokeTrans }).Parent = btn
				GlassSheen(btn)

				if variant == "primary" then
					RegAccent(btn, "BackgroundColor3", "raw")
					RegAccent(btn:FindFirstChildOfClass("UIStroke"), "Color", "raw")
				end

				HookHoverLift(btn, hoverColor, bgColor, { baseTrans = baseTrans, hoverTrans = hoverTrans, scale = 1.03, StrokeColor = strokeColor, glowTrans = strokeTrans })
				HookRipple(btn, variant == "default" and Theme.TextSub or txtColor)

				btn.Activated:Connect(function()
					if t.Callback then
						task.spawn(t.Callback)
					end
				end)

				local api = {}
				function api:SetText(s)
					btn.Text = tostring(s)
				end
				return api
			end

			function Section:AddParagraph(t)
				t = t or {}
				local wrap = New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = TakeOrder(),
					Parent = SecBody,
				})
				local card = New("Frame", {
				BackgroundColor3 = Theme.BgSoft,
				BackgroundTransparency = 0.4,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = wrap,
			}, { Corner(12) })
			Glassify(card, { Radius = 12, Transparency = 0.4, GlowTrans = 0.4 })
				New("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 10),
				}).Parent = card
				New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = card

				local titleLabel
				if t.Title and t.Title ~= "" then
					titleLabel = New("TextLabel", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 15),
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Theme.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = t.Title,
						Parent = card,
					})
				end
				local body = New("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Font = Enum.Font.Gotham,
					TextSize = 11.5,
					TextColor3 = Theme.TextSub,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					Text = t.Text or "",
					Parent = card,
				})

				local api = {}
				function api:Set(text)
					body.Text = tostring(text)
				end
				function api:SetText(s)
					body.Text = tostring(s)
				end
				return api
			end

			function Section:AddDivider()
				New("Frame", {
					BackgroundColor3 = Theme.Stroke,
					Size = UDim2.new(1, 0, 0, 1),
					LayoutOrder = TakeOrder(),
					Parent = SecBody,
				})
			end

			function Section:AddLabel(t)
				t = type(t) == "table" and t or { Text = tostring(t) }
				local row = NewRow(18)
				New("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 2, 0, 0),
					Size = UDim2.new(1, -4, 1, 0),
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextColor3 = Theme.TextDim,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = t.Text or "",
					Parent = row,
				})
			end

			return Section
		end

		if not CurrentTab then
			Window.SelectTab(name)
		end

		return Tab
	end

	minBtn.Activated:Connect(function()
		minimized = not minimized
		Tween(Root, 0.45, { Size = UDim2.fromOffset(width, minimized and 56 or height) }, Enum.EasingStyle.Back)
		Tween(Halo, 0.45, { Size = UDim2.fromOffset(width + 14, (minimized and 56 or height) + 14) }, Enum.EasingStyle.Back)
	end)

	function Window.SetVisible(v)
		visible = v
		if v then
			Root.Visible = true
			Halo.Visible = true
		end
		Tween(Scale, 0.38, { Scale = v and 1 or 0.9 }, Enum.EasingStyle.Back)
		local haloStroke = Halo:FindFirstChildOfClass("UIStroke")
		Tween(haloStroke, 0.3, { Transparency = v and 0.6 or 1 })
		if not v then
			task.delay(0.33, function()
				if not visible then
					Root.Visible = false
					Halo.Visible = false
				end
			end)
		end
	end

	function Window.Toggle()
		Window.SetVisible(not visible)
	end

	closeBtn.Activated:Connect(function()
		Window.SetVisible(false)
	end)

	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	Connect(UserInput.InputBegan, function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == toggleKey then
			Window.Toggle()
		end
	end)

	local dragState = nil
	TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragState = { Pos = Shell.Position, Mouse = input.Position }
		end
	end)
	Connect(UserInput.InputChanged, function(input)
		if dragState and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dx = input.Position.X - dragState.Mouse.X
			local dy = input.Position.Y - dragState.Mouse.Y
			local base = dragState.Pos
			Shell.Position = UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset + dy)
		end
	end)
	Connect(UserInput.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragState = nil
		end
	end)

	if cfg.MobileButton ~= false then
		local fab = New("TextButton", {
			Name = "MobileToggle",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Accent,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18, 1, -18),
			Size = UDim2.fromOffset(46, 46),
			Parent = Gui,
		}, { Corner(23) })
		local fabStroke = New("UIStroke", { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.4 })
		fabStroke.Parent = fab
		GlassSheen(fab)
		RegAccent(fab, "BackgroundColor3", "raw")
		RegAccent(fabStroke, "Color", "raw")
		local fabIconHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = fab })
		local fabIcon = Icons.Draw("spark", fabIconHolder, 20, Theme.White)
		fabIcon.Position = UDim2.new(0.5, -10, 0.5, -10)

		local fstart = nil
		fab.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				fstart = { Pos = fab.Position, Mouse = input.Position, Moved = false }
			end
		end)
		Connect(UserInput.InputChanged, function(input)
			if fstart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local dx = input.Position.X - fstart.Mouse.X
				local dy = input.Position.Y - fstart.Mouse.Y
				if math.abs(dx) + math.abs(dy) > 10 then
					fstart.Moved = true
				end
				fab.Position = UDim2.new(1, fstart.Pos.X.Offset - dx, 1, fstart.Pos.Y.Offset - dy)
			end
		end)
		fab.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if fstart and not fstart.Moved then
					Window.Toggle()
				end
				fstart = nil
			end
		end)

		task.spawn(function()
			while not Unloaded and fab.Parent do
				Tween(fab, 1.2, { Size = UDim2.fromOffset(50, 50) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(1.2)
				Tween(fab, 1.2, { Size = UDim2.fromOffset(46, 46) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(1.2)
			end
		end)
	end

	Scale.Scale = 0.9
	local haloStroke = Halo:FindFirstChildOfClass("UIStroke")
	if haloStroke then
		haloStroke.Transparency = 1
	end
	task.defer(function()
		Tween(Scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		if haloStroke then
			Tween(haloStroke, 0.5, { Transparency = 0.6 })
		end
	end)

	return Window
end

return OxLib
