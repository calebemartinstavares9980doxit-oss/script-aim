--[[
    QuantumFOV - Advanced FOV Targeting System
    Versão: 1.0.0
    Criado para: script-aim
    Repositório: github.com/calebemartinstavares9980doxit-oss/script-aim
]]

-- Proteção contra execução múltipla
if game:GetService("CoreGui"):FindFirstChild("QuantumFOV") then
    game:GetService("CoreGui"):FindFirstChild("QuantumFOV"):Destroy()
end

-- Configurações
local Config = {
    FOV = {
        Min = 10,
        Max = 180,
        Default = 40,
        Color = Color3.fromRGB(255, 65, 65),
        Transparency = 0.25,
        Thickness = 2
    },
    UI = {
        BackgroundColor = Color3.fromRGB(20, 20, 30),
        AccentColor = Color3.fromRGB(70, 130, 255),
        SecondaryColor = Color3.fromRGB(35, 35, 45),
        TextColor = Color3.fromRGB(240, 240, 240),
        SuccessColor = Color3.fromRGB(50, 200, 80),
        DangerColor = Color3.fromRGB(255, 70, 70),
        AnimationSpeed = 0.2
    },
    System = {
        AutoUpdate = true,
        SafeMode = true,
        FPS = 60
    }
}

-- Serviços
local Services = {
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    CoreGui = game:GetService("CoreGui"),
    HttpService = game:GetService("HttpService")
}

-- Proteção para Delta Executor
if syn and syn.protect_gui then
    Services.CoreGui = syn.protect_gui(Services.CoreGui)
end

-- Funções Utilitárias
local function CreateInstance(class, properties)
    local instance = Instance.new(class)
    for prop, value in pairs(properties or {}) do
        if prop ~= "Parent" then
            instance[prop] = value
        end
    end
    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

local function Lerp(a, b, t)
    return a + (b - a) * math.clamp(t, 0, 1)
end

local function ColorLerp(colorA, colorB, t)
    return Color3.new(
        Lerp(colorA.R, colorB.R, t),
        Lerp(colorA.G, colorB.G, t),
        Lerp(colorA.B, colorB.B, t)
    )
end

-- Sistema de Interface
local UI = {}
UI.__index = UI

function UI.new()
    local self = setmetatable({}, UI)
    self.enabled = false
    self.fovRadius = Config.FOV.Default
    self.connections = {}
    self.isDragging = false
    self:Build()
    self:ConnectEvents()
    return self
end

