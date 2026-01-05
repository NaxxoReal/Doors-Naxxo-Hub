--==================================================
-- Naxxo Hub (Roblox Lua)		
local UNLOADED = false
local CONNECTIONS = {}

local ALLOWED_USERS = {
	[8693341003] = { expiry = nil }, -- naxxoisme
	[7279642207] = { expiry = nil }, -- diegohsuperportal
}

-- 👑 ADMINS (client-side)
local ADMINS = {
	[8693341003] = true, -- naxxoisme
}

-- 📺 Tutorial link
local TUTORIAL_URL = "https://www.youtube.com/watch?v=BhmzbDAds5U"

-- ⏳ Verify cooldown after denial
local DENY_COOLDOWN = 10

-- ⏱️ COUNTDOWN COLOR THRESHOLDS (seconds)
local WARN_TIME = 60 * 60      -- 1 hour → yellow
local CRITICAL_TIME = 5 * 60   -- 5 minutes → red

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService") -- ✅ chat fix
local player = Players.LocalPlayer

local authorized = false
local farmenabled = false
local farmIterations = 0
local authorizedAt = 0
local userExpiry = nil

--==================================================
-- EXPIRY NORMALIZER (FIXES ms vs s BUG)
--==================================================

local function normalizeExpiry(expiry)
	if expiry == nil then return nil end
	if type(expiry) ~= "number" then return nil end
	if expiry > 1e12 then
		return math.floor(expiry / 1000)
	end
	return expiry
end

--==================================================
-- EXTEND AMOUNT PARSER (m / h / d / timestamp)
--==================================================

local function parseExtendAmount(arg)
	if not arg then return nil, false end
	if tonumber(arg) then
		return normalizeExpiry(tonumber(arg)), true
	end

	local value, unit = arg:match("^(%d+)([mhd])$")
	value = tonumber(value)
	if not value then return nil, false end

	if unit == "m" then return value * 60, false end
	if unit == "h" then return value * 3600, false end
	if unit == "d" then return value * 86400, false end

	return nil, false
end

--==================================================
-- STATUS BANNER (ANIMATED)
--==================================================

local statusGui = Instance.new("ScreenGui", CoreGui)
statusGui.ResetOnSpawn = false
statusGui.IgnoreGuiInset = true

local banner = Instance.new("TextLabel", statusGui)
banner.Size = UDim2.new(0, 260, 0, 36)
banner.Position = UDim2.new(0.5, -130, 0, 20)
banner.BackgroundColor3 = Color3.fromRGB(120,120,120)
banner.TextColor3 = Color3.new(1,1,1)
banner.Font = Enum.Font.GothamBold
banner.TextSize = 14
banner.BorderSizePixel = 0
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)

local basePos = banner.Position
local pulseConn

local function stopPulse()
	if pulseConn then pulseConn:Disconnect() pulseConn = nil end
end

local function pulseBanner()
	stopPulse()
	local t = 0
	pulseConn = RunService.RenderStepped:Connect(function(dt)
		t += dt * 2
		local a = (math.sin(t) + 1) / 2
		banner.BackgroundTransparency = 0.15 + a * 0.15
	end)
end

local function shakeBanner()
	for _ = 1, 6 do
		banner.Position = basePos + UDim2.new(0, math.random(-6,6), 0, 0)
		task.wait(0.03)
	end
	banner.Position = basePos
end

local function setStatus(text, color, anim)
	stopPulse()
	banner.Text = "Status: " .. text
	TweenService:Create(
		banner,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{ BackgroundColor3 = color, BackgroundTransparency = 0 }
	):Play()

	if anim == "shake" then
		shakeBanner()
	elseif anim == "pulse" then
		pulseBanner()
	end
end

setStatus("Not Verified", Color3.fromRGB(120,120,120))

--==================================================
-- TOASTS
--==================================================

local toastGui = Instance.new("ScreenGui", CoreGui)
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true

