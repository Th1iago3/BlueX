-- Prevent Duplicate Injection on Game
if game:GetService("CoreGui"):FindFirstChild("UltimateSuiteGui") then
    return
end

-- Import Modules To Run
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local visibilityRaycastParams = RaycastParams.new()
visibilityRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Main
local Aimbot = {}
local lockedTarget = nil
local isAiming = false
local velocityHistory = {}
local accelerationHistory = {}
local pingHistory = {}

RunService.Heartbeat:Connect(function(dt)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character and plr.Character.PrimaryPart then
            local currentVel = plr.Character.PrimaryPart.AssemblyLinearVelocity
            accelerationHistory[plr] = (currentVel - (velocityHistory[plr] or Vector3.zero)) / dt
            velocityHistory[plr] = currentVel
            pingHistory[plr] = (pingHistory[plr] or 0) * 0.9 + dt * 0.1
        end
    end
end)

local state = {
    aimEnabled = false,
    visibleCheck = true,
    teamCheckEnabled = false,
    fovDegrees = 10, -- Increased for better target acquisition
    aimDistance = 500,
    smoothAim = true,
    smoothSpeed = 0.2, -- Adjusted for smoother aim
    prediction = 0.1, -- Fine-tuned for better prediction
    aimPart = "Head",
    aimPriority = "Distance",
    espEnabled = false,
}

local non_enemies = {}
local did_map = false
local espDrawings = {}

-- Utils
local function isAlive(character)
    local hum = character and character:FindFirstChildWhichIsA("Humanoid")
    return hum and hum.Health > 0
end

local function getPartFromCharacter(character, name)
    return character and character:FindFirstChild(name)
end

local function isGameTeammate(plr)
    return plr.Team == LocalPlayer.Team
end

local function isManualFriend(plr)
    return non_enemies[plr.UserId] == true
end

local function isPartVisible(part)
    if not part then return false end
    local camPos = Camera.CFrame.Position
    local dir = (part.Position - camPos)
    visibilityRaycastParams.FilterDescendantsInstances = {LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(), Camera}
    local res = workspace:Raycast(camPos, dir, visibilityRaycastParams)
    return not res or res.Instance:IsDescendantOf(part.Parent)
end

local function isPlayerVisible(player)
    local targetPart = player.Character and player.Character:FindFirstChild(state.aimPart)
    return isPartVisible(targetPart)
end

local function isEnemy(plr)
    if plr == LocalPlayer or not plr.Character or not plr.Character.PrimaryPart or not isAlive(plr.Character) then return false end
    local isTeammate
    if state.teamCheckEnabled then
        isTeammate = isGameTeammate(plr)
    else
        isTeammate = isManualFriend(plr)
    end
    return not isTeammate
end

local function isValidTarget(plr)
    if not isEnemy(plr) then return false end
    local char = plr.Character
    local part = getPartFromCharacter(char, state.aimPart)
    if not part then return false end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local dist = (part.Position - hrp.Position).Magnitude
    if dist > state.aimDistance then return false end
    return true
end

local function getClosestVisibleTarget(returnPlayer)
    local cam = Camera
    local camPos = cam.CFrame.Position
    local camLook = cam.CFrame.LookVector
    local bestAngle = math.rad(state.fovDegrees / 2)
    local candidates = {}
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    for _, plr in pairs(Players:GetPlayers()) do
        if isValidTarget(plr) then
            local part = plr.Character:FindFirstChild(state.aimPart)
            if part then
                local dir = (part.Position - camPos)
                local dirUnit = dir.Unit
                local dot = camLook:Dot(dirUnit)
                local angle = math.acos(math.clamp(dot, -1, 1))
                if angle <= bestAngle then
                    local isVisible = not state.visibleCheck or isPartVisible(part)
                    if isVisible then
                        local hum = plr.Character:FindFirstChild("Humanoid")
                        local health = hum and hum.Health or 100
                        local dist = (part.Position - myHrp.Position).Magnitude
                        local threat = (100 - health) / 100 + (1 / dist)
                        table.insert(candidates, {plr = plr, part = part, angle = angle, health = health, dist = dist, threat = threat, isVisible = isVisible})
                    end
                end
            end
        end
    end
    if #candidates == 0 then return nil end
    local sortFunc
    if state.aimPriority == "Distance" then
        sortFunc = function(a, b)
            return a.dist < b.dist or (a.dist == b.dist and a.angle < b.angle)
        end
    elseif state.aimPriority == "Life" then
        sortFunc = function(a, b)
            return a.health < b.health or (a.health == b.health and a.angle < b.angle)
        end
    elseif state.aimPriority == "Distance + Life" then
        sortFunc = function(a, b)
            return a.threat > b.threat or (a.threat == b.threat and a.angle < b.angle)
        end
    end
    table.sort(candidates, sortFunc)
    local best = candidates[1]
    return returnPlayer and best.plr or best.part
