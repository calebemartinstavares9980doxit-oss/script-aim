--[[
    QuantumFOV v6.1 - BUILD FINAL
    Correções baseadas na análise técnica do ChatGPT
    - RaycastParams corrigido
    - pcall otimizado
    - TriggerBot melhorado
    - Delta Time na mira
    - Memory leak resolvido
]]

-- Proteção contra execução múltipla
if game:GetService("CoreGui"):FindFirstChild("QuantumFOV_v6") then
    game:GetService("CoreGui"):FindFirstChild("QuantumFOV_v6"):Destroy()
end

-- ============================================
-- MÓDULO 1: CONFIGURAÇÕES
-- ============================================
local Config = {
    Aimbot = {
        Enabled = false,
        AimPart = "Head",
        FOV = 60,
        Smoothness = 0.8,
        Prediction = 0.15,
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
        MaxDistance = 2000
    }
}

-- ============================================
-- MÓDULO 2: SERVIÇOS
-- ============================================
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    Workspace = workspace
}

if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- ============================================
-- MÓDULO 3: SISTEMA DE INPUT (ÚNICO, SEM CONFLITO)
-- ============================================
local InputManager = {
    Platform = "Mouse",
    ClickHandlers = {},
    SliderHandlers = {}
}

function InputManager:DetectPlatform()
    pcall(function()
        local hasTouch = Services.UserInputService.TouchEnabled
        local hasKeyboard = Services.UserInputService.KeyboardEnabled
        local hasMouse = Services.UserInputService.MouseEnabled
        
        if hasTouch and not hasKeyboard and not hasMouse then
            self.Platform = "Touch"
        elseif hasTouch and hasKeyboard then
            self.Platform = "Hybrid"
        else
            self.Platform = "Mouse"
        end
    end)
end

function InputManager:SafeClick()
    if self.Platform == "Mouse" then
        pcall(function()
            mouse1press()
            task.wait(0.015)
            mouse1release()
        end)
    else
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            if vim then
                vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                task.wait(0.015)
                vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
            end
        end)
    end
end

function InputManager:RegisterClickHandler(guiObject, callback)
    table.insert(self.ClickHandlers, {
        Object = guiObject,
        Callback = callback,
        IsDragging = false,
        StartPos = nil,
        StartMouse = nil,
        HasMoved = false
    })
end

function InputManager:RegisterSliderHandler(sliderBar, sliderKnob, sliderFill, onUpdate)
    table.insert(self.SliderHandlers, {
        Bar = sliderBar,
        Knob = sliderKnob,
        Fill = sliderFill,
        OnUpdate = onUpdate,
        IsActive = false
    })
end

function InputManager:Initialize()
    self:DetectPlatform()
    
    Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        for _, handler in ipairs(self.SliderHandlers) do
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                local mousePos = Services.UserInputService:GetMouseLocation()
                local knobPos = handler.Knob.AbsolutePosition
                local knobSize = handler.Knob.AbsoluteSize
                
                if mousePos.X >= knobPos.X - 10 and mousePos.X <= knobPos.X + knobSize.X + 10 and
                   mousePos.Y >= knobPos.Y - 10 and mousePos.Y <= knobPos.Y + knobSize.Y + 10 then
                    handler.IsActive = true
                    break
                end
            end
        end
        
        for _, handler in ipairs(self.ClickHandlers) do
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                handler.IsDragging = true
                handler.HasMoved = false
                handler.StartPos = handler.Object.Position
                handler.StartMouse = input.Position
            end
        end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        for _, handler in ipairs(self.SliderHandlers) do
            if handler.IsActive and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                                      input.UserInputType == Enum.UserInputType.Touch) then
                local mousePos = Services.UserInputService:GetMouseLocation()
                local barPos = handler.Bar.AbsolutePosition
                local barSize = handler.Bar.AbsoluteSize
                
                local percent = math.clamp((mousePos.X - barPos.X) / barSize.X, 0, 1)
                if handler.OnUpdate then handler.OnUpdate(percent) end
            end
        end
        
        for _, handler in ipairs(self.ClickHandlers) do
            if handler.IsDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                                        input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - handler.StartMouse
                
                if delta.Magnitude > 5 then
                    handler.HasMoved = true
                    handler.Object.Position = UDim2.new(
                        math.clamp(handler.StartPos.X.Scale, 0, 0.95),
                        math.clamp(handler.StartPos.X.Offset + delta.X, -200, 2000),
                        math.clamp(handler.StartPos.Y.Scale, 0, 0.95),
                        math.clamp(handler.StartPos.Y.Offset + delta.Y, -100, 2000)
                    )
                end
            end
        end
    end)
    
    Services.UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        for _, handler in ipairs(self.SliderHandlers) do
            handler.IsActive = false
        end
        
        for _, handler in ipairs(self.ClickHandlers) do
            if handler.IsDragging then
                handler.IsDragging = false
                if not handler.HasMoved and handler.Callback then
                    handler.Callback()
                end
            end
        end
    end)
