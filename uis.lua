local uis = game:GetService("UserInputService")
local tween_service = game:GetService("TweenService")
local camera = workspace.CurrentCamera
local vec2 = Vector2.new
local dim2 = UDim2.new
local dim_offset = UDim2.fromOffset
local dim = UDim.new
local rgb = Color3.fromRGB
local rgbseq = ColorSequence.new
local rgbkey = ColorSequenceKeypoint.new
local random = math.random
local clamp = math.clamp
local max = math.max
local insert = table.insert
local remove = table.remove
local find = table.find

local themes = {
	preset = {
		outline = rgb(12, 12, 12),
		inline = rgb(28, 28, 28),
		accent = rgb(152, 188, 255),
		high_contrast = rgb(19, 19, 19),
		low_contrast = rgb(23, 23, 23),
		text = rgb(180, 180, 180),
		text_outline = rgb(0, 0, 0),
	},
	utility = {
		outline = { BackgroundColor3 = {} },
		inline = { BackgroundColor3 = {} },
		accent = { BackgroundColor3 = {}, TextColor3 = {}, ScrollBarImageColor3 = {} },
		contrast = { Color = {} },
		high_contrast = { BackgroundColor3 = {} },
		low_contrast = { BackgroundColor3 = {} },
		text = { TextColor3 = {} },
		text_outline = { Color = {} },
	},
}

local library = {
	guis = {},
	loaders = {},
	unload_hooks = {},
	text_objects = {},
	flags = {},
	config_flags = {},
	visible_flags = {},
	toggle_registry = {},
	layout_registry = {},
	widget_state = setmetatable({}, { __mode = "k" }),
	fade_base = setmetatable({}, { __mode = "k" }),
	no_bg_fade = setmetatable({}, { __mode = "k" }),
	theme_map = setmetatable({}, { __mode = "k" }),
}
library.__index = library
local flags = library.flags
library.font = Font.fromEnum(Enum.Font.SourceSans)

do
	local path = "Genesis/Fonts/smallest-pixel7.ttf"
	if type(isfile) == "function" and type(writefile) == "function" and not isfile(path) then
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" then
				if not isfolder("Genesis") then makefolder("Genesis") end
				if not isfolder("Genesis/Fonts") then makefolder("Genesis/Fonts") end
			end
			for _, url in ipairs({
				"https://raw.githubusercontent.com/sad-ddot/assets/main/Fonts/smallest-pixel7.ttf",
				"https://cdn.jsdelivr.net/gh/sad-ddot/assets@main/Fonts/smallest-pixel7.ttf",
				"https://github.com/sametexe001/luas/raw/refs/heads/main/smallest_pixel-7.ttf",
			}) do
				local ok, body = pcall(game.HttpGet, game, url)
				if ok and type(body) == "string" and #body > 512 and pcall(writefile, path, body) then break end
			end
		end)
	end
	if type(isfile) == "function" and type(getcustomasset) == "function" and type(writefile) == "function" and isfile(path) then
		local ok, face = pcall(function()
			local json = game:GetService("HttpService"):JSONEncode({
				name = "smallest-pixel7",
				faces = { { name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(path) } },
			})
			local descriptor = "Genesis/Fonts/smallest-pixel7.json"
			writefile(descriptor, json)
			return Font.new(getcustomasset(descriptor), Enum.FontWeight.Regular)
		end)
		if ok and face then library.font = face end
	end
end

local function get_parent()
	if type(gethui) == "function" then return gethui() end
	return game:GetService("CoreGui")
end

function library:create(kind, properties)
	if kind == "UIStroke" and properties and properties.Parent then
		local existing = properties.Parent:FindFirstChildOfClass("UIStroke")
		if existing then
			for property, value in pairs(properties) do
				if property ~= "Parent" then existing[property] = value end
			end
			return existing
		end
	end
	local instance = Instance.new(kind)
	for property, value in pairs(properties) do instance[property] = value end
	if kind == "ScreenGui" then insert(self.guis, instance) end
	if kind == "TextLabel" or kind == "TextButton" or kind == "TextBox" then
		insert(self.text_objects, instance)
		self:apply_theme(instance, "text", "TextColor3")
		self:apply_stroke(instance)
	end
	return instance
end

