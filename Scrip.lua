--[[
=========================================================================================================================
    QuantumLeap v7.0 - Persistence Edition
    Versión: 7.0 (Configuración guardada y lógica de auto-búsqueda)
    Objetivo: Un script "configúralo y olvídalo" que recuerda tus ajustes y busca automáticamente.
=========================================================================================================================
]]

local success, err = pcall(function()
    -- Verificar si las funciones de lectura/escritura existen
    if not isfile or not writefile or not readfile then
        warn("QuantumLeap v7.0 requiere un ejecutor con capacidad de leer/escribir archivos (readfile/writefile).")
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
    local CONFIG_FILE = "QuantumLeap_Config.txt" -- Archivo para guardar la configuración

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
        end
    end

    local function autoScanAndHop()
        actualizarStatus("Esperando carga del servidor...")
        task.wait(5) -- Espera crucial para que todo en el nuevo servidor cargue

        local valorMinimo = procesarInputValor(gui.mainFrame.ValorInput.Text)
        actualizarStatus("Escaneando para > "..formatNumber(valorMinimo).."/s")
        
        local infoEncontrada = escanearServidor(valorMinimo)
        
        if infoEncontrada then
            local nombre = "Desconocido"
            local overhead = infoEncontrada:FindFirstChild("AnimalOverhead")
            if overhead and overhead:FindFirstChild("DisplayName") then nombre = overhead.DisplayName.Value end
            
            actualizarStatus("¡ENCONTRADO!: "..nombre..". Búsqueda finalizada.", Color3.fromRGB(0, 255, 127))
            gui.mainFrame.ValorInput.TextColor3 = Color3.fromRGB(0, 255, 127)
        else
            actualizarStatus("Servidor vacío. Saltando a uno nuevo...", Color3.fromRGB(255, 255, 150))
            task.wait(2) -- Pequeña pausa para leer el mensaje
            saltarDeServidor()
        end
    end

    -- =====================================================================================================================
    --  CREACIÓN DE LA INTERFAZ GRÁFICA (GUI)
    -- =====================================================================================================================
    local function crearGUI()
        if CoreGui:FindFirstChild("QuantumLeapPersistence") then CoreGui.QuantumLeapPersistence:Destroy() end
        
        gui = Instance.new("ScreenGui", CoreGui)
        gui.Name = "QuantumLeapPersistence"
        gui.ResetOnSpawn = false

        local mainFrame = Instance.new("Frame", gui)
        mainFrame.Name = "mainFrame"
        mainFrame.Size = UDim2.new(0, 280, 0, 110)
        mainFrame.Position = UDim2.new(1, -290, 0, 10)
        mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        mainFrame.Draggable = true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
        
        local titleLabel = Instance.new("TextLabel", mainFrame)
        titleLabel.Size = UDim2.new(1, 0, 0, 30)
        titleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        titleLabel.Text = "QuantumLeap v7.0 🔥"
        titleLabel.Font = Enum.Font.SourceSansBold
        titleLabel.TextColor3 = Color3.new(1, 1, 1)
        
        local statusLabel = Instance.new("TextLabel", mainFrame)
        statusLabel.Name = "Status"
        statusLabel.Size = UDim2.new(1, -20, 0, 20)
        statusLabel.Position = UDim2.new(0, 10, 0, 35)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "Estado: Iniciando..."
        statusLabel.TextColor3 = Color3.new(1, 1, 1)
        statusLabel.Font = Enum.Font.SourceSans
        statusLabel.TextSize = 14
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local valorInput = Instance.new("TextBox", mainFrame)
        valorInput.Name = "ValorInput"
        valorInput.Size = UDim2.new(1, -20, 0, 35)
        valorInput.Position = UDim2.new(0, 10, 1, -45)
        valorInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        valorInput.TextColor3 = Color3.new(1, 1, 1)
        valorInput.PlaceholderText = "Generación Mínima/s"
        valorInput.Font = Enum.Font.SourceSansBold
        valorInput.TextSize = 16
        Instance.new("UICorner", valorInput).CornerRadius = UDim.new(0, 8)

        -- Cargar la configuración guardada
        if isfile(CONFIG_FILE) then
            valorInput.Text = readfile(CONFIG_FILE)
        else
            valorInput.Text = "10m" -- Valor por defecto la primera vez
        end

        -- Guardar la configuración cuando el usuario la cambie
        valorInput.FocusLost:Connect(function()
            writefile(CONFIG_FILE, valorInput.Text)
            actualizarStatus("Configuración guardada.", Color3.fromRGB(150, 255, 150))
        end)
    end

    -- =====================================================================================================================
    --  PUNTO DE ENTRADA
    -- =====================================================================================================================
    crearGUI()
    autoScanAndHop()
end)

if not success then
    warn("--- QuantumLeap: Error Crítico ---")
    warn("Detalles:", err)
end
