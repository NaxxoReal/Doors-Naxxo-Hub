--==================================================
-- LOCAL USERID VERIFICATION + UI + FARM (FINAL)
--==================================================

-- 🔒 USERID WHITELIST
-- expiry can be:
--   nil                -> lifetime
--   seconds timestamp  -> OK
--   milliseconds       -> OK (auto-normalized)
local ALLOWED_USERS = {
	[8693341003] = { expiry = nil }, -- naxxoisme
	[7279642207] = { expiry = nil }, -- diegohsuperportal
}

-- 👑 ADMINS (client-side)
local ADMINS = {
	[8693341003] = true, -- naxxoisme
}

-- 📺 Tutorial link
local TUTORIAL_URL = "https://www.youtube.com/watch?v=FHQLqaSwFQs"

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
		authorizedAt = os.clock()
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

local statsGui = Instance.new("ScreenGui", CoreGui)
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

local statTime = stat(20, "Time Left: ...")
local statFarm = stat(40, "Farm: OFF")
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
	while authorized do
		statFarm.Text = "Farm: " .. (farmenabled and "ON" or "OFF")
		statIter.Text = "Iterations: " .. farmIterations
		statUp.Text = "Uptime: " .. math.floor(os.clock() - authorizedAt) .. "s"

		if userExpiry == nil then
			statTime.Text = "Time Left: Lifetime"
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

			statTime.Text = "Time Left: " .. formatTimeLeft(remaining)
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

--==================================================
-- ANTI-AFK
--==================================================

player.Idled:Connect(function()
	game:GetService("VirtualUser"):CaptureController()
	game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

--==================================================
-- FARM GUI + LOGIC + TUTORIAL BUTTON
--==================================================

local farmGui = Instance.new("ScreenGui", CoreGui)
farmGui.ResetOnSpawn = false
farmGui.IgnoreGuiInset = true

local button = Instance.new("TextButton", farmGui)
button.Size = UDim2.new(0,200,0,50)
button.Position = UDim2.new(0,10,1,-150)
button.Text = "Knob Farm: OFF"
button.Font = Enum.Font.GothamBold
button.TextSize = 24
button.TextColor3 = Color3.new(1,1,1)
button.BackgroundColor3 = Color3.fromRGB(255,69,58)
button.BorderSizePixel = 0
Instance.new("UICorner", button).CornerRadius = UDim.new(0,12)

local tutorialButton = Instance.new("TextButton", farmGui)
tutorialButton.Size = UDim2.new(0,200,0,50)
tutorialButton.Position = UDim2.new(0,220,1,-150)
tutorialButton.Text = "TUTORIAL"
tutorialButton.Font = Enum.Font.GothamBold
tutorialButton.TextSize = 24
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

local function startFarm()
	task.spawn(function()
		setStatus("Farm Running", Color3.fromRGB(52,199,89), "pulse")
		while farmenabled do
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

button.MouseButton1Click:Connect(function()
	farmenabled = not farmenabled
	if farmenabled then
		button.Text = "Knob Farm: ON"
		button.BackgroundColor3 = Color3.fromRGB(52,199,89)
		startFarm()
	else
		stopPulse()
		setStatus("Verified", Color3.fromRGB(52,199,89))
		button.Text = "Knob Farm: OFF"
		button.BackgroundColor3 = Color3.fromRGB(255,69,58)
	end
end)