end

local function aimAtTargetSmooth(targetPart, dt)
    if not targetPart then return end
    local cam = Camera
    local camPos = cam.CFrame.Position
    local vel = velocityHistory[lockedTarget] or Vector3.zero
    local acc = accelerationHistory[lockedTarget] or Vector3.zero
    local ping = pingHistory[lockedTarget] or 0
    local time = state.prediction + ping
    local predictedPos = targetPart.Position + vel * time + 0.5 * acc * time * time

    -- Convert target position to screen coordinates to check if within FOV
    local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
    if not onScreen then return end

    -- Smooth camera movement using spherical linear interpolation (slerp)
    local targetCFrame = CFrame.new(camPos, predictedPos)
    local currentCFrame = cam.CFrame
    local deltaAngle = math.acos(currentCFrame.LookVector:Dot(targetCFrame.LookVector))
    local t = math.clamp(state.smoothSpeed * dt * 60, 0, 1)
    local smoothedCFrame = currentCFrame:Lerp(targetCFrame, t)
    cam.CFrame = smoothedCFrame
end

local function performTeamMapping()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        did_map = true
        local my_pos = LocalPlayer.Character.HumanoidRootPart.Position
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (plr.Character.HumanoidRootPart.Position - my_pos).Magnitude
                if dist <= 1 and dist >= 0 then
                    non_enemies[plr.UserId] = true
                end
            end
        end
    end
end

-- GUI
local coreGui = game:GetService("CoreGui")

