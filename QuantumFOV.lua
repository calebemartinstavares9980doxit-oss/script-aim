--[[
    QuantumAim v8.0 - AIMBOT APELÃO + ESP ESQUELETO
    - Mira instantânea na cabeça
    - ESP mostrando esqueleto dos inimigos
    - Sem FOV Circle (mais limpo)
    - Ultra agressivo
]]

if game:GetService("CoreGui"):FindFirstChild("QuantumAim_v8") then
    game:GetService("CoreGui"):FindFirstChild("QuantumAim_v8"):Destroy()
end

-- Configurações
local Config = {
    Aimbot = {
        Enabled = false,
        AimPart = "Head", -- Head = cabeça, HumanoidRootPart = peito
        Smoothness = 1, -- 1 = instantâneo (apelão)
        Prediction = 0.2, -- Predição de movimento
        TeamCheck = false, -- false = atira em todos
        WallCheck = false, -- false = atira através de paredes
        AutoShoot = true, -- Já liga atirando
        TriggerBot = false,
        MaxDistance = 5000 -- Alcance máximo
    },
    ESP = {
        Enabled = false,
        Skeleton = false, -- Esqueleto completo
        Box = false,
        Name = false,
        Distance = false,
        HealthBar = false,
        MaxDistance = 3000
    }
}

-- Serviços
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    UserInputService = game:GetService("UserInputService"),
    Workspace = workspace
}

if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- Sistema de Input (SIMPLIFICADO)
local InputManager = {
    ClickHandlers = {},
    Platform = "Mouse"
}

function InputManager:DetectPlatform()
    pcall(function()
        local hasTouch = Services.UserInputService.TouchEnabled
        local hasKeyboard = Services.UserInputService.KeyboardEnabled
        if hasTouch and not hasKeyboard then
            self.Platform = "Touch"
        else
            self.Platform = "Mouse"
        end
    end)
end

function InputManager:SafeClick()
    if self.Platform == "Mouse" then
        pcall(function() mouse1press() task.wait(0.01) mouse1release() end)
    else
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            if vim then
                vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                task.wait(0.01)
                vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
            end
        end)
    end
end

function InputManager:IsClickOnObject(input, guiObject)
    if not guiObject or not input then return false end
    local mousePos = Services.UserInputService:GetMouseLocation()
    local objPos = guiObject.AbsolutePosition
    local objSize = guiObject.AbsoluteSize
    return mousePos.X >= objPos.X and mousePos.X <= objPos.X + objSize.X and
           mousePos.Y >= objPos.Y and mousePos.Y <= objPos.Y + objSize.Y
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

function InputManager:Initialize()
    self:DetectPlatform()
    
    Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        for _, handler in ipairs(self.ClickHandlers) do
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                if self:IsClickOnObject(input, handler.Object) then
                    handler.IsDragging = true
                    handler.HasMoved = false
                    handler.StartPos = handler.Object.Position
                    handler.StartMouse = input.Position
                    return
                end
            end
        end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
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
-- SISTEMA DE ESP ESQUELETO
-- ============================================
local ESPManager = {
    Objects = {},
    HasDrawing = false,
    LastUpdate = 0,
    UpdateInterval = 0.05
}

-- Partes do esqueleto
local SkeletonParts = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
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
        Bones = {}, -- Linhas do esqueleto
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        Destroyed = false
    }
    
    -- Criar linhas para cada osso
    for _ = 1, #SkeletonParts do
        local line = Drawing.new("Line")
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Thickness = 1.5
        line.Visible = false
        table.insert(esp.Bones, line)
    end
    
    esp.Box.Color = Color3.fromRGB(255, 50, 50)
    esp.Box.Thickness = 2
    esp.Box.Filled = false
    esp.Box.Visible = false
    
    esp.Name.Color = Color3.fromRGB(255, 255, 255)
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Visible = false
    
    esp.Distance.Color = Color3.fromRGB(200, 200, 200)
    esp.Distance.Size = 12
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Visible = false
    
    esp.HealthBar.Color = Color3.fromRGB(30, 30, 30)
    esp.HealthBar.Filled = true
    esp.HealthBar.Visible = false
    
    esp.HealthFill.Color = Color3.fromRGB(0, 255, 0)
    esp.HealthFill.Filled = true
    esp.HealthFill.Visible = false
    
    table.insert(self.Objects, esp)
end

