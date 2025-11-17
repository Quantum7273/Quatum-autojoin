--[[
=========================================================================================================================
    QuantumLeap v8.0 - Control Edition
    Versión: 8.0 (Control del usuario + Configuración guardada)
    Objetivo: El script definitivo que recuerda tus ajustes y te da control total sobre cuándo iniciar la búsqueda.
=========================================================================================================================
]]

local success, err = pcall(function()
    if not isfile or not writefile or not readfile then
        warn("QuantumLeap v8.0 requiere un ejecutor con capacidad de leer/escribir archivos (readfile/writefile).")
        return
    end

    -- =====================================================================================================================
    --  SERVICIOS Y VARIABLES GLOBALES
    -- =====================================================================================================================
    local CoreGui = game:GetService("CoreGui")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local PlaceID = game.PlaceId
    local CONFIG_FILE = "QuantumLeap_Config.txt"

    local busquedaActiva = false
    local gui

    -- =====================================================================================================================
    --  FUNCIONES PRINCIPALES
    -- =====================================================================================================================
    
    local function formatNumber(num)
        local s = string.format("%.0f", num); local rev = s:reverse()
        while true do local k; rev, k = rev:gsub("^(%d%d%d)(,)", "%1,%2"); if k == 0 then break end end
        return rev:reverse()
    end

    local function actualizarStatus(texto, color)
        if gui and gui:FindFirstChild("mainFrame") and gui.mainFrame:FindFirstChild("Status") then
            gui.mainFrame.Status.Text = texto
            gui.mainFrame.Status.TextColor3 = color or Color3.new(1, 1, 1)
        end
    end

    local function procesarInputValor(texto)
        local num = string.gsub(texto, "[,%s]", ""):lower()
        local multiplicador = 1
        if num:find("k") then multiplicador = 1e3; num = num:gsub("k", "")
        elseif num:find("m") then multiplicador = 1e6; num = num:gsub("m", "")
        elseif num:find("b") then multiplicador = 1e9; num = num:gsub("b", "") end
        return (tonumber(num) or 0) * multiplicador
    end

    local function escanearServidor(valorMinimo)
        for _, obj in pairs(Workspace:GetChildren()) do
            local part = obj:FindFirstChild("Part")
            if part then
                local info = part:FindFirstChild("Info")
                if info then
                    local generation = info:FindFirstChild("Generation")
                    if generation and generation.Value >= valorMinimo then
                        return info
                    end
                end
            end
        end
        return nil
    end
    
    local function saltarDeServidor()
        local servidores = {}
        local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
        local getSuccess, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)

        if getSuccess and response.data then
            for _, server in pairs(response.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(servidores, server.id)
                end
            end
        end
        
        if #servidores > 0 then
            TeleportService:TeleportToPlaceInstance(PlaceID, servidores[math.random(1, #servidores)], LocalPlayer)
        else
            actualizarStatus("No hay servidores disponibles.", Color3.fromRGB(255, 100, 100))
            busquedaActiva = false -- Detener si no hay a dónde ir
        end
    end

    local function iniciarBusqueda()
        task.wait(1) -- Pequeña espera al inicio
        local valorMinimo = procesarInputValor(gui.mainFrame.ValorInput.Text)
        actualizarStatus("Buscando > "..formatNumber(valorMinimo).."/s")
        
        local infoEncontrada = escanearServidor(valorMinimo)
        
        if infoEncontrada then
            local nombre = "Desconocido"
            local overhead = infoEncontrada:FindFirstChild("AnimalOverhead")
            if overhead and overhead:FindFirstChild("DisplayName") then nombre = overhead.DisplayName.Value end
            
            actualizarStatus("¡ENCONTRADO!: "..nombre, Color3.fromRGB(0, 255, 127))
            gui.mainFrame.ToggleButton.Text = "ENCONTRADO"
            gui.mainFrame.ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 100, 50)
            busquedaActiva = false
        else
            if not busquedaActiva then return end -- Verificar si el usuario canceló mientras se escaneaba
            actualizarStatus("Servidor vacío. Saltando...", Color3.fromRGB(255, 255, 150))
            task.wait(2)
            saltarDeServidor()
        end
    end

    -- =====================================================================================================================
    --  CREACIÓN DE LA INTERFAZ GRÁFICA (GUI)
    -- =====================================================================================================================
    local function crearGUI()
        if CoreGui:FindFirstChild("QuantumLeapControl") then CoreGui.QuantumLeapControl:Destroy() end
        
        gui = Instance.new("ScreenGui", CoreGui)
        gui.Name = "QuantumLeapControl"
        gui.ResetOnSpawn = false

        local mainFrame = Instance.new("Frame", gui)
        mainFrame.Name = "mainFrame"
        mainFrame.Size = UDim2.new(0, 280, 0, 140)
        mainFrame.Position = UDim2.new(1, -290, 0, 10)
        mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        mainFrame.Draggable = true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
        
        local titleLabel = Instance.new("TextLabel", mainFrame)
        titleLabel.Size = UDim2.new(1, 0, 0, 30)
        titleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        titleLabel.Text = "QuantumLeap v8.0 🔥"
        titleLabel.Font = Enum.Font.SourceSansBold
        titleLabel.TextColor3 = Color3.new(1, 1, 1)
        
        local statusLabel = Instance.new("TextLabel", mainFrame)
        statusLabel.Name = "Status"
        statusLabel.Size = UDim2.new(1, -20, 0, 20)
        statusLabel.Position = UDim2.new(0, 10, 0, 35)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "Estado: Inactivo"
        statusLabel.TextColor3 = Color3.new(1, 1, 1)
        statusLabel.Font = Enum.Font.SourceSans
        statusLabel.TextSize = 14
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local valorInput = Instance.new("TextBox", mainFrame)
        valorInput.Name = "ValorInput"
        valorInput.Size = UDim2.new(1, -20, 0, 35)
        valorInput.Position = UDim2.new(0, 10, 0, 55)
        valorInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        valorInput.TextColor3 = Color3.new(1, 1, 1)
        valorInput.PlaceholderText = "Generación Mínima/s"
        valorInput.Font = Enum.Font.SourceSansBold
        valorInput.TextSize = 16
        Instance.new("UICorner", valorInput).CornerRadius = UDim.new(0, 8)

        local toggleButton = Instance.new("TextButton", mainFrame)
        toggleButton.Name = "ToggleButton"
        toggleButton.Size = UDim2.new(1, -20, 0, 35)
        toggleButton.Position = UDim2.new(0, 10, 1, -45)
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 85)
        toggleButton.Text = "INICIAR AUTOHOP"
        toggleButton.Font = Enum.Font.SourceSansBold
        toggleButton.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)

        if isfile(CONFIG_FILE) then
            valorInput.Text = readfile(CONFIG_FILE)
        else
            valorInput.Text = "10m"
        end

        valorInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                writefile(CONFIG_FILE, valorInput.Text)
                actualizarStatus("Configuración guardada.", Color3.fromRGB(150, 255, 150))
            end
        end)

        toggleButton.MouseButton1Click:Connect(function()
            if toggleButton.Text == "ENCONTRADO" then return end
            
            busquedaActiva = not busquedaActiva
            if busquedaActiva then
                toggleButton.Text = "DETENER AUTOHOP"
                toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                task.spawn(iniciarBusqueda)
            else
                toggleButton.Text = "INICIAR AUTOHOP"
                toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 85)
                actualizarStatus("Detenido por el usuario.")
            end
        end)
    end

    crearGUI()
end)

if not success then
    warn("--- QuantumLeap: Error Crítico ---")
    warn("Detalles:", err)
end