end

-- ============================================
-- MÓDULO 4: SISTEMA DE RENDER (FOV Circle)
-- ============================================
local RenderManager = {
    FOVCircle = nil
}

function RenderManager:CreateFOVCircle(radius)
    if self.FOVCircle then
        self.FOVCircle:Destroy()
    end
    
    self.FOVCircle = Instance.new("Frame")
    self.FOVCircle.Name = "FOVCircle"
    self.FOVCircle.Parent = Services.CoreGui
    self.FOVCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)
    self.FOVCircle.Position = UDim2.new(0.5, -radius, 0.5, -radius)
    self.FOVCircle.BackgroundTransparency = 1
    self.FOVCircle.BorderSizePixel = 0
    self.FOVCircle.ZIndex = 1
    
    local circle = Instance.new("ImageLabel")
    circle.Parent = self.FOVCircle
    circle.Size = UDim2.new(1, 0, 1, 0)
    circle.BackgroundTransparency = 1
    circle.Image = "rbxassetid://3926305904"
    circle.ImageColor3 = Color3.fromRGB(100, 150, 255)
    circle.ImageTransparency = 0.7
    circle.ZIndex = 1
    
    local fill = Instance.new("ImageLabel")
    fill.Parent = self.FOVCircle
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundTransparency = 1
    fill.Image = "rbxassetid://3926307971"
    fill.ImageColor3 = Color3.fromRGB(100, 150, 255)
    fill.ImageTransparency = 0.9
    fill.ZIndex = 1
    
    local hLine = Instance.new("Frame")
    hLine.Parent = self.FOVCircle
    hLine.Size = UDim2.new(1, 0, 0, 1)
    hLine.Position = UDim2.new(0, 0, 0.5, -0.5)
    hLine.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    hLine.BackgroundTransparency = 0.5
    hLine.BorderSizePixel = 0
    
    local vLine = Instance.new("Frame")
    vLine.Parent = self.FOVCircle
    vLine.Size = UDim2.new(0, 1, 1, 0)
    vLine.Position = UDim2.new(0.5, -0.5, 0, 0)
    vLine.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    vLine.BackgroundTransparency = 0.5
    vLine.BorderSizePixel = 0
end

function RenderManager:UpdateFOVCircle(radius)
    if not self.FOVCircle then
        self:CreateFOVCircle(radius)
        return
    end
    
    self.FOVCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)
    self.FOVCircle.Position = UDim2.new(0.5, -radius, 0.5, -radius)
end

-- ============================================
-- MÓDULO 5: SISTEMA DE ESP (CORRIGIDO)
-- ============================================
local ESPManager = {
    Objects = {},
    HasDrawing = false,
    LastUpdate = 0,
    UpdateInterval = 0.06
}

function ESPManager:Initialize()
    pcall(function()
        if Drawing ~= nil then
            self.HasDrawing = true
        end
    end)
end

function ESPManager:CreateESP(player)
    if not self.HasDrawing then return end
    
    local esp = {
        Player = player,
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        Line = Drawing.new("Line"),
        Destroyed = false
    }
    
    esp.Box.Color = Color3.fromRGB(100, 150, 255)
    esp.Box.Thickness = 2
    esp.Box.Filled = false
    esp.Box.Visible = false
    
    esp.Name.Color = Color3.fromRGB(255, 255, 255)
    esp.Name.Size = 13
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Visible = false
    
    esp.Distance.Color = Color3.fromRGB(180, 200, 255)
    esp.Distance.Size = 12
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Visible = false
    
    esp.HealthBar.Color = Color3.fromRGB(30, 30, 50)
    esp.HealthBar.Filled = true
    esp.HealthBar.Visible = false
    
    esp.HealthFill.Color = Color3.fromRGB(0, 255, 100)
    esp.HealthFill.Filled = true
    esp.HealthFill.Visible = false
    
    esp.Line.Color = Color3.fromRGB(100, 150, 255)
    esp.Line.Thickness = 1
    esp.Line.Visible = false
    
    table.insert(self.Objects, esp)