local function toast(text, bad)
	local f = Instance.new("Frame", toastGui)
	f.Size = UDim2.new(0, 340, 0, 42)
	f.Position = UDim2.new(0.5, -170, 1, -30)
	f.AnchorPoint = Vector2.new(0.5,1)
	f.BackgroundColor3 = bad and Color3.fromRGB(255,69,58) or Color3.fromRGB(52,199,89)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)

	local t = Instance.new("TextLabel", f)
	t.Size = UDim2.new(1,-20,1,0)
	t.Position = UDim2.new(0,10,0,0)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1,1,1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text

	TweenService:Create(f, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
	task.delay(1.6, function()
		TweenService:Create(f, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		f:Destroy()
	end)
end

--==================================================
-- VERIFY GUI
--==================================================

local verifyGui = Instance.new("ScreenGui", CoreGui)
verifyGui.ResetOnSpawn = false
verifyGui.IgnoreGuiInset = true

local frame = Instance.new("Frame", verifyGui)
frame.Size = UDim2.new(0, 320, 0, 160)
frame.Position = UDim2.new(0.5, -160, 0.5, -80)
frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,50)
title.Text = "Verification Required"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1

local verify = Instance.new("TextButton", frame)
verify.Size = UDim2.new(1,-40,0,45)
verify.Position = UDim2.new(0,20,0,80)
verify.Text = "Verify"
verify.Font = Enum.Font.GothamBold
verify.TextSize = 18
verify.TextColor3 = Color3.new(1,1,1)
verify.BackgroundColor3 = Color3.fromRGB(52,199,89)
verify.BorderSizePixel = 0
Instance.new("UICorner", verify).CornerRadius = UDim.new(0,10)

local cooldown = false

local function denyCooldown()
	cooldown = true
	for i = DENY_COOLDOWN,1,-1 do
		verify.Text = "Wait "..i.."s"
		verify.BackgroundColor3 = Color3.fromRGB(255,69,58)
		task.wait(1)
	end
	verify.Text = "Verify"
	verify.BackgroundColor3 = Color3.fromRGB(52,199,89)
	cooldown = false
end

verify.MouseButton1Click:Connect(function()
	if cooldown then return end

	local record = ALLOWED_USERS[player.UserId]
	local expiry = record and normalizeExpiry(record.expiry)

	if record and (expiry == nil or os.time() <= expiry) then
		authorized = true
		authorizedAt = os.time()
		userExpiry = expiry
		setStatus("Verified", Color3.fromRGB(52,199,89))
		toast("Verified successfully", false)
		verifyGui:Destroy()
	else
		setStatus("Access Denied", Color3.fromRGB(255,69,58), "shake")
		toast("Access denied", true)
		denyCooldown()
	end
end)

--==================================================
-- AUTH GATE
--==================================================

repeat task.wait() until authorized

--==================================================
-- ADMIN CHAT COMMANDS: /extend and /revoke (CLIENT-SIDE)
-- FIXED: legacy chat + TextChatService
--==================================================

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function handleAdminCommand(msg)
	if not ADMINS[player.UserId] then return end
	if type(msg) ~= "string" then return end
	msg = trim(msg)

	-- /extend <userid> <amount>
	do
		local targetIdStr, amountStr = msg:match("^/extend%s+(%d+)%s+(.+)$")
		if targetIdStr and amountStr then
			local targetId = tonumber(targetIdStr)
			local value, isAbsolute = parseExtendAmount(amountStr)
			if not targetId or not value then
				toast("Invalid /extend usage", true)
				return
			end

			local record = ALLOWED_USERS[targetId]
			if not record then
				toast("User not in whitelist", true)
				return
			end

			local now = os.time()
			local current = normalizeExpiry(record.expiry)
			record.expiry = isAbsolute and value or ((current and current > now) and current + value or now + value)

			if targetId == player.UserId then
				userExpiry = record.expiry
			end

			toast("Extended user "..targetId, false)
			return
		end
	end

	-- /revoke <userid>
	do
		local targetIdStr = msg:match("^/revoke%s+(%d+)%s*$")
		if targetIdStr then
			local targetId = tonumber(targetIdStr)
			local record = ALLOWED_USERS[targetId]
			if not record then
				toast("User not in whitelist", true)
				return
			end

			record.expiry = 0
			if targetId == player.UserId then
				userExpiry = 0
			end

			toast("Revoked access for "..targetId, true)
			return
		end
	end
end

player.Chatted:Connect(handleAdminCommand)

TextChatService.MessageReceived:Connect(function(message)
	if message.TextSource and message.TextSource.UserId == player.UserId then
		handleAdminCommand(message.Text)
	end
end)

--==================================================
-- RUNTIME STATUS PANEL (TIME LEFT + COLOR + AUTO-KICK)
--==================================================

if false then

local statsGui = nil
statsGui.ResetOnSpawn = false
statsGui.IgnoreGuiInset = true

local statsFrame = Instance.new("Frame", statsGui)
statsFrame.Size = UDim2.new(0, 260, 0, 140)
statsFrame.Position = UDim2.new(1, -280, 0, 70)
statsFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
statsFrame.BorderSizePixel = 0
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 14)

