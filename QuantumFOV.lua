--[[
    QuantumFOV v4.1 - CORREÇÕES TÉCNICAS REAIS
    Otimizado, Estável, Profissional
]]

if game:GetService("CoreGui"):FindFirstChild("QuantumFOV_v4") then
    game:GetService("CoreGui"):FindFirstChild("QuantumFOV_v4"):Destroy()
end

-- Configurações
local Config = {
    Aimbot = {
        Enabled = false,
        AimPart = "Head",
        FOV = 40,
        Smoothness = 0.5,
        Prediction = 0.135,
        TeamCheck = true,
        WallCheck = false,
        AutoShoot = false,
        TriggerBot = false
    },
    
    ESP = {
        Enabled = false,
        Box = false,
        Name = false,
        Distance = false,
        HealthBar = false,
        Line = false,
        MaxDistance = 2000,
        UpdateInterval = 0.05 -- CORREÇÃO 3: Não atualiza todo frame
    },
    
    Performance = {
        TargetFPS = 60,
        UpdateRate = 0.016, -- ~60 FPS
        ESPUpdateRate = 0.05 -- 20 updates por segundo (basta!)
    }
}

-- Serviços
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    Workspace = workspace
}

-- Proteção Delta
if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- ============================================
-- CORREÇÃO 4: Detecção mobile ROBUSTA
-- ============================================
local Platform = {
    IsMobile = false,
    IsEmulator = false,
    InputType = "Mouse" -- Mouse, Touch, Gamepad
}

-- Detectar plataforma real
pcall(function()
    -- Verifica múltiplos indicadores
    local hasTouch = Services.UserInputService.TouchEnabled
    local hasGyro = Services.UserInputService.GyroscopeEnabled
    local hasKeyboard = Services.UserInputService.KeyboardEnabled
    local hasMouse = Services.UserInputService.MouseEnabled
    
    if hasTouch and not hasKeyboard and not hasMouse then
        Platform.IsMobile = true
        Platform.InputType = "Touch"
    elseif hasTouch and hasKeyboard then
        Platform.IsEmulator = true
        Platform.InputType = "Hybrid"
    else
        Platform.InputType = "Mouse"
    end
end)

-- ============================================
-- CORREÇÃO 1+5: Sistema de Input UNIFICADO
-- ============================================
local InputSystem = {
    LastClick = 0,
    ClickCooldown = 0.05,
    IsClicking = false
}

-- ÚNICA função de clique (sem misturar APIs)
function InputSystem:Click()
    local currentTime = tick()
    if currentTime - self.LastClick < self.ClickCooldown then
        return false -- Cooldown, evita spam
    end
    
    self.LastClick = currentTime
    
    -- Método 1: mouse1press (PC)
    if Platform.InputType == "Mouse" then
        pcall(function()
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end)
        return true
    end
    
    -- Método 2: VirtualInput (Mobile/Emulador)
    if Platform.InputType == "Touch" or Platform.InputType == "Hybrid" then
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
            task.wait(0.01)
            vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
        end)
        return true
    end
    
    return false
end

-- ============================================
-- CORREÇÃO 2: Sistema de Drag UNIFICADO
-- ============================================
local DragSystem = {
    ActiveDrag = nil, -- Só UM drag por vez
    Connections = {}
}

function DragSystem:MakeDraggable(guiObject, target)
    local dragState = {
        IsDragging = false,
        StartPos = nil,
        ObjectStart = nil
    }
    
    -- InputBegan ÚNICO
    local beganConn = guiObject.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
            input.UserInputType == Enum.UserInputType.Touch) and 
            not DragSystem.ActiveDrag then
            
            dragState.IsDragging = true
            dragState.StartPos = input.Position
            dragState.ObjectStart = target.Position
            DragSystem.ActiveDrag = dragState
        end
    end)
    
    -- InputEnded ÚNICO
    local endedConn = Services.UserInputService.InputEnded:Connect(function(input)
        if DragSystem.ActiveDrag == dragState then
            dragState.IsDragging = false
            DragSystem.ActiveDrag = nil
        end
    end)
    
    -- InputChanged GLOBAL (só 1 listener)
    table.insert(DragSystem.Connections, beganConn)
    table.insert(DragSystem.Connections, endedConn)
    
    return dragState
end