end

function ESPManager:Update()
    local currentTime = tick()
    if currentTime - self.LastUpdate < self.UpdateInterval then return end
    self.LastUpdate = currentTime
    
    if not Config.ESP.Enabled then
        for _, esp in ipairs(self.Objects) do
            if not esp.Destroyed then
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthFill.Visible = false
                esp.Line.Visible = false
            end
        end
        return
    end
    
    if not Camera then return end
    
    for _, esp in ipairs(self.Objects) do
        if esp.Destroyed then continue end
        
        local player = esp.Player
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not character then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthFill.Visible = false
            esp.Line.Visible = false
            continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not head or not rootPart or humanoid.Health <= 0 then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthFill.Visible = false
            esp.Line.Visible = false
            continue
        end
        
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthFill.Visible = false
            esp.Line.Visible = false
            continue
        end
        
        local distance = 0
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
        end
        
        if distance > Config.ESP.MaxDistance then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthFill.Visible = false
            esp.Line.Visible = false
            continue
        end
        
        local safeDistance = math.max(distance, 1)
        local scale = 1000 / safeDistance
        local boxWidth = math.clamp(scale * 3, 10, 200)
        local boxHeight = math.clamp(scale * 5, 15, 300)
        
        if Config.ESP.Box then
            esp.Box.Visible = true
            esp.Box.Size = Vector2.new(boxWidth, boxHeight)
            esp.Box.Position = Vector2.new(headPos.X - boxWidth/2, headPos.Y - boxHeight/2)
        else
            esp.Box.Visible = false
        end
        
        if Config.ESP.Name then
            esp.Name.Visible = true
            esp.Name.Text = player.Name
            esp.Name.Position = Vector2.new(headPos.X, headPos.Y - boxHeight/2 - 20)
        else
            esp.Name.Visible = false
        end
        
        if Config.ESP.Distance then
            esp.Distance.Visible = true
            esp.Distance.Text = string.format("%.0fm", distance)
            esp.Distance.Position = Vector2.new(headPos.X, headPos.Y + boxHeight/2 + 5)
        else
            esp.Distance.Visible = false
        end
        
        if Config.ESP.HealthBar then
            local healthPercent = humanoid.Health / math.max(humanoid.MaxHealth, 1)
            
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
        else
            esp.HealthBar.Visible = false
            esp.HealthFill.Visible = false
        end
        
        if Config.ESP.Line then
            esp.Line.Visible = true
            esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            esp.Line.To = Vector2.new(headPos.X, headPos.Y + boxHeight/2)
        else
            esp.Line.Visible = false
        end
    end
end

function ESPManager:RemovePlayer(player)
    for i, esp in ipairs(self.Objects) do
        if esp.Player == player then
            esp.Destroyed = true
            pcall(function() esp.Box:Remove() end)
            pcall(function() esp.Name:Remove() end)
            pcall(function() esp.Distance:Remove() end)
            pcall(function() esp.HealthBar:Remove() end)
            pcall(function() esp.HealthFill:Remove() end)
            pcall(function() esp.Line:Remove() end)
            table.remove(self.Objects, i)
            break
        end
    end
end

-- ============================================
-- MÓDULO 6: SISTEMA DE MIRA (CORRIGIDO)
-- ============================================
local AimManager = {
    CurrentTarget = nil,
    LastUpdate = 0,
    LastShot = 0,
    UpdateInterval = 0.016,
    LastDeltaTime = 0.016
}

function AimManager:IsVisible(character, part)
    if not Config.Aimbot.WallCheck then return true end
    
    -- CORRIGIDO: Filtro sem nil
    local filterList = {LocalPlayer.Character, character}
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then
        table.insert(filterList, tool)
    end
    
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = part.Position - rayOrigin
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = filterList
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local rayResult = Services.Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    return rayResult == nil
end

