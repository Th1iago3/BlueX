if game:GetService("CoreGui"):FindFirstChild("UltimateSuiteGui") then
    return
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Anti-kick bypass
local mt = getrawmetatable(game)
local oldindex = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(self, key)
    if checkcaller() then return oldindex(self, key) end
    if key == "Kick" and self == LocalPlayer then
        return function() end
    end
    return oldindex(self, key)
end)
setreadonly(mt, true)
-- Silent Aim setup with workspace
local oldRaycast = workspace.Raycast
local hooked = false
local Colors = {
    VisibleColor = Color3.fromRGB(255, 0, 0),
    OccludedColor = Color3.fromRGB(200, 200, 200),
    TeamColor = Color3.fromRGB(0, 0, 255),
    BoxColor = Color3.fromRGB(255, 255, 255),
}
local visibilityRaycastParams = RaycastParams.new()
visibilityRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
-- Aimbot module (improved)
local Aimbot = {}
local lockedTarget = nil
local isAiming = false
local velocityHistory = {}
local accelerationHistory = {}
local pingHistory = {} -- For better prediction
RunService.Heartbeat:Connect(function(dt)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character and plr.Character.PrimaryPart then
            local currentVel = plr.Character.PrimaryPart.AssemblyLinearVelocity
            accelerationHistory[plr] = (currentVel - (velocityHistory[plr] or Vector3.zero)) / dt
            velocityHistory[plr] = currentVel
            -- Simulate ping for prediction
            pingHistory[plr] = (pingHistory[plr] or 0) * 0.9 + dt * 0.1 -- Approximate latency
        end
    end
end)
function Aimbot.enableSilentAimHook()
    if not hooked then
        oldRaycast = hookfunction(workspace.Raycast, newcclosure(function(self, origin, direction, params)
            if not checkcaller() and state.silentAimEnabled and isAiming then
                local target = lockedTarget or Aimbot.getBestTarget()
                if target and target.Character then
                    local aimPartName = state.aimPart
                    if state.aimLegit then
                        aimPartName = math.random() < 0.3 and "Head" or "UpperTorso"
                    end
                    local aimPart = target.Character:FindFirstChild(aimPartName)
                    if aimPart then
                        local velocity = velocityHistory[target] or Vector3.zero
                        local acceleration = accelerationHistory[target] or Vector3.zero
                        local ping = pingHistory[target] or 0
                        local predictedPosition = aimPart.Position + velocity * (state.prediction + ping) + 0.5 * acceleration * ((state.prediction + ping) ^ 2)
                        if state.silentAimMode == "Redirect" then
                            direction = (predictedPosition - origin).Unit * direction.Magnitude
                            return oldRaycast(self, origin, direction, params)
                        elseif state.silentAimMode == "Expand" and state.hitboxExpansion > 0 then
                            local result = oldRaycast(self, origin, direction, params)
                            if result and result.Instance and result.Instance:IsDescendantOf(target.Character) then
                                return result
                            end
                            local rayDir = direction.Unit
                            local toPoint = predictedPosition - origin
                            local proj = toPoint:Dot(rayDir)
                            if proj < 0 or proj > direction.Magnitude then
                                return result
                            end
                            local closest = origin + rayDir * proj
                            local dist = (closest - predictedPosition).Magnitude
                            if dist <= state.hitboxExpansion then
                                local fakeResult = {
                                    Position = closest,
                                    Instance = aimPart,
                                    Material = aimPart.Material,
                                    Normal = (predictedPosition - closest).Unit,
                                }
                                return fakeResult
                            else
                                return result
                            end
                        end
                    end
                end
            end
            return oldRaycast(self, origin, direction, params)
        end))
        hooked = true
    end
end
function Aimbot.disableSilentAimHook()
    if hooked then
        hookfunction(workspace.Raycast, oldRaycast)
        hooked = false
    end
end
function Aimbot.getBestTarget()
    return getClosestVisibleTarget(true)
end
local AIM_PART_OPTIONS = { "Head", "UpperTorso", "HumanoidRootPart" }
local state = {
    aimEnabled = false,
    silentAimEnabled = false,
    visibleCheck = false,
    espEnabled = false,
    espDistanceEnabled = false,
    teamCheckEnabled = true,
    fovDegrees = 80,
    aimDistance = 150,
    smoothAim = true,
    smoothSpeed = 0.2,
    teleportEnemyActive = false,
    teleportAllyActive = false,
    flyHeight = 0,
    flySpeed = 0,
    prediction = 0.1,
    espLine = false,
    aimPart = "Head",
    aimPriority = "Distance",
    noRecoil = false,
    instantRespawn = false,
    flyAuto = false,
    aimLegit = false,
    speedHack = false,
    speedValue = 0.2, -- Embedded fixed value
    assistRadius = 50, -- Embedded fixed value for assist trigger
    aimKillEnabled = false,  -- New state for AimKill
    silentAimMode = "Redirect",
    hitboxExpansion = 0,
}
local savedState = {}
local espTable = {}
local teleportEnemyCoroutine = nil
local teleportAllyCoroutine = nil
local bodyPos = nil
local bodyVel = nil
local non_enemies = {} -- UserId -> true for manual friends
local did_map = false
-- Utils
local function isAlive(character)
    local hum = character and character:FindFirstChildWhichIsA("Humanoid")
    return hum and gethiddenproperty(hum, "Health") > 0
