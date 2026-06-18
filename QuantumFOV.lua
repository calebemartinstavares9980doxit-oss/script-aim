--[[
    QuantumAim PRO - Aimbot + ESP System (VERSÃO FINAL CORRIGIDA)
    Versão: 3.0.2
    TODOS os bugs corrigidos
]]

-- Proteção contra execução múltipla
if game:GetService("CoreGui"):FindFirstChild("QuantumAimPRO") then
    game:GetService("CoreGui"):FindFirstChild("QuantumAimPRO"):Destroy()
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
        WallCheck = false, -- false = atira através de paredes, true = respeita paredes
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

-- Serviços
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    UserInputService = game:GetService("UserInputService"),
    Workspace = workspace
}

-- Proteção Delta
if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- ============================================
-- CORREÇÃO 3: Verificação segura do Drawing
-- ============================================
local HasDrawing = false
pcall(function()
    if Drawing ~= nil then
        HasDrawing = true
    end
end)

local ESP_Objects = {}

local function CreateESP(player)
    -- Verificação segura
    if not HasDrawing then
        return nil
    end
    
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
        
        -- Configurar Box
        newESP.Box.Color = Color3.fromRGB(255, 0, 0)
        newESP.Box.Thickness = 2
        newESP.Box.Filled = false
        newESP.Box.Visible = false
        
        -- Configurar Nome
        newESP.Name.Color = Color3.fromRGB(255, 255, 255)
        newESP.Name.Size = 14
        newESP.Name.Center = true
        newESP.Name.Outline = true
        newESP.Name.Visible = false
        
        -- Configurar Distância
        newESP.Distance.Color = Color3.fromRGB(200, 200, 200)
        newESP.Distance.Size = 13
        newESP.Distance.Center = true
        newESP.Distance.Outline = true
        newESP.Distance.Visible = false
        
        -- Configurar Health
        newESP.HealthBar.Color = Color3.fromRGB(50, 50, 50)
        newESP.HealthBar.Filled = true
        newESP.HealthBar.Visible = false
        
        newESP.HealthFill.Color = Color3.fromRGB(0, 255, 0)
        newESP.HealthFill.Filled = true
        newESP.HealthFill.Visible = false
        
        -- Configurar Linha
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
-- CORREÇÃO 4: Raycast corrigido
-- ============================================
local function IsVisible(character, part)
    -- CORREÇÃO 1: Se WallCheck = false, atira através de paredes
    if not Config.Aimbot.WallCheck then
        return true
    end
    
    -- Se WallCheck = true, verifica se tem parede
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = part.Position - rayOrigin  -- CORREÇÃO 4: Distância real
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local rayResult = Services.Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    
    return rayResult == nil
end

-- ============================================
-- CORREÇÃO 2: TriggerBot REAL
-- ============================================
local function IsMouseOnTarget(target)
    if not target then return false end
    
    local mousePos = Services.UserInputService:GetMouseLocation()
    
    -- Verificar se o mouse está sobre o alvo na tela
    local targetScreenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
    
    if not onScreen then return false end
    
    local targetScreenVector = Vector2.new(targetScreenPos.X, targetScreenPos.Y)
    local mouseVector = Vector2.new(mousePos.X, mousePos.Y)
    
    -- Distância do mouse até o alvo na tela
    local distanceToTarget = (targetScreenVector - mouseVector).Magnitude
    
    -- Só considera "no alvo" se estiver a menos de 50 pixels
    return distanceToTarget < 50
end

-- ============================================
-- CORREÇÃO 5: Verificação segura de funções
-- ============================================
local function SafeClick()
    local success = pcall(function()
        mouse1press()
        wait(0.01)
        mouse1release()
    end)
    
    if not success then
        -- Fallback: tenta usar VirtualInputManager
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
            wait(0.01)
            vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
        end)
    end
end

-- Sistema de Aimbot
local CurrentTarget = nil
local LastShot = 0

local function GetTargets()
    local targets = {}
    
    if not LocalPlayer.Character then return targets end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then
            continue
        end
        
        local character = player.Character
        if not character then continue end
        
        local aimPart = character:FindFirstChild(Config.Aimbot.AimPart)
        if not aimPart then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        -- Wall Check
        if not IsVisible(character, aimPart) then
            continue
        end
        
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

local function AimbotUpdate()
    if not Config.Aimbot.Enabled then
        CurrentTarget = nil
        return
    end
    
    local targets = GetTargets()
    
    if #targets > 0 then
        CurrentTarget = targets[1]
        
        -- Aplicar mira
        if Config.Aimbot.Smoothness >= 1 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position)
        else
            local targetCFrame = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.Aimbot.Smoothness)
        end
        
        local currentTime = tick()
        
        -- Auto Shoot
        if Config.Aimbot.AutoShoot then
            if currentTime - LastShot > 0.1 then
                SafeClick()
                LastShot = currentTime
            end
        end
        
        -- TriggerBot REAL (verifica mouse no alvo)
        if Config.Aimbot.TriggerBot and not Config.Aimbot.AutoShoot then
            if IsMouseOnTarget(CurrentTarget) then
                if currentTime - LastShot > 0.05 then
                    SafeClick()
                    LastShot = currentTime
                end
            end
        end
    else
        CurrentTarget = nil
    end