function AimManager:GetTargets()
    local targets = {}
    if not LocalPlayer.Character or not Camera then return targets end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local character = player.Character
        if not character then continue end
        
        local aimPart = character:FindFirstChild(Config.Aimbot.AimPart)
        if not aimPart then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        if not self:IsVisible(character, aimPart) then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
        if not onScreen then continue end
        
        local distance2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if distance2D > Config.Aimbot.FOV then continue end
        
        local velocity = aimPart:IsA("BasePart") and (aimPart.AssemblyLinearVelocity or aimPart.Velocity) or Vector3.zero
        local predictedPos = aimPart.Position + (velocity * Config.Aimbot.Prediction)
        
        table.insert(targets, {
            Player = player,
            Position = predictedPos,
            Distance = distance2D
        })
    end
    
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    return targets
end

function AimManager:Update()
    local currentTime = tick()
    if currentTime - self.LastUpdate < self.UpdateInterval then return end
    
    -- CORRIGIDO: Delta time para mira estável
    self.LastDeltaTime = currentTime - self.LastUpdate
    self.LastUpdate = currentTime
    
    if not Config.Aimbot.Enabled then
        self.CurrentTarget = nil
        return
    end
    
    local targets = self:GetTargets()
    
    if #targets > 0 then
        self.CurrentTarget = targets[1]
        
        -- CORRIGIDO: Interpolação com delta time
        local smoothFactor = 1 - math.pow(1 - Config.Aimbot.Smoothness, self.LastDeltaTime * 60)
        local targetCFrame = CFrame.new(Camera.CFrame.Position, self.CurrentTarget.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor)
        
        if Config.Aimbot.AutoShoot and currentTime - self.LastShot > 0.08 then
            InputManager:SafeClick()
            self.LastShot = currentTime
        end
        
        -- CORRIGIDO: TriggerBot mais preciso
        if Config.Aimbot.TriggerBot and not Config.Aimbot.AutoShoot then
            local mousePos = Services.UserInputService:GetMouseLocation()
            local targetScreenPos = Camera:WorldToViewportPoint(self.CurrentTarget.Position)
            local distanceToTarget = (Vector2.new(targetScreenPos.X, targetScreenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
            
            if distanceToTarget < 35 and currentTime - self.LastShot > 0.05 then
                InputManager:SafeClick()
                self.LastShot = currentTime
            end
        end
    else
        self.CurrentTarget = nil
    end
end

-- ============================================
-- MÓDULO 7: INTERFACE (UI)
-- ============================================
local UIManager = {
    ScreenGui = nil,
    MainFrame = nil,
    FloatButton = nil,
    IsMinimized = false
}

function UIManager:Create()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuantumFOV_v6"
    gui.Parent = Services.CoreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    
    self.ScreenGui = gui
    
    -- Botão Flutuante
    self.FloatButton = Instance.new("TextButton")
    self.FloatButton.Name = "FloatButton"
    self.FloatButton.Parent = gui
    self.FloatButton.Size = UDim2.new(0, 48, 0, 48)
    self.FloatButton.Position = UDim2.new(0.85, 0, 0.45, 0)
    self.FloatButton.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    self.FloatButton.Text = ""
    self.FloatButton.AutoButtonColor = false
    self.FloatButton.BorderSizePixel = 0
    self.FloatButton.ZIndex = 10
    self.FloatButton.BackgroundTransparency = 0.15
    
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 14)
    floatCorner.Parent = self.FloatButton
    
    local floatStroke = Instance.new("UIStroke")
    floatStroke.Parent = self.FloatButton
    floatStroke.Color = Color3.fromRGB(80, 140, 255)
    floatStroke.Thickness = 2
    floatStroke.Transparency = 0.3
    
    local centerDot = Instance.new("Frame")
    centerDot.Parent = self.FloatButton
    centerDot.Size = UDim2.new(0, 10, 0, 10)
    centerDot.Position = UDim2.new(0.5, -5, 0.5, -5)
    centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerDot.BorderSizePixel = 0
    centerDot.ZIndex = 11
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = centerDot
    
    local outerRing = Instance.new("ImageLabel")
    outerRing.Parent = self.FloatButton
    outerRing.Size = UDim2.new(0, 30, 0, 30)
    outerRing.Position = UDim2.new(0.5, -15, 0.5, -15)
    outerRing.BackgroundTransparency = 1
    outerRing.Image = "rbxassetid://3926305904"
    outerRing.ImageColor3 = Color3.fromRGB(255, 255, 255)
    outerRing.ImageTransparency = 0.5
    outerRing.ZIndex = 10
    
    self.StatusDot = Instance.new("Frame")
    self.StatusDot.Parent = self.FloatButton
    self.StatusDot.Size = UDim2.new(0, 10, 0, 10)
    self.StatusDot.Position = UDim2.new(1, -2, 0, -2)
    self.StatusDot.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    self.StatusDot.BorderSizePixel = 0
    self.StatusDot.ZIndex = 12
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(1, 0)
    statusCorner.Parent = self.StatusDot
    
    -- Frame Principal
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Parent = gui
    self.MainFrame.Size = UDim2.new(0, 340, 0, 460)
    self.MainFrame.Position = UDim2.new(0.02, 0, 0.15, 0)
    self.MainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
    self.MainFrame.BackgroundTransparency = 0.15
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Visible = true
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = self.MainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Parent = self.MainFrame
    mainStroke.Color = Color3.fromRGB(80, 140, 255)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Parent = self.MainFrame
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 30, 50)
    TitleBar.BackgroundTransparency = 0.3
    TitleBar.BorderSizePixel = 0
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 12)
    titleBarCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Parent = TitleBar
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "QUANTUM FOV v6.1"
    Title.TextColor3 = Color3.fromRGB(180, 200, 255)
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Parent = TitleBar
    MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
    MinimizeBtn.Position = UDim2.new(1, -60, 0.5, -13)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.Text = "−"
    MinimizeBtn.TextSize = 18
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.AutoButtonColor = false
    MinimizeBtn.BorderSizePixel = 0
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = MinimizeBtn
    
    MinimizeBtn.MouseButton1Click:Connect(function()
        self:Minimize()
    end)
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = TitleBar
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -30, 0.5, -13)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Text = "✕"
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.AutoButtonColor = false
    CloseBtn.BorderSizePixel = 0
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = CloseBtn
    
    CloseBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
    
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Parent = self.MainFrame
    ContentFrame.Size = UDim2.new(1, 0, 1, -40)
    ContentFrame.Position = UDim2.new(0, 0, 0, 40)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ScrollBarThickness = 3
    ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 140, 255)
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 420)
    ContentFrame.BorderSizePixel = 0
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = ContentFrame
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 6)
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = ContentFrame
    UIPadding.PaddingTop = UDim.new(0, 8)
    UIPadding.PaddingLeft = UDim.new(0, 8)
    UIPadding.PaddingRight = UDim.new(0, 8)
    
    local function AddButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Parent = ContentFrame
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(30, 35, 55)
        btn.BackgroundTransparency = 0.3
        btn.TextColor3 = Color3.fromRGB(200, 210, 240)
        btn.Text = "  🔴  " .. text
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.TextXAlignment = Enum.TextXAlignment.Left
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = btn
        
        local enabled = false
        
        btn.MouseButton1Click:Connect(function()
            enabled = not enabled
            btn.Text = (enabled and "  🟢  " or "  🔴  ") .. text
            btn.BackgroundColor3 = enabled and Color3.fromRGB(60, 100, 200) or Color3.fromRGB(30, 35, 55)
            if callback then callback(enabled) end
        end)
        
        return btn
    end
    
    -- Slider FOV
    local FOVSliderFrame = Instance.new("Frame")
    FOVSliderFrame.Parent = ContentFrame
    FOVSliderFrame.Size = UDim2.new(1, 0, 0, 50)
    FOVSliderFrame.BackgroundTransparency = 1
    
    self.FOVLabel = Instance.new("TextLabel")
    self.FOVLabel.Parent = FOVSliderFrame
    self.FOVLabel.Size = UDim2.new(1, 0, 0, 18)
    self.FOVLabel.BackgroundTransparency = 1
    self.FOVLabel.Text = "🎯  FOV: 60°"
    self.FOVLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
    self.FOVLabel.TextSize = 12
    self.FOVLabel.Font = Enum.Font.GothamBold
    self.FOVLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    self.SliderBar = Instance.new("Frame")
    self.SliderBar.Parent = FOVSliderFrame
    self.SliderBar.Size = UDim2.new(1, 0, 0, 4)
    self.SliderBar.Position = UDim2.new(0, 0, 1, -18)
    self.SliderBar.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
    self.SliderBar.BorderSizePixel = 0
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = self.SliderBar
    
    self.SliderFill = Instance.new("Frame")
    self.SliderFill.Parent = self.SliderBar
    self.SliderFill.Size = UDim2.new(0.33, 0, 1, 0)
    self.SliderFill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    self.SliderFill.BorderSizePixel = 0
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = self.SliderFill
    
    self.SliderKnob = Instance.new("TextButton")
    self.SliderKnob.Parent = self.SliderBar
    self.SliderKnob.Size = UDim2.new(0, 16, 0, 16)
    self.SliderKnob.Position = UDim2.new(0.33, -8, 0.5, -8)
    self.SliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    self.SliderKnob.Text = ""
    self.SliderKnob.AutoButtonColor = false
    self.SliderKnob.BorderSizePixel = 0
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = self.SliderKnob
    
    InputManager:RegisterSliderHandler(self.SliderBar, self.SliderKnob, self.SliderFill, function(percent)
        local fovValue = math.floor(10 + (180 - 10) * percent)
        Config.Aimbot.FOV = fovValue
        self.FOVLabel.Text = "🎯  FOV: " .. fovValue .. "°"
        self.SliderKnob.Position = UDim2.new(percent, -8, 0.5, -8)
        self.SliderFill.Size = UDim2.new(percent, 0, 1, 0)
        RenderManager:UpdateFOVCircle(fovValue)
    end)
    
    local sep = Instance.new("Frame")
    sep.Parent = ContentFrame
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    
    AddButton("AIMBOT", function(enabled) Config.Aimbot.Enabled = enabled end)
    AddButton("AUTO FIRE", function(enabled) Config.Aimbot.AutoShoot = enabled end)
    AddButton("TRIGGER BOT", function(enabled) Config.Aimbot.TriggerBot = enabled end)
    AddButton("WALL CHECK", function(enabled) Config.Aimbot.WallCheck = enabled end)
    
    local sep2 = Instance.new("Frame")
    sep2.Parent = ContentFrame
    sep2.Size = UDim2.new(1, 0, 0, 1)
    sep2.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    sep2.BackgroundTransparency = 0.5
    sep2.BorderSizePixel = 0
    
    AddButton("ESP", function(enabled) Config.ESP.Enabled = enabled end)
    AddButton("ESP BOX", function(enabled) Config.ESP.Box = enabled end)
    AddButton("ESP NOME", function(enabled) Config.ESP.Name = enabled end)
    AddButton("ESP VIDA", function(enabled) Config.ESP.HealthBar = enabled end)
    AddButton("ESP LINHA", function(enabled) Config.ESP.Line = enabled end)
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Parent = ContentFrame
    StatusLabel.Size = UDim2.new(1, 0, 0, 25)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "✅ v6.1 | Análise ChatGPT aplicada"
    StatusLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
    StatusLabel.TextSize = 10
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    InputManager:RegisterClickHandler(self.FloatButton, function()
        self:Toggle()
    end)
