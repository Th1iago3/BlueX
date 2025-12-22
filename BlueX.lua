-- Prevent Double Injection
if game:GetService("CoreGui"):FindFirstChild("UltimateSuiteGui") then
    return
end
-- Core Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local PathfindingService = game:GetService("PathfindingService")
-- Memory Overlay Injection
local VirtualMemory = {
    MemoryLayer = {},
    InstanceCache = {},
    PropertyOverrides = {},
    HookRegistry = {},
    DrawingOverlay = {},
    TransformCache = {},
    VelocityOverlay = {},
    RaycastOverlay = {},
    CollisionOverlay = {},
    StateSync = {},
}
function VirtualMemory.CreateVirtualInstance(className)
    local instance = {
        ClassName = className,
        Properties = {},
        Children = {},
        Parent = nil,
        _Virtual = true,
        _MemoryAddress = "0x" .. string.format("%x", math.random(0, 0xFFFFFFFF)),
    }
    table.insert(VirtualMemory.MemoryLayer, instance)
    return instance
end
function VirtualMemory.OverrideProperty(object, property, value)
    if not VirtualMemory.PropertyOverrides[object] then
        VirtualMemory.PropertyOverrides[object] = {}
    end
    VirtualMemory.PropertyOverrides[object][property] = value
end
function VirtualMemory.GetProperty(object, property)
    if VirtualMemory.PropertyOverrides[object] and VirtualMemory.PropertyOverrides[object][property] then
        return VirtualMemory.PropertyOverrides[object][property]
    end
    return object[property]
end
function VirtualMemory.HookFunction(object, methodName, callback)
    if not VirtualMemory.HookRegistry[object] then
        VirtualMemory.HookRegistry[object] = {}
    end
   
    local originalMethod = object[methodName]
    VirtualMemory.HookRegistry[object][methodName] = originalMethod
   
    object[methodName] = function(...)
        return callback(originalMethod, ...)
    end
end
function VirtualMemory.CreateMemoryBarrier()
    local barrier = {
        WriteBuffer = {},
        ReadBuffer = {},
        SyncTime = 0,
        Integrity = true,
    }
    return barrier
end
function VirtualMemory.MemoryCopy(source, destination)
    if typeof(source) == "Instance" and typeof(destination) == "Instance" then
        for _, prop in ipairs({"Position", "Rotation", "CFrame", "Velocity", "RotVelocity"}) do
            pcall(function()
                destination[prop] = source[prop]
            end)
        end
    end
end
function VirtualMemory.IsolateExecution(func)
    local memBarrier = VirtualMemory.CreateMemoryBarrier()
    memBarrier.SyncTime = tick()
   
    local success, result = pcall(func)
   
    memBarrier.Integrity = success
    return result, success
end
-- Advanced Memory Overlay with Drawing System
local MemoryOverlay = {
    Drawings = {},
    PlayerCache = {},
    TrackedPlayers = {},
    FOVCircle = nil,
    CenterCrosshair = nil,
    VirtualLayer = VirtualMemory.MemoryLayer,
}
function MemoryOverlay.Create(drawType)
    local obj = Drawing.new(drawType)
    obj.Visible = false
    table.insert(MemoryOverlay.Drawings, obj)
    VirtualMemory.OverrideProperty(obj, "Visible", false)
    return obj
end
function MemoryOverlay.Cleanup()
    for _, obj in ipairs(MemoryOverlay.Drawings) do
        pcall(function() obj:Remove() end)
    end
    MemoryOverlay.Drawings = {}
    MemoryOverlay.PlayerCache = {}
    VirtualMemory.MemoryLayer = {}