function ESPManager:Update()
    local currentTime = os.clock()
    if currentTime - self.LastUpdate < self.UpdateInterval then return end
    self.LastUpdate = currentTime
    
    if not Config.ESP.Enabled then
        for _, esp in ipairs(self.Objects) do
            if not esp.Destroyed then
                for _, bone in ipairs(esp.Bones) do
                    bone.Visible = false
                end
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthFill.Visible = false
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
            for _, bone in ipairs(esp.Bones) do bone.Visible = false end
            esp.Box.Visible = false esp.Name.Visible = false esp.Distance.Visible = false
            esp.HealthBar.Visible = false esp.HealthFill.Visible = false
            continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not head or not rootPart or humanoid.Health <= 0 then
            for _, bone in ipairs(esp.Bones) do bone.Visible = false end
            esp.Box.Visible = false esp.Name.Visible = false esp.Distance.Visible = false
            esp.HealthBar.Visible = false esp.HealthFill.Visible = false
            continue
        end
        
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        
        if not onScreen then
            for _, bone in ipairs(esp.Bones) do bone.Visible = false end
            esp.Box.Visible = false esp.Name.Visible = false esp.Distance.Visible = false
            esp.HealthBar.Visible = false esp.HealthFill.Visible = false
            continue
        end
        
        local distance = 0
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
        end
        
        if distance > Config.ESP.MaxDistance then
            for _, bone in ipairs(esp.Bones) do bone.Visible = false end
            esp.Box.Visible = false esp.Name.Visible = false esp.Distance.Visible = false
            esp.HealthBar.Visible = false esp.HealthFill.Visible = false
            continue
        end
        
        -- ESP Esqueleto
        if Config.ESP.Skeleton then
            for i, partPair in ipairs(SkeletonParts) do
                local partA = character:FindFirstChild(partPair[1])
                local partB = character:FindFirstChild(partPair[2])
                
                if partA and partB then
                    local posA, visibleA = Camera:WorldToViewportPoint(partA.Position)
                    local posB, visibleB = Camera:WorldToViewportPoint(partB.Position)
                    
                    if visibleA and visibleB then
                        esp.Bones[i].Visible = true
                        esp.Bones[i].From = Vector2.new(posA.X, posA.Y)
                        esp.Bones[i].To = Vector2.new(posB.X, posB.Y)
                    else
                        esp.Bones[i].Visible = false
                    end
                else
                    esp.Bones[i].Visible = false
                end
            end
        else
            for _, bone in ipairs(esp.Bones) do bone.Visible = false end
        end
        
        -- Box
        local safeDistance = math.max(distance, 1)
        local scale = 1000 / safeDistance
        local boxWidth = math.clamp(scale * 3, 10, 200)
        local boxHeight = math.clamp(scale * 5, 15, 300)
        
        if Config.ESP.Box then
            esp.Box.Visible = true
            esp.Box.Size = Vector2.new(boxWidth, boxHeight)
            esp.Box.Position = Vector2.new(headPos.X - boxWidth/2, headPos.Y - boxHeight/2)
        else esp.Box.Visible = false end
        
        if Config.ESP.Name then
            esp.Name.Visible = true
            esp.Name.Text = player.Name
            esp.Name.Position = Vector2.new(headPos.X, headPos.Y - boxHeight/2 - 20)
        else esp.Name.Visible = false end
        
        if Config.ESP.Distance then
            esp.Distance.Visible = true
            esp.Distance.Text = string.format("%.0fm", distance)
            esp.Distance.Position = Vector2.new(headPos.X, headPos.Y + boxHeight/2 + 5)
        else esp.Distance.Visible = false end
        
        if Config.ESP.HealthBar then
            local healthPercent = humanoid.Health / math.max(humanoid.MaxHealth, 1)
            esp.HealthBar.Visible = true
            esp.HealthBar.Size = Vector2.new(3, boxHeight)
            esp.HealthBar.Position = Vector2.new(headPos.X - boxWidth/2 - 5, headPos.Y - boxHeight/2)
            
            esp.HealthFill.Visible = true
            esp.HealthFill.Size = Vector2.new(3, boxHeight * healthPercent)
            esp.HealthFill.Position = Vector2.new(headPos.X - boxWidth/2 - 5, 
                headPos.Y - boxHeight/2 + boxHeight * (1 - healthPercent))
        else
            esp.HealthBar.Visible = false esp.HealthFill.Visible = false
        end
    end
end