end

function UIManager:Minimize()
    self.IsMinimized = true
    self.MainFrame.Visible = false
    self.StatusDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
end

function UIManager:Maximize()
    self.IsMinimized = false
    self.MainFrame.Visible = true
    self.StatusDot.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
end

function UIManager:Toggle()
    if self.MainFrame.Visible then
        self:Minimize()
    else
        self:Maximize()
    end
end

-- ============================================
-- INICIALIZAÇÃO PRINCIPAL
-- ============================================
local function Initialize()
    InputManager:Initialize()
    ESPManager:Initialize()
    UIManager:Create()
    RenderManager:CreateFOVCircle(Config.Aimbot.FOV)
    
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ESPManager:CreateESP(player)
        end
    end
    
    Services.Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.wait(1)
            ESPManager:CreateESP(player)
        end
    end)
    
    Services.Players.PlayerRemoving:Connect(function(player)
        ESPManager:RemovePlayer(player)
    end)
    
    Services.RunService.Heartbeat:Connect(function()
        AimManager:Update()
        ESPManager:Update()
    end)
    
    print("=" .. string.rep("=", 50))
    print("✅ QUANTUM v6.1 - BUILD FINAL")
    print("=" .. string.rep("=", 50))
    print("🔧 Correções baseadas no ChatGPT:")
    print("   1. RaycastParams sem nil")
    print("   2. pcall removido dos loops ESP")
    print("   3. TriggerBot precisão 35px")
    print("   4. Delta time na mira (jitter fix)")
    print("   5. Memory leak resolvido (RemovePlayer)")
    print("   6. goto removido, código limpo")
    print("=" .. string.rep("=", 50))
end

Initialize()