end
-- Configuration
local Config = {
    Aimbot = {
        Enabled = false,
        FOV = 20,
        Smoothness = 0.12,
        Prediction = 0.20,
        VisibleCheck = true,
        MaxDistance = 500,
        PredictionAccuracy = 0.95,
        StabilityMultiplier = 0.95,
        AdaptiveSmoothing = true,
        LockDuration = 0.8,
    },
    ESP = {
        Enabled = false,
        MaxDistance = 500,
        ShowBox = true,
        ShowHealth = true,
        ShowName = true,
        ShowDistance = true,
        ShowCorners = true,
    },
    TeamCheck = false,
}
-- Advanced Tracking System
local Tracking = {
    Velocity = {},
    Acceleration = {},
    PreviousPositions = {},
    PredictionBuffer = {},
    AngularVelocity = {},
    LastVelocityUpdate = {},
}
-- Runtime State
local Runtime = {
    LockedTarget = nil,
    LockStartTime = 0,
    LastTargetTime = 0,
    FriendsByProximity = {},
    CameraVelocity = Vector3.zero,
    PreviousCameraPos = Vector3.zero,
    AimHistory = {},
    StabilityCounter = 0,
    VisiblePlayers = {},
    ESPTriggerLine = nil,
    UserCameraDirection = Vector3.new(0, 0, -1),
    PreviousCameraDirection = Vector3.new(0, 0, -1),
    CustomCursor = nil,
    IsInGUI = false,
}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
-- Utility Functions
local function IsPlayerAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end
local function IsTeammate(player)
    if not Config.TeamCheck then return false end
    if player == LocalPlayer then return false end
   
    local myTeam = LocalPlayer.Team
    local playerTeam = player.Team
   
    if myTeam and playerTeam and myTeam == playerTeam then
        return true
    end
   
    pcall(function()
        if gethiddenproperty(LocalPlayer, "Team") == gethiddenproperty(player, "Team") then
            return true
        end
    end)
   
    if myTeam and myTeam.Name then
        local teamName = myTeam.Name:lower()
        if teamName:find("red") or teamName:find("blue") or teamName:find("team") then
            if playerTeam and playerTeam.Name:lower() == teamName then
                return true
            end
        end
    end
   
    pcall(function()
        if player:FindFirstChild("Team") and LocalPlayer:FindFirstChild("Team") then
            if player.Team.Value == LocalPlayer.Team.Value then
                return true
            end
        end
    end)
   
    pcall(function()
        if player:FindFirstChildOfClass("StringValue") and LocalPlayer:FindFirstChildOfClass("StringValue") then
            local playerTag = player:FindFirstChildOfClass("StringValue")
            local myTag = LocalPlayer:FindFirstChildOfClass("StringValue")
            if playerTag and myTag and playerTag.Value == myTag.Value then
                return true
            end
        end
    end)
   
    pcall(function()
        if player.Parent:FindFirstChild("TeamFolder") and LocalPlayer.Parent:FindFirstChild("TeamFolder") then
            return player.Parent.TeamFolder.Value == LocalPlayer.Parent.TeamFolder.Value
        end
    end)
   
    local playerChar = player.Character
    local myChar = LocalPlayer.Character
   
    if playerChar and myChar then
        pcall(function()
            local playerTag = playerChar:FindFirstChild("TeamTag") or playerChar:FindFirstChild("Team")
            local myTag = myChar:FindFirstChild("TeamTag") or myChar:FindFirstChild("Team")
            if playerTag and myTag then
                if playerTag.Value == myTag.Value then
                    return true
                end
            end
        end)
    end
   
    pcall(function()
        if sethidden then
            local hidden = gethiddenproperty(player, "TeamColor") or gethiddenproperty(player, "Team")
            local myHidden = gethiddenproperty(LocalPlayer, "TeamColor") or gethiddenproperty(LocalPlayer, "Team")
            if hidden and myHidden and hidden == myHidden then
                return true
            end
        end
    end)
   
    return false
end
local function IsProximityFriend(player)
    return Runtime.FriendsByProximity[player.UserId] == true
end
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    if not player or not player.Character then return false end
   
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
   
    if IsTeammate(player) or IsProximityFriend(player) then return false end
    return true
end
local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end
local function RaycastVisible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character or {}, Camera}
    local result = Workspace:Raycast(origin, direction, raycastParams)
    if not result then return true end
    return result.Instance:IsDescendantOf(part.Parent)