local function initGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltimateSuiteGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = coreGui
    screenGui.Enabled = false

    local mainWidth, mainHeight = 350, 450
    local main = Instance.new("Frame", screenGui)
    main.Name = "Main"
    main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
    main.Position = UDim2.new(0.5, -mainWidth/2, 0.5, -mainHeight/2)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    local uiCorner = Instance.new("UICorner", main)
    uiCorner.CornerRadius = UDim.new(0, 20)
    local uiShadow = Instance.new("UIStroke", main)
    uiShadow.Thickness = 3
    uiShadow.Color = Color3.fromRGB(0, 0, 0)
    uiShadow.Transparency = 0.5
    local uiGradient = Instance.new("UIGradient", main)
    uiGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
    }

    local header = Instance.new("Frame", main)
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundTransparency = 1
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(0.7, -12, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "BlueX"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 24
    title.TextColor3 = Color3.fromRGB(0, 170, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local tabFrame = Instance.new("ScrollingFrame", main)
    tabFrame.Position = UDim2.new(0, 10, 0, 50)
    tabFrame.Size = UDim2.new(1, -20, 1, -60)
    tabFrame.BackgroundTransparency = 1
    tabFrame.ScrollBarThickness = 5
    tabFrame.ScrollBarImageTransparency = 0.4
    tabFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabFrame.Visible = true

    local listLayout = Instance.new("UIListLayout", tabFrame)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)

    local function makeSlider(parent, labelText, min, max, initial, onChange, snap, scale, fmt)
        snap = snap or 1
        scale = scale or 1
        fmt = fmt or "%.0f"
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 40)
        container.BackgroundTransparency = 1
        local labelContainer = Instance.new("Frame", container)
        labelContainer.Size = UDim2.new(1, 0, 0, 20)
        labelContainer.Position = UDim2.new(0, 0, 0, 0)
        labelContainer.BackgroundTransparency = 1
        local label = Instance.new("TextLabel", labelContainer)
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        local init_real = initial / scale
        local valueLabel = Instance.new("TextLabel", labelContainer)
        valueLabel.Size = UDim2.new(0.3, 0, 1, 0)
        valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = string.format(fmt, init_real)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 14
        valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        local slider = Instance.new("Frame", container)
        slider.Position = UDim2.new(0, 0, 0, 20)
        slider.Size = UDim2.new(1, -10, 0, 10)
        slider.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        local sliderCorner = Instance.new("UICorner", slider)
        sliderCorner.CornerRadius = UDim.new(0, 5)
        local sliderGradient = Instance.new("UIGradient", slider)
        sliderGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
        }
        local sliderShadow = Instance.new("UIStroke", slider)
        sliderShadow.Thickness = 1
        sliderShadow.Color = Color3.fromRGB(0, 170, 255)
        sliderShadow.Transparency = 0.8
        local fill = Instance.new("Frame", slider)
        fill.Size = UDim2.new((initial - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        local fillCorner = Instance.new("UICorner", fill)
        fillCorner.CornerRadius = UDim.new(0, 5)
        local fillGradient = Instance.new("UIGradient", fill)
        fillGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 120, 200))
        }
        local fillStroke = Instance.new("UIStroke", fill)
        fillStroke.Thickness = 1
        fillStroke.Color = Color3.fromRGB(0, 200, 255)
        fillStroke.Transparency = 0.5
        local dragging = false
        slider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local rel = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
                local value = min + rel * (max - min)
                value = math.round(value / snap) * snap
                local real = value / scale
                valueLabel.Text = string.format(fmt, real)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                if onChange then pcall(onChange, real) end
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        return container
    end

    local settingsLabel = Instance.new("TextLabel", tabFrame)
    settingsLabel.Size = UDim2.new(1, 0, 0, 30)
    settingsLabel.BackgroundTransparency = 1
    settingsLabel.Text = "Settings"
    settingsLabel.Font = Enum.Font.GothamBold
    settingsLabel.TextSize = 18
    settingsLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    settingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local aimRow = Instance.new("Frame", tabFrame)
    aimRow.Size = UDim2.new(1, 0, 0, 40)
    aimRow.BackgroundTransparency = 1
    local aimLabel = Instance.new("TextLabel", aimRow)
    aimLabel.Size = UDim2.new(0.6, 0, 1, 0)
    aimLabel.BackgroundTransparency = 1
    aimLabel.Text = "Aim"
    aimLabel.Font = Enum.Font.GothamBold
    aimLabel.TextSize = 16
    aimLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimLabel.TextXAlignment = Enum.TextXAlignment.Left
    local keySquare = Instance.new("Frame", aimRow)
    keySquare.Size = UDim2.new(0, 40, 0, 20)
    keySquare.Position = UDim2.new(0.65, 0, 0.5, -10)
    keySquare.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    local keyCorner = Instance.new("UICorner", keySquare)
    keyCorner.CornerRadius = UDim.new(0, 5)
    local keyStroke = Instance.new("UIStroke", keySquare)
    keyStroke.Thickness = 1
    keyStroke.Color = Color3.fromRGB(255, 255, 255)
    keyStroke.Transparency = 0.8
    local keyLabel = Instance.new("TextLabel", keySquare)
    keyLabel.Size = UDim2.new(1, 0, 1, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = "Q"
    keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLabel.Font = Enum.Font.Gotham
    keyLabel.TextSize = 14
    keyLabel.TextXAlignment = Enum.TextXAlignment.Center
    keyLabel.TextYAlignment = Enum.TextYAlignment.Center
    local dotFrame = Instance.new("Frame", aimRow)
    dotFrame.Size = UDim2.new(0, 18, 0, 18)
    dotFrame.Position = UDim2.new(0.85, 0, 0.5, -9)
    dotFrame.BackgroundColor3 = state.aimEnabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    local dotCorner = Instance.new("UICorner", dotFrame)
    dotCorner.CornerRadius = UDim.new(1, 0)
    local dotStroke = Instance.new("UIStroke", dotFrame)
    dotStroke.Thickness = 1
    dotStroke.Color = Color3.fromRGB(255, 255, 255)
    dotStroke.Transparency = 0.8

    makeSlider(tabFrame, "Prediction", 0, 1, state.prediction, function(v) state.prediction = v end, 0.01, 1, "%.2f")
    makeSlider(tabFrame, "Smooth Speed", 0, 1, state.smoothSpeed, function(v) state.smoothSpeed = v end, 0.01, 1, "%.2f")
    makeSlider(tabFrame, "FOV", 5, 90, state.fovDegrees, function(v) state.fovDegrees = v end, 1, 1, "%.0f")

    local teamRow = Instance.new("Frame", tabFrame)
    teamRow.Size = UDim2.new(1, 0, 0, 40)
    teamRow.BackgroundTransparency = 1
    local teamLabel = Instance.new("TextLabel", teamRow)
    teamLabel.Size = UDim2.new(0.6, 0, 1, 0)
    teamLabel.BackgroundTransparency = 1
    teamLabel.Text = "Team Check"
    teamLabel.Font = Enum.Font.GothamBold
    teamLabel.TextSize = 16
    teamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    teamLabel.TextXAlignment = Enum.TextXAlignment.Left
    local teamDot = Instance.new("Frame", teamRow)
    teamDot.Size = UDim2.new(0, 18, 0, 18)
    teamDot.Position = UDim2.new(0.85, 0, 0.5, -9)
    teamDot.BackgroundColor3 = state.teamCheckEnabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    local teamCorner = Instance.new("UICorner", teamDot)
    teamCorner.CornerRadius = UDim.new(1, 0)
    local teamStroke = Instance.new("UIStroke", teamDot)
    teamStroke.Thickness = 1
    teamStroke.Color = Color3.fromRGB(255, 255, 255)
    teamStroke.Transparency = 0.8
    local teamBtn = Instance.new("TextButton", teamRow)
    teamBtn.Size = UDim2.new(1, 0, 1, 0)
    teamBtn.BackgroundTransparency = 1
    teamBtn.Text = ""
    teamBtn.MouseButton1Click:Connect(function()
        state.teamCheckEnabled = not state.teamCheckEnabled
        teamDot.BackgroundColor3 = state.teamCheckEnabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    end)

    local manualRow = Instance.new("Frame", tabFrame)
    manualRow.Size = UDim2.new(1, 0, 0, 40)
    manualRow.BackgroundTransparency = 1
    local manualLabel = Instance.new("TextLabel", manualRow)
    manualLabel.Size = UDim2.new(1, 0, 1, 0)
    manualLabel.BackgroundTransparency = 1
    manualLabel.Text = "Manual Team Check"
    manualLabel.Font = Enum.Font.GothamBold
    manualLabel.TextSize = 16
    manualLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    manualLabel.TextXAlignment = Enum.TextXAlignment.Left
    local manualBtn = Instance.new("TextButton", manualRow)
    manualBtn.Size = UDim2.new(1, 0, 1, 0)
    manualBtn.BackgroundTransparency = 1
    manualBtn.Text = ""
    manualBtn.MouseButton1Click:Connect(function()
        local selectGui = Instance.new("ScreenGui", coreGui)
        selectGui.Name = "TeamSelectGui"
        selectGui.ResetOnSpawn = false
        local selectFrame = Instance.new("Frame", selectGui)
        selectFrame.Size = UDim2.new(0, 300, 0, 400)
        selectFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
        selectFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        selectFrame.BorderSizePixel = 0
        selectFrame.Active = true
        selectFrame.Draggable = true
        local selectCorner = Instance.new("UICorner", selectFrame)
        selectCorner.CornerRadius = UDim.new(0, 20)
        local selectShadow = Instance.new("UIStroke", selectFrame)
        selectShadow.Thickness = 3
        selectShadow.Color = Color3.fromRGB(0, 0, 0)
        selectShadow.Transparency = 0.5
        local selectGradient = Instance.new("UIGradient", selectFrame)
        selectGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
        }
        local header = Instance.new("Frame", selectFrame)
        header.Size = UDim2.new(1, 0, 0, 50)
        header.BackgroundTransparency = 1
        local title = Instance.new("TextLabel", header)
        title.Size = UDim2.new(0.7, -12, 1, 0)
        title.Position = UDim2.new(0, 12, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "Team Select"
        title.Font = Enum.Font.GothamBlack
        title.TextSize = 22
        title.TextColor3 = Color3.fromRGB(0, 170, 255)
        title.TextXAlignment = Enum.TextXAlignment.Left
        local closeBtn = Instance.new("TextButton", header)
        closeBtn.Size = UDim2.new(0, 40, 0, 40)
        closeBtn.Position = UDim2.new(1, -50, 0, 5)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 20
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.BorderSizePixel = 0
        local closeCorner = Instance.new("UICorner", closeBtn)
        closeCorner.CornerRadius = UDim.new(0, 12)
        local closeGradient = Instance.new("UIGradient", closeBtn)
        closeGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
        }
        closeBtn.MouseButton1Click:Connect(function()
            selectGui:Destroy()
        end)
        local scroll = Instance.new("ScrollingFrame", selectFrame)
        scroll.Size = UDim2.new(1, 0, 1, -50)
        scroll.Position = UDim2.new(0, 0, 0, 50)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 5
        local list = Instance.new("UIListLayout", scroll)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 10)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local row = Instance.new("Frame", scroll)
                row.Size = UDim2.new(1, 0, 0, 40)
                row.BackgroundTransparency = 1
                local nameLabel = Instance.new("TextLabel", row)
                nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = plr.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 18
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                local checkFrame = Instance.new("Frame", row)
                checkFrame.Size = UDim2.new(0, 35, 0, 35)
                checkFrame.Position = UDim2.new(0.85, 0, 0, 2.5)
                checkFrame.BackgroundColor3 = non_enemies[plr.UserId] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                checkFrame.BorderSizePixel = 0
                local checkCorner = Instance.new("UICorner", checkFrame)
                checkCorner.CornerRadius = UDim.new(0, 10)
                local checkStroke = Instance.new("UIStroke", checkFrame)
                checkStroke.Thickness = 1
                checkStroke.Color = Color3.fromRGB(255, 255, 255)
                checkStroke.Transparency = 0.2
                local checkLabel = Instance.new("TextLabel", checkFrame)
                checkLabel.Size = UDim2.new(1, 0, 1, 0)
                checkLabel.BackgroundTransparency = 1
                checkLabel.Text = ""
                checkLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                checkLabel.Font = Enum.Font.GothamBold
                checkLabel.TextSize = 22
                local checkBtn = Instance.new("TextButton", checkFrame)
                checkBtn.Size = UDim2.new(1, 0, 1, 0)
                checkBtn.BackgroundTransparency = 1
                checkBtn.Text = ""
                checkBtn.MouseButton1Click:Connect(function()
                    if non_enemies[plr.UserId] then
                        non_enemies[plr.UserId] = nil
                        checkFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                        checkLabel.Text = ""
                    else
                        non_enemies[plr.UserId] = true
                        checkFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                        checkLabel.Text = ""
                    end
                end)
            end
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)

    tabFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabFrame.CanvasSize = UDim2.new(0, 0, 0, tabFrame.UIListLayout.AbsoluteContentSize.Y + 40)
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            screenGui.Enabled = not screenGui.Enabled
        elseif input.KeyCode == Enum.KeyCode.Q then
            state.aimEnabled = not state.aimEnabled
            dotFrame.BackgroundColor3 = state.aimEnabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
            if state.aimEnabled then
                StarterGui:SetCore("SendNotification", {
                    Title = "Aimbot",
                    Text = "Aimbot Enabled",
                    Duration = 2
                })
            else
                StarterGui:SetCore("SendNotification", {
                    Title = "Aimbot",
                    Text = "Aimbot Disabled",
                    Duration = 2
                })
            end
        elseif input.KeyCode == Enum.KeyCode.F6 then
            state.espEnabled = not state.espEnabled
            StarterGui:SetCore("SendNotification", {
                Title = "ESP",
                Text = state.espEnabled and "ESP Enabled" or "ESP Disabled",
                Duration = 2
            })
        end
    end)
    screenGui.Enabled = true
    LocalPlayer.CharacterAdded:Connect(function(char)
        did_map = false
        performTeamMapping()
    end)