function UI:Build()
    -- ScreenGui principal
    self.ScreenGui = CreateInstance("ScreenGui", {
        Name = "QuantumFOV",
        Parent = Services.CoreGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    -- Frame principal
    self.MainFrame = CreateInstance("Frame", {
        Name = "MainFrame",
        Parent = self.ScreenGui,
        Size = UDim2.new(0, 340, 0, 220),
        Position = UDim2.new(0.5, -170, 0.3, 0),
        BackgroundColor3 = Config.UI.BackgroundColor,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true
    })

    -- Cantos arredondados
    CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = self.MainFrame
    })

    -- Borda decorativa
    CreateInstance("UIStroke", {
        Parent = self.MainFrame,
        Color = Config.UI.AccentColor,
        Thickness = 1,
        Transparency = 0.7,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })

    -- Gradiente de fundo
    local gradient = CreateInstance("UIGradient", {
        Parent = self.MainFrame,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 35)),
            ColorSequenceKeypoint.new(1, Config.UI.BackgroundColor)
        }),
        Rotation = 135
    })

    -- Barra de título
    local TitleBar = CreateInstance("Frame", {
        Name = "TitleBar",
        Parent = self.MainFrame,
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundColor3 = Config.UI.SecondaryColor,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0
    })

    -- Título
    CreateInstance("TextLabel", {
        Name = "Title",
        Parent = TitleBar,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = "QUANTUM FOV SYSTEM",
        TextColor3 = Config.UI.AccentColor,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    -- Versão
    CreateInstance("TextLabel", {
        Name = "Version",
        Parent = TitleBar,
        Size = UDim2.new(0, 60, 1, 0),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Text = "v1.0.0",
        TextColor3 = Config.UI.AccentColor,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right
    })

    -- Container de conteúdo
    local ContentFrame = CreateInstance("Frame", {
        Name = "Content",
        Parent = self.MainFrame,
        Size = UDim2.new(1, -20, 1, -100),
        Position = UDim2.new(0, 10, 0, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    })

    -- Botão Toggle
    self.ToggleButton = CreateInstance("TextButton", {
        Name = "ToggleButton",
        Parent = ContentFrame,
        Size = UDim2.new(0, 200, 0, 40),
        Position = UDim2.new(0.5, -100, 0, 5),
        BackgroundColor3 = Config.UI.SecondaryColor,
        TextColor3 = Config.UI.TextColor,
        Text = "SISTEMA: DESATIVADO",
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        BorderSizePixel = 0
    })

    CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = self.ToggleButton
    })

    -- Indicador de status
    self.StatusDot = CreateInstance("Frame", {
        Name = "StatusDot",
        Parent = self.ToggleButton,
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 12, 0.5, -6),
        BackgroundColor3 = Config.UI.DangerColor,
        BorderSizePixel = 0
    })

    CreateInstance("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.StatusDot
    })

    -- Brilho do indicador
    CreateInstance("ImageLabel", {
        Parent = self.StatusDot,
        Size = UDim2.new(2, 0, 2, 0),
        Position = UDim2.new(0.5, -6, 0.5, -6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6819594411",
        ImageColor3 = Config.UI.DangerColor,
        ImageTransparency = 0.7
    })

    -- Seção FOV
    local FOVSection = CreateInstance("Frame", {
        Name = "FOVSection",
        Parent = ContentFrame,
        Size = UDim2.new(1, 0, 0, 70),
        Position = UDim2.new(0, 0, 0, 55),
        BackgroundColor3 = Config.UI.SecondaryColor,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0
    })

    CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = FOVSection
    })

    -- Label FOV
    CreateInstance("TextLabel", {
        Name = "FOVLabel",
        Parent = FOVSection,
        Size = UDim2.new(0, 100, 0, 25),
        Position = UDim2.new(0, 10, 0, 5),
        BackgroundTransparency = 1,
        Text = "RAIO DO FOV",
        TextColor3 = Config.UI.AccentColor,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    -- Valor do FOV
    self.FOVValueLabel = CreateInstance("TextLabel", {
        Name = "FOVValue",
        Parent = FOVSection,
        Size = UDim2.new(0, 60, 0, 25),
        Position = UDim2.new(1, -70, 0, 5),
        BackgroundTransparency = 1,
        Text = "40°",
        TextColor3 = Config.UI.TextColor,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right
    })

    -- Barra do Slider
    self.SliderBar = CreateInstance("Frame", {
        Name = "SliderBar",
        Parent = FOVSection,
        Size = UDim2.new(1, -20, 0, 4),
        Position = UDim2.new(0, 10, 1, -20),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
        BorderSizePixel = 0
    })

    CreateInstance("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.SliderBar
    })

    -- Preenchimento do Slider
    self.SliderFill = CreateInstance("Frame", {
        Name = "SliderFill",
        Parent = self.SliderBar,
        Size = UDim2.new(0.22, 0, 1, 0),
        BackgroundColor3 = Config.UI.AccentColor,
        BorderSizePixel = 0
    })

    CreateInstance("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.SliderFill
    })

    -- Botão do Slider
    self.SliderKnob = CreateInstance("TextButton", {
        Name = "SliderKnob",
        Parent = self.SliderBar,
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0.22, -9, 0.5, -9),
        BackgroundColor3 = Config.UI.AccentColor,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 2
    })

    CreateInstance("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = self.SliderKnob
    })

    -- Sombra do Knob
    CreateInstance("UIStroke", {
        Parent = self.SliderKnob,
        Color = Color3.fromRGB(0, 0, 0),
        Thickness = 2,
        Transparency = 0.5
    })

    -- Label de status do alvo
    self.TargetLabel = CreateInstance("TextLabel", {
        Name = "TargetLabel",
        Parent = ContentFrame,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Alvo: Nenhum",
        TextColor3 = Color3.fromRGB(150, 150, 160),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center
    })

    -- Animação de entrada
    self.MainFrame.Size = UDim2.new(0, 0, 0, 220)
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = Services.TweenService:Create(self.MainFrame, tweenInfo, {
        Size = UDim2.new(0, 340, 0, 220)
    })
    tween:Play()