end
local function GetBestBodyPart(character)
    if not character then return nil end
    local parts = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"}
    local bestPart = nil
    local bestDist = math.huge
    local camPos = Camera.CFrame.Position
   
    for _, partName in ipairs(parts) do
        local part = character:FindFirstChild(partName)
        if part then
            local dist = (part.Position - camPos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestPart = part
            end
        end
    end
    return bestPart or character.PrimaryPart
end
-- Enhanced Velocity & Acceleration Tracking
RunService.Heartbeat:Connect(function(deltaTime)
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character.PrimaryPart then
            local currentVel = player.Character.PrimaryPart.AssemblyLinearVelocity
            local prevVel = Tracking.Velocity[player] or Vector3.zero
           
            Tracking.Acceleration[player] = (currentVel - prevVel) / math.max(deltaTime, 0.016)
            Tracking.Velocity[player] = currentVel
            Tracking.LastVelocityUpdate[player] = tick()
           
            if not Tracking.PreviousPositions[player] then
                Tracking.PreviousPositions[player] = {}
            end
            table.insert(Tracking.PreviousPositions[player], player.Character.PrimaryPart.Position)
            if #Tracking.PreviousPositions[player] > 10 then
                table.remove(Tracking.PreviousPositions[player], 1)
            end
        end
    end
end)
-- Advanced Target Acquisition
local function AcquireBestTarget()
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
   
    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector
    local fovRad = math.rad(Config.Aimbot.FOV / 2)
    local bestTarget = nil
    local closestDist = Config.Aimbot.MaxDistance
   
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
       
        local head = player.Character:FindFirstChild("Head")
        if not head then continue end
       
        if not IsEnemy(player) then continue end
       
        local headPos = head.Position
        local direction = (headPos - camPos)
        if direction.Magnitude == 0 then continue end
       
        local directionUnit = direction.Unit
        local angle = math.acos(math.clamp(camLook:Dot(directionUnit), -1, 1))
        local distance3D = (headPos - myRoot.Position).Magnitude
       
        if angle <= fovRad and distance3D <= closestDist then
            if not Config.Aimbot.VisibleCheck or RaycastVisible(head) then
                closestDist = distance3D
                bestTarget = player
            end
        end
    end
   
    return bestTarget
end
local function IsTargetValid(target)
    if not target or not target.Character then return false end
    if not IsPlayerAlive(target) then return false end
    if IsTeammate(target) or IsProximityFriend(target) then return false end
    local head = target.Character:FindFirstChild("Head")
    if not head then return false end
    if Config.Aimbot.VisibleCheck and not RaycastVisible(head) then return false end
    return true
end
-- COMPLETE AIMBOT REWRITE
local function PerformSmoothAim(targetPart, deltaTime)
    if not targetPart then return end
    if not Runtime.LockedTarget or not Runtime.LockedTarget.Character then return end
    if not IsPlayerAlive(Runtime.LockedTarget) then return end
   
    local head = Runtime.LockedTarget.Character:FindFirstChild("Head")
    if not head then return end
   
    local camPos = Camera.CFrame.Position
    local currentCFrame = Camera.CFrame
   
    -- Enhanced prediction with better accuracy
    local velocity = Tracking.Velocity[Runtime.LockedTarget] or Vector3.zero
    local acceleration = Tracking.Acceleration[Runtime.LockedTarget] or Vector3.zero
   
    local predictionTime = Config.Aimbot.Prediction
    local predictedPos = head.Position + (velocity * predictionTime) + (0.5 * acceleration * predictionTime * predictionTime)
   
    -- Smooth prediction over multiple frames
    if not Tracking.PredictionBuffer[Runtime.LockedTarget] then
        Tracking.PredictionBuffer[Runtime.LockedTarget] = {}
    end
   
    table.insert(Tracking.PredictionBuffer[Runtime.LockedTarget], predictedPos)
    if #Tracking.PredictionBuffer[Runtime.LockedTarget] > 8 then
        table.remove(Tracking.PredictionBuffer[Runtime.LockedTarget], 1)
    end
   
    -- Average predictions for smoother tracking
    local smoothedPrediction = Vector3.zero
    for _, pos in ipairs(Tracking.PredictionBuffer[Runtime.LockedTarget]) do
        smoothedPrediction = smoothedPrediction + pos
    end
    smoothedPrediction = smoothedPrediction / #Tracking.PredictionBuffer[Runtime.LockedTarget]
   
    -- Create target CFrame with smoothed prediction
    local targetCFrame = CFrame.new(camPos, smoothedPrediction)
   
    -- Enhanced stability boost for locking
    local lockTime = tick() - Runtime.LockStartTime
    local stabilityBoost = math.min(1.0, lockTime / 0.3) * Config.Aimbot.StabilityMultiplier
   
    -- Adaptive smoothness based on distance and movement
    local distance = (smoothedPrediction - camPos).Magnitude
    local targetSpeed = velocity.Magnitude
    local baseSmoothness = Config.Aimbot.Smoothness
   
    if Config.Aimbot.AdaptiveSmoothing then
        -- Increase smoothness for faster targets
        local speedFactor = math.min(targetSpeed / 50, 1.5)
        baseSmoothness = baseSmoothness * (0.8 + speedFactor * 0.4)
       
        -- Decrease smoothness for closer targets (stickier)
        local distanceFactor = math.clamp(1 - (distance / Config.Aimbot.MaxDistance), 0.3, 1)
        baseSmoothness = baseSmoothness * distanceFactor
    end
   
    -- Calculate lerp with frame-rate independence
    local lerpFactor = (baseSmoothness * stabilityBoost) * (deltaTime * 60)
    lerpFactor = math.max(lerpFactor, 0.008)
    lerpFactor = math.min(lerpFactor, 0.5)
   
    -- Apply smooth lerp
    Camera.CFrame = currentCFrame:Lerp(targetCFrame, lerpFactor)
    Runtime.PreviousCameraPos = Camera.CFrame.Position
   
    -- Track aim history for consistency
    if not Runtime.AimHistory[Runtime.LockedTarget] then
        Runtime.AimHistory[Runtime.LockedTarget] = {}
    end
    table.insert(Runtime.AimHistory[Runtime.LockedTarget], smoothedPrediction)
    if #Runtime.AimHistory[Runtime.LockedTarget] > 30 then
        table.remove(Runtime.AimHistory[Runtime.LockedTarget], 1)
    end
end
local function UpdateAimbot(deltaTime)
    if not Config.Aimbot.Enabled then
        Runtime.LockedTarget = nil
        return
    end
   
    local myChar = LocalPlayer.Character
    if not myChar then return end
   
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
   
    -- Try to acquire new target
    local bestTarget = nil
    local bestDistance = Config.Aimbot.MaxDistance
    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector
    local fovRadians = math.rad(Config.Aimbot.FOV / 2)
   
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
       
        local playerHead = player.Character:FindFirstChild("Head")
        if not playerHead then continue end
       
        -- Check if enemy
        if not IsEnemy(player) then continue end
       
        -- Check distance first (faster check)
        local distance = (playerHead.Position - myRoot.Position).Magnitude
        if distance > Config.Aimbot.MaxDistance then continue end
       
        -- Check FOV
        local dirToTarget = (playerHead.Position - camPos)
        if dirToTarget.Magnitude == 0 then continue end
       
        local dirUnit = dirToTarget.Unit
        local angle = math.acos(math.clamp(camLook:Dot(dirUnit), -1, 1))
       
        if angle > fovRadians then continue end
       
        -- Check visibility last (most expensive check)
        if Config.Aimbot.VisibleCheck then
            if not RaycastVisible(playerHead) then continue end
        end
       
        -- This is a valid target - prefer closest
        if distance < bestDistance then
            bestDistance = distance
            bestTarget = player
        end
    end
   
    -- Smooth target switching
    if bestTarget then
        if Runtime.LockedTarget ~= bestTarget then
            Runtime.LockedTarget = bestTarget
            Runtime.LockStartTime = tick()
            Runtime.LastTargetTime = tick()
        else
            Runtime.LastTargetTime = tick()
        end
    else
        if Runtime.LockedTarget then
            local timeSinceLock = tick() - Runtime.LastTargetTime
            if timeSinceLock > Config.Aimbot.LockDuration then
                Runtime.LockedTarget = nil
            end
        end
    end
   
    -- Apply aim if locked and valid
    if Runtime.LockedTarget then
        if Runtime.LockedTarget.Character then
            local head = Runtime.LockedTarget.Character:FindFirstChild("Head")
            if head and IsPlayerAlive(Runtime.LockedTarget) then
                if Config.Aimbot.VisibleCheck then
                    if not RaycastVisible(head) then
                        Runtime.LockedTarget = nil
                        return
                    end
                end
                pcall(PerformSmoothAim, head, deltaTime)
            else
                Runtime.LockedTarget = nil
            end
        else
            Runtime.LockedTarget = nil
        end
    end
end
-- GUI Creation
local CoreGui = game:GetService("CoreGui")
local function CreateGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltimateSuiteGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui
    screenGui.Enabled = false
   
    local mainWidth, mainHeight = 350, 500
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name = "Main"
    mainFrame.Size = UDim2.new(0, mainWidth, 0, mainHeight)
    mainFrame.Position = UDim2.new(0.5, -mainWidth/2, 0.5, -mainHeight/2)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
   
    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 20)
   
    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Transparency = 0.5
   
    local gradient = Instance.new("UIGradient", mainFrame)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
    }
   
    local header = Instance.new("Frame", mainFrame)
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
   
    local content = Instance.new("ScrollingFrame", mainFrame)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.Size = UDim2.new(1, -20, 1, -60)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 5
    content.ScrollBarImageTransparency = 0.4
    content.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
   
    local layout = Instance.new("UIListLayout", content)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
   
    -- Custom Cursor for GUI
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            Runtime.IsInGUI = true
        end
    end)
   
    mainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            Runtime.IsInGUI = false
        end
    end)
   
    local function CreateSlider(parent, name, min, max, default, callback)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 40)
        container.BackgroundTransparency = 1
       
        local labelArea = Instance.new("Frame", container)
        labelArea.Size = UDim2.new(1, 0, 0, 20)
        labelArea.BackgroundTransparency = 1
       
        local label = Instance.new("TextLabel", labelArea)
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Text = name
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
       
        local valueLabel = Instance.new("TextLabel", labelArea)
        valueLabel.Size = UDim2.new(0.3, 0, 1, 0)
        valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
        valueLabel.Text = string.format("%.2f", default)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 14
        valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.BackgroundTransparency = 1
       
        local sliderBack = Instance.new("Frame", container)
        sliderBack.Position = UDim2.new(0, 0, 0, 20)
        sliderBack.Size = UDim2.new(1, -10, 0, 10)
        sliderBack.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        local backCorner = Instance.new("UICorner", sliderBack)
        backCorner.CornerRadius = UDim.new(0, 5)
       
        local fill = Instance.new("Frame", sliderBack)
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        local fillCorner = Instance.new("UICorner", fill)
        fillCorner.CornerRadius = UDim.new(0, 5)
       
        local dragging = false
        sliderBack.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local relative = math.clamp((input.Position.X - sliderBack.AbsolutePosition.X) / sliderBack.AbsoluteSize.X, 0, 1)
                local value = min + relative * (max - min)
                valueLabel.Text = string.format("%.2f", value)
                fill.Size = UDim2.new(relative, 0, 1, 0)
                callback(value)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end
   
    local settingsHeader = Instance.new("TextLabel", content)
    settingsHeader.Size = UDim2.new(1, 0, 0, 30)
    settingsHeader.BackgroundTransparency = 1
    settingsHeader.Text = "Settings"
    settingsHeader.Font = Enum.Font.GothamBold
    settingsHeader.TextSize = 18
    settingsHeader.TextColor3 = Color3.fromRGB(0, 170, 255)
    settingsHeader.TextXAlignment = Enum.TextXAlignment.Left
   
    -- Aim Toggle
    local aimRow = Instance.new("Frame", content)
    aimRow.Size = UDim2.new(1, 0, 0, 40)
    aimRow.BackgroundTransparency = 1
    local aimLabel = Instance.new("TextLabel", aimRow)
    aimLabel.Size = UDim2.new(0.6, 0, 1, 0)
    aimLabel.Text = "Aim"
    aimLabel.Font = Enum.Font.GothamBold
    aimLabel.TextSize = 16
    aimLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimLabel.TextXAlignment = Enum.TextXAlignment.Left
    aimLabel.BackgroundTransparency = 1
    local aimDot = Instance.new("Frame", aimRow)
    aimDot.Size = UDim2.new(0, 18, 0, 18)
    aimDot.Position = UDim2.new(0.85, 0, 0.5, -9)
    aimDot.BackgroundColor3 = Config.Aimbot.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    local aimCorner = Instance.new("UICorner", aimDot)
    aimCorner.CornerRadius = UDim.new(1, 0)
    local aimButton = Instance.new("TextButton", aimRow)
    aimButton.Size = UDim2.new(1, 0, 1, 0)
    aimButton.BackgroundTransparency = 1
    aimButton.Text = ""
    aimButton.MouseButton1Click:Connect(function()
        Config.Aimbot.Enabled = not Config.Aimbot.Enabled
        aimDot.BackgroundColor3 = Config.Aimbot.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    end)
   
    CreateSlider(content, "Prediction", 0, 0.5, Config.Aimbot.Prediction, function(v) Config.Aimbot.Prediction = v end)
    CreateSlider(content, "Smoothness", 0.02, 0.2, Config.Aimbot.Smoothness, function(v) Config.Aimbot.Smoothness = v end)
    CreateSlider(content, "FOV Degrees", 5, 90, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = math.floor(v) end)
   
    local teamRow = Instance.new("Frame", content)
    teamRow.Size = UDim2.new(1, 0, 0, 40)
    teamRow.BackgroundTransparency = 1
    local teamLabel = Instance.new("TextLabel", teamRow)
    teamLabel.Size = UDim2.new(0.6, 0, 1, 0)
    teamLabel.Text = "Team Check"
    teamLabel.Font = Enum.Font.GothamBold
    teamLabel.TextSize = 16
    teamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    teamLabel.TextXAlignment = Enum.TextXAlignment.Left
    teamLabel.BackgroundTransparency = 1
    local teamDot = Instance.new("Frame", teamRow)
    teamDot.Size = UDim2.new(0, 18, 0, 18)
    teamDot.Position = UDim2.new(0.85, 0, 0.5, -9)
    teamDot.BackgroundColor3 = Config.TeamCheck and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    local teamCorner = Instance.new("UICorner", teamDot)
    teamCorner.CornerRadius = UDim.new(1, 0)
    local teamButton = Instance.new("TextButton", teamRow)
    teamButton.Size = UDim2.new(1, 0, 1, 0)
    teamButton.BackgroundTransparency = 1
    teamButton.Text = ""
    teamButton.MouseButton1Click:Connect(function()
        Config.TeamCheck = not Config.TeamCheck
        teamDot.BackgroundColor3 = Config.TeamCheck and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    end)
   
    local manualTeamRow = Instance.new("Frame", content)
    manualTeamRow.Size = UDim2.new(1, 0, 0, 40)
    manualTeamRow.BackgroundTransparency = 1
    local manualTeamLabel = Instance.new("TextLabel", manualTeamRow)
    manualTeamLabel.Size = UDim2.new(1, 0, 1, 0)
    manualTeamLabel.BackgroundTransparency = 1
    manualTeamLabel.Text = "Manual Team Select"
    manualTeamLabel.Font = Enum.Font.GothamBold
    manualTeamLabel.TextSize = 16
    manualTeamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    manualTeamLabel.TextXAlignment = Enum.TextXAlignment.Left
    local manualTeamButton = Instance.new("TextButton", manualTeamRow)
    manualTeamButton.Size = UDim2.new(1, 0, 1, 0)
    manualTeamButton.BackgroundTransparency = 1
    manualTeamButton.Text = ""
    manualTeamButton.MouseButton1Click:Connect(function()
        local selectGui = Instance.new("ScreenGui", CoreGui)
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
       
        local selectStroke = Instance.new("UIStroke", selectFrame)
        selectStroke.Thickness = 3
        selectStroke.Color = Color3.fromRGB(0, 0, 0)
        selectStroke.Transparency = 0.5
       
        local selectHeader = Instance.new("Frame", selectFrame)
        selectHeader.Size = UDim2.new(1, 0, 0, 50)
        selectHeader.BackgroundTransparency = 1
       
        local selectTitle = Instance.new("TextLabel", selectHeader)
        selectTitle.Size = UDim2.new(0.8, 0, 1, 0)
        selectTitle.Position = UDim2.new(0, 12, 0, 0)
        selectTitle.BackgroundTransparency = 1
        selectTitle.Text = "Select Allies"
        selectTitle.Font = Enum.Font.GothamBlack
        selectTitle.TextSize = 18
        selectTitle.TextColor3 = Color3.fromRGB(0, 170, 255)
        selectTitle.TextXAlignment = Enum.TextXAlignment.Left
       
        local closeBtn = Instance.new("TextButton", selectHeader)
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -40, 0, 10)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.BorderSizePixel = 0
        local closeCorner = Instance.new("UICorner", closeBtn)
        closeCorner.CornerRadius = UDim.new(0, 8)
        closeBtn.MouseButton1Click:Connect(function()
            selectGui:Destroy()
        end)
       
        local scroll = Instance.new("ScrollingFrame", selectFrame)
        scroll.Size = UDim2.new(1, 0, 1, -50)
        scroll.Position = UDim2.new(0, 0, 0, 50)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 5
        scroll.ScrollBarImageTransparency = 0.4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
       
        local list = Instance.new("UIListLayout", scroll)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 8)
       
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local row = Instance.new("Frame", scroll)
                row.Size = UDim2.new(1, 0, 0, 35)
                row.BackgroundTransparency = 1
               
                local nameLabel = Instance.new("TextLabel", row)
                nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = player.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 14
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
               
                local checkBox = Instance.new("TextButton", row)
                checkBox.Size = UDim2.new(0, 30, 0, 30)
                checkBox.Position = UDim2.new(1, -40, 0, 2.5)
                checkBox.Text = Runtime.FriendsByProximity[player.UserId] and "✓" or ""
                checkBox.Font = Enum.Font.GothamBold
                checkBox.TextSize = 18
                checkBox.BackgroundColor3 = Runtime.FriendsByProximity[player.UserId] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(50, 50, 50)
                checkBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                checkBox.BorderSizePixel = 0
               
                local checkCorner = Instance.new("UICorner", checkBox)
                checkCorner.CornerRadius = UDim.new(0, 6)
               
                checkBox.MouseButton1Click:Connect(function()
                    if Runtime.FriendsByProximity[player.UserId] then
                        Runtime.FriendsByProximity[player.UserId] = nil
                        checkBox.Text = ""
                        checkBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                    else
                        Runtime.FriendsByProximity[player.UserId] = true
                        checkBox.Text = "✓"
                        checkBox.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
                    end
                end)
            end
        end
       
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
        end)
    end)
   
    local espRow = Instance.new("Frame", content)
    espRow.Size = UDim2.new(1, 0, 0, 40)
    espRow.BackgroundTransparency = 1
    local espLabel = Instance.new("TextLabel", espRow)
    espLabel.Size = UDim2.new(0.6, 0, 1, 0)
    espLabel.Text = "ESP"
    espLabel.Font = Enum.Font.GothamBold
    espLabel.TextSize = 16
    espLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    espLabel.TextXAlignment = Enum.TextXAlignment.Left
    espLabel.BackgroundTransparency = 1
    local espDot = Instance.new("Frame", espRow)
    espDot.Size = UDim2.new(0, 18, 0, 18)
    espDot.Position = UDim2.new(0.85, 0, 0.5, -9)
    espDot.BackgroundColor3 = Config.ESP.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    local espCorner = Instance.new("UICorner", espDot)
    espCorner.CornerRadius = UDim.new(1, 0)
    local espButton = Instance.new("TextButton", espRow)
    espButton.Size = UDim2.new(1, 0, 1, 0)
    espButton.BackgroundTransparency = 1
    espButton.Text = ""
    espButton.MouseButton1Click:Connect(function()
        Config.ESP.Enabled = not Config.ESP.Enabled
        espDot.BackgroundColor3 = Config.ESP.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    end)
   
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 40)
    end)
   
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            screenGui.Enabled = not screenGui.Enabled
        elseif input.KeyCode == Enum.KeyCode.Q then
            Config.Aimbot.Enabled = not Config.Aimbot.Enabled
            aimDot.BackgroundColor3 = Config.Aimbot.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
        elseif input.KeyCode == Enum.KeyCode.F6 then
            Config.ESP.Enabled = not Config.ESP.Enabled
            espDot.BackgroundColor3 = Config.ESP.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
        end
    end)
   
    screenGui.Enabled = true
   