end

performTeamMapping()
initGui()

-- ESP Functions
local function createESP(player)
    local drawings = {
        box = Drawing.new("Square"),
        line = Drawing.new("Line"),
        name = Drawing.new("Text"),
        health = Drawing.new("Text"),
        distance = Drawing.new("Text")
    }
    drawings.box.Thickness = 2
    drawings.box.Transparency = 1
    drawings.box.Color = Color3.fromRGB(255, 0, 0)
    drawings.box.Filled = false
    drawings.line.Thickness = 2
    drawings.line.Color = Color3.fromRGB(0, 255, 0)
    drawings.line.Transparency = 1
    drawings.name.Size = 16
    drawings.name.Color = Color3.fromRGB(255, 255, 255)
    drawings.name.Outline = true
    drawings.name.Center = true
    drawings.name.Font = 2
    drawings.health.Size = 14
    drawings.health.Color = Color3.fromRGB(0, 255, 0)
    drawings.health.Outline = true
    drawings.health.Center = true
    drawings.health.Font = 2
    drawings.distance.Size = 14
    drawings.distance.Color = Color3.fromRGB(255, 255, 255)
    drawings.distance.Outline = true
    drawings.distance.Center = true
    drawings.distance.Font = 2
    return drawings
end

local function updateESP()
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then
        for _, drawings in pairs(espDrawings) do
            drawings.box.Visible = false
            drawings.line.Visible = false
            drawings.name.Visible = false
            drawings.health.Visible = false
            drawings.distance.Visible = false
        end
        return
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if isEnemy(plr) and plr.Character and plr.Character:FindFirstChild("Head") and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChildOfClass("Humanoid") then
            local head = plr.Character.Head
            local rootPart = plr.Character.HumanoidRootPart
            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
            local dist = (rootPart.Position - myHrp.Position).Magnitude
            if dist > state.aimDistance then
                if espDrawings[plr] then
                    espDrawings[plr].box.Visible = false
                    espDrawings[plr].line.Visible = false
                    espDrawings[plr].name.Visible = false
                    espDrawings[plr].health.Visible = false
                    espDrawings[plr].distance.Visible = false
                end
                continue
            end
            local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            local rootPos = Camera:WorldToViewportPoint(rootPart.Position)
            local topPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 3, 0))
            local bottomPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
            if onScreen then
                if not espDrawings[plr] then
                    espDrawings[plr] = createESP(plr)
                end
                local drawings = espDrawings[plr]
                local boxHeight = math.abs(topPos.Y - bottomPos.Y)
                local boxWidth = boxHeight * 0.6
                drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                drawings.box.Position = Vector2.new(headPos.X - boxWidth / 2, topPos.Y)
                drawings.box.Visible = true
                drawings.line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                drawings.line.To = Vector2.new(headPos.X, headPos.Y)
                drawings.line.Visible = true
                drawings.name.Text = plr.Name
                drawings.name.Position = Vector2.new(headPos.X, topPos.Y - 30)
                drawings.name.Visible = true
                local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
                drawings.health.Text = "HP: " .. healthPercent .. "%"
                drawings.health.Position = Vector2.new(headPos.X, topPos.Y - 50)
                drawings.health.Color = Color3.fromRGB(255 * (1 - healthPercent / 100), 255 * (healthPercent / 100), 0)
                drawings.health.Visible = true
                drawings.distance.Text = math.floor(dist) .. "m"
                drawings.distance.Position = Vector2.new(headPos.X, bottomPos.Y + 15)
                drawings.distance.Visible = true
            else
                if espDrawings[plr] then
                    espDrawings[plr].box.Visible = false
                    espDrawings[plr].line.Visible = false
                    espDrawings[plr].name.Visible = false
                    espDrawings[plr].health.Visible = false
                    espDrawings[plr].distance.Visible = false
                end
            end
        else
            if espDrawings[plr] then
                espDrawings[plr].box.Visible = false
                espDrawings[plr].line.Visible = false
                espDrawings[plr].name.Visible = false
                espDrawings[plr].health.Visible = false
                espDrawings[plr].distance.Visible = false
            end
        end
    end