end
local function getPartFromCharacter(character, name)
    return character and character:FindFirstChild(name)
end
local function isGameTeammate(plr)
    return gethiddenproperty(plr, "Team") == gethiddenproperty(LocalPlayer, "Team")
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
            local aimPartName = state.aimPart
            if state.aimLegit then
                aimPartName = math.random() < 0.3 and "Head" or "UpperTorso"
            end
            local part = plr.Character:FindFirstChild(aimPartName)
            if part then
                local dir = (part.Position - camPos)
                local dirUnit = dir.Unit
                local dot = camLook:Dot(dirUnit)
                local angle = math.acos(math.clamp(dot, -1, 1))
                if angle <= bestAngle then
                    local isVisible = not state.visibleCheck or isPartVisible(part)
                    if isVisible then
                        local hum = plr.Character:FindFirstChild("Humanoid")
                        local health = hum and gethiddenproperty(hum, "Health") or 100
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
local function getClosestEnemyPart(ignoreVisibility)
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    local bestPart, bestDist = nil, math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if isValidTarget(plr) then
            local char = plr.Character
            local part = getPartFromCharacter(char, "HumanoidRootPart")
            if part then
                if ignoreVisibility or isPlayerVisible(plr) then
                    local dist = (part.Position - myHrp.Position).Magnitude
                    if dist < bestDist then
                        bestPart = part
                        bestDist = dist
                    end
                end
            end
        end
    end
    return bestPart
end
local function getClosestAllyPart()
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    local bestPart, bestDist = nil, math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and isAlive(plr.Character) and not isEnemy(plr) then
            local part = getPartFromCharacter(plr.Character, "HumanoidRootPart")
            if part then
                local dist = (part.Position - myHrp.Position).Magnitude
                if dist < bestDist then
                    bestPart = part
                    bestDist = dist
                end
            end
        end
    end
    return bestPart
end
local function aimAtTargetSmooth(targetPart)
    if not targetPart then return end
    local cam = Camera
    local camPos = cam.CFrame.Position
    local offset = Vector3.new(math.random(-0.1,0.1), math.random(-0.1,0.1), math.random(-0.1,0.1))
    if state.aimLegit then
        offset = Vector3.new(math.random(-1,1)*0.2, math.random(-1,1)*0.2, math.random(-1,1)*0.2)
    end
    local targetPos = targetPart.Position + offset
    local targetCFrame = CFrame.new(camPos, targetPos)
    local t = state.smoothSpeed + math.random(-0.02, 0.02)
    local blended = cam.CFrame:Lerp(targetCFrame, t)
    cam.CFrame = blended
end
-- ESP Functions
local function destroyESPForPlayer(plr)
    if espTable[plr] then
        if espTable[plr].billboard then espTable[plr].billboard:Destroy() end
        if espTable[plr].line then espTable[plr].line:Remove() end
        espTable[plr] = nil
    end
end
local function createESPForPlayer(plr)
    if not plr or plr == LocalPlayer then return end
    if espTable[plr] then return end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bill = Instance.new("BillboardGui")
    bill.Name = "ESP_GUI"
    bill.Adornee = hrp
    bill.AlwaysOnTop = true
    bill.Size = UDim2.new(6, 0, 6, 0)
    bill.StudsOffset = Vector3.new(0, 2.3, 0)
    bill.Parent = plr.Character
    local outer = Instance.new("Frame", bill)
    outer.Size = UDim2.new(1, 0, 1, 0)
    outer.Position = UDim2.new(0, 0, 0, 0)
    outer.BackgroundTransparency = 1
    local nameLabel = Instance.new("TextLabel", outer)
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, -0.18, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.Name
    nameLabel.TextColor3 = Colors.TeamColor
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    espTable[plr] = {
        billboard = bill,
        nameLabel = nameLabel,
        line = Drawing.new("Line"),
    }
end
local function updateAllESPs()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    local screenSize = Camera.ViewportSize
    for plr, t in pairs(espTable) do
        if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and t.billboard and t.billboard.Parent then
            local hrp = plr.Character.HumanoidRootPart
            local dist = (hrp.Position - myPos).Magnitude
            local isTeammate = state.teamCheckEnabled and isGameTeammate(plr) or isManualFriend(plr)
            local isVisible = isPlayerVisible(plr)
            local espText = plr.Name
            if state.espDistanceEnabled then
                espText = espText .. " [" .. math.floor(dist) .. "]"
            end
            t.nameLabel.Text = espText
            t.nameLabel.TextColor3 = isTeammate and Colors.TeamColor or (isVisible and Colors.VisibleColor or Colors.OccludedColor)
            if state.espLine then
                local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    t.line.From = Vector2.new(screenSize.X / 2, screenSize.Y)
                    t.line.To = Vector2.new(rootPos.X, rootPos.Y)
                    t.line.Color = isTeammate and Colors.TeamColor or (isVisible and Colors.VisibleColor or Colors.OccludedColor)
                    t.line.Visible = true
                    t.line.Thickness = 1
                    t.line.Transparency = 1
                else
                    t.line.Visible = false
                end
            else
                t.line.Visible = false
            end
        else
            destroyESPForPlayer(plr)
        end
    end
