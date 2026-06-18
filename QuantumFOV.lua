--[[
    QuantumAim PRO - Aimbot + ESP System
    Versão: 3.0.0
    Funcionalidades: Aimbot, ESP, Wall Hack
]]

-- Proteção
if game:GetService("CoreGui"):FindFirstChild("QuantumAimPRO") then
    game:GetService("CoreGui"):FindFirstChild("QuantumAimPRO"):Destroy()
end

-- Configurações COMPLETAS
local Config = {
    Aimbot = {
        Enabled = false,
        AimPart = "Head",
        FOV = 40,
        Smoothness = 0.5,
        Prediction = 0.135,
        TeamCheck = true,
        WallCheck = true,
        AutoShoot = false,
        TriggerBot = true
    },
    
    ESP = {
        Enabled = false,
        Box = true,          -- Caixa ao redor
        BoxColor = Color3.fromRGB(255, 0, 0),
        Name = true,         -- Nome do jogador
        NameColor = Color3.fromRGB(255, 255, 255),
        Distance = true,     -- Distância
        HealthBar = true,    -- Barra de vida
        HealthColor = Color3.fromRGB(0, 255, 0),
        Line = true,         -- Linha até o alvo
        LineColor = Color3.fromRGB(255, 255, 255),
        MaxDistance = 2000,  -- Distância máxima
        TextSize = 14,
        Font = Drawing.Fonts.Monospace
    }
}

-- Serviços
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    UserInputService = game:GetService("UserInputService")
}

-- Proteção Delta
if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

local LocalPlayer = Services.Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Sistema de Desenho (ESP)
local Drawing = {}

function Drawing.new(type)
    local drawing = Drawing.new(type)
    return drawing
end

local ESP_Objects = {}

-- Criar ESP para um jogador
local function CreateESP(player)
    local esp = {
        Player = player,
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthFill = Drawing.new("Square"),
        Line = Drawing.new("Line")
    }
    
    -- Configurar cores
    esp.Box.Color = Config.ESP.BoxColor
    esp.Box.Thickness = 2
    esp.Box.Filled = false
    esp.Box.Visible = false
    
    esp.Name.Color = Config.ESP.NameColor
    esp.Name.Size = Config.ESP.TextSize
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Visible = false
    
    esp.Distance.Color = Color3.fromRGB(200, 200, 200)
    esp.Distance.Size = Config.ESP.TextSize
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Visible = false
    
    esp.HealthBar.Color = Color3.fromRGB(50, 50, 50)
    esp.HealthBar.Filled = true
    esp.HealthBar.Visible = false
    
    esp.HealthFill.Color = Config.ESP.HealthColor
    esp.HealthFill.Filled = true
    esp.HealthFill.Visible = false
    
    esp.Line.Color = Config.ESP.LineColor
    esp.Line.Thickness = 1
    esp.Line.Visible = false
    
    table.insert(ESP_Objects, esp)
    return esp
end

