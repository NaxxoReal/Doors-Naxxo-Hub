--==================================================
-- LOCAL USERID VERIFICATION + UI + FARM
--==================================================

-- 🔒 USERID WHITELIST
local ALLOWED_USERS = {
	[8693341003] = { expiry = nil }, -- naxxoisme
	[7279642207] = { expiry = nil }, -- diegohsuperportal
}

-- ⏳ Verify cooldown after denial
local DENY_COOLDOWN = 10

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local authorized = false
local farmenabled = false
local farmIterations = 0
local authorizedAt = 0

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
banner.Text = "Status: Not Verified"
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)

local basePos = banner.Position
local pulseConn

local function stopPulse()
	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end
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
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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
	if record and (record.expiry == nil or os.time() <= record.expiry) then
		authorized = true
		authorizedAt = os.clock()
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
-- RUNTIME STATUS PANEL
--==================================================

local statsGui = Instance.new("ScreenGui", CoreGui)
statsGui.ResetOnSpawn = false
statsGui.IgnoreGuiInset = true

local statsFrame = Instance.new("Frame", statsGui)
statsFrame.Size = UDim2.new(0, 240, 0, 120)
statsFrame.Position = UDim2.new(1, -260, 0, 70)
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

local statFarm = stat(20, "Farm: OFF")
local statIter = stat(40, "Iterations: 0")
local statUp = stat(60, "Uptime: 0s")

task.spawn(function()
	while true do
		statFarm.Text = "Farm: " .. (farmenabled and "ON" or "OFF")
		statIter.Text = "Iterations: " .. farmIterations
		statUp.Text = "Uptime: " .. math.floor(os.clock() - authorizedAt) .. "s"
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
-- FARM GUI + LOGIC
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