local function stat(y, text)
	local t = Instance.new("TextLabel", statsFrame)
	t.Size = UDim2.new(1,-20,0,18)
	t.Position = UDim2.new(0,10,0,y)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1,1,1)
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	return t
end

local statTime = stat(20, "Expires At: ...")
local statFarm = stat(40, "Knob Farm: OFF")
local statUp = stat(60, "Uptime: 0s")
local statIter = stat(80, "Iterations: 0")

local function formatTimeLeft(seconds)
	local d = math.floor(seconds / 86400)
	local h = math.floor((seconds % 86400) / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%dd %dh %dm %ds", d, h, m, s)
end

task.spawn(function()
	while authorized and not UNLOADED do
		statFarm.Text = "Knob Farm: " .. (farmenabled and "ON" or "OFF")
		statIter.Text = "Iterations: " .. farmIterations
		statUp.Text = "Uptime: " .. math.floor(os.clock() - authorizedAt) .. "s"

		if userExpiry == nil then
			statTime.Text = "Expires At: Never"
			statTime.TextColor3 = Color3.fromRGB(52,199,89)
		else
			local remaining = userExpiry - os.time()
			if remaining <= 0 then
				farmenabled = false
				setStatus("Expired", Color3.fromRGB(255,149,0), "shake")
				toast("Your access has expired.", true)
				task.wait(1.5)
				player:Kick("Your access has expired.")
				break
			end

			statTime.Text = "Expires At: " .. formatTimeLeft(remaining)
			if remaining <= CRITICAL_TIME then
				statTime.TextColor3 = Color3.fromRGB(255,69,58)
			elseif remaining <= WARN_TIME then
				statTime.TextColor3 = Color3.fromRGB(255,214,10)
			else
				statTime.TextColor3 = Color3.fromRGB(52,199,89)
			end
		end

		task.wait(0.5)
	end
end)

end
--==================================================
-- ANTI-AFK
--==================================================

player.Idled:Connect(function()
	game:GetService("VirtualUser"):CaptureController()
	game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

--==================================================
-- SCRIPT HUB (MAIN / SETTINGS)
--==================================================

local UserInputService = game:GetService("UserInputService")

-- Hub keybind settings
local HUB_KEY = Enum.KeyCode.RightShift
local keybindEnabled = true
local hubVisible = true

local hubGui = Instance.new("ScreenGui", CoreGui)
hubGui.ResetOnSpawn = false
hubGui.IgnoreGuiInset = true

local hub = Instance.new("Frame", hubGui)
hub.Size = UDim2.new(0, 420, 0, 260)
hub.Position = UDim2.new(0.5, -180, 0.6, -130)
hub.BackgroundColor3 = Color3.fromRGB(20,20,20)
hub.BorderSizePixel = 0
Instance.new("UICorner", hub).CornerRadius = UDim.new(0,14)

hub.Active = true
hub.Draggable = true

-- Title
local title = Instance.new("TextLabel", hub)
title.Size = UDim2.new(1,0,0,45)
title.Text = "Naxxo Hub"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1

-- Tabs bar
local tabBar = Instance.new("Frame", hub)
tabBar.Size = UDim2.new(1,0,0,40)
tabBar.Position = UDim2.new(0,0,0,45)
tabBar.BackgroundTransparency = 1

local tabIndicator = Instance.new("Frame", tabBar)
tabIndicator.Size = UDim2.new(1/3, -14, 0, 4)
tabIndicator.Position = UDim2.new(0, 7, 1, -4)
tabIndicator.BackgroundColor3 = Color3.fromRGB(52,199,89)
tabIndicator.BorderSizePixel = 0
Instance.new("UICorner", tabIndicator).CornerRadius = UDim.new(1, 0)

local function createTabButton(text, pos)
	local b = Instance.new("TextButton", tabBar)
	b.Size = UDim2.new(1/3, -14, 1, 0)
    b.Position = UDim2.new(pos, 7, 0, 0)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.new(1,1,1)
	b.BackgroundColor3 = Color3.fromRGB(35,35,35)
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,10)
	return b
end

local infoTabBtn     = createTabButton("INFORMATION", 0)
local mainTabBtn     = createTabButton("MAIN", 1/3)
local settingsTabBtn = createTabButton("SETTINGS", 2/3)

-- Pages
local pages = Instance.new("Folder", hub)

local function createPage()
	local f = Instance.new("Frame", pages)
	f.Size = UDim2.new(1,-40,1,-110)
	f.Position = UDim2.new(0,20,0,100)
	f.BackgroundTransparency = 1
	f.Visible = false
	return f
end

local mainPage = createPage()
local settingsPage = createPage()
local infoPage = createPage()

infoPage.Visible = true
infoTabBtn.BackgroundColor3 = Color3.fromRGB(52,199,89)

local function switchTab(target)
	mainPage.Visible = target == mainPage
	settingsPage.Visible = target == settingsPage
	infoPage.Visible = target == infoPage

	mainTabBtn.BackgroundColor3 =
		target == mainPage and Color3.fromRGB(52,199,89) or Color3.fromRGB(35,35,35)

	settingsTabBtn.BackgroundColor3 =
		target == settingsPage and Color3.fromRGB(52,199,89) or Color3.fromRGB(35,35,35)

	infoTabBtn.BackgroundColor3 =
		target == infoPage and Color3.fromRGB(52,199,89) or Color3.fromRGB(35,35,35)

	-- 🔥 animate underline
	local goalX =
		target == infoPage and 0
		or target == mainPage and 1/3
		or 2/3

	TweenService:Create(
		tabIndicator,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(goalX, 7, 1, -4) }
	):Play()