end

-- Main Loop
RunService.RenderStepped:Connect(function(dt)
    if not did_map then
        performTeamMapping()
    end
    lockedTarget = getClosestVisibleTarget(true)
    isAiming = state.aimEnabled
    if state.aimEnabled then
        local targetPart = getClosestVisibleTarget()
        if targetPart and state.smoothAim and lockedTarget then
            pcall(aimAtTargetSmooth, targetPart, dt)
        end
    end
    if state.espEnabled then
        updateESP()
    else
        for _, drawings in pairs(espDrawings) do
            drawings.box:Remove()
            drawings.line:Remove()
            drawings.name:Remove()
            drawings.health:Remove()
            drawings.distance:Remove()
        end
        espDrawings = {}
    end
end)

-- Silent Aim Integration
local success, utility = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"))
end)

if success then
    local aimbotEnabled = false

    local function get_players()
        local entities = {}
        for _, child in pairs(workspace:GetChildren()) do
            if child:FindFirstChildOfClass("Humanoid") and child ~= LocalPlayer.Character then
                table.insert(entities, child)
            elseif child.Name == "HurtEffect" then
                for _, hurt_player in pairs(child:GetChildren()) do
                    if hurt_player.ClassName ~= "Highlight" then
                        table.insert(entities, hurt_player.Parent or hurt_player)
                    end
                end
            end
        end
        return entities
    end

    local function get_closest_player()
        local closest, closest_distance = nil, math.huge
        local character = LocalPlayer.Character
        if not character then return nil end

        for _, player_char in pairs(get_players()) do
            if player_char == LocalPlayer.Character then continue end
            local plr = Players:GetPlayerFromCharacter(player_char)
            if plr and not isEnemy(plr) then continue end
            if not player_char:FindFirstChild("HumanoidRootPart") or not player_char:FindFirstChild("Head") then continue end

            local head = player_char:FindFirstChild("Head")
            if not isPartVisible(head) then continue end

            local position, on_screen = Camera:WorldToViewportPoint(player_char.HumanoidRootPart.Position)
            if not on_screen then continue end

            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local distance = (center - Vector2.new(position.X, position.Y)).Magnitude

            if distance < closest_distance then
                closest = player_char
                closest_distance = distance
            end
        end
        return closest
    end

    local old_raycast = utility.Raycast
    utility.Raycast = function(...)
        local arguments = {...}
        aimbotEnabled = state.aimEnabled
        if aimbotEnabled and #arguments > 0 and (arguments[4] == 999 or arguments[4] == true) then
            local closest = get_closest_player()
            if closest and closest:FindFirstChild("Head") then
                local plr = Players:GetPlayerFromCharacter(closest)
                local vel = velocityHistory[plr] or Vector3.zero
                local acc = accelerationHistory[plr] or Vector3.zero
                local ping = pingHistory[plr] or 0
                local time = state.prediction + ping
                local predictedPos = closest.Head.Position + vel * time + 0.5 * acc * time * time
                arguments[3] = predictedPos
            end
        end
        return old_raycast(table.unpack(arguments))
    end
end