end

-- Sistema ESP
local function UpdateESP()
    if not Config.ESP.Enabled then
        for _, esp in pairs(ESP_Objects) do
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() 
                        if drawing.Visible then
                            drawing.Visible = false
                        end
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
        
        if distance > Config.ESP.MaxDistance then
            for key, drawing in pairs(esp) do
                if key ~= "Player" and type(drawing) == "userdata" then
                    pcall(function() drawing.Visible = false end)
                end
            end
            continue
        end
        
        local safeDistance = math.max(distance, 1)
        local scale = 1000 / safeDistance
        local boxWidth = math.clamp(scale * 3, 10, 200)
        local boxHeight = math.clamp(scale * 5, 15, 300)
        
        -- Box
        if Config.ESP.Box then
            pcall(function()
                esp.Box.Visible = true
                esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                esp.Box.Position = Vector2.new(headPos.X - boxWidth/2, headPos.Y - boxHeight/2)
            end)
        end
        
        -- Nome
        if Config.ESP.Name then
            pcall(function()
                esp.Name.Visible = true
                esp.Name.Text = player.Name
                esp.Name.Position = Vector2.new(headPos.X, headPos.Y - boxHeight/2 - 20)
            end)
        end
        
        -- Distância
        if Config.ESP.Distance then
            pcall(function()
                esp.Distance.Visible = true
                esp.Distance.Text = string.format("%.0fm", distance)
                esp.Distance.Position = Vector2.new(headPos.X, headPos.Y + boxHeight/2 + 5)
            end)
        end
        
        -- Barra de vida
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
        
        -- Linha
        if Config.ESP.Line then
            pcall(function()
                esp.Line.Visible = true
                esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                esp.Line.To = Vector2.new(headPos.X, headPos.Y + boxHeight/2)
            end)
        end
    end
end

-- Interface
local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuantumAimPRO"
    gui.Parent = Services.CoreGui
    gui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = gui
    mainFrame.Size = UDim2.new(0, 380, 0, 520)
    mainFrame.Position = UDim2.new(0.5, -190, 0.2, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Parent = mainFrame
    title.Size = UDim2.new(1, -20, 0, 35)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🎯 QUANTUM PRO v3.0.2"
    title.TextColor3 = Color3.fromRGB(255, 70, 70)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local function AddButton(text, yPos, callback)
        local btn = Instance.new("TextButton")
        btn.Parent = mainFrame
        btn.Size = UDim2.new(1, -20, 0, 35)
        btn.Position = UDim2.new(0, 10, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = "🔴 " .. text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        
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
    
    -- CORREÇÃO 1: Botão com texto correto
    AddButton("AIMBOT PRINCIPAL", 50, function(enabled)
        Config.Aimbot.Enabled = enabled
    end)
    
    AddButton("AUTO SHOOT", 95, function(enabled)
        Config.Aimbot.AutoShoot = enabled
    end)
    
    -- CORREÇÃO 2: TriggerBot com descrição correta
    AddButton("TRIGGER BOT (Mouse no alvo)", 140, function(enabled)
        Config.Aimbot.TriggerBot = enabled
    end)
    
    -- CORREÇÃO 1: Texto correto do WallCheck
    AddButton("RESPEITAR PAREDES (Wall Check)", 185, function(enabled)
        Config.Aimbot.WallCheck = enabled
        -- Quando ligado, NÃO atira através de paredes
    end)
    
    AddButton("ESP (VER INIMIGOS)", 230, function(enabled)
        Config.ESP.Enabled = enabled
    end)
    
    AddButton("ESP BOX", 275, function(enabled)
        Config.ESP.Box = enabled
    end)
    
    AddButton("ESP NOME", 320, function(enabled)
        Config.ESP.Name = enabled
    end)
    
    AddButton("ESP VIDA", 365, function(enabled)
        Config.ESP.HealthBar = enabled
    end)
    
    AddButton("ESP LINHA", 410, function(enabled)
        Config.ESP.Line = enabled
    end)
    
    -- Status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = mainFrame
    statusLabel.Size = UDim2.new(1, -20, 0, 40)
    statusLabel.Position = UDim2.new(0, 10, 0, 465)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "✅ v3.0.2 - Todos bugs corrigidos\nWallCheck: OFF = Atira através de paredes"
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
end

-- Inicializar
CreateUI()

-- Criar ESP para jogadores
for _, player in pairs(Services.Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Services.Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        wait(1)
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

-- Loop principal
Services.RunService.RenderStepped:Connect(function()
    pcall(UpdateESP)
    pcall(AimbotUpdate)
end)

print("=" .. string.rep("=", 50))
print("✅ QUANTUM PRO v3.0.2 - VERSÃO FINAL")
print("=" .. string.rep("=", 50))
print("🔧 TODAS as correções do ChatGPT aplicadas:")
print("   ✅ WallCheck: texto corrigido")
print("   ✅ TriggerBot: verifica mouse no alvo")
print("   ✅ Drawing: verificação segura")
print("   ✅ Raycast: distância real")
print("   ✅ mouse1: fallback seguro")
print("=" .. string.rep("=", 50))