end

infoTabBtn.MouseButton1Click:Connect(function()
	switchTab(infoPage)
end)

mainTabBtn.MouseButton1Click:Connect(function()
	switchTab(mainPage)
end)

settingsTabBtn.MouseButton1Click:Connect(function()
	switchTab(settingsPage)
end)

--==================================================
-- MAIN TAB (KNOB FARM + TUTORIAL)
--==================================================

local farmButton = Instance.new("TextButton", mainPage)
farmButton.Size = UDim2.new(1,0,0,50)
farmButton.Position = UDim2.new(0,0,0,0)
farmButton.Text = "KNOB FARM: OFF"
farmButton.Font = Enum.Font.GothamBold
farmButton.TextSize = 18
farmButton.TextColor3 = Color3.new(1,1,1)
farmButton.BackgroundColor3 = Color3.fromRGB(255,69,58)
farmButton.BorderSizePixel = 0
Instance.new("UICorner", farmButton).CornerRadius = UDim.new(0,12)

local tutorialButton = Instance.new("TextButton", mainPage)
tutorialButton.Size = UDim2.new(1,0,0,50)
tutorialButton.Position = UDim2.new(0,0,0,60)
tutorialButton.Text = "KNOB FARM TUTORIAL"
tutorialButton.Font = Enum.Font.GothamBold
tutorialButton.TextSize = 18
tutorialButton.TextColor3 = Color3.new(1,1,1)
tutorialButton.BackgroundColor3 = Color3.fromRGB(0,122,255)
tutorialButton.BorderSizePixel = 0
Instance.new("UICorner", tutorialButton).CornerRadius = UDim.new(0,12)

tutorialButton.MouseButton1Click:Connect(function()
	if setclipboard then
		setclipboard(TUTORIAL_URL)
		toast("Tutorial video has been copied to your clipboard.", false)
	else
		toast("Clipboard not supported.", true)
	end
end)

--==================================================
-- SETTINGS TAB (KEYBIND TOGGLE)
--==================================================

local keybindToggle = Instance.new("TextButton", settingsPage)
keybindToggle.Size = UDim2.new(1,0,0,50)
keybindToggle.Position = UDim2.new(0,0,0,0)
keybindToggle.Font = Enum.Font.GothamBold
keybindToggle.TextSize = 16
keybindToggle.TextColor3 = Color3.new(1,1,1)
keybindToggle.BorderSizePixel = 0
Instance.new("UICorner", keybindToggle).CornerRadius = UDim.new(0,12)

local function updateKeybindUI()
	keybindToggle.Text = "Hub Keybind: "..HUB_KEY.Name.." ["..(keybindEnabled and "ON" or "OFF").."]"
	keybindToggle.BackgroundColor3 = keybindEnabled
		and Color3.fromRGB(52,199,89)
		or Color3.fromRGB(255,69,58)
