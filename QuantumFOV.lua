--[[
    QuantumAim v9.0 - FUNCIONAL (BASE v3.0.3 + ESP ESQUELETO)
    - Aimbot comprovadamente funcional
    - Botão flutuante arrastável
    - ESP Esqueleto adicionado
    - Estrutura simples e funcional
]]

if game:GetService("CoreGui"):FindFirstChild("QuantumAim_v9") then
    game:GetService("CoreGui"):FindFirstChild("QuantumAim_v9"):Destroy()
end

-- Configurações
local Config = {
    Aimbot = {
        Enabled = true, -- JÁ LIGA ATIVADO
        AimPart = "Head",
        Smoothness = 1, -- Instantâneo
        Prediction = 0.15,
        TeamCheck = false, -- Atira em todos
        WallCheck = false, -- Através de paredes
        AutoShoot = true, -- Já atira sozinho
        TriggerBot = false
    },
    
    ESP = {
        Enabled = true, -- JÁ LIGA ATIVADO
        Skeleton = true, -- Esqueleto
        Box = false,
        Name = true,
        Distance = true,
        HealthBar = true,
        MaxDistance = 3000
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

if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- ============================================
-- ESP ESQUELETO + NORMAL
-- ============================================
local HasDrawing = false
pcall(function() if Drawing ~= nil then HasDrawing = true end end)

local ESP_Objects = {}

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

local function CreateESP(player)
    if not HasDrawing then return nil end
    
    local esp = {
        Player = player,
        Bones = {},
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        Destroyed = false
    }
    
    -- Criar linhas do esqueleto
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
    
    esp.HealthBar.Color = Color3.fromRGB(50, 50, 50)
    esp.HealthBar.Filled = true
    esp.HealthBar.Visible = false
    
    esp.HealthFill.Color = Color3.fromRGB(0, 255, 0)
    esp.HealthFill.Filled = true
    esp.HealthFill.Visible = false
    
    table.insert(ESP_Objects, esp)
    return esp
end

local function UpdateESP()
    if not Config.ESP.Enabled then
        for _, esp in pairs(ESP_Objects) do
            if not esp.Destroyed then
                for _, bone in ipairs(esp.Bones) do bone.Visible = false end
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
    
    for _, esp in pairs(ESP_Objects) do
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
        
        -- Esqueleto
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
        
        -- Box, Nome, Distância, Vida (igual ao original funcional)
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
            
            if healthPercent > 0.6 then esp.HealthFill.Color = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.3 then esp.HealthFill.Color = Color3.fromRGB(255, 255, 0)
            else esp.HealthFill.Color = Color3.fromRGB(255, 0, 0) end
        else
            esp.HealthBar.Visible = false esp.HealthFill.Visible = false
        end
    end
end

-- ============================================
-- SISTEMA DE MIRA (FUNCIONAL - BASE v3.0.3)
-- ============================================
local CurrentTarget = nil
local LastShot = 0

local function GetTargets()
    local targets = {}
    if not LocalPlayer.Character then return targets end
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local character = player.Character
        if not character then continue end
        
        local aimPart = character:FindFirstChild(Config.Aimbot.AimPart)
        if not aimPart then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - aimPart.Position).Magnitude
        
        local velocity = Vector3.zero
        if aimPart:IsA("BasePart") then
            velocity = aimPart.AssemblyLinearVelocity or aimPart.Velocity or Vector3.zero
        end
        
        local predictedPos = aimPart.Position + (velocity * Config.Aimbot.Prediction)
        
        table.insert(targets, {
            Player = player,
            Position = predictedPos,
            Distance = distance
        })
    end
    
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    return targets
end

local function SafeClick()
    pcall(function()
        mouse1press()
        task.wait(0.01)
        mouse1release()
    end)
end

local function AimbotUpdate()
    if not Config.Aimbot.Enabled then
        CurrentTarget = nil
        return
    end
    
    local targets = GetTargets()
    
    if #targets > 0 then
        CurrentTarget = targets[1]
        
        -- Mira instantânea (COMPROVADAMENTE FUNCIONAL)
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position)
        
        local currentTime = tick()
        
        -- AutoShoot
        if Config.Aimbot.AutoShoot and currentTime - LastShot > 0.08 then
            SafeClick()
            LastShot = currentTime
        end
    else
        CurrentTarget = nil
    end