function ESPManager:RemovePlayer(player)
    for i, esp in ipairs(self.Objects) do
        if esp.Player == player then
            esp.Destroyed = true
            for _, bone in ipairs(esp.Bones) do
                pcall(function() bone:Remove() end)
            end
            pcall(function() esp.Box:Remove() end)
            pcall(function() esp.Name:Remove() end)
            pcall(function() esp.Distance:Remove() end)
            pcall(function() esp.HealthBar:Remove() end)
            pcall(function() esp.HealthFill:Remove() end)
            table.remove(self.Objects, i)
            break
        end
    end
end

-- ============================================
-- SISTEMA DE AIMBOT APELÃO
-- ============================================
local AimManager = {
    CurrentTarget = nil,
    LastShot = 0,
    ShotCooldown = 0.05 -- 20 tiros por segundo
}

function AimManager:GetBestTarget()
    if not LocalPlayer.Character or not Camera then return nil end
    
    local bestTarget = nil
    local closestDistance = Config.Aimbot.MaxDistance
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
        
        local distance3D = (LocalPlayer.Character.HumanoidRootPart.Position - aimPart.Position).Magnitude
        if distance3D > Config.Aimbot.MaxDistance then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
        if not onScreen then continue end
        
        local distance2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        
        if distance3D < closestDistance then
            closestDistance = distance3D
            
            local velocity = aimPart:IsA("BasePart") and (aimPart.AssemblyLinearVelocity or aimPart.Velocity) or Vector3.zero
            local predictedPos = aimPart.Position + (velocity * Config.Aimbot.Prediction)
            
            bestTarget = {
                Player = player,
                Position = predictedPos,
                Distance = distance3D
            }
        end
    end
    
    return bestTarget
end

function AimManager:Update()
    if not Config.Aimbot.Enabled then
        self.CurrentTarget = nil
        return
    end
    
    local target = self:GetBestTarget()
    
    if target then
        self.CurrentTarget = target
        
        -- Mira instantânea na cabeça (APELÃO)
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        
        -- AutoShoot disparando loucamente
        if Config.Aimbot.AutoShoot then
            local currentTime = os.clock()
            if currentTime - self.LastShot > self.ShotCooldown then
                InputManager:SafeClick()
                self.LastShot = currentTime
            end
        end
    else
        self.CurrentTarget = nil
    end
end

-- ============================================
-- INTERFACE SIMPLES
-- ============================================
local UIManager = {
    ScreenGui = nil,
    MainFrame = nil,
    FloatButton = nil
}