end

function UI:ConnectEvents()
    -- Toggle do sistema
    table.insert(self.connections, self.ToggleButton.MouseButton1Click:Connect(function()
        self.enabled = not self.enabled
        self:UpdateToggle()
    end))

    -- Drag do Slider
    table.insert(self.connections, self.SliderKnob.MouseButton1Down:Connect(function()
        self.isDragging = true
    end))

    table.insert(self.connections, Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = false
        end
    end))

    -- Efeitos hover
    table.insert(self.connections, self.ToggleButton.MouseEnter:Connect(function()
        if not self.enabled then
            local tweenInfo = TweenInfo.new(0.15)
            local tween = Services.TweenService:Create(self.ToggleButton, tweenInfo, {
                BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            })
            tween:Play()
        end
    end))

    table.insert(self.connections, self.ToggleButton.MouseLeave:Connect(function()
        if not self.enabled then
            local tweenInfo = TweenInfo.new(0.15)
            local tween = Services.TweenService:Create(self.ToggleButton, tweenInfo, {
                BackgroundColor3 = Config.UI.SecondaryColor
            })
            tween:Play()
        end
    end))
end

function UI:UpdateToggle()
    self.ToggleButton.Text = self.enabled and "SISTEMA: ATIVADO" or "SISTEMA: DESATIVADO"
    
    local buttonColor = self.enabled and Config.UI.AccentColor or Config.UI.SecondaryColor
    local dotColor = self.enabled and Config.UI.SuccessColor or Config.UI.DangerColor
    
    local tweenInfo = TweenInfo.new(Config.UI.AnimationSpeed)
    
    local buttonTween = Services.TweenService:Create(self.ToggleButton, tweenInfo, {
        BackgroundColor3 = buttonColor
    })
    buttonTween:Play()
    
    local dotTween = Services.TweenService:Create(self.StatusDot, tweenInfo, {
        BackgroundColor3 = dotColor
    })
    dotTween:Play()
end

function UI:UpdateSlider()
    if not self.isDragging then return end
    
    local mousePos = Services.UserInputService:GetMouseLocation()
    local barPos = self.SliderBar.AbsolutePosition
    local barSize = self.SliderBar.AbsoluteSize
    
    local percent = math.clamp((mousePos.X - barPos.X) / barSize.X, 0, 1)
    self.fovRadius = math.floor(Config.FOV.Min + (Config.FOV.Max - Config.FOV.Min) * percent)
    
    self.FOVValueLabel.Text = self.fovRadius .. "°"
    self.SliderKnob.Position = UDim2.new(percent, -9, 0.5, -9)
    self.SliderFill.Size = UDim2.new(percent, 0, 1, 0)
end

function UI:UpdateTarget(targetName)
    self.TargetLabel.Text = targetName or "Alvo: Nenhum"
    self.TargetLabel.TextColor3 = targetName and Config.UI.SuccessColor or Color3.fromRGB(150, 150, 160)
end

function UI:Destroy()
    for _, conn in pairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

-- Sistema de Renderização FOV
local Renderer = {}
Renderer.__index = Renderer

function Renderer.new()
    local self = setmetatable({}, Renderer)
    self.container = nil
    self:Create(Config.FOV.Default)
    return self
end