end
-- Player Events
Players.PlayerRemoving:Connect(function(plr)
    destroyESPForPlayer(plr)
    non_enemies[plr.UserId] = nil
    velocityHistory[plr] = nil
    accelerationHistory[plr] = nil
    pingHistory[plr] = nil
end)
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then
        if state.espEnabled and isEnemy(plr) then
            pcall(createESPForPlayer, plr)
        end
    end
end)
-- Choice GUI (modernized, no title)
local coreGui = game:GetService("CoreGui")
local mode = nil
local choiceGui = Instance.new("ScreenGui")
choiceGui.Name = "UltimateSuiteGui"
choiceGui.ResetOnSpawn = false
choiceGui.Parent = coreGui
local choiceFrame = Instance.new("Frame", choiceGui)
choiceFrame.Size = UDim2.new(0, 250, 0, 150)
choiceFrame.Position = UDim2.new(0.5, -125, 0.5, -75)
choiceFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
choiceFrame.BorderSizePixel = 0
local choiceCorner = Instance.new("UICorner", choiceFrame)
choiceCorner.CornerRadius = UDim.new(0, 20)
local choiceShadow = Instance.new("UIStroke", choiceFrame)
choiceShadow.Thickness = 3
choiceShadow.Color = Color3.fromRGB(0, 0, 0)
choiceShadow.Transparency = 0.5
local choiceGradient = Instance.new("UIGradient", choiceFrame)
choiceGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
}
-- Removed titleLabel
local liteBtn = Instance.new("TextButton", choiceFrame)
liteBtn.Size = UDim2.new(0.8, 0, 0, 40)
liteBtn.Position = UDim2.new(0.1, 0, 0.3, 0) -- Adjusted position since no title
liteBtn.Text = "Lite"
liteBtn.Font = Enum.Font.GothamBold
liteBtn.TextSize = 20
liteBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
liteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
liteBtn.BorderSizePixel = 0
local liteCorner = Instance.new("UICorner", liteBtn)
liteCorner.CornerRadius = UDim.new(0, 12)
local liteGradient = Instance.new("UIGradient", liteBtn)
liteGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 120, 200))
}
local brutalBtn = Instance.new("TextButton", choiceFrame)
brutalBtn.Size = UDim2.new(0.8, 0, 0, 40)
brutalBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
brutalBtn.Text = "Brutal (Risk Ban)"
brutalBtn.Font = Enum.Font.GothamBold
brutalBtn.TextSize = 20
brutalBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
brutalBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
brutalBtn.BorderSizePixel = 0
local brutalCorner = Instance.new("UICorner", brutalBtn)
brutalCorner.CornerRadius = UDim.new(0, 12)
local brutalGradient = Instance.new("UIGradient", brutalBtn)
brutalGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
}
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
        if state.espEnabled then
            for _, p in pairs(Players:GetPlayers()) do
                if isEnemy(p) then
                    pcall(createESPForPlayer, p)
                end
            end
        end
    end