function UIManager:Create()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuantumAim_v8"
    gui.Parent = Services.CoreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    
    self.ScreenGui = gui
    
    -- Botão Flutuante
    self.FloatButton = Instance.new("TextButton")
    self.FloatButton.Name = "FloatButton"
    self.FloatButton.Parent = gui
    self.FloatButton.Size = UDim2.new(0, 45, 0, 45)
    self.FloatButton.Position = UDim2.new(0.88, 0, 0.45, 0)
    self.FloatButton.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
    self.FloatButton.Text = "🎯"
    self.FloatButton.TextSize = 20
    self.FloatButton.AutoButtonColor = false
    self.FloatButton.BorderSizePixel = 0
    self.FloatButton.ZIndex = 10
    self.FloatButton.BackgroundTransparency = 0.1
    
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 14)
    floatCorner.Parent = self.FloatButton
    
    self.StatusDot = Instance.new("Frame")
    self.StatusDot.Parent = self.FloatButton
    self.StatusDot.Size = UDim2.new(0, 10, 0, 10)
    self.StatusDot.Position = UDim2.new(1, -2, 0, -2)
    self.StatusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    self.StatusDot.BorderSizePixel = 0
    self.StatusDot.ZIndex = 12
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(1, 0)
    statusCorner.Parent = self.StatusDot
    
    -- Frame Principal
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Parent = gui
    self.MainFrame.Size = UDim2.new(0, 320, 0, 380)
    self.MainFrame.Position = UDim2.new(0.02, 0, 0.15, 0)
    self.MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    self.MainFrame.BackgroundTransparency = 0.1
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Visible = true
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = self.MainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Parent = self.MainFrame
    mainStroke.Color = Color3.fromRGB(255, 50, 50)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    
    -- TitleBar
    local TitleBar = Instance.new("Frame")
    TitleBar.Parent = self.MainFrame
    TitleBar.Size = UDim2.new(1, 0, 0, 38)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    TitleBar.BackgroundTransparency = 0.3
    TitleBar.BorderSizePixel = 0
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 10)
    titleBarCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Parent = TitleBar
    Title.Size = UDim2.new(1, -60, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "💀 QUANTUM AIM"
    Title.TextColor3 = Color3.fromRGB(255, 200, 200)
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBlack
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Parent = TitleBar
    MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
    MinimizeBtn.Position = UDim2.new(1, -30, 0.5, -12)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.Text = "−"
    MinimizeBtn.TextSize = 16
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.AutoButtonColor = false
    MinimizeBtn.BorderSizePixel = 0
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = MinimizeBtn
    
    MinimizeBtn.MouseButton1Click:Connect(function()
        self.MainFrame.Visible = false
        self.StatusDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    end)
    
    -- Conteúdo
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Parent = self.MainFrame
    ContentFrame.Size = UDim2.new(1, 0, 1, -38)
    ContentFrame.Position = UDim2.new(0, 0, 0, 38)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ScrollBarThickness = 3
    ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 50, 50)
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 350)
    ContentFrame.BorderSizePixel = 0
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = ContentFrame
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 5)
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = ContentFrame
    UIPadding.PaddingTop = UDim.new(0, 8)
    UIPadding.PaddingLeft = UDim.new(0, 8)
    UIPadding.PaddingRight = UDim.new(0, 8)
    
    local function AddButton(text, callback, defaultEnabled)
        local btn = Instance.new("TextButton")
        btn.Parent = ContentFrame
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = defaultEnabled and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(30, 30, 45)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = (defaultEnabled and "  🟢  " or "  🔴  ") .. text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.TextXAlignment = Enum.TextXAlignment.Left
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        local enabled = defaultEnabled or false
        
        btn.MouseButton1Click:Connect(function()
            enabled = not enabled
            btn.Text = (enabled and "  🟢  " or "  🔴  ") .. text
            btn.BackgroundColor3 = enabled and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(30, 30, 45)
            if callback then callback(enabled) end
        end)
        
        return btn
    end
    
    AddButton("AIMBOT (MIRA NA CABEÇA)", function(enabled) Config.Aimbot.Enabled = enabled end, true)
    AddButton("AUTO FIRE (ATIRA SOZINHO)", function(enabled) Config.Aimbot.AutoShoot = enabled end, true)
    AddButton("ATRAVÉS DE PAREDES", function(enabled) Config.Aimbot.WallCheck = not enabled end, true)
    AddButton("MIRAR EM TODOS", function(enabled) Config.Aimbot.TeamCheck = not enabled end, true)
    
    local sep = Instance.new("Frame")
    sep.Parent = ContentFrame
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    
    AddButton("ESP ESQUELETO", function(enabled) Config.ESP.Skeleton = enabled end, true)
    AddButton("ESP BOX", function(enabled) Config.ESP.Box = enabled end, true)
    AddButton("ESP NOME", function(enabled) Config.ESP.Name = enabled end, true)
    AddButton("ESP VIDA", function(enabled) Config.ESP.HealthBar = enabled end, true)
    AddButton("ESP DISTÂNCIA", function(enabled) Config.ESP.Distance = enabled end, true)
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Parent = ContentFrame
    StatusLabel.Size = UDim2.new(1, 0, 0, 25)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "💀 AIMBOT APELÃO ATIVO"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    StatusLabel.TextSize = 10
    StatusLabel.Font = Enum.Font.GothamBlack
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    InputManager:RegisterClickHandler(self.FloatButton, function()
        self.MainFrame.Visible = not self.MainFrame.Visible
        if self.MainFrame.Visible then
            self.StatusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        else
            self.StatusDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
        end
    end)
end

-- ============================================
-- INICIALIZAÇÃO
-- ============================================
local function Initialize()
    -- Já liga o aimbot e ESP
    Config.Aimbot.Enabled = true
    Config.Aimbot.AutoShoot = true
    Config.Aimbot.WallCheck = false
    Config.Aimbot.TeamCheck = false
    Config.ESP.Enabled = true
    Config.ESP.Skeleton = true
    
    InputManager:Initialize()
    ESPManager:Initialize()
    UIManager:Create()
    
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
    print("💀 QUANTUM AIM v8.0 - AIMBOT APELÃO")
    print("=" .. string.rep("=", 50))
    print("🎯 Mira instantânea na cabeça")
    print("🔫 AutoFire 20 tiros/segundo")
    print("🧱 Através de paredes")
    print("🦴 ESP Esqueleto")
    print("=" .. string.rep("=", 50))
end

Initialize()