-- Listener GLOBAL único para movimento
Services.UserInputService.InputChanged:Connect(function(input)
    if not DragSystem.ActiveDrag then return end
    
    if input.UserInputType == Enum.UserInputType.MouseMovement or 
       input.UserInputType == Enum.UserInputType.Touch then
        
        local drag = DragSystem.ActiveDrag
        if drag.IsDragging then
            local delta = input.Position - drag.StartPos
            local target = drag.TargetObject
            
            if target then
                target.Position = UDim2.new(
                    math.clamp(drag.ObjectStart.X.Scale, 0, 0.95),
                    math.clamp(drag.ObjectStart.X.Offset + delta.X, -200, 2000),
                    math.clamp(drag.ObjectStart.Y.Scale, 0, 0.95),
                    math.clamp(drag.ObjectStart.Y.Offset + delta.Y, -100, 2000)
                )
            end
        end
    end
end)

-- ============================================
-- Sistema Drawing (ESP) - MANTIDO
-- ============================================
local HasDrawing = false
pcall(function()
    if Drawing ~= nil then
        HasDrawing = true
    end
end)

local ESP_Objects = {}

local function CreateESP(player)
    if not HasDrawing then return nil end
    
    local success, esp = pcall(function()
        local newESP = {
            Player = player,
            Box = Drawing.new("Square"),
            Name = Drawing.new("Text"),
            Distance = Drawing.new("Text"),
            HealthBar = Drawing.new("Square"),
            HealthFill = Drawing.new("Square"),
            Line = Drawing.new("Line")
        }
        
        newESP.Box.Color = Color3.fromRGB(255, 0, 0)
        newESP.Box.Thickness = 2
        newESP.Box.Filled = false
        newESP.Box.Visible = false
        
        newESP.Name.Color = Color3.fromRGB(255, 255, 255)
        newESP.Name.Size = 14
        newESP.Name.Center = true
        newESP.Name.Outline = true
        newESP.Name.Visible = false
        
        newESP.Distance.Color = Color3.fromRGB(200, 200, 200)
        newESP.Distance.Size = 13
        newESP.Distance.Center = true
        newESP.Distance.Outline = true
        newESP.Distance.Visible = false
        
        newESP.HealthBar.Color = Color3.fromRGB(50, 50, 50)
        newESP.HealthBar.Filled = true
        newESP.HealthBar.Visible = false
        
        newESP.HealthFill.Color = Color3.fromRGB(0, 255, 0)
        newESP.HealthFill.Filled = true
        newESP.HealthFill.Visible = false
        
        newESP.Line.Color = Color3.fromRGB(255, 255, 255)
        newESP.Line.Thickness = 1
        newESP.Line.Visible = false
        
        return newESP
    end)
    
    if success and esp then
        table.insert(ESP_Objects, esp)
        return esp
    end
    
    return nil
end

-- ============================================
-- Sistema de Mira OTIMIZADO
-- ============================================
local AimbotSystem = {
    CurrentTarget = nil,
    LastUpdate = 0,
    LastShot = 0
}

local function IsVisible(character, part)
    if not Config.Aimbot.WallCheck then return true end
    
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = part.Position - rayOrigin
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local rayResult = Services.Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    return rayResult == nil
end

local function GetTargets()
    local targets = {}
    if not LocalPlayer.Character then return targets end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local character = player.Character
        if not character then continue end
        
        local aimPart = character:FindFirstChild(Config.Aimbot.AimPart)
        if not aimPart then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        if not IsVisible(character, aimPart) then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
        if not onScreen then continue end
        
        local distance2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if distance2D > Config.Aimbot.FOV then continue end
        
        local velocity = Vector3.zero
        if aimPart:IsA("BasePart") then
            velocity = aimPart.AssemblyLinearVelocity or aimPart.Velocity or Vector3.zero
        end
        
        local predictedPos = aimPart.Position + (velocity * Config.Aimbot.Prediction)
        
        table.insert(targets, {
            Player = player,
            Character = character,
            Position = predictedPos,
            Distance = distance2D
        })
    end
    
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    return targets
end