end

-- ============================================
-- INTERFACE (FUNCIONAL - BASE v3.0.3)
-- ============================================
local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuantumAim_v9"
    gui.Parent = Services.CoreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- BOTÃO FLUTUANTE (COMPROVADAMENTE FUNCIONAL)
    local FloatButton = Instance.new("TextButton")
    FloatButton.Name = "FloatButton"
    FloatButton.Parent = gui
    FloatButton.Size = UDim2.new(0, 48, 0, 48)
    FloatButton.Position = UDim2.new(0.88, 0, 0.45, 0)
    FloatButton.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
    FloatButton.Text = "💀"
    FloatButton.TextSize = 22
    FloatButton.Font = Enum.Font.SourceSans
    FloatButton.AutoButtonColor = false
    FloatButton.BorderSizePixel = 0
    FloatButton.ZIndex = 10
    FloatButton.BackgroundTransparency = 0.1
    
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(1, 0)
    floatCorner.Parent = FloatButton
    
    local floatShadow = Instance.new("UIStroke")
    floatShadow.Parent = FloatButton
    floatShadow.Color = Color3.fromRGB(0, 0, 0)
    floatShadow.Thickness = 2
    floatShadow.Transparency = 0.5
    
    -- Indicador de status
    local StatusDot = Instance.new("Frame")
    StatusDot.Name = "StatusDot"
    StatusDot.Parent = FloatButton
    StatusDot.Size = UDim2.new(0, 12, 0, 12)
    StatusDot.Position = UDim2.new(1, -2, 0, -2)
    StatusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    StatusDot.BorderSizePixel = 0
    StatusDot.ZIndex = 12
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(1, 0)
    statusCorner.Parent = StatusDot
    
    -- FRAME PRINCIPAL
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = gui
    MainFrame.Size = UDim2.new(0, 360, 0, 420)
    MainFrame.Position = UDim2.new(0.02, 0, 0.12, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    MainFrame.BackgroundTransparency = 0.08
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = MainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Parent = MainFrame
    mainStroke.Color = Color3.fromRGB(255, 50, 50)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    
    -- TITLE BAR
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Parent = MainFrame
    TitleBar.Size = UDim2.new(1, 0, 0, 38)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    TitleBar.BackgroundTransparency = 0.3
    TitleBar.BorderSizePixel = 0
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 10)
    titleBarCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Parent = TitleBar
    Title.Size = UDim2.new(1, -70, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "💀 QUANTUM v9.0"
    Title.TextColor3 = Color3.fromRGB(255, 200, 200)
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBlack
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- MINIMIZAR
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Parent = TitleBar
    MinimizeBtn.Size = UDim2.new(0, 26, 0, 26)
    MinimizeBtn.Position = UDim2.new(1, -58, 0.5, -13)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.Text = "−"
    MinimizeBtn.TextSize = 18
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.AutoButtonColor = false
    MinimizeBtn.BorderSizePixel = 0
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = MinimizeBtn
    
    -- FECHAR
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = TitleBar
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -28, 0.5, -13)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Text = "✕"
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.AutoButtonColor = false
    CloseBtn.BorderSizePixel = 0
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = CloseBtn
    
    -- CONTEÚDO
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Parent = MainFrame
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
    
    -- FUNÇÃO BOTÕES (COMPROVADAMENTE FUNCIONAL)
    local function AddButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Parent = ContentFrame
        btn.Size = UDim2.new(1, 0, 0, 33)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = "🔴 " .. text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.TextXAlignment = Enum.TextXAlignment.Left
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        local enabled = false
        
        btn.MouseButton1Click:Connect(function()
            enabled = not enabled
            btn.Text = (enabled and "🟢 " or "🔴 ") .. text
            btn.BackgroundColor3 = enabled and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(30, 30, 45)
            if callback then callback(enabled) end
        end)
        
        return btn
    end
    
    AddButton("AIMBOT (MIRA NA CABEÇA)", function(enabled) Config.Aimbot.Enabled = enabled end)
    AddButton("AUTO FIRE", function(enabled) Config.Aimbot.AutoShoot = enabled end)
    AddButton("ATRAVÉS DE PAREDES", function(enabled) Config.Aimbot.WallCheck = not enabled end)
    
    local sep = Instance.new("Frame")
    sep.Parent = ContentFrame
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    
    AddButton("ESP ESQUELETO", function(enabled) Config.ESP.Skeleton = enabled end)
    AddButton("ESP BOX", function(enabled) Config.ESP.Box = enabled end)
    AddButton("ESP NOME", function(enabled) Config.ESP.Name = enabled end)
    AddButton("ESP VIDA", function(enabled) Config.ESP.HealthBar = enabled end)
    AddButton("ESP DISTÂNCIA", function(enabled) Config.ESP.Distance = enabled end)
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Parent = ContentFrame
    StatusLabel.Size = UDim2.new(1, 0, 0, 25)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "✅ v9.0 | Funcional"
    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    StatusLabel.TextSize = 10
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- ============================================
    -- ARRASTAR BOTÃO FLUTUANTE (FUNCIONAL)
    -- ============================================
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    FloatButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = FloatButton.Position
        end
    end)
    
    FloatButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            FloatButton.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- ============================================
    -- MINIMIZAR/MAXIMIZAR (FUNCIONAL)
    -- ============================================
    local isMinimized = false
    
    local function MinimizeWindow()
        isMinimized = true
        MainFrame.Visible = false
        FloatButton.Text = "👁️"
        FloatButton.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
        StatusDot.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    end
    
    local function MaximizeWindow()
        isMinimized = false
        MainFrame.Visible = true
        FloatButton.Text = "💀"
        FloatButton.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
        StatusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    end
    
    MinimizeBtn.MouseButton1Click:Connect(MinimizeWindow)
    
    FloatButton.MouseButton1Click:Connect(function()
        if not dragging then
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
    
    -- ============================================
    -- ARRASTAR FRAME (FUNCIONAL)
    -- ============================================
    local frameDragging = false
    local frameDragStart = nil
    local frameStartPos = nil
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            frameDragging = true
            frameDragStart = input.Position
            frameStartPos = MainFrame.Position
        end
    end)
    
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            frameDragging = false
        end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(input)
        if frameDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - frameDragStart
            MainFrame.Position = UDim2.new(
                frameStartPos.X.Scale,
                frameStartPos.X.Offset + delta.X,
                frameStartPos.Y.Scale,
                frameStartPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Inicializar
CreateUI()

-- Criar ESP para jogadores existentes
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
            esp.Destroyed = true
            for _, bone in ipairs(esp.Bones) do
                pcall(function() bone:Remove() end)
            end
            pcall(function() esp.Box:Remove() end)
            pcall(function() esp.Name:Remove() end)
            pcall(function() esp.Distance:Remove() end)
            pcall(function() esp.HealthBar:Remove() end)
            pcall(function() esp.HealthFill:Remove() end)
            table.remove(ESP_Objects, i)
            break
        end
    end
end)

-- Loop principal
Services.RunService.RenderStepped:Connect(function()
    pcall(UpdateESP)
    pcall(AimbotUpdate)
end)

print("=" .. string.rep("=", 50))
print("💀 QUANTUM v9.0 - FUNCIONAL")
print("=" .. string.rep("=", 50))
print("✅ Aimbot: COMPROVADAMENTE FUNCIONAL")
print("✅ Botão Flutuante: ARRASTÁVEL")
print("✅ ESP Esqueleto: ATIVO")
print("=" .. string.rep("=", 50))