-- Atualizar ESP
local function UpdateESP()
    if not Config.ESP.Enabled then
        for _, esp in pairs(ESP_Objects) do
            for _, drawing in pairs(esp) do
                if type(drawing) == "table" and drawing.Visible then
                    pcall(function() drawing.Visible = false end)
                end
            end
        end
        return
    end
    
    for _, esp in pairs(ESP_Objects) do
        local player = esp.Player
        if player == LocalPlayer then goto continue end
        
        local character = player.Character
        if not character then
            for _, drawing in pairs(esp) do
                if type(drawing) == "table" and drawing.Visible then
                    pcall(function() drawing.Visible = false end)
                end
            end
            goto continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not head or not rootPart then
            goto continue
        end
        
        if humanoid.Health <= 0 then
            goto continue
        end
        
        -- Team Check
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then
            goto continue
        end
        
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        
        if not onScreen then
            for _, drawing in pairs(esp) do
                if type(drawing) == "table" and drawing.Visible then
                    pcall(function() drawing.Visible = false end)
                end
            end
            goto continue
        end
        
        local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and 
            (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude) or 0
        
        if distance > Config.ESP.MaxDistance then
            goto continue
        end
        
        -- Calcular tamanho da box
        local scale = 1000 / distance
        local boxWidth = math.clamp(scale * 4, 2, 150)
        local boxHeight = math.clamp(scale * 6, 3, 200)
        
        -- Box
        if Config.ESP.Box then
            esp.Box.Visible = true
            esp.Box.Size = Vector2.new(boxWidth, boxHeight)
            esp.Box.Position = Vector2.new(headPos.X - boxWidth/2, headPos.Y - boxHeight/2)
        end
        
        -- Nome
        if Config.ESP.Name then
            esp.Name.Visible = true
            esp.Name.Text = player.Name
            esp.Name.Position = Vector2.new(headPos.X, headPos.Y - boxHeight/2 - 20)
        end
        
        -- Distância
        if Config.ESP.Distance then
            esp.Distance.Visible = true
            esp.Distance.Text = string.format("%.0fm", distance)
            esp.Distance.Position = Vector2.new(headPos.X, headPos.Y + boxHeight/2 + 5)
        end
        
        -- Barra de vida
        if Config.ESP.HealthBar then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            
            esp.HealthBar.Visible = true
            esp.HealthBar.Size = Vector2.new(4, boxHeight)
            esp.HealthBar.Position = Vector2.new(headPos.X - boxWidth/2 - 6, headPos.Y - boxHeight/2)
            
            esp.HealthFill.Visible = true
            esp.HealthFill.Size = Vector2.new(4, boxHeight * healthPercent)
            esp.HealthFill.Position = Vector2.new(headPos.X - boxWidth/2 - 6, headPos.Y - boxHeight/2 + boxHeight * (1 - healthPercent))
            
            -- Mudar cor baseado na vida
            if healthPercent > 0.5 then
                esp.HealthFill.Color = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.25 then
                esp.HealthFill.Color = Color3.fromRGB(255, 255, 0)
            else
                esp.HealthFill.Color = Color3.fromRGB(255, 0, 0)
            end
        end
        
        -- Linha
        if Config.ESP.Line then
            esp.Line.Visible = true
            esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            esp.Line.To = Vector2.new(headPos.X, headPos.Y + boxHeight/2)
        end
        
        ::continue::
    end
end

-- Sistema de Aimbot
local CurrentTarget = nil

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
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
        if not onScreen then continue end
        
        local distance2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if distance2D > Config.Aimbot.FOV then continue end
        
        local predictedPos = aimPart.Position
        if aimPart.Velocity then
            predictedPos = aimPart.Position + (aimPart.Velocity * Config.Aimbot.Prediction)
        end
        
        table.insert(targets, {
            Player = player,
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
        
        -- Auto Shoot
        if Config.Aimbot.AutoShoot or Config.Aimbot.TriggerBot then
            mouse1press()
            wait(0.05)
            mouse1release()
        end
    end
end

-- Criar interface
local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuantumAimPRO"
    gui.Parent = Services.CoreGui
    gui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = gui
    mainFrame.Size = UDim2.new(0, 380, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -190, 0.2, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Parent = mainFrame
    title.Size = UDim2.new(1, -20, 0, 35)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🎯 QUANTUM PRO AIM + ESP"
    title.TextColor3 = Color3.fromRGB(255, 70, 70)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Botões (você pode adicionar mais)
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
    
    AddButton("AIMBOT PRINCIPAL", 50, function(enabled)
        Config.Aimbot.Enabled = enabled
    end)
    
    AddButton("AUTO SHOOT", 95, function(enabled)
        Config.Aimbot.AutoShoot = enabled
    end)
    
    AddButton("TRIGGER BOT", 140, function(enabled)
        Config.Aimbot.TriggerBot = enabled
    end)
    
    AddButton("ATRAVÉS DE PAREDES", 185, function(enabled)
        Config.Aimbot.WallCheck = enabled
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
        CreateESP(player)
    end
end)

Services.Players.PlayerRemoving:Connect(function(player)
    for i, esp in pairs(ESP_Objects) do
        if esp.Player == player then
            for _, drawing in pairs(esp) do
                if type(drawing) == "table" then
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

print("✅ Quantum AIM + ESP carregado!")
print("🎯 AIMBOT - Mira automática nos inimigos")
print("👁️ ESP - Vê inimigos através de paredes")
print("⚠️ Use em conta alternativa!")