function Renderer:Create(radius)
    self:Destroy()
    
    self.container = CreateInstance("Frame", {
        Name = "FOVCircle",
        Parent = Services.CoreGui,
        Size = UDim2.new(0, radius * 2, 0, radius * 2),
        Position = UDim2.new(0.5, -radius, 0.5, -radius),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1
    })

    -- Círculo principal
    CreateInstance("ImageLabel", {
        Parent = self.container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3926305904",
        ImageColor3 = Config.FOV.Color,
        ImageTransparency = Config.FOV.Transparency,
        ZIndex = 1
    })

    -- Preenchimento interno
    CreateInstance("ImageLabel", {
        Parent = self.container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3926307971",
        ImageColor3 = Config.FOV.Color,
        ImageTransparency = 0.85,
        ZIndex = 1
    })

    -- Linha central horizontal
    CreateInstance("Frame", {
        Parent = self.container,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0.5, -0.5),
        BackgroundColor3 = Config.FOV.Color,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0
    })

    -- Linha central vertical
    CreateInstance("Frame", {
        Parent = self.container,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(0.5, -0.5, 0, 0),
        BackgroundColor3 = Config.FOV.Color,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0
    })
end

function Renderer:Update(radius)
    if not self.container then
        self:Create(radius)
        return
    end
    
    self.container.Size = UDim2.new(0, radius * 2, 0, radius * 2)
    self.container.Position = UDim2.new(0.5, -radius, 0.5, -radius)
end

function Renderer:Destroy()
    if self.container then
        self.container:Destroy()
        self.container = nil
    end
end

-- Sistema de Mira
local Targeting = {}
Targeting.__index = Targeting

function Targeting.new()
    local self = setmetatable({}, Targeting)
    self.currentTarget = nil
    self.lastUpdate = 0
    return self
end

function Targeting:Update(fovRadius, enabled)
    if not enabled then
        self.currentTarget = nil
        return nil
    end
    
    local currentTime = tick()
    if currentTime - self.lastUpdate < (1 / Config.System.FPS) then
        return self.currentTarget
    end
    
    self.lastUpdate = currentTime
    
    local localPlayer = Services.Players.LocalPlayer
    if not localPlayer or not localPlayer.Character then
        return nil
    end
    
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closestPlayer = nil
    local closestDistance = fovRadius
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player == localPlayer then continue end
        
        local character = player.Character
        if not character then continue end
        
        local head = character:FindFirstChild("Head")
        if not head then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local screenPos, onScreen = camera:WorldToScreenPoint(head.Position)
        if not onScreen then continue end
        
        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        
        if distance < closestDistance then
            closestPlayer = player
            closestDistance = distance
        end
    end
    
    self.currentTarget = closestPlayer
    return self.currentTarget
end

-- Sistema Principal
local QuantumFOV = {}

function QuantumFOV:Start()
    local system = {}
    
    -- Inicializar módulos
    system.UI = UI.new()
    system.Renderer = Renderer.new()
    system.Targeting = Targeting.new()
    
    -- Loop principal
    system.UpdateConnection = Services.RunService.RenderStepped:Connect(function()
        -- Atualizar slider
        system.UI:UpdateSlider()
        
        -- Atualizar FOV circle
        system.Renderer:Update(system.UI.fovRadius)
        
        -- Atualizar targeting
        local target = system.Targeting:Update(system.UI.fovRadius, system.UI.enabled)
        local targetName = target and target.Name or nil
        system.UI:UpdateTarget(targetName)
    end)
    
    -- Função de limpeza
    function system:Destroy()
        if self.UpdateConnection then
            self.UpdateConnection:Disconnect()
        end
        if self.UI then
            self.UI:Destroy()
        end
        if self.Renderer then
            self.Renderer:Destroy()
        end
    end
    
    print("[QuantumFOV] Sistema carregado com sucesso!")
    print("[QuantumFOV] Pressione o botão para ativar")
    print("[QuantumFOV] Ajuste o FOV com o slider")
    
    return system
end

-- Inicialização segura
local System = nil
local success, error = pcall(function()
    System = QuantumFOV:Start()
end)

if not success then
    warn("[QuantumFOV] Erro ao iniciar:", error)
end

return System