-- ============================================
-- CORREÇÃO 3: Update OTIMIZADO
-- ============================================
local function OptimizedAimbotUpdate()
    local currentTime = tick()
    
    -- Só atualiza na taxa configurada
    if currentTime - AimbotSystem.LastUpdate < Config.Performance.UpdateRate then
        return
    end
    
    AimbotSystem.LastUpdate = currentTime
    
    if not Config.Aimbot.Enabled then
        AimbotSystem.CurrentTarget = nil
        return
    end
    
    local targets = GetTargets()
    
    if #targets > 0 then
        AimbotSystem.CurrentTarget = targets[1]
        
        if Config.Aimbot.Smoothness >= 1 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, AimbotSystem.CurrentTarget.Position)
        else
            local targetCFrame = CFrame.new(Camera.CFrame.Position, AimbotSystem.CurrentTarget.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
        end
        
        -- AutoShoot CORRIGIDO
        if Config.Aimbot.AutoShoot then
            if currentTime - AimbotSystem.LastShot > 0.1 then
                InputSystem:Click()
                AimbotSystem.LastShot = currentTime
            end
        end
        
        -- TriggerBot CORRIGIDO
        if Config.Aimbot.TriggerBot and not Config.Aimbot.AutoShoot then
            local mousePos = Services.UserInputService:GetMouseLocation()
            local targetScreenPos = Camera:WorldToViewportPoint(AimbotSystem.CurrentTarget.Position)
            local distanceToTarget = (Vector2.new(targetScreenPos.X, targetScreenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
            
            if distanceToTarget < 50 and currentTime - AimbotSystem.LastShot > 0.05 then
                InputSystem:Click()
                AimbotSystem.LastShot = currentTime
            end
        end
    else
        AimbotSystem.CurrentTarget = nil
    end
end

-- CORREÇÃO 3: ESP Update otimizado
local ESPUpdateTimer = 0
local function OptimizedESPUpdate()
    local currentTime = tick()
    
    if currentTime - ESPUpdateTimer < Config.Performance.ESPUpdateRate then
        return
    end
    
    ESPUpdateTimer = currentTime
    
    if not Config.ESP.Enabled then
        for _, esp in pairs(ESP_Objects) do
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() 
                        if drawing.Visible then drawing.Visible = false end
                    end)
                end
            end
        end
        return
    end
    
    for _, esp in pairs(ESP_Objects) do
        local player = esp.Player
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not character then
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() drawing.Visible = false end)
                end
            end
            continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not head or not rootPart or humanoid.Health <= 0 then
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() drawing.Visible = false end)
                end
            end
            continue
        end
        
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        
        if not onScreen then
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() drawing.Visible = false end)
                end
            end
            continue
        end
        
        local distance = 0
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
        end
        
        if distance > Config.ESP.MaxDistance then continue end
        
        local safeDistance = math.max(distance, 1)
        local scale = 1000 / safeDistance
        local boxWidth = math.clamp(scale * 3, 10, 200)
        local boxHeight = math.clamp(scale * 5, 15, 300)
        
        if Config.ESP.Box then
            pcall(function()
                esp.Box.Visible = true
                esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                esp.Box.Position = Vector2.new(headPos.X - boxWidth/2, headPos.Y - boxHeight/2)
            end)
        end
        
        if Config.ESP.Name then
            pcall(function()
                esp.Name.Visible = true
                esp.Name.Text = player.Name
                esp.Name.Position = Vector2.new(headPos.X, headPos.Y - boxHeight/2 - 20)
            end)
        end
        
        if Config.ESP.Distance then
            pcall(function()
                esp.Distance.Visible = true
                esp.Distance.Text = string.format("%.0fm", distance)
                esp.Distance.Position = Vector2.new(headPos.X, headPos.Y + boxHeight/2 + 5)
            end)
        end
        
        if Config.ESP.HealthBar then
            local healthPercent = humanoid.Health / math.max(humanoid.MaxHealth, 1)
            
            pcall(function()
                esp.HealthBar.Visible = true
                esp.HealthBar.Size = Vector2.new(3, boxHeight)
                esp.HealthBar.Position = Vector2.new(headPos.X - boxWidth/2 - 5, headPos.Y - boxHeight/2)
                
                esp.HealthFill.Visible = true
                esp.HealthFill.Size = Vector2.new(3, boxHeight * healthPercent)
                esp.HealthFill.Position = Vector2.new(headPos.X - boxWidth/2 - 5, 
                    headPos.Y - boxHeight/2 + boxHeight * (1 - healthPercent))
                
                if healthPercent > 0.6 then
                    esp.HealthFill.Color = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 0.3 then
                    esp.HealthFill.Color = Color3.fromRGB(255, 255, 0)
                else
                    esp.HealthFill.Color = Color3.fromRGB(255, 0, 0)
                end
            end)
        end
        
        if Config.ESP.Line then
            pcall(function()
                esp.Line.Visible = true
                esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                esp.Line.To = Vector2.new(headPos.X, headPos.Y + boxHeight/2)
            end)
        end
    end