end
local function initGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltimateSuiteGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = coreGui
    screenGui.Enabled = false -- Start hidden for animation
    local mainWidth, mainHeight = 300, 450
    local main = Instance.new("Frame", screenGui)
    main.Name = "Main"
    main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
    main.Position = UDim2.new(0.5, -mainWidth/2, 0.5, -mainHeight/2)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.BackgroundTransparency = 1 -- Start transparent
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
    title.Text = "BlueX (" .. mode .. ")"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 24
    title.TextColor3 = Color3.fromRGB(0, 170, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    local btnClose = Instance.new("TextButton", header)
    btnClose.Size = UDim2.new(0, 40, 0, 40)
    btnClose.Position = UDim2.new(1, -50, 0, 5)
    btnClose.Text = "X"
    btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 20
    btnClose.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.BorderSizePixel = 0
    local btnCloseCorner = Instance.new("UICorner", btnClose)
    btnCloseCorner.CornerRadius = UDim.new(0, 12)
    local btnCloseGradient = Instance.new("UIGradient", btnClose)
    btnCloseGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
    }
    local btnMin = Instance.new("TextButton", header)
    btnMin.Size = UDim2.new(0, 40, 0, 40)
    btnMin.Position = UDim2.new(1, -100, 0, 5)
    btnMin.Text = "_"
    btnMin.Font = Enum.Font.GothamBold
    btnMin.TextSize = 24
    btnMin.BackgroundColor3 = Color3.fromRGB(100, 100, 105)
    btnMin.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnMin.BorderSizePixel = 0
    local btnMinCorner = Instance.new("UICorner", btnMin)
    btnMinCorner.CornerRadius = UDim.new(0, 12)
    local btnMinGradient = Instance.new("UIGradient", btnMin)
    btnMinGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 105)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 85))
    }
    local tabBar = Instance.new("Frame", main)
    tabBar.Position = UDim2.new(0, 0, 0, 50)
    tabBar.Size = UDim2.new(1, 0, 0, 40)
    tabBar.BackgroundTransparency = 1
    local tabs = {"Aim", "ESP"}
    if mode == "Brutal" then
        table.insert(tabs, "Misc")
    end
    local tabButtons = {}
    local currentTab = "Aim"
    local tabFrames = {}
    for i, tabName in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton", tabBar)
        tabBtn.Size = UDim2.new(1/#tabs, 0, 1, 0)
        tabBtn.Position = UDim2.new((i-1)/#tabs, 0, 0, 0)
        tabBtn.Text = tabName
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 18
        tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabBtn.BorderSizePixel = 0
        local tabCorner = Instance.new("UICorner", tabBtn)
        tabCorner.CornerRadius = UDim.new(0, 12)
        local tabGradient = Instance.new("UIGradient", tabBtn)
        tabGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
        }
        tabBtn.MouseButton1Click:Connect(function()
            currentTab = tabName
            for _, frm in pairs(tabFrames) do
                frm.Visible = false
            end
            tabFrames[tabName].Visible = true
            for _, btn in pairs(tabButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
            tabBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
            tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)
        tabButtons[tabName] = tabBtn
        local tabFrame = Instance.new("ScrollingFrame", main)
        tabFrame.Position = UDim2.new(0, 10, 0, 90)
        tabFrame.Size = UDim2.new(1, -20, 1, -100)
        tabFrame.BackgroundTransparency = 1
        tabFrame.ScrollBarThickness = 5
        tabFrame.ScrollBarImageTransparency = 0.4
        tabFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
        tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabFrame.Visible = (tabName == "Aim")
        local listLayout = Instance.new("UIListLayout", tabFrame)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 10)
        tabFrames[tabName] = tabFrame
    end
    tabButtons["Aim"].BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    local function makeToggleButton(parent, text, initial, onChange)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 40)
        container.BackgroundTransparency = 1
        container.LayoutOrder = #parent:GetChildren()
        local btn = Instance.new("TextButton", container)
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.Text = text .. ": " .. (initial and "ON" or "OFF")
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BorderSizePixel = 0
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 12)
        local gradient = Instance.new("UIGradient", btn)
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
        }
        local shadow = Instance.new("UIStroke", btn)
        shadow.Thickness = 2
        shadow.Color = Color3.fromRGB(0, 0, 0)
        shadow.Transparency = 0.6
        btn.MouseButton1Click:Connect(function()
            initial = not initial
            btn.Text = text .. ": " .. (initial and "ON" or "OFF")
            savedState[text] = initial
            if onChange then
                pcall(onChange, initial)
            end
        end)
        return btn, initial
    end
    local function makeSlider(parent, labelText, min, max, initial, onChange, snap, scale, fmt, off_zero)
        snap = snap or 1
        scale = scale or 1
        fmt = fmt or "%.0f"
        off_zero = off_zero or false
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 60)
        container.BackgroundTransparency = 1
        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        local init_real = initial / scale
        label.Text = labelText .. ": " .. (off_zero and initial < snap/2 and "Off" or string.format(fmt, init_real))
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        local slider = Instance.new("Frame", container)
        slider.Position = UDim2.new(0, 0, 0, 25)
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
        local knob = Instance.new("TextButton", slider)
        knob.Size = UDim2.new(0, 24, 0, 24)
        local rel = (initial - min) / (max - min)
        knob.Position = UDim2.new(rel, -12, 0, -7)
        knob.AutoButtonColor = false
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.Text = ""
        knob.BorderSizePixel = 0
        local knobCorner = Instance.new("UICorner", knob)
        knobCorner.CornerRadius = UDim.new(1, 0)
        local knobGradient = Instance.new("UIGradient", knob)
        knobGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
        }
        local knobShadow = Instance.new("UIStroke", knob)
        knobShadow.Thickness = 2
        knobShadow.Color = Color3.fromRGB(0, 0, 0)
        knobShadow.Transparency = 0.5
        local dragging = false
        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.Position then
                local rel = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
                local value = min + rel * (max - min)
                value = math.round(value / snap) * snap
                local real = value / scale
                local disp = (off_zero and value < snap/2 and "Off" or string.format(fmt, real))
                knob.Position = UDim2.new(rel, -12, 0, -7)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                label.Text = labelText .. ": " .. disp
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
    local function makeDropdown(parent, labelText, options, initial, onChange)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 60)
        container.BackgroundTransparency = 1
        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        local dropdown = Instance.new("TextButton", container)
        dropdown.Position = UDim2.new(0, 0, 0, 25)
        dropdown.Size = UDim2.new(1, 0, 0, 30)
        dropdown.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        dropdown.BorderSizePixel = 0
        local dropCorner = Instance.new("UICorner", dropdown)
        dropCorner.CornerRadius = UDim.new(0, 12)
        local dropGradient = Instance.new("UIGradient", dropdown)
        dropGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
        }
        dropdown.Text = initial
        dropdown.Font = Enum.Font.GothamBold
        dropdown.TextSize = 16
        dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
        local dropShadow = Instance.new("UIStroke", dropdown)
        dropShadow.Thickness = 2
        dropShadow.Color = Color3.fromRGB(0, 0, 0)
        dropShadow.Transparency = 0.6
        dropdown.MouseButton1Click:Connect(function()
            local idx = table.find(options, initial) or 1
            idx = (idx % #options) + 1
            initial = options[idx]
            dropdown.Text = initial
            if onChange then pcall(onChange, initial) end
        end)
        return container
    end
    -- Aim Tab
    local aimTab = tabFrames["Aim"]
    local aimToggle, _ = makeToggleButton(aimTab, "Aim Assist", state.aimEnabled, function(v) state.aimEnabled = v end)
    local silentToggle, _ = makeToggleButton(aimTab, "Silent Aim", state.silentAimEnabled, function(v)
        state.silentAimEnabled = v
        if v then
            Aimbot.enableSilentAimHook()
        else
            Aimbot.disableSilentAimHook()
        end
    end)
    local silentModeDrop = makeDropdown(aimTab, "Silent Mode:", {"Redirect", "Expand"}, state.silentAimMode, function(v) state.silentAimMode = v end)
    local expandSlider = makeSlider(aimTab, "Hitbox Expand", 0, 10, state.hitboxExpansion, function(v) state.hitboxExpansion = v end, 0.1, 1, "%.1f")
    local smoothToggle, _ = makeToggleButton(aimTab, "Smooth Aim", state.smoothAim, function(v) state.smoothAim = v end)
    local legitToggle, _ = makeToggleButton(aimTab, "Aim Legit", state.aimLegit, function(v) state.aimLegit = v end)
    local visToggle, _ = makeToggleButton(aimTab, "Visible Check", state.visibleCheck, function(v) state.visibleCheck = v end)
    local teamToggle, _ = makeToggleButton(aimTab, "Team Check", state.teamCheckEnabled, function(v)
        state.teamCheckEnabled = v
        for plr in pairs(espTable) do destroyESPForPlayer(plr) end
        if state.espEnabled then
            for _, p in pairs(Players:GetPlayers()) do
                if isEnemy(p) then
                    pcall(createESPForPlayer, p)
                end
            end
        end
    end)
    makeDropdown(aimTab, "Aim Part:", AIM_PART_OPTIONS, state.aimPart, function(v) state.aimPart = v end)
    makeDropdown(aimTab, "Aim Priority:", {"Distance", "Life", "Distance + Life"}, state.aimPriority, function(v) state.aimPriority = v end)
    makeSlider(aimTab, "Smooth Speed", 10, 100, state.smoothSpeed * 100, function(v) state.smoothSpeed = v end, 1, 100, "%.2f")
    makeSlider(aimTab, "FOV Degrees", 0, 360, state.fovDegrees, function(v) state.fovDegrees = v end, 1, 1, "%.0f")
    makeSlider(aimTab, "Aim Distance", 50, 500, state.aimDistance, function(v) state.aimDistance = v end, 1, 1, "%.0f")
    makeSlider(aimTab, "Prediction", 0, 50, state.prediction * 100, function(v) state.prediction = v end, 1, 100, "%.2f")
    -- Add AimKill toggle
    local aimKillToggle, _ = makeToggleButton(aimTab, "AimKill", state.aimKillEnabled, function(v)
        state.aimKillEnabled = v
        if v then
            spawn(function()
                while state.aimKillEnabled do
                    local Gun = ReplicatedStorage.Weapons:FindFirstChild(LocalPlayer.NRPBS.EquippedTool.Value)
                    if Gun then
                        local Crit = math.random() > .6 and true or false
                        for _, v in pairs(Players:GetPlayers()) do
                            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Head") and isEnemy(v) and isPlayerVisible(v) then
                                local Distance = (LocalPlayer.Character.Head.Position - v.Character.Head.Position).Magnitude
                                for i = 1, 10 do
                                    ReplicatedStorage.Events.HitPart:FireServer(
                                        v.Character.Head,
                                        v.Character.Head.Position + Vector3.new(math.random(), math.random(), math.random()),
                                        Gun.Name,
                                        Crit and 2 or 1,
                                        Distance,
                                        false,
                                        Crit,
                                        false,
                                        1,
                                        false,
                                        Gun.FireRate.Value,
                                        Gun.ReloadTime.Value,
                                        Gun.Ammo.Value,
                                        Gun.StoredAmmo.Value,
                                        Gun.Bullets.Value,
                                        Gun.EquipTime.Value,
                                        Gun.RecoilControl.Value,
                                        Gun.Auto.Value,
                                        Gun['Speed%'].Value,
                                        ReplicatedStorage.wkspc.DistributedTime.Value
                                    )
                                end
                            end
                        end
                    end
                    wait(0.1)
                end
            end)
        end
    end)
    -- Manual Team Select Button
    local manualContainer = Instance.new("Frame", aimTab)
    manualContainer.Size = UDim2.new(1, 0, 0, 40)
    manualContainer.BackgroundTransparency = 1
    local manualBtn = Instance.new("TextButton", manualContainer)
    manualBtn.Size = UDim2.new(1, 0, 1, 0)
    manualBtn.Text = "Manual Team Select"
    manualBtn.Font = Enum.Font.GothamBold
    manualBtn.TextSize = 16
    manualBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    manualBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    manualBtn.BorderSizePixel = 0
    local manualCorner = Instance.new("UICorner", manualBtn)
    manualCorner.CornerRadius = UDim.new(0, 12)
    local manualGradient = Instance.new("UIGradient", manualBtn)
    manualGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
    }
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
                checkLabel.Text = non_enemies[plr.UserId] and "✔" or "✖"
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
                        checkLabel.Text = "✖"
                    else
                        non_enemies[plr.UserId] = true
                        checkFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                        checkLabel.Text = "✔"
                    end
                    for plr in pairs(espTable) do destroyESPForPlayer(plr) end
                    if state.espEnabled then
                        for _, p in pairs(Players:GetPlayers()) do
                            if isEnemy(p) then
                                pcall(createESPForPlayer, p)
                            end
                        end
                    end
                end)
            end
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)
    -- ESP Tab (renamed toggles)
    local espTab = tabFrames["ESP"]
    local espToggle, _ = makeToggleButton(espTab, "Esp Enabled", state.espEnabled, function(v)
        state.espEnabled = v
        if not v then
            for plr in pairs(espTable) do
                destroyESPForPlayer(plr)
            end
        else
            for _, p in pairs(Players:GetPlayers()) do
                if isEnemy(p) then
                    pcall(createESPForPlayer, p)
                end
            end
        end
    end)
    local lineToggle, _ = makeToggleButton(espTab, "Esp Line", state.espLine, function(v)
        state.espLine = v
        for _, t in pairs(espTable) do
            t.line.Visible = v and state.espEnabled
        end
    end)
    local espDistanceToggle, _ = makeToggleButton(espTab, "Esp Distance", state.espDistanceEnabled, function(v)
        state.espDistanceEnabled = v
        for plr in pairs(espTable) do
            if espTable[plr] then
                pcall(updateAllESPs)
            end
        end
    end)
    -- Misc Tab (Brutal only)
    if mode == "Brutal" then
        local miscTab = tabFrames["Misc"]
        local noRecoilToggle, _ = makeToggleButton(miscTab, "No Recoil", state.noRecoil, function(v)
            state.noRecoil = v
        end)
        local instantRespawnToggle, _ = makeToggleButton(miscTab, "Instant Respawn", state.instantRespawn, function(v)
            state.instantRespawn = v
        end)
        local flyAutoToggle, _ = makeToggleButton(miscTab, "Fly Auto", state.flyAuto, function(v)
            state.flyAuto = v
            if v and state.flyHeight > 0 and state.flySpeed > 0 then
                -- No noclip
            else
                state.flyAuto = false
                flyAutoToggle.Text = "Fly Auto: OFF"
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            sethiddenproperty(part, "CanCollide", true)
                        end
                    end
                end
            end
        end)
        local tpEnemyToggle, _ = makeToggleButton(miscTab, "Teleport -> Enemy", state.teleportEnemyActive, function(v)
            state.teleportEnemyActive = v
            if v then
                if teleportEnemyCoroutine then coroutine.close(teleportEnemyCoroutine) end
                teleportEnemyCoroutine = coroutine.create(function()
                    while state.teleportEnemyActive do
                        RunService.Heartbeat:Wait()
                        local targetPart = getClosestEnemyPart(true)
                        if targetPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 5, 0)
                        end
                    end
                end)
                coroutine.resume(teleportEnemyCoroutine)
            else
                if teleportEnemyCoroutine then coroutine.close(teleportEnemyCoroutine) teleportEnemyCoroutine = nil end
            end
        end)
        local tpAllyToggle, _ = makeToggleButton(miscTab, "Teleport -> Ally", state.teleportAllyActive, function(v)
            state.teleportAllyActive = v
            if v then
                if teleportAllyCoroutine then coroutine.close(teleportAllyCoroutine) end
                teleportAllyCoroutine = coroutine.create(function()
                    while state.teleportAllyActive do
                        RunService.Heartbeat:Wait()
                        local targetPart = getClosestAllyPart()
                        if targetPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
                        end
                    end
                end)
                coroutine.resume(teleportAllyCoroutine)
            else
                if teleportAllyCoroutine then coroutine.close(teleportAllyCoroutine) teleportAllyCoroutine = nil end
            end
        end)
        local speedHackToggle, _ = makeToggleButton(miscTab, "Speed Hack", state.speedHack, function(v)
            state.speedHack = v
        end)
        makeSlider(miscTab, "Fly Height", 0, 20, state.flyHeight, function(v)
            state.flyHeight = v
            if state.flyAuto and v == 0 then
                state.flyAuto = false
                flyAutoToggle.Text = "Fly Auto: OFF"
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            sethiddenproperty(part, "CanCollide", true)
                        end
                    end
                end
            end
        end, 0.1, 1, "%.1f", true)
        makeSlider(miscTab, "Fly Speed", 0, 50, state.flySpeed, function(v)
            state.flySpeed = v
            if state.flyAuto and v == 0 then
                state.flyAuto = false
                flyAutoToggle.Text = "Fly Auto: OFF"
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            sethiddenproperty(part, "CanCollide", true)
                        end
                    end
                end
            end
        end, 0.1, 1, "%.1f", true)
        local autoKitarToggle, _ = makeToggleButton(miscTab, "Auto Kitar", false, function(v)
            if v then
                LocalPlayer:Kick("")
            end
        end)
    end
    -- Auto adjust canvas size
    for _, tabFrame in pairs(tabFrames) do
        tabFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabFrame.CanvasSize = UDim2.new(0, 0, 0, tabFrame.UIListLayout.AbsoluteContentSize.Y + 40)
        end)
    end
    local minimized = false
    btnMin.MouseButton1Click:Connect(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if not minimized then
            TweenService:Create(main, tweenInfo, {Size = UDim2.new(0, mainWidth, 0, 50)}):Play()
            tabBar.Visible = false
            for _, frm in pairs(tabFrames) do frm.Visible = false end
            minimized = true
        else
            TweenService:Create(main, tweenInfo, {Size = UDim2.new(0, mainWidth, 0, mainHeight)}):Play()
            tabBar.Visible = true
            tabFrames[currentTab].Visible = true
            minimized = false
        end
    end)
    btnClose.MouseButton1Click:Connect(function()
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        TweenService:Create(main, tweenInfo, {BackgroundTransparency = 1}):Play()
        task.wait(0.5)
        screenGui:Destroy()
        if bodyPos then bodyPos:Destroy() end
        if bodyVel then bodyVel:Destroy() end
        for plr in pairs(espTable) do destroyESPForPlayer(plr) end
        Aimbot.disableSilentAimHook()
        if teleportEnemyCoroutine then coroutine.close(teleportEnemyCoroutine) end
        if teleportAllyCoroutine then coroutine.close(teleportAllyCoroutine) end
    end)
    LocalPlayer.CharacterAdded:Connect(function(char)
        did_map = false
        performTeamMapping()
        for key, value in pairs(savedState) do
            if value then
                if key == "Aim Assist" then
                    state.aimEnabled = true
                    aimToggle.Text = key .. ": ON"
                end
                if key == "Silent Aim" then
                    state.silentAimEnabled = true
                    silentToggle.Text = key .. ": ON"
                    Aimbot.enableSilentAimHook()
                end
                if key == "Smooth Aim" then
                    state.smoothAim = true
                    smoothToggle.Text = key .. ": ON"
                end
                if key == "Aim Legit" then
                    state.aimLegit = true
                    legitToggle.Text = key .. ": ON"
                end
                if key == "Visible Check" then
                    state.visibleCheck = true
                    visToggle.Text = key .. ": ON"
                end
                if key == "Team Check" then
                    state.teamCheckEnabled = true
                    teamToggle.Text = key .. ": ON"
                    for plr in pairs(espTable) do destroyESPForPlayer(plr) end
                    if state.espEnabled then
                        for _, p in pairs(Players:GetPlayers()) do
                            if isEnemy(p) then
                                pcall(createESPForPlayer, p)
                            end
                        end
                    end
                end
                if key == "Esp Enabled" then
                    state.espEnabled = true
                    espToggle.Text = key .. ": ON"
                    for _, p in pairs(Players:GetPlayers()) do
                        if isEnemy(p) then
                            pcall(createESPForPlayer, p)
                        end
                    end
                end
                if key == "Esp Line" then
                    state.espLine = true
                    lineToggle.Text = key .. ": ON"
                    for _, t in pairs(espTable) do
                        t.line.Visible = true
                    end
                end
                if key == "Esp Distance" then
                    state.espDistanceEnabled = true
                    espDistanceToggle.Text = key .. ": ON"
                    for plr in pairs(espTable) do
                        if espTable[plr] then
                            pcall(updateAllESPs)
                        end
                    end
                end
                if key == "No Recoil" and mode == "Brutal" then
                    state.noRecoil = true
                    noRecoilToggle.Text = key .. ": ON"
                end
                if key == "Instant Respawn" and mode == "Brutal" then
                    state.instantRespawn = true
                    instantRespawnToggle.Text = key .. ": ON"
                end
                if key == "Fly Auto" and mode == "Brutal" then
                    state.flyAuto = true
                    flyAutoToggle.Text = key .. ": ON"
                end
                if key == "Teleport -> Enemy" and mode == "Brutal" then
                    state.teleportEnemyActive = true
                    tpEnemyToggle.Text = key .. ": ON"
                    if teleportEnemyCoroutine then coroutine.close(teleportEnemyCoroutine) end
                    teleportEnemyCoroutine = coroutine.create(function()
                        while state.teleportEnemyActive do
                            RunService.Heartbeat:Wait()
                            local targetPart = getClosestEnemyPart(true)
                            if targetPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 5, 0)
                            end
                        end
                    end)
                    coroutine.resume(teleportEnemyCoroutine)
                end
                if key == "Teleport -> Ally" and mode == "Brutal" then
                    state.teleportAllyActive = true
                    tpAllyToggle.Text = key .. ": ON"
                    if teleportAllyCoroutine then coroutine.close(teleportAllyCoroutine) end
                    teleportAllyCoroutine = coroutine.create(function()
                        while state.teleportAllyActive do
                            RunService.Heartbeat:Wait()
                            local targetPart = getClosestAllyPart()
                            if targetPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
                            end
                        end
                    end)
                    coroutine.resume(teleportAllyCoroutine)
                end
                if key == "Speed Hack" and mode == "Brutal" then
                    state.speedHack = true
                    speedHackToggle.Text = key .. ": ON"
                end
                if key == "AimKill" then
                    state.aimKillEnabled = true
                    aimKillToggle.Text = key .. ": ON"
                    spawn(function()
                        while state.aimKillEnabled do
                            local Gun = ReplicatedStorage.Weapons:FindFirstChild(LocalPlayer.NRPBS.EquippedTool.Value)
                            if Gun then
                                local Crit = math.random() > .6 and true or false
                                for _, v in pairs(Players:GetPlayers()) do
                                    if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Head") and isEnemy(v) and isPlayerVisible(v) then
                                        local Distance = (LocalPlayer.Character.Head.Position - v.Character.Head.Position).Magnitude
                                        for i = 1, 10 do
                                            ReplicatedStorage.Events.HitPart:FireServer(
                                                v.Character.Head,
                                                v.Character.Head.Position + Vector3.new(math.random(), math.random(), math.random()),
                                                Gun.Name,
                                                Crit and 2 or 1,
                                                Distance,
                                                false,
                                                Crit,
                                                false,
                                                1,
                                                false,
                                                Gun.FireRate.Value,
                                                Gun.ReloadTime.Value,
                                                Gun.Ammo.Value,
                                                Gun.StoredAmmo.Value,
                                                Gun.Bullets.Value,
                                                Gun.EquipTime.Value,
                                                Gun.RecoilControl.Value,
                                                Gun.Auto.Value,
                                                Gun['Speed%'].Value,
                                                ReplicatedStorage.wkspc.DistributedTime.Value
                                            )
                                        end
                                    end
                                end
                            end
                            wait(0.1)
                        end
                    end)
                end
            end
        end
    end)
    -- Animation for GUI entrance
    screenGui.Enabled = true
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(main, tweenInfo, {BackgroundTransparency = 0}):Play()
end
liteBtn.MouseButton1Click:Connect(function()
    mode = "Lite"
    choiceGui:Destroy()
    performTeamMapping()
    initGui()
end)
brutalBtn.MouseButton1Click:Connect(function()
    mode = "Brutal"
    choiceGui:Destroy()
    performTeamMapping()
    initGui()
end)
-- Main Loop
RunService.RenderStepped:Connect(function(dt)
    if not did_map then
        performTeamMapping()
    end
    lockedTarget = getClosestVisibleTarget(true)
    isAiming = state.aimEnabled
    if state.aimEnabled then
        local targetPart = getClosestVisibleTarget()
        if targetPart and state.smoothAim then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local pixelDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if pixelDist < state.assistRadius then
                    pcall(aimAtTargetSmooth, targetPart)
                end
            end
        end
    end
    if state.espEnabled then
        for _, p in pairs(Players:GetPlayers()) do
            if isEnemy(p) then
                if not espTable[p] then
                    pcall(createESPForPlayer, p)
                end
            else
                destroyESPForPlayer(p)
            end
        end
        pcall(updateAllESPs)
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if root and hum and mode == "Brutal" then
        if state.flyHeight > 0 or state.flySpeed > 0 then
            if not bodyPos then
                bodyPos = Instance.new("BodyPosition")
                bodyPos.Parent = root
                bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
                bodyPos.P = 1250
            end
            if not bodyVel then
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.Parent = root
                bodyVel.MaxForce = Vector3.new(math.huge, 0, math.huge)
                bodyVel.P = 1250
            end
            local moveDir = gethiddenproperty(hum, "MoveDirection")
            if state.flyAuto then
                if moveDir.Magnitude > 0 then
                    bodyVel.Velocity = moveDir * state.flySpeed * 16
                else
                    local targetPart = getClosestEnemyPart(true)
                    if targetPart then
                        local direction = (targetPart.Position - root.Position).Unit
                        bodyVel.Velocity = direction * state.flySpeed * 16
                    else
                        bodyVel.Velocity = Vector3.new(0, 0, 0)
                    end
                end
            else
                bodyVel.Velocity = moveDir * state.flySpeed * 16
            end
            local targetY = root.Position.Y
            if state.flyHeight > 0 then
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayParams)
                if rayResult then
                    targetY = rayResult.Position.Y + state.flyHeight + (state.flySpeed > 0 and 0 or state.flyHeight)
                end
            end
            bodyPos.Position = Vector3.new(root.Position.X, targetY, root.Position.Z)
        else
            if bodyPos then
                bodyPos:Destroy()
                bodyPos = nil
            end
            if bodyVel then
                bodyVel:Destroy()
                bodyVel = nil
            end
            if state.flyAuto then
                state.flyAuto = false
                if flyAutoToggle then flyAutoToggle.Text = "Fly Auto: OFF" end
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            sethiddenproperty(part, "CanCollide", true)
                        end
                    end
                end
            end
        end
        if state.noRecoil then
            if char:FindFirstChildOfClass("Tool") then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    for _, v in pairs(tool:GetDescendants()) do
                        if v:IsA("Vector3Value") and v.Name == "Recoil" then
                            sethiddenproperty(v, "Value", Vector3.new(0, 0, 0))
                        end
                    end
                end
            end
        end
        if state.instantRespawn and gethiddenproperty(hum, "Health") <= 0 then
            hum:ChangeState(Enum.HumanoidStateType.Dead)
            task.wait()
            LocalPlayer:LoadCharacter()
        end
        if state.speedHack then
            if gethiddenproperty(hum, "MoveDirection").Magnitude > 0 then
                root.CFrame = root.CFrame + gethiddenproperty(hum, "MoveDirection") * state.speedValue
            end
        end
    else
        if bodyPos then
            bodyPos:Destroy()
            bodyPos = nil
        end
        if bodyVel then
            bodyVel:Destroy()
            bodyVel = nil
        end
        if state.flyAuto then
            state.flyAuto = false
            if flyAutoToggle then flyAutoToggle.Text = "Fly Auto: OFF" end
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        sethiddenproperty(part, "CanCollide", true)
                    end
                end
            end
        end
    end
end)
-- Initialize existing players
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
        if state.espEnabled and isEnemy(p) then
            pcall(createESPForPlayer, p)
        end
        p.CharacterAdded:Connect(function(char)
            if state.espEnabled and isEnemy(p) then
                task.wait(0.5)
                pcall(createESPForPlayer, p)
            end
        end)
    end
end

-- @0xffff00 // Rivals Script.