end

updateKeybindUI()

keybindToggle.MouseButton1Click:Connect(function()
	keybindEnabled = not keybindEnabled
	updateKeybindUI()
	toast("Hub keybind "..(keybindEnabled and "enabled" or "disabled"), not keybindEnabled)
end)

-- Unload button (SETTINGS tab)
local unloadButton = Instance.new("TextButton", settingsPage)
unloadButton.Size = UDim2.new(1, 0, 0, 50)
unloadButton.Position = UDim2.new(0, 0, 0, 60)
unloadButton.BackgroundColor3 = Color3.fromRGB(255,69,58)
unloadButton.TextColor3 = Color3.new(1,1,1)
unloadButton.Font = Enum.Font.GothamBold
unloadButton.TextSize = 18
unloadButton.BorderSizePixel = 0
unloadButton.Text = "UNLOAD"
Instance.new("UICorner", unloadButton).CornerRadius = UDim.new(0, 12)
unloadButton.MouseButton1Click:Connect(function()
	if UNLOADED then return end
	UNLOADED = true

	-- Stop farm
	farmenabled = false

	-- Disconnect all tracked connections
	for _, conn in ipairs(CONNECTIONS) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(CONNECTIONS)

	-- Destroy all GUIs created by this script
	for _, gui in ipairs(CoreGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			pcall(function()
				gui:Destroy()
			end)
		end
	end

	-- Final confirmation (best-effort)
	pcall(function()
		warn("[Naxxo Hub] Script unloaded.")
	end)
end)

--==================================================
-- HUB KEYBIND VISIBILITY TOGGLE
--==================================================

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if keybindEnabled and input.KeyCode == HUB_KEY then
		hubVisible = not hubVisible
		hub.Visible = hubVisible
	end
end)

-- Player avatar (INFORMATION tab)
local infoAvatar = Instance.new("ImageLabel", infoPage)
infoAvatar.Size = UDim2.new(0, 36, 0, 36)
infoAvatar.Position = UDim2.new(0, 10, 0, 0)
infoAvatar.BackgroundTransparency = 1
infoAvatar.Image = Players:GetUserThumbnailAsync(
	player.UserId,
	Enum.ThumbnailType.HeadShot,
	Enum.ThumbnailSize.Size100x100
)
Instance.new("UICorner", infoAvatar).CornerRadius = UDim.new(1, 0)

-- Username header (INFORMATION tab)
local infoUsername = Instance.new("TextLabel", infoPage)
infoUsername.Size = UDim2.new(1, -20, 0, 36)
infoUsername.Position = UDim2.new(0, 54, 0, 0)
infoUsername.BackgroundTransparency = 1
infoUsername.Text = "User: " .. player.Name
infoUsername.Font = Enum.Font.GothamBold
infoUsername.TextSize = 20
infoUsername.TextColor3 = Color3.fromRGB(255,255,255)
infoUsername.TextXAlignment = Enum.TextXAlignment.Left

-- Status badge
local infoBadge = Instance.new("TextLabel", infoPage)
infoBadge.Size = UDim2.new(0, 90, 0, 22)
infoBadge.Position = UDim2.new(1, -100, 0, 7)
infoBadge.BackgroundColor3 = Color3.fromRGB(52,199,89)
infoBadge.TextColor3 = Color3.new(1,1,1)
infoBadge.Font = Enum.Font.GothamBold
infoBadge.TextSize = 12
infoBadge.BorderSizePixel = 0
infoBadge.Text = "VERIFIED"
Instance.new("UICorner", infoBadge).CornerRadius = UDim.new(1, 0)

--==================================================
-- INFORMATION TAB (RUNTIME STATUS – DUPLICATE VIEW)
--==================================================

local function infoStat(y, text)
	local t = Instance.new("TextLabel", infoPage)
	t.Size = UDim2.new(1,-20,0,18)
	t.Position = UDim2.new(0,10,0,y)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1,1,1)
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	return t
end

local infoTime = infoStat(38, "Expires At: ...")