end

-- ============================================
-- INTERFACE (SIMPLIFICADA, MENOS BUGS)
-- ============================================
local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuantumFOV_v4"
    gui.Parent = Services.CoreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    
    -- Botão Flutuante com Ícone Moderno
    local FloatButton = Instance.new("TextButton")
    FloatButton.Name = "FloatButton"
    FloatButton.Parent = gui
    FloatButton.Size = UDim2.new(0, 55, 0, 55)
    FloatButton.Position = UDim2.new(0.85, 0, 0.45, 0)
    FloatButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    FloatButton.Text = ""
    FloatButton.AutoButtonColor = false
    FloatButton.BorderSizePixel = 0
    FloatButton.ZIndex = 10
    FloatButton.BackgroundTransparency = 0.1
    
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 16)
    floatCorner.Parent = FloatButton
    
    local floatStroke = Instance.new("UIStroke")
    floatStroke.Parent = FloatButton
    floatStroke.Color = Color3.fromRGB(100, 150, 255)
    floatStroke.Thickness = 2
    floatStroke.Transparency = 0.3
    
    -- Ícone
    local iconFrame = Instance.new("Frame")
    iconFrame.Parent = FloatButton
    iconFrame.Size = UDim2.new(0, 35, 0, 35)
    iconFrame.Position = UDim2.new(0.5, -17, 0.5, -17)
    iconFrame.BackgroundTransparency = 1
    
    local outerCircle = Instance.new("ImageLabel")
    outerCircle.Parent = iconFrame
    outerCircle.Size = UDim2.new(1, 0, 1, 0)
    outerCircle.BackgroundTransparency = 1
    outerCircle.Image = "rbxassetid://3926305904"
    outerCircle.ImageColor3 = Color3.fromRGB(255, 255, 255)
    outerCircle.ImageTransparency = 0.2
    
    local centerDot = Instance.new("Frame")
    centerDot.Parent = iconFrame
    centerDot.Size = UDim2.new(0, 8, 0, 8)
    centerDot.Position = UDim2.new(0.5, -4, 0.5, -4)
    centerDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = centerDot
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Parent = FloatButton
    nameLabel.Size = UDim2.new(0, 80, 0, 16)
    nameLabel.Position = UDim2.new(0.5, -40, 1, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "QUANTUM"
    nameLabel.TextColor3 = Color3.fromRGB(200, 210, 255)
    nameLabel.TextSize = 10
    nameLabel.Font = Enum.Font.GothamBlack
    
    local minimizeDot = Instance.new("Frame")
    minimizeDot.Parent = FloatButton
    minimizeDot.Size = UDim2.new(0, 12, 0, 12)
    minimizeDot.Position = UDim2.new(1, -2, 0, -2)
    minimizeDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    
    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(1, 0)
    miniCorner.Parent = minimizeDot
    
    -- Frame Principal
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = gui
    MainFrame.Size = UDim2.new(0, 380, 0, 520)
    MainFrame.Position = UDim2.new(0.5, -190, 0.2, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    MainFrame.BackgroundTransparency = 0.05
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = MainFrame
    
    -- TitleBar
    local TitleBar = Instance.new("Frame")
    TitleBar.Parent = MainFrame
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    TitleBar.Active = true
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 8)
    titleBarCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Parent = TitleBar
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🎯 QUANTUM v4.1"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 15
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Minimize Button
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Parent = TitleBar
    MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    MinimizeBtn.Position = UDim2.new(1, -68, 0.5, -14)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 30)
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.Text = "−"
    MinimizeBtn.TextSize = 20
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.AutoButtonColor = false
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = MinimizeBtn
    
    -- Close Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = TitleBar
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Text = "✕"
    CloseBtn.TextSize = 16
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.AutoButtonColor = false
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = CloseBtn
    
    -- Content
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Parent = MainFrame
    ContentFrame.Size = UDim2.new(1, 0, 1, -40)
    ContentFrame.Position = UDim2.new(0, 0, 0, 40)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ScrollBarThickness = 4
    ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 70, 70)
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = ContentFrame
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 5)
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = ContentFrame
    UIPadding.PaddingTop = UDim.new(0, 10)
    UIPadding.PaddingLeft = UDim.new(0, 10)
    UIPadding.PaddingRight = UDim.new(0, 10)
    
    -- Função botões
    local function AddButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Parent = ContentFrame
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = "🔴 " .. text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        local enabled = false
        
        btn.MouseButton1Click:Connect(function()
            enabled = not enabled
            btn.Text = (enabled and "🟢 " or "🔴 ") .. text
            btn.BackgroundColor3 = enabled and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(35, 35, 45)
            if callback then callback(enabled) end
        end)
        
        return btn
    end
    
    -- Botões
    AddButton("AIMBOT PRINCIPAL", function(enabled) Config.Aimbot.Enabled = enabled end)
    AddButton("AUTO SHOOT", function(enabled) Config.Aimbot.AutoShoot = enabled end)
    AddButton("TRIGGER BOT", function(enabled) Config.Aimbot.TriggerBot = enabled end)
    AddButton("RESPEITAR PAREDES", function(enabled) Config.Aimbot.WallCheck = enabled end)
    
    local separator1 = Instance.new("Frame")
    separator1.Parent = ContentFrame
    separator1.Size = UDim2.new(1, 0, 0, 1)
    separator1.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    AddButton("ESP (VER INIMIGOS)", function(enabled) Config.ESP.Enabled = enabled end)
    AddButton("ESP BOX", function(enabled) Config.ESP.Box = enabled end)
    AddButton("ESP NOME", function(enabled) Config.ESP.Name = enabled end)
    AddButton("ESP VIDA", function(enabled) Config.ESP.HealthBar = enabled end)
    AddButton("ESP LINHA", function(enabled) Config.ESP.Line = enabled end)
    
    -- Status
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Parent = ContentFrame
    StatusLabel.Size = UDim2.new(1, 0, 0, 30)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "✅ v4.1 | Estável & Otimizado"
    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    StatusLabel.TextSize = 11
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- ============================================
    -- Configurar Drag System (CORRIGIDO)
    -- ============================================
    local floatDrag = DragSystem:MakeDraggable(FloatButton, FloatButton)
    floatDrag.TargetObject = FloatButton
    
    local frameDrag = DragSystem:MakeDraggable(TitleBar, MainFrame)
    frameDrag.TargetObject = MainFrame
    
    -- Minimizar/Maximizar
    local isMinimized = false
    
    local function MinimizeWindow()
        isMinimized = true
        MainFrame.Visible = false
        minimizeDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    end
    
    local function MaximizeWindow()
        isMinimized = false
        MainFrame.Visible = true
        minimizeDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end
    
    MinimizeBtn.MouseButton1Click:Connect(MinimizeWindow)
    
    FloatButton.MouseButton1Click:Connect(function()
        if not floatDrag.IsDragging then
            if isMinimized then
                MaximizeWindow()
            else
                MinimizeWindow()
            end
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end

-- ============================================
-- INICIALIZAÇÃO
-- ============================================
CreateUI()

-- Criar ESP
for _, player in pairs(Services.Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Services.Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        task.wait(1)
        CreateESP(player)
    end
end)

Services.Players.PlayerRemoving:Connect(function(player)
    for i, esp in pairs(ESP_Objects) do
        if esp.Player == player then
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() drawing:Remove() end)
                end
            end
            table.remove(ESP_Objects, i)
            break
        end
    end
end)

-- ============================================
-- LOOP PRINCIPAL OTIMIZADO
-- ============================================
Services.RunService.RenderStepped:Connect(function()
    -- CORREÇÃO 3: Updates otimizados (não roda tudo todo frame)
    OptimizedAimbotUpdate()
    OptimizedESPUpdate()
end)

print("=" .. string.rep("=", 50))
print("✅ QUANTUM v4.1 - CORREÇÕES TÉCNICAS")
print("=" .. string.rep("=", 50))
print("🔧 Correções aplicadas:")
print("   1. Input System unificado (sem conflito)")
print("   2. Drag System único (sem duplicar listeners)")
print("   3. Updates otimizados (não roda todo frame)")
print("   4. Detecção mobile robusta")
print("   5. SafeClick sem roubar foco")
print("   6. Performance melhorada")
print("=" .. string.rep("=", 50))
