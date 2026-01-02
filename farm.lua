game:GetService("Players").LocalPlayer.Idled:connect(function()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
local farmenabled = false
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KnobFarmGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui
local button = Instance.new("TextButton")
button.Parent = screenGui
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(0, 10, 1, -150)
button.Text = "Knob Farm: OFF"
button.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 24
button.BorderSizePixel = 0
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = button

local function startFarm()
    while farmenabled do
        replicatesignal(player.Kill)
        game:GetService("ReplicatedStorage"):WaitForChild("RemotesFolder"):WaitForChild("Statistics"):FireServer()
        wait(0.25)
    end
end    


button.MouseButton1Click:Connect(function()
    farmenabled = not farmenabled
    if farmenabled then
        button.Text = "Knob Farm: ON"
        button.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
        startFarm()
    else
        button.Text = "Knob Farm: OFF"
        button.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
    end
end)