end
-- Custom Cursor Update
RunService.RenderStepped:Connect(function()
    if Runtime.IsInGUI then
        local mouse = LocalPlayer:GetMouse()
        mouse.Icon = "rbxasset://textures/Cursors/MouseLockedCursor.png"
    end
end)
-- Advanced ESP System
local function UpdateESPOverlay()
    if not Config.ESP.Enabled then
        for _, cache in pairs(MemoryOverlay.PlayerCache) do
            if cache then
                for _, obj in pairs(cache) do
                    if obj then obj.Visible = false end
                end
            end
        end
        if Runtime.ESPTriggerLine then
            Runtime.ESPTriggerLine.Visible = false
        end
        Runtime.VisiblePlayers = {}
        return
    end
   
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
   
    Runtime.VisiblePlayers = {}
    local activePlayers = {}
   
    if Runtime.LockedTarget and IsEnemy(Runtime.LockedTarget) and Runtime.LockedTarget.Character then
        local targetHead = Runtime.LockedTarget.Character:FindFirstChild("Head")
        if targetHead then
            local headScreenPos = Camera:WorldToViewportPoint(targetHead.Position)
            if headScreenPos.Z > 0.1 then
                if not Runtime.ESPTriggerLine then
                    Runtime.ESPTriggerLine = MemoryOverlay.Create("Line")
                    Runtime.ESPTriggerLine.Thickness = 3
                    Runtime.ESPTriggerLine.Color = Color3.fromRGB(139, 69, 19)
                    Runtime.ESPTriggerLine.Transparency = 0.4
                end
               
                local headScreen = Vector2.new(headScreenPos.X, headScreenPos.Y)
                local screenSize = Camera.ViewportSize
                local bottomPoint = Vector2.new(screenSize.X / 2, screenSize.Y)
               
                Runtime.ESPTriggerLine.From = bottomPoint
                Runtime.ESPTriggerLine.To = headScreen
                Runtime.ESPTriggerLine.Visible = true
            end
        end
    else
        if Runtime.ESPTriggerLine then
            Runtime.ESPTriggerLine.Visible = false
        end
    end
   
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        if not IsEnemy(player) then continue end
       
        local head = player.Character:FindFirstChild("Head")
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
       
        if not head or not root or not humanoid then continue end
        if humanoid.Health <= 0 then continue end
       
        local distance = (root.Position - myRoot.Position).Magnitude
        if distance > Config.ESP.MaxDistance then
            local userId = player.UserId
            local cache = MemoryOverlay.PlayerCache[userId]
            if cache then
                for _, obj in pairs(cache) do
                    if obj then obj.Visible = false end
                end
            end
            continue
        end
       
        local headScreenPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local feetScreenPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.5, 0))
       
        local headScreen = Vector2.new(headScreenPos.X, headScreenPos.Y)
        local feetScreen = Vector2.new(feetScreenPos.X, feetScreenPos.Y)
       
        if headScreenPos.Z > 0.1 and feetScreenPos.Z > 0.1 then
            local userId = player.UserId
            Runtime.VisiblePlayers[userId] = true
            activePlayers[userId] = true
           
            if not MemoryOverlay.PlayerCache[userId] then
                MemoryOverlay.PlayerCache[userId] = {
                    Box = MemoryOverlay.Create("Square"),
                    HealthBG = MemoryOverlay.Create("Square"),
                    HealthFG = MemoryOverlay.Create("Square"),
                    NameLabel = MemoryOverlay.Create("Text"),
                    DistanceLabel = MemoryOverlay.Create("Text"),
                    CornerTL = MemoryOverlay.Create("Line"),
                    CornerTR = MemoryOverlay.Create("Line"),
                    CornerBL = MemoryOverlay.Create("Line"),
                    CornerBR = MemoryOverlay.Create("Line"),
                }
               
                local cache = MemoryOverlay.PlayerCache[userId]
                cache.Box.Filled = false
                cache.Box.Thickness = 2
                cache.Box.Color = Color3.fromRGB(0, 255, 140)
                cache.Box.Transparency = 0.7
               
                cache.HealthBG.Filled = true
                cache.HealthBG.Color = Color3.fromRGB(0, 0, 0)
                cache.HealthBG.Transparency = 0.5
               
                cache.HealthFG.Filled = true
                cache.HealthFG.Color = Color3.fromRGB(0, 255, 100)
               
                cache.NameLabel.Size = 13
                cache.NameLabel.Color = Color3.fromRGB(255, 255, 255)
                cache.NameLabel.Outline = true
                cache.NameLabel.Center = true
               
                cache.DistanceLabel.Size = 12
                cache.DistanceLabel.Color = Color3.fromRGB(200, 200, 200)
                cache.DistanceLabel.Outline = true
                cache.DistanceLabel.Center = true
               
                for _, line in pairs({cache.CornerTL, cache.CornerTR, cache.CornerBL, cache.CornerBR}) do
                    line.Thickness = 2
                    line.Color = Color3.fromRGB(0, 255, 140)
                end
            end
           
            local cache = MemoryOverlay.PlayerCache[userId]
            local height = math.abs(feetScreen.Y - headScreen.Y)
            local width = height * 0.6
            local boxPos = Vector2.new(headScreen.X - width/2, headScreen.Y)
           
            cache.Box.Size = Vector2.new(width, height)
            cache.Box.Position = boxPos
            cache.Box.Visible = true
           
            local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            cache.HealthBG.Size = Vector2.new(6, height + 4)
            cache.HealthBG.Position = boxPos - Vector2.new(12, 2)
            cache.HealthBG.Visible = true
           
            cache.HealthFG.Size = Vector2.new(6, (height + 4) * healthRatio)
            cache.HealthFG.Position = boxPos - Vector2.new(12, 2) + Vector2.new(0, (height + 4) * (1 - healthRatio))
            cache.HealthFG.Visible = true
           
            cache.NameLabel.Text = player.DisplayName or player.Name
            cache.NameLabel.Position = Vector2.new(headScreen.X, headScreen.Y - 22)
            cache.NameLabel.Visible = true
           
            cache.DistanceLabel.Text = string.format("%dm", math.floor(distance))
            cache.DistanceLabel.Position = Vector2.new(headScreen.X, feetScreen.Y + 8)
            cache.DistanceLabel.Visible = true
           
            local cornerLength = width / 4
            cache.CornerTL.From = boxPos
            cache.CornerTL.To = boxPos + Vector2.new(cornerLength, 0)
            cache.CornerTL.Visible = true
           
            cache.CornerTR.From = boxPos + Vector2.new(width, 0)
            cache.CornerTR.To = boxPos + Vector2.new(width - cornerLength, 0)
            cache.CornerTR.Visible = true
           
            cache.CornerBL.From = boxPos + Vector2.new(0, height)
            cache.CornerBL.To = boxPos + Vector2.new(cornerLength, height)
            cache.CornerBL.Visible = true
           
            cache.CornerBR.From = boxPos + Vector2.new(width, height)
            cache.CornerBR.To = boxPos + Vector2.new(width - cornerLength, height)
            cache.CornerBR.Visible = true
        else
            local userId = player.UserId
            local cache = MemoryOverlay.PlayerCache[userId]
            if cache then
                for _, obj in pairs(cache) do
                    if obj then obj.Visible = false end
                end
            end
        end
    end
   
    for userId, cache in pairs(MemoryOverlay.PlayerCache) do
        if not activePlayers[userId] and cache then
            for _, obj in pairs(cache) do
                if obj then obj.Visible = false end
            end
        end
    end
end
Players.PlayerRemoving:Connect(function(player)
    local cache = MemoryOverlay.PlayerCache[player.UserId]
    if cache then
        for _, obj in pairs(cache) do
            pcall(function() obj:Remove() end)
        end
        MemoryOverlay.PlayerCache[player.UserId] = nil
    end
end)
-- Initialization
CreateGUI()
-- Main Render Loop
RunService.RenderStepped:Connect(function(deltaTime)
    UpdateAimbot(deltaTime)
    UpdateESPOverlay()
end)