function library:apply_stroke(parent)
	local stroke = self:create("UIStroke", {
		Parent = parent, Color = themes.preset.text_outline,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
	self:apply_theme(stroke, "text_outline", "Color")
end

function library:apply_theme(instance, theme, property)
	property = property or "BackgroundColor3"
	local group = themes.utility[theme]
	local bucket = group and group[property]
	if not bucket then return end
	if not find(bucket, instance) then insert(bucket, instance) end
	local map = self.theme_map[instance]
	if not map then map = {} self.theme_map[instance] = map end
	if instance[property] == themes.preset[theme] then map[property] = theme end
end

function library:set_theme_state(instance, property, theme)
	local map = self.theme_map[instance]
	if not map then map = {} self.theme_map[instance] = map end
	map[property] = theme
end

function library:update_theme(theme, value)
	local group = themes.utility[theme]
	if not group then return end
	themes.preset[theme] = value
	for property, bucket in pairs(group) do
		for _, instance in ipairs(bucket) do
			local map = self.theme_map[instance]
			if instance.Parent and map and map[property] == theme then instance[property] = value end
		end
	end

end

function library:tween(instance, properties, info)
	for property, value in pairs(properties) do
		for theme, preset in pairs(themes.preset) do
			local group = themes.utility[theme]
			if value == preset and group and group[property] and find(group[property], instance) then
				self:set_theme_state(instance, property, theme)
				break
			end
		end
	end
	local tween = tween_service:Create(instance, info or TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

function library:loader(options)
	options = options or {}
	local name = tostring(options.Name or options.name or options.Title or options.title or "Loader")
	local size = options.Size or options.size or dim_offset(460, 340)
	local nav_width = clamp(tonumber(options.NavigationWidth or options.navigationWidth) or 130, 90, 210)
	local loader = { Name = name, IsOpen = false, Closing = false, Tabs = {}, ActiveTab = nil, Items = {}, Connections = {} }
	library.loaders = library.loaders or {}
	insert(library.loaders, loader)
	local items = loader.Items
	local function put(key, kind, properties, theme, property)
		local instance = library:create(kind, properties)
		items[key] = { Instance = instance }
		if theme then library:apply_theme(instance, theme, property or "BackgroundColor3") end
		return instance
	end
	local gui = put("gui", "ScreenGui", {
		Name = "Loader", Parent = get_parent(), Enabled = true, ResetOnSpawn = false,
		IgnoreGuiInset = true, DisplayOrder = 999998, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local root = put("root", "CanvasGroup", {
		Name = "LoaderWindow", Parent = gui, AnchorPoint = vec2(0.5, 0.5),
		Position = dim2(0.5, 0, 0.5, 0), Size = size, Visible = false,
		BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 1,
	})
	local scale = put("scale", "UIScale", { Parent = root, Scale = 1 })
	local outline = put("outline", "Frame", {
		Parent = root, Size = dim2(1, 0, 1, 0), BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.outline,
	}, "outline")
	local inline = put("inline", "Frame", {
		Parent = outline, Position = dim_offset(1, 1), Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.inline,
	}, "inline")
	local background = put("background", "Frame", {
		Parent = inline, Position = dim_offset(1, 1), Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.inline,
	}, "inline")
	put("accent", "Frame", {
		Parent = background, Size = dim2(1, 0, 0, 2), BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.accent,
	}, "accent")
	local header = put("header", "Frame", {
		Parent = background, Position = dim_offset(0, 2), Size = dim2(1, 0, 0, 30),
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
	})
	local title = put("title", "TextLabel", {
		Parent = header, Position = dim_offset(9, 0), Size = dim2(1, -90, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = library.font,
		Text = name, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = themes.preset.accent,
	}, "accent", "TextColor3")
	put("headerSeparator", "Frame", {
		Parent = background, Position = dim_offset(0, 32), Size = dim2(1, 0, 0, 1),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.outline,
	}, "outline")
	local exit = put("exitOutline", "TextButton", {
		Parent = header, AnchorPoint = vec2(1, 0.5), Position = dim2(1, -7, 0.5, 0),
		Size = dim_offset(48, 19), Text = "", AutoButtonColor = false,
		BorderSizePixel = 0, Visible = options.ButtonText ~= false,
		BackgroundColor3 = themes.preset.outline,
	}, "outline")
	put("exitInline", "Frame", {
		Parent = exit, Position = dim_offset(1, 1), Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.inline,
	}, "inline")
	local exit_text = put("exitText", "TextLabel", {
		Parent = exit, Size = dim2(1, 0, 1, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, FontFace = library.font, TextSize = 12,
		Text = tostring(options.ButtonText or "exit"), TextColor3 = themes.preset.text,
	}, "text", "TextColor3")
	library:apply_theme(exit_text, "accent", "TextColor3")
	local footer = put("footer", "Frame", {
		Parent = background, Position = dim2(0, 9, 1, -25), Size = dim2(1, -18, 0, 19),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	library:create("UIListLayout", {
		Parent = footer, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = dim(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local footer_dim = put("footerDim", "TextLabel", {
		Parent = footer, Size = dim_offset(0, 19), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = library.font,
		TextSize = 12, TextColor3 = themes.preset.text, Text = "", LayoutOrder = 1,
	}, "text", "TextColor3")
	local footer_bright = put("footerBright", "TextLabel", {
		Parent = footer, Size = dim_offset(0, 19), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = library.font,
		TextSize = 12, TextColor3 = themes.preset.accent, Text = "", LayoutOrder = 2,
	}, "accent", "TextColor3")
	local body = put("bodyOutline", "Frame", {
		Parent = background, Position = dim_offset(9, 39), Size = dim2(1, -18, 1, -70),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.outline,
	}, "outline")
	local body_inline = put("bodyInline", "Frame", {
		Parent = body, Position = dim_offset(1, 1), Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.low_contrast,
	}, "low_contrast")
	local nav = put("navigation", "Frame", {
		Parent = body_inline, Position = dim_offset(7, 14), Size = dim2(0, nav_width, 1, -21),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.outline,
	}, "outline")
	local nav_inner = put("navigationInner", "Frame", {
		Parent = nav, Position = dim_offset(1, 1), Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.high_contrast,
	}, "high_contrast")
	local nav_title = put("navigationTitle", "TextLabel", {
		Parent = body_inline, Position = dim_offset(13, 1), Size = dim2(0, nav_width - 10, 0, 15),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		FontFace = library.font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = themes.preset.accent, TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(options.NavigationTitle or "Menu"),
	}, "accent", "TextColor3")
	local nav_scroll = put("navigationScroll", "ScrollingFrame", {
		Parent = nav_inner, Position = dim_offset(6, 10), Size = dim2(1, -12, 1, -15),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = dim_offset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	library:create("UIListLayout", {
		Parent = nav_scroll, Padding = dim(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local panel = put("panelOutline", "Frame", {
		Parent = body_inline, Position = dim_offset(nav_width + 13, 14),
		Size = dim2(1, -nav_width - 20, 1, -21), BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.outline,
	}, "outline")
	local panel_inner = put("panel", "Frame", {
		Parent = panel, Position = dim_offset(1, 1), Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0, BackgroundColor3 = themes.preset.high_contrast,
	}, "high_contrast")
	local panel_title = put("panelTitle", "TextLabel", {
		Parent = body_inline, Position = dim_offset(nav_width + 19, 1),
		Size = dim2(1, -nav_width - 27, 0, 15), BackgroundTransparency = 1,
		BorderSizePixel = 0, FontFace = library.font, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = themes.preset.accent, Text = "",
	}, "accent", "TextColor3")
	local fade_tween, scale_tween, fade_connection, fade_token = nil, nil, nil, 0
	local page_tweens = {}
	local saved_mouse, dragging, drag_origin, root_origin, top_left
	local destroyed = false
	local unload_hook
	local function set_mouse(open)
		if options.UnlockMouse == false then return end
		if open and not saved_mouse then
			saved_mouse = { uis.MouseBehavior, uis.MouseIconEnabled }
			uis.MouseBehavior = Enum.MouseBehavior.Default
			uis.MouseIconEnabled = true
		elseif not open and saved_mouse then
			uis.MouseBehavior = saved_mouse[1]
			uis.MouseIconEnabled = saved_mouse[2]
			saved_mouse = nil
		end
	end
	local function show_page(page)
		if page_tweens[page] then page_tweens[page]:Cancel() end
		page.Visible = true
		page.Position = dim_offset(7, 0)
		page.GroupTransparency = 1
		page_tweens[page] = tween_service:Create(page, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = dim_offset(0, 0), GroupTransparency = 0,
		})
		page_tweens[page]:Play()
	end
	local function fade(open, finished)
		fade_token += 1
		local token = fade_token
		if fade_connection then fade_connection:Disconnect() fade_connection = nil end
		if fade_tween then fade_tween:Cancel() fade_tween = nil end
		if scale_tween then scale_tween:Cancel() scale_tween = nil end
		if open and not root.Visible then
			root.GroupTransparency = 1
			scale.Scale = 0.97
		end
		if open then root.Visible = true end
		local info = TweenInfo.new(open and 0.26 or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		fade_tween = tween_service:Create(root, info, { GroupTransparency = open and 0 or 1 })
		scale_tween = tween_service:Create(scale, info, { Scale = open and 1 or 0.98 })
		fade_connection = fade_tween.Completed:Connect(function(state)
			if token ~= fade_token or state ~= Enum.PlaybackState.Completed then return end
			fade_connection = nil
			fade_tween = nil
			scale_tween = nil
			if not open then
				root.Visible = false
				scale.Scale = 1
				if loader.ActiveTab then loader.ActiveTab.Items.page.Instance.Visible = false end
			end
			if finished then finished() end
		end)
		scale_tween:Play()
		fade_tween:Play()
	end
	function loader:SetOpen(open)
		open = open == true
		if destroyed or loader.Closing or loader.IsOpen == open then return end
		if open then
			for _, other in ipairs(library.loaders) do
				if other ~= loader and other.IsOpen then other:SetOpen(false) end
			end
		end
		loader.IsOpen = open
		set_mouse(open)
		fade(open)
		if open and loader.ActiveTab then show_page(loader.ActiveTab.Items.page.Instance) end
	end
	function loader:SetTitle(text)
		loader.Name = tostring(text or loader.Name)
		title.Text = loader.Name
	end
	function loader:SetButtonText(text)
		exit.Visible = text ~= false
		if text ~= false then exit_text.Text = tostring(text or "exit") end
	end
	function loader:SetFooter(dim_text, bright_text)
		footer_dim.Text = tostring(dim_text or "")
		footer_bright.Text = tostring(bright_text or "")
	end
	function loader:SelectTab(target)
		if destroyed then return end
		local selected
		for _, tab in ipairs(loader.Tabs) do
			if tab == target or tab.Name == target then selected = tab break end
		end
		if not selected or selected == loader.ActiveTab then return end
		loader.ActiveTab = selected
		panel_title.Text = selected.Title
		for _, tab in ipairs(loader.Tabs) do
			local active = tab == selected
			local page = tab.Items.page.Instance
			tab.Active = active
			if active and loader.IsOpen then
				show_page(page)
			else
				if page_tweens[page] then page_tweens[page]:Cancel() page_tweens[page] = nil end
				page.Visible = false
			end
			library:set_theme_state(tab.Items.indicator.Instance, "BackgroundColor3", active and "accent" or "outline")
			library:set_theme_state(tab.Items.text.Instance, "TextColor3", active and "accent" or "text")
			library:tween(tab.Items.indicator.Instance, { BackgroundColor3 = active and themes.preset.accent or themes.preset.outline }, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			library:tween(tab.Items.text.Instance, { TextColor3 = active and themes.preset.accent or themes.preset.text }, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		end
	end
	function loader:Destroy()
		if destroyed then return end
		destroyed = true
		fade_token += 1
		if fade_connection then fade_connection:Disconnect() fade_connection = nil end
		if fade_tween then fade_tween:Cancel() fade_tween = nil end
		if scale_tween then scale_tween:Cancel() scale_tween = nil end
		for page, tween in pairs(page_tweens) do tween:Cancel() page_tweens[page] = nil end
		set_mouse(false)
		for _, connection in ipairs(loader.Connections) do connection:Disconnect() end
		for _, obj in ipairs(gui:GetDescendants()) do
			for _, group in pairs(themes.utility) do
				for _, bucket in pairs(group) do
					local index = find(bucket, obj)
					if index then remove(bucket, index) end
				end
			end
			local index = find(library.text_objects, obj)
			if index then remove(library.text_objects, index) end
		end
		local index = find(library.loaders, loader)
		if index then remove(library.loaders, index) end
		index = find(library.guis, gui)
		if index then remove(library.guis, index) end
		index = find(library.unload_hooks, unload_hook)
		if index then remove(library.unload_hooks, index) end
		loader.IsOpen = false
		gui:Destroy()
	end
	function loader:Close()
		if destroyed or loader.Closing then return end
		loader.Closing = true
		loader.IsOpen = false
		set_mouse(false)
		if root.Visible then fade(false, function() loader:Destroy() end) else loader:Destroy() end
	end
	function loader:Tab(params)
		if destroyed then return end
		params = params or {}
		local tab = {
			Name = tostring(params.Name or params.name or "Tab"),
			Title = tostring(params.Title or params.title or params.Name or params.name or "Tab"),
			Active = false, Window = loader, Loader = loader, IsSettings = false, Items = {},
		}
		tab.Page = tab
		local button = library:create("TextButton", {
			Parent = nav_scroll, Size = dim2(1, 0, 0, 20), LayoutOrder = #loader.Tabs + 1,
			BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
		})
		tab.Items.button = { Instance = button }
		local marker = library:create("Frame", {
			Parent = button, Size = dim2(0, 2, 1, 0), BorderSizePixel = 0,
			BackgroundColor3 = themes.preset.outline,
		})
		tab.Items.indicator = { Instance = marker }
		library:apply_theme(marker, "outline")
		library:apply_theme(marker, "accent")
		local label = library:create("TextLabel", {
			Parent = button, Position = dim_offset(9, 0), Size = dim2(1, -9, 1, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = library.font,
			TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = tab.Name, TextColor3 = themes.preset.text,
		})
		tab.Items.text = { Instance = label }
		library:apply_theme(label, "accent", "TextColor3")
		local page = library:create("CanvasGroup", {
			Parent = panel_inner, Size = dim2(1, 0, 1, 0), Visible = false,
			BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 0,
		})
		tab.Items.page = { Instance = page }
		local scroll = library:create("ScrollingFrame", {
			Parent = page, Position = dim_offset(0, 5), Size = dim2(1, 0, 1, -5),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
			CanvasSize = dim_offset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		})
		tab.Items.scroll = { Instance = scroll }
		local content = library:create("Frame", {
			Parent = scroll, Position = dim_offset(20, 0), Size = dim2(1, -40, 0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
		})
		tab.Items.content = { Instance = content }
		tab.holder = content
		tab.Items.Section = tab.Items.scroll
		tab.Items.Content = tab.Items.content
		library:create("UIListLayout", { Parent = content, Padding = dim(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		library:create("UIPadding", { Parent = content, PaddingTop = dim(0, 15), PaddingBottom = dim(0, 15) })
		function tab:Turn(active)
			if active then loader:SelectTab(tab) elseif loader.ActiveTab == tab then
				loader.ActiveTab = nil
				tab.Active = false
				if page_tweens[page] then page_tweens[page]:Cancel() page_tweens[page] = nil end
				page.Visible = false
				panel_title.Text = ""
				library:set_theme_state(marker, "BackgroundColor3", "outline")
				library:set_theme_state(label, "TextColor3", "text")
				library:tween(marker, { BackgroundColor3 = themes.preset.outline }, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
				library:tween(label, { TextColor3 = themes.preset.text }, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			end
		end
		function tab:SetTitle(value)
			tab.Title = tostring(value or "")
			if tab.Active then panel_title.Text = tab.Title end
		end
		insert(loader.Connections, button.MouseButton1Click:Connect(function() loader:SelectTab(tab) end))
		insert(loader.Connections, button.MouseEnter:Connect(function()
			if not tab.Active then library:tween(label, { TextColor3 = themes.preset.accent }, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)) end
		end))
		insert(loader.Connections, button.MouseLeave:Connect(function()
			if not tab.Active then library:tween(label, { TextColor3 = themes.preset.text }, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)) end
		end))
		insert(loader.Tabs, tab)
		if #loader.Tabs == 1 then loader:SelectTab(tab) end
		return setmetatable(tab, library)
	end
	insert(loader.Connections, exit.MouseButton1Click:Connect(function()
		if type(options.ButtonCallback) == "function" then
			local ok, err = pcall(options.ButtonCallback, loader)
			if not ok then warn(err) end
		end
		loader:Close()
	end))
	insert(loader.Connections, exit.MouseEnter:Connect(function()
		library:tween(exit_text, { TextColor3 = themes.preset.accent }, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end))
	insert(loader.Connections, exit.MouseLeave:Connect(function()
		library:tween(exit_text, { TextColor3 = themes.preset.text }, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end))
	insert(loader.Connections, header.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		drag_origin = input.Position
		root_origin = root.Position
		top_left = root.AbsolutePosition
	end))
	insert(loader.Connections, uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
	insert(loader.Connections, uis.InputChanged:Connect(function(input)
		if not dragging or not loader.IsOpen then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = input.Position - drag_origin
		local bounds = root.AbsoluteSize
		local viewport = camera.ViewportSize
		if bounds.X > 0 and bounds.Y > 0 then
			local x = clamp(top_left.X + delta.X, 0, max(0, viewport.X - bounds.X))
			local y = clamp(top_left.Y + delta.Y, 0, max(0, viewport.Y - bounds.Y))
			root.Position = dim_offset(x + bounds.X * 0.5, y + bounds.Y * 0.5)
		else
			root.Position = dim2(root_origin.X.Scale, root_origin.X.Offset + delta.X, root_origin.Y.Scale, root_origin.Y.Offset + delta.Y)
		end
	end))
	if options.Footer ~= nil then loader:SetFooter(options.Footer, options.FooterBright)
	else loader:SetFooter(os.date("%d.%m"), os.date("%Y")) end
	library.unload_hooks = library.unload_hooks or {}
	unload_hook = function() loader:Destroy() end
	insert(library.unload_hooks, unload_hook)
	if options.Open ~= false then loader:SetOpen(true) end
	return loader
end

library.Loader = library.loader



function library:connection(signal, callback)
	return signal:Connect(callback)
end

function library:close_current_element()
end

local function ensure_fade_base(instance)
	local stored = library.fade_base[instance]
	if not stored then
		stored = { BackgroundTransparency = instance.BackgroundTransparency }
		library.fade_base[instance] = stored
	end
	return stored
end

function library:play_fade(root, visible, duration, on_done)
	root.Visible = visible
	if on_done then on_done() end
end

function library:animate_child_element(holder, base_h, auto_size, visible)
	holder.Visible = visible
end

function library:hoverify(hover, parent)
	local hover_instance = library:create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, 0, 1, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.accent,
		ZIndex = 1,
	})
	library:apply_theme(hover_instance, "accent", "BackgroundColor3")

	hover.MouseEnter:Connect(function()
		library:tween(hover_instance, {
			BackgroundTransparency = 0,
		})
	end)

	hover.MouseLeave:Connect(function()
		library:tween(hover_instance, {
			BackgroundTransparency = 1,
		})
	end)

	return hover_instance
end


function library:resolve_parent(owner, options)
	options = options or {}
	local parent_toggle = nil
	if owner and owner.toggle_ref then
		parent_toggle = owner.toggle_ref
	elseif owner and owner.is_toggle then
		parent_toggle = owner
	elseif type(options.parent) == "table" then
		parent_toggle = options.parent.toggle_ref or (options.parent.is_toggle and options.parent or nil)
	elseif type(options.parent) == "string" then
		parent_toggle = library.toggle_registry[options.parent]
	elseif (options.sub or options.child or options.indent) and owner and owner.last_toggle then
		parent_toggle = owner.last_toggle
	end
	local indent = 0
	if type(options.indent) == "number" then
		indent = options.indent
	elseif parent_toggle then
		indent = (parent_toggle.indent or 0) + 14
	elseif options.sub or options.child then
		indent = 14
	end
	return parent_toggle, indent
end

function library:register_child(parent_toggle, child_cfg)
	if not parent_toggle or not child_cfg then return end
	parent_toggle.children = parent_toggle.children or {}
	child_cfg.parent_toggle = parent_toggle
	insert(parent_toggle.children, child_cfg)
	local should_show = (parent_toggle.enabled == true) and (parent_toggle.is_visible ~= false)
	child_cfg.set_element_visible(should_show, 0, true, true)
	library:relayout(child_cfg.holder or parent_toggle.holder)
end

function library:track_layout(holder, cfg)
	if not holder or not cfg or not cfg.holder_instance then return end
	local list = library.layout_registry[holder]
	if not list then
		list = {}
		library.layout_registry[holder] = list
	end
	insert(list, cfg)
end

function library:relayout(holder)
	local list = library.layout_registry[holder]
	if not list then return end
	local order = 0
	local function place(cfg)
		if cfg.holder_instance then
			order += 1
			cfg.holder_instance.LayoutOrder = order
		end
		for _, child in ipairs(cfg.children or {}) do
			place(child)
		end
	end
	for _, cfg in ipairs(list) do
		if not cfg.parent_toggle then place(cfg) end
	end
end


function library:section(options)
	local cfg = {
		name = options.name or "Section",
	}
	local parent_holder = self.holder
	if self.columns then
		self.section_count = (self.section_count or 0) + 1
		parent_holder = self.columns[((self.section_count - 1) % 2) + 1]
	end

	local section = library:create("Frame", {
		Parent = parent_holder,
		Name = "\0",
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.inline,
	})
	library:apply_theme(section, "inline", "BackgroundColor3")

	local inline = library:create("Frame", {
		Parent = section,
		Name = "\0",
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.outline,
	})
	library:apply_theme(inline, "outline", "BackgroundColor3")

	local background = library:create("Frame", {
		Parent = inline,
		Name = "\0",
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local text = library:create("TextLabel", {
		Parent = background,
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = cfg.name,
		Name = "\0",
		BackgroundTransparency = 1,
		Position = dim2(0, 6, 0, 4),
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	library:create("UIStroke", {
		Parent = text,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})

	local accent = library:create("Frame", {
		Parent = background,
		Name = "\0",
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, 0, 0, 2),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.accent,
	})
	library:apply_theme(accent, "accent", "BackgroundColor3")

	local UIGradient = library:create("UIGradient", {
		Parent = accent,
		Rotation = 90,
		Color = rgbseq({
			rgbkey(0, rgb(255, 255, 255)),
			rgbkey(1, rgb(167, 167, 167)),
		}),
	})

	local UIGradient = library:create("UIGradient", {
		Parent = background,
		Rotation = 90,
		Color = rgbseq({ rgbkey(0, themes.preset.low_contrast), rgbkey(1, themes.preset.high_contrast) }),
	})
	library:apply_theme(UIGradient, "contrast", "Color")

	local ScrollingFrame = library:create("ScrollingFrame", {
		Parent = background,
		ScrollBarImageColor3 = themes.preset.accent,
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		MidImage = "rbxassetid://103468666327206",
		TopImage = "rbxassetid://103468666327206",
		BottomImage = "rbxassetid://103468666327206",
		Size = dim2(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = dim2(0, 0, 0, 20),
		BackgroundColor3 = rgb(255, 255, 255),
		BorderColor3 = rgb(0, 0, 0),
		BorderSizePixel = 0,
		CanvasSize = dim2(0, 0, 0, 0),
	})
	library:apply_theme(ScrollingFrame, "accent", "ScrollBarImageColor3")

	ScrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function() library:close_current_element() end)

	local elements = library:create("Frame", {
		Parent = ScrollingFrame,
		Name = "\0",
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	cfg.holder = elements

	library:create("UIListLayout", {
		Parent = elements,
		Padding = dim(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	library:create("UIPadding", {
		Parent = ScrollingFrame,
		PaddingBottom = dim(0, 10),
	})

	function cfg:space(pixels)
		return library:create("Frame", {
			Parent = elements,
			Name = "spacing",
			BackgroundTransparency = 1,
			Size = dim2(1, 0, 0, pixels or 6),
		})
	end

	return setmetatable(cfg, library)
end


function library:toggle(options)
	local parent_toggle, indent = library:resolve_parent(self, options)
	local display_name = options.name or "Toggle"
	local cfg = {
		enabled = options.default or false,
		name = options.name or "Toggle",
		flag = options.flag or tostring(random(1, 9999999)),
		callback = options.callback or function() end,
		default = options.default or false,
		colorpicker = options.color or nil,
		visible = options.visible ~= false,
		tooltip = options.tooltip or nil,
		holder = self.holder,
		is_toggle = true,
		is_visible = true,
		indent = indent,
		children = {},
	}

	local toggle_holder = library:create("TextButton", {
		Parent = self.holder,
		FontFace = library.font,
		TextColor3 = rgb(151, 151, 151),
		BorderColor3 = rgb(0, 0, 0),
		Text = "",
		Name = "toggle",
		ZIndex = 1,
		Size = dim2(1, -8, 0, 12),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local right_components = library:create("Frame", {
		Parent = toggle_holder,
		Name = "right_components",
		BackgroundTransparency = 1,
		Position = dim2(1, -1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(0, 0, 0, 12),
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	cfg["right_holder"] = right_components

	local list = library:create("UIListLayout", {
		Parent = right_components,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = dim(0, 4),
		Name = "list",
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	library:create("UIPadding", {
		Parent = toggle_holder,
	})

	local left_components = library:create("Frame", {
		Parent = toggle_holder,
		Name = "left_components",
		BackgroundTransparency = 1,
		Position = dim2(0, indent, 0, 0),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(0, 0, 0, 14),
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local text = library:create("TextLabel", {
		Parent = left_components,
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = display_name,
		Name = "text",
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = dim2(0, 0, 1, -1),
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	library:apply_theme(text, "accent", "TextColor3")

	library:create("UIStroke", {
		Parent = text,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})

	library:create("UIListLayout", {
		Parent = left_components,
		Padding = dim(0, 5),
		Name = "_",
		FillDirection = Enum.FillDirection.Horizontal,
	})

	local toggle = library:create("TextButton", {
		Parent = left_components,
		Name = "!toggle",
		Text = "",
		AutoButtonColor = false,
		Position = dim2(0, 0, 0, 2),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(0, 14, 0, 14),
		BorderSizePixel = 0,
		ZIndex = 1,
		BackgroundColor3 = themes.preset.outline,
	})
	library:apply_theme(toggle, "outline", "BackgroundColor3")

	local inline = library:create("Frame", {
		Parent = toggle,
		Name = "inline",
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		ZIndex = 2,
		BackgroundColor3 = themes.preset.inline,
	})
	library:apply_theme(inline, "inline", "BackgroundColor3")

	local accent = library:create("Frame", {
		Parent = inline,
		BackgroundTransparency = 1,
		ZIndex = 4,
		Name = "background",
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.accent,
	})
	library:apply_theme(accent, "accent", "BackgroundColor3")

	local UIGradient = library:create("UIGradient", {
		Parent = accent,
		Rotation = 90,
		Color = rgbseq({
			rgbkey(0, rgb(255, 255, 255)),
			rgbkey(1, rgb(167, 167, 167)),
		}),
	})

	local background = library:create("Frame", {
		Parent = inline,
		ZIndex = 3,
		Name = "background",
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	library.no_bg_fade[background] = true

	local UIGradient = library:create("UIGradient", {
		Parent = background,
		Rotation = 90,
		Name = "_",
		Color = rgbseq({ rgbkey(0, themes.preset.low_contrast), rgbkey(1, themes.preset.high_contrast) }),
	})
	library:apply_theme(UIGradient, "contrast", "Color")

	library:hoverify(toggle_holder, toggle)

	cfg.holder_instance = toggle_holder
	library:track_layout(self.holder, cfg)
	cfg.toggle_ref = cfg

	local function collect_all_children(node, out)
		out = out or {}
		local kids = node.children
		if not kids then return out end
		for i = 1, #kids do
			local ch = kids[i]
			out[#out + 1] = ch
			if ch.is_toggle then collect_all_children(ch, out) end
		end
		return out
	end

	local function update_children_visibility(show_children, instant)
		if show_children then
			local step = 0
			local function show_branch(node)
				local kids = node.children
				if not kids then return end
				for i = 1, #kids do
					local ch = kids[i]
					if not ch.suppressed then
						step = step + 1
						ch.set_element_visible(true, (step - 1) * 0.025, instant, true)
						if ch.is_toggle and ch.enabled then show_branch(ch) end
					end
				end
			end
			show_branch(cfg)
		else
			local list = collect_all_children(cfg)
			local n = #list
			local step = 0
			for i = n, 1, -1 do
				local item = list[i]
				if instant then
					item.set_element_visible(false, 0, true, true)
				elseif item.holder_instance and not item.holder_instance.Visible then
					item.set_element_visible(false, 0, true, true)
				else
					item.set_element_visible(false, step * 0.025, false, true)
					step = step + 1
				end
			end
		end
	end

	function cfg.set(bool, instant, silent)
		bool = bool == true
		cfg.enabled = bool
		library:set_theme_state(text, "TextColor3", bool and "accent" or "text")
		if instant then
			local stored = ensure_fade_base(accent)
			if stored then stored.BackgroundTransparency = bool and 0 or 1 end
			accent.BackgroundTransparency = bool and 0 or 1
			text.TextColor3 = bool and themes.preset.accent or themes.preset.text
		else
			library:tween(accent, { BackgroundTransparency = bool and 0 or 1 })
			library:tween(text, { TextColor3 = bool and themes.preset.accent or themes.preset.text })
		end
		flags[cfg.flag] = bool
		update_children_visibility(bool and cfg.is_visible, instant)
		library:relayout(cfg.holder)
		if not silent then cfg.callback(bool) end
	end

	function cfg.set_element_visible(bool, delay_sec, instant, from_cascade)
		cfg.is_visible = bool
		library:animate_child_element(toggle_holder, 14, Enum.AutomaticSize.Y, bool, delay_sec, instant)
		if not from_cascade then
			if not bool then
				update_children_visibility(false, instant)
			elseif cfg.enabled then
				update_children_visibility(true, instant)
			end
		end
		library:relayout(cfg.holder)
	end

	library:connection(toggle_holder.MouseButton1Click, function()
		cfg.enabled = not cfg.enabled

		cfg.set(cfg.enabled)
	end)

	library:connection(toggle.MouseButton1Click, function()
		cfg.enabled = not cfg.enabled

		cfg.set(cfg.enabled)
	end)

	if cfg.tooltip then library:tool_tip({ name = cfg.tooltip, path = toggle_holder }) end

	library.toggle_registry[cfg.flag] = cfg
	if not parent_toggle and not self.is_toggle then self.last_toggle = cfg end

	cfg.set(cfg.default, true)
	cfg.set_element_visible(cfg.visible, 0, true)

	library.config_flags[cfg.flag] = cfg.set
	library.visible_flags[cfg.flag] = cfg.set_element_visible
	if parent_toggle then library:register_child(parent_toggle, cfg) end

	return setmetatable(cfg, library)
end


function library:textbox(options)
	local parent_toggle, indent = library:resolve_parent(self, options)
	local cfg = {
		placeholder = options.placeholder or options.placeholdertext or options.holder or options.holdertext or "type here...",
		default = options.default,
		flag = options.flag or "flag",
		callback = options.callback or function() end,
		visible = options.visible ~= false,
	}

	local textbox_holder = library:create("TextLabel", {
		Parent = self.holder,
		Name = "",
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = "",
		ZIndex = 2,
		Size = dim2(1, -8, 0, 12),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	library:create("UIPadding", {
		Parent = textbox_holder,
		Name = "",
		PaddingLeft = dim(0, 1),
	})

	library:create("UIStroke", {
		Parent = textbox_holder,
		Name = "",
	})

	local button = library:create("Frame", {
		Parent = textbox_holder,
		Name = "",
		Position = dim2(0, indent, 0, 2),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -27 - indent, 0, 18),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.outline,
	})
	library:hoverify(textbox_holder, button)

	library:apply_theme(button, "outline", "BackgroundColor3")

	local inline = library:create("Frame", {
		Parent = button,
		Name = "",
		Position = dim2(0, 1, 0, 1),
		ZIndex = 2,
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.inline,
	})

	library:apply_theme(inline, "inline", "BackgroundColor3")

	local background = library:create("Frame", {
		Parent = inline,
		Name = "",
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		ZIndex = 3,
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		BackgroundColor3 = themes.preset.inline,
	})

	local TextBox = library:create("TextBox", {
		Parent = background,
		Name = "",
		CursorPosition = -1,
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = "",
		Size = dim2(1, 0, 1, 0),
		BorderSizePixel = 0,
		TextWrapped = true,
		BackgroundTransparency = 1,
		TextTruncate = Enum.TextTruncate.SplitWord,
		PlaceholderText = cfg.placeholder,
		ClearTextOnFocus = false,
		ZIndex = 4,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	library:create("UIStroke", {
		Parent = TextBox,
		Name = "",
	})

	local TextButton = library:create("TextButton", {
		Parent = background,
		Name = "",
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextColor3 = rgb(0, 0, 0),
		BorderColor3 = rgb(0, 0, 0),
		Text = "",
		AutoButtonColor = false,
		Size = dim2(1, 0, 1, 0),
		BorderSizePixel = 0,
		TextSize = 14,
		ZIndex = 3,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	library.no_bg_fade[TextButton] = true

	local UIGradient = library:create("UIGradient", {
		Parent = TextButton,
		Name = "",
		Rotation = 90,
		Color = rgbseq({ rgbkey(0, themes.preset.low_contrast), rgbkey(1, themes.preset.high_contrast) }),
	})

	library:apply_theme(UIGradient, "contrast", "Color")

	library:create("UIListLayout", {
		Parent = textbox_holder,
		Name = "",
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		Padding = dim(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	TextBox:GetPropertyChangedSignal("Text"):Connect(function()
		flags[cfg.flag] = TextBox.Text
		cfg.callback(TextBox.Text)
	end)

	cfg.holder = self.holder
	cfg.holder_instance = textbox_holder
	library:track_layout(self.holder, cfg)
	function cfg.set_element_visible(bool, delay_sec, instant)
		cfg.is_visible = bool
		library:animate_child_element(textbox_holder, 20, Enum.AutomaticSize.Y, bool, delay_sec, instant)
	end

	function cfg.set(text)
		flags[cfg.flag] = text
		TextBox.Text = text
		cfg.callback(text)
	end

	if cfg.default then cfg.set(cfg.default) end

	cfg.set_element_visible(cfg.visible, 0, true)

	library.config_flags[cfg.flag] = cfg.set
	library.visible_flags[cfg.flag] = cfg.set_element_visible
	if parent_toggle then library:register_child(parent_toggle, cfg) end

	return setmetatable(cfg, library)
end


function library:button_holder(options)
	local cfg = {
		flag = options.flag or "hi",
		visible = options.visible ~= false,
	}

	local button_holder = library:create("TextLabel", {
		Parent = self.holder,
		Name = "",
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = "",
		ZIndex = 2,
		Size = dim2(1, -8, 0, 12),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	self.current_holder = button_holder

	library:create("UIStroke", {
		Parent = button_holder,
		Name = "",
	})

	library:create("UIListLayout", {
		Parent = button_holder,
		Name = "",
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		Padding = dim(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	function cfg.set_element_visible(bool)
		if button_holder.Visible == bool then return end
		if bool then
			button_holder.Visible = true
			library:play_fade(button_holder, true, 0.18)
		else
			library:play_fade(button_holder, false, 0.15, function() button_holder.Visible = false end)
		end
	end

	cfg.set_element_visible(cfg.visible)

	library.visible_flags[cfg.flag] = cfg.set_element_visible

	return setmetatable(cfg, library)
end

function library:button(options)
	local cfg = {
		callback = options.callback or function() end,
		name = options.text or options.name or "Button",
	}

	local button = library:create("TextButton", {
		Parent = self.current_holder,
		Name = "",
		Position = dim2(0, 0, 0, 2),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -27, 0, 18),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.outline,
		Text = "",
	})

	library:hoverify(button, button)

	library:apply_theme(button, "outline", "BackgroundColor3")

	local inline = library:create("Frame", {
		Parent = button,
		Name = "",
		ZIndex = 2,
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		BackgroundColor3 = themes.preset.inline,
	})

	library:apply_theme(inline, "inline", "BackgroundColor3")

	local contrast = library:create("Frame", {
		Parent = inline,
		Name = "",
		ZIndex = 3,
		Position = dim2(0, 1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(1, -2, 1, -2),
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	library.no_bg_fade[contrast] = true

	local UIGradient = library:create("UIGradient", {
		Parent = contrast,
		Name = "",
		Rotation = 90,
		Color = rgbseq({ rgbkey(0, themes.preset.low_contrast), rgbkey(1, themes.preset.high_contrast) }),
	})

	library:apply_theme(UIGradient, "contrast", "Color")

	local text = library:create("TextLabel", {
		Parent = contrast,
		Name = "",
		TextWrapped = true,
		ZIndex = 4,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = cfg.name,
		Size = dim2(1, -4, 1, 0),
		Position = dim2(0, 4, 0, -1),
		BackgroundTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BorderSizePixel = 0,
		FontFace = library.font,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local UIStroke = library:create("UIStroke", {
		Parent = text,
		Name = "",
		LineJoinMode = Enum.LineJoinMode.Miter,
	})

	button.MouseButton1Click:Connect(function() cfg.callback() end)

	return setmetatable(cfg, library)
end


function library:label(options)
	local parent_toggle, indent = library:resolve_parent(self, options)
	local raw_name = options.text or options.name or "Label"
	local cfg = {
		name = raw_name,
		flag = options.flag or tostring(random(1, 9999999)),
		visible = options.visible ~= false,
	}

	local dropdown = library:create("TextLabel", {
		Parent = self.holder,
		Name = "",
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = "",
		ZIndex = 2,
		Size = dim2(1, -8, 0, 12),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local UIStroke = library:create("UIStroke", {
		Parent = dropdown,
		Name = "",
	})

	local left_components = library:create("Frame", {
		Parent = dropdown,
		Name = "",
		BackgroundTransparency = 1,
		Position = dim2(0, 2 + indent, 0, -1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(0, 0, 0, 14),
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local TextLabel = library:create("TextLabel", {
		Parent = left_components,
		Name = "",
		FontFace = library.font,
		TextColor3 = themes.preset.text,
		BorderColor3 = rgb(0, 0, 0),
		Text = cfg.name,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 12,
		BackgroundColor3 = rgb(255, 255, 255),
	})

	local right_components = library:create("Frame", {
		Parent = dropdown,
		Name = "right_components",
		BackgroundTransparency = 1,
		Position = dim2(1, -1, 0, 1),
		BorderColor3 = rgb(0, 0, 0),
		Size = dim2(0, 0, 0, 12),
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(255, 255, 255),
	})
	cfg.right_holder = right_components

	local list = library:create("UIListLayout", {
		Parent = right_components,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = dim(0, 4),
		Name = "list",
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local UIStroke = library:create("UIStroke", {
		Parent = TextLabel,
		Name = "",
	})

	function cfg.set(text) TextLabel.Text = tostring(text) end

	cfg.holder = self.holder
	cfg.holder_instance = dropdown
	library:track_layout(self.holder, cfg)
	function cfg.set_element_visible(bool, delay_sec, instant)
		cfg.is_visible = bool
		library:animate_child_element(dropdown, 14, Enum.AutomaticSize.Y, bool, delay_sec, instant)
	end

	cfg.set_element_visible(cfg.visible, 0, true)
	library.visible_flags[cfg.flag] = cfg.set_element_visible
	if parent_toggle then library:register_child(parent_toggle, cfg) end

	return setmetatable(cfg, library)
end

return library, themes