task.spawn(function()
	while authorized and not UNLOADED do
		-- Status badge update
         if userExpiry == nil then
	        infoBadge.Text = "LIFETIME"
	        infoBadge.BackgroundColor3 = Color3.fromRGB(52,199,89)
        else
	        infoBadge.Text = "VERIFIED"
	        infoBadge.BackgroundColor3 = Color3.fromRGB(0,122,255)
        end

		if userExpiry == nil then
	infoTime.Text = "Expires At: Never"
	infoTime.TextColor3 = Color3.fromRGB(52,199,89)

	-- Progress bar (lifetime)
	expiryBarFill.Size = UDim2.new(1, 0, 1, 0)
	expiryBarFill.BackgroundColor3 = Color3.fromRGB(52,199,89)
else
	local remaining = userExpiry - os.time()
	infoTime.Text = "Expires At: " .. formatTimeLeft(remaining)

	-- Progress bar (timed)
	local total = userExpiry - authorizedAt
	local ratio = math.clamp(remaining / total, 0, 1)
	expiryBarFill.Size = UDim2.new(ratio, 0, 1, 0)

	if remaining <= CRITICAL_TIME then
		infoTime.TextColor3 = Color3.fromRGB(255,69,58)
		expiryBarFill.BackgroundColor3 = Color3.fromRGB(255,69,58)
	elseif remaining <= WARN_TIME then
		infoTime.TextColor3 = Color3.fromRGB(255,214,10)
		expiryBarFill.BackgroundColor3 = Color3.fromRGB(255,214,10)
	else
		infoTime.TextColor3 = Color3.fromRGB(52,199,89)
		expiryBarFill.BackgroundColor3 = Color3.fromRGB(52,199,89)
	end
end

		task.wait(0.5)
	end
end)

-- Expiry progress bar background
local expiryBarBg = Instance.new("Frame", infoPage)
expiryBarBg.Size = UDim2.new(1, -20, 0, 6)
expiryBarBg.Position = UDim2.new(0, 10, 0, 58)
expiryBarBg.BackgroundColor3 = Color3.fromRGB(60,60,60)
expiryBarBg.BorderSizePixel = 0
Instance.new("UICorner", expiryBarBg).CornerRadius = UDim.new(1, 0)

-- Expiry progress bar fill
local expiryBarFill = Instance.new("Frame", expiryBarBg)
expiryBarFill.Size = UDim2.new(1, 0, 1, 0)
expiryBarFill.BackgroundColor3 = Color3.fromRGB(52,199,89)
expiryBarFill.BorderSizePixel = 0
Instance.new("UICorner", expiryBarFill).CornerRadius = UDim.new(1, 0)

-- Copy UserID button (INFORMATION tab)
local copyIdButton = Instance.new("TextButton", infoPage)
copyIdButton.Size = UDim2.new(1, -20, 0, 40)
copyIdButton.Position = UDim2.new(0, 10, 0, 82)
copyIdButton.BackgroundColor3 = Color3.fromRGB(0,122,255)
copyIdButton.TextColor3 = Color3.new(1,1,1)
copyIdButton.Font = Enum.Font.GothamBold
copyIdButton.TextSize = 16
copyIdButton.BorderSizePixel = 0
copyIdButton.Text = "Copy UserID"
Instance.new("UICorner", copyIdButton).CornerRadius = UDim.new(0, 12)
copyIdButton.MouseButton1Click:Connect(function()
	if setclipboard then
		setclipboard(tostring(player.UserId))
		toast("UserID copied to clipboard.", false)
	else
		toast("Clipboard not supported.", true)
	end
end)

--==================================================
-- FARM LOGIC (SAME AS BEFORE)
--==================================================

local function startFarm()
	task.spawn(function()
		setStatus("Farm Running", Color3.fromRGB(52,199,89), "pulse")
		while farmenabled and not UNLOADED do
			replicatesignal(player.Kill)
			game:GetService("ReplicatedStorage")
				:WaitForChild("RemotesFolder")
				:WaitForChild("Statistics")
				:FireServer()
			farmIterations += 1
			task.wait(0.25)
		end
	end)
end

farmButton.MouseButton1Click:Connect(function()
	farmenabled = not farmenabled
	if farmenabled then
		farmButton.Text = "KNOB FARM: ON"
		farmButton.BackgroundColor3 = Color3.fromRGB(52,199,89)
		startFarm()
	else
		stopPulse()
		setStatus("Verified", Color3.fromRGB(52,199,89))
		farmButton.Text = "KNOB FARM: OFF"
		farmButton.BackgroundColor3 = Color3.fromRGB(255,69,58)
	end
end)
