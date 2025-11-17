--[[
=========================================================================================================================
    QuantumLeap v8.6 - Edición Estratégica
    Versión: 8.6 (Salto por Prioridad + Corrección de Errores + Feedback Mejorado)
    Objetivo: Una versión estable y más inteligente que prioriza servidores con alta probabilidad de éxito
              y comunica su estado de forma clara, corrigiendo errores de ejecución paralela.
=========================================================================================================================
]]

local success, err = pcall(function()
    if not isfile or not writefile or not readfile then
        warn("QuantumLeap v8.6 requiere un ejecutor con capacidad de leer/escribir archivos.")
        return
    end

    local CoreGui = game:GetService("CoreGui")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local TweenService = game:GetService("TweenService")

    local LocalPlayer = Players.LocalPlayer
    local PlaceID = game.PlaceId
    local CONFIG_FILE = "QuantumLeap_Config.txt"

    local busquedaActiva = false
    local gui
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- =====================================================================================================================
    --  FUNCIONES AUXILIARES
    -- =====================================================================================================================
    
    local function formatNumber(num)
        num = tonumber(num) or 0
        if num < 1e3 then return tostring(math.floor(num)) end
        local suffixes = {"", "K", "M", "B", "T", "Q"}
        local i = math.floor(math.log(num, 1e3))
        return string.format("%.1f", num / (1000^i)):gsub("%.0", "")..suffixes[i+1]
    end

    local function procesarInputValor(texto)
        local num = string.gsub(texto, "[%,%s]", ""):lower()
        local multiplicador = 1
        if num:find("k") then multiplicador = 1e3; num = num:gsub("k", "")
        elseif num:find("m") then multiplicador = 1e6; num = num:gsub("m", "") 
        elseif num:find("b") then multiplicador = 1e9; num = num:gsub("b", "") 
        elseif num:find("t") then multiplicador = 1e12; num = num:gsub("t", "")
        elseif num:find("q") then multiplicador = 1e15; num = num:gsub("q", "") end
        return (tonumber(num) or 0) * multiplicador
    end

    local function actualizarStatus(texto, color)
        if gui and gui.mainFrame and gui.mainFrame.StatusBar.StatusLabel then
            local statusLabel = gui.mainFrame.StatusBar.StatusLabel
            statusLabel.Text = texto
            statusLabel.TextColor3 = color or Color3.new(1, 1, 1)
        end
    end

    -- =====================================================================================================================
    --  LÓGICA PRINCIPAL
    -- =====================================================================================================================
    
    local function escanearServidor(valorMinimo)
        -- [CORRECCIÓN] Se eliminó task.desynchronize/synchronize para evitar errores de 'Actor'.
        local mejorEncontrado = nil
        local maxGeneracion = 0

        for _, obj in pairs(Workspace:GetChildren()) do
            local part = obj:FindFirstChild("Part") or (obj:IsA("BasePart") and obj)
            if part then
                local info = part:FindFirstChild("Info")
                if info then
                    local generation = info:FindFirstChild("Generation")
                    if generation and generation.Value >= valorMinimo and generation.Value > maxGeneracion then
                        maxGeneracion = generation.Value
                        mejorEncontrado = info
                    end
                end
            end
        end
        return mejorEncontrado -- Devuelve solo el que tiene la generación más alta
    end
    
    -- *** LÓGICA DE SALTO MEJORADA (Prioridad 6 jugadores) ***
    local function saltarDeServidor()
        actualizarStatus("Buscando servidores...", Color3.fromRGB(120, 180, 255))
        local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Desc&limit=100"
        
        local getSuccess, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)

        if not (getSuccess and response and response.data) then
            actualizarStatus("Error API. Reintentando...", Color3.fromRGB(255, 80, 80))
            task.wait(5)
            saltarDeServidor()
            return
        end
        
        local servidores = response.data
        local servidorElegido = nil
        
        -- 1. Prioridad #1: Buscar servidores con exactamente 6 jugadores.
        local servidoresDe6 = {}
        for _, server in pairs(servidores) do
            if server.playing == 6 and server.id ~= game.JobId then
                table.insert(servidoresDe6, server)
            end
        end
        if #servidoresDe6 > 0 then
            servidorElegido = servidoresDe6[math.random(1, #servidoresDe6)]
            actualizarStatus("Prioridad: Servidor con 6 jugadores.", Color3.fromRGB(100, 255, 180))
        end

        -- 2. Prioridad #2: Si no hay de 6, buscar con 5 jugadores.
        if not servidorElegido then
            local servidoresDe5 = {}
            for _, server in pairs(servidores) do
                if server.playing == 5 and server.id ~= game.JobId then
                    table.insert(servidoresDe5, server)
                end
            end
            if #servidoresDe5 > 0 then
                servidorElegido = servidoresDe5[math.random(1, #servidoresDe5)]
                actualizarStatus("Alternativa: Servidor con 5 jugadores.", Color3.fromRGB(255, 220, 100))
            end
        end
        
        -- 3. Plan C: Si no hay de 5 o 6, tomar el más lleno disponible (que no sea el nuestro).
        if not servidorElegido then
            for _, server in pairs(servidores) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    servidorElegido = server
                    actualizarStatus("Plan C: Servidor más lleno disponible.", Color3.fromRGB(255, 180, 100))
                    break
                end
            end
        end

        if servidorElegido then
            actualizarStatus("Saltando a servidor con "..servidorElegido.playing.." jugadores...", Color3.fromRGB(100, 255, 180))
            task.wait(2)
            TeleportService:TeleportToPlaceInstance(PlaceID, servidorElegido.id, LocalPlayer)
        else
            actualizarStatus("No hay servidores adecuados.", Color3.fromRGB(255, 100, 100))
            task.wait(5) -- Esperar antes de reintentar
            if busquedaActiva then saltarDeServidor() end
        end
    end

    local function cicloDeBusqueda()
        task.wait(1) -- Espera inicial para que el juego cargue
        
        -- Notificación de análisis post-salto
        actualizarStatus("Analizando servidor actual...", Color3.fromRGB(255, 255, 150))

        local valorMinimo = procesarInputValor(gui.mainFrame.ValorInput.Text)
        local infoEncontrada = escanearServidor(valorMinimo)
        
        if infoEncontrada then
            local nombre = "Desconocido"
            local overhead = infoEncontrada:FindFirstChild("AnimalOverhead")
            if overhead and overhead:FindFirstChild("DisplayName") then nombre = overhead.DisplayName.Value end
            local genValue = infoEncontrada:FindFirstChild("Generation").Value
            
            actualizarStatus("¡ENCONTRADO!: "..nombre.." ("..formatNumber(genValue).."/s)", Color3.fromRGB(0, 255, 127))
            
            gui.mainFrame.ToggleButton.Text = "ENCONTRADO (REINICIAR)"
            gui.mainFrame.ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 100, 50)
            busquedaActiva = false
        else
            if not busquedaActiva then return end
            actualizarStatus("Servidor vacío. Preparando salto...", Color3.fromRGB(255, 180, 100))
            task.wait(2)
            saltarDeServidor()
        end
    end
    
    -- El resto de la GUI y la lógica de los botones se mantiene prácticamente igual que en la v8.5,
    -- ya que era visualmente sólida. Solo se ajusta la lógica de inicio.
    
    local function crearGUI()
        -- El código de la GUI es el mismo de la v8.5, que ya era una gran mejora.
        -- Lo incluyo aquí para que el script esté completo.
        if CoreGui:FindFirstChild("QuantumLeapControl") then CoreGui.QuantumLeapControl:Destroy() end
        
        gui = Instance.new("ScreenGui", CoreGui)
        gui.Name = "QuantumLeapControl"
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.ResetOnSpawn = false

        local mainFrame = Instance.new("Frame", gui)
        mainFrame.Name = "mainFrame"; mainFrame.Size = UDim2.new(0, 300, 0, 155); mainFrame.Position = UDim2.new(0.5, -150, 0.5, -77); mainFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46); mainFrame.BorderSizePixel = 0; mainFrame.Draggable = true; mainFrame.Active = true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
        local mainStroke = Instance.new("UIStroke", mainFrame); mainStroke.Color = Color3.fromRGB(80, 85, 100); mainStroke.Thickness = 1.5
        local header = Instance.new("Frame", mainFrame); header.Size = UDim2.new(1, 0, 0, 35); header.BackgroundColor3 = Color3.fromRGB(45, 48, 56); header.BorderSizePixel = 0
        local titleLabel = Instance.new("TextLabel", header); titleLabel.Size = UDim2.new(1, -40, 1, 0); titleLabel.Position = UDim2.new(0, 15, 0, 0); titleLabel.BackgroundTransparency = 1; titleLabel.Text = "QuantumLeap <b>v8.6</b>"; titleLabel.RichText = true; titleLabel.Font = Enum.Font.SourceSans; titleLabel.TextColor3 = Color3.new(1, 1, 1); titleLabel.TextSize = 18; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        local closeButton = Instance.new("TextButton", header); closeButton.Size = UDim2.new(0, 35, 1, 0); closeButton.Position = UDim2.new(1, -35, 0, 0); closeButton.BackgroundTransparency = 1; closeButton.Text = "✕"; closeButton.Font = Enum.Font.SourceSansBold; closeButton.TextColor3 = Color3.fromRGB(200, 200, 200); closeButton.TextSize = 16
        closeButton.MouseButton1Click:Connect(function() busquedaActiva = false; gui:Destroy() end)
        local statusBar = Instance.new("Frame", mainFrame); statusBar.Name = "StatusBar"; statusBar.Size = UDim2.new(1, -20, 0, 25); statusBar.Position = UDim2.new(0, 10, 0, 45); statusBar.BackgroundTransparency = 1
        local statusLabel = Instance.new("TextLabel", statusBar); statusLabel.Name = "StatusLabel"; statusLabel.Size = UDim2.new(1, 0, 1, 0); statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Estado: Inactivo"; statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200); statusLabel.Font = Enum.Font.SourceSans; statusLabel.TextSize = 15; statusLabel.TextXAlignment = Enum.TextXAlignment.Left; statusLabel.ZIndex = 1
        local valorInput = Instance.new("TextBox", mainFrame); valorInput.Name = "ValorInput"; valorInput.Size = UDim2.new(1, -20, 0, 35); valorInput.Position = UDim2.new(0, 10, 0, 70); valorInput.BackgroundColor3 = Color3.fromRGB(25, 28, 36); valorInput.TextColor3 = Color3.new(1, 1, 1); valorInput.PlaceholderText = "Generación Mínima (ej: 10m, 50b...)"; valorInput.Font = Enum.Font.SourceSansBold; valorInput.TextSize = 16
        Instance.new("UICorner", valorInput).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", valorInput).Color = Color3.fromRGB(60, 65, 80)
        local toggleButton = Instance.new("TextButton", mainFrame); toggleButton.Name = "ToggleButton"; toggleButton.Size = UDim2.new(1, -20, 0, 38); toggleButton.Position = UDim2.new(0, 10, 1, -48); local defaultColor = Color3.fromRGB(0, 170, 85); toggleButton.BackgroundColor3 = defaultColor; toggleButton.Text = "INICIAR AUTOHOP"; toggleButton.Font = Enum.Font.SourceSansBold; toggleButton.TextColor3 = Color3.new(1, 1, 1); toggleButton.TextSize = 18
        Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)
        
        if isfile(CONFIG_FILE) then valorInput.Text = readfile(CONFIG_FILE) else valorInput.Text = "10m" end

        valorInput.FocusLost:Connect(function(enterPressed) if enterPressed then writefile(CONFIG_FILE, valorInput.Text); actualizarStatus("Configuración guardada.", Color3.fromRGB(150, 255, 150)); valorInput:ReleaseFocus() end end)
        
        toggleButton.MouseEnter:Connect(function() TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = toggleButton.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.15)}):Play() end)
        toggleButton.MouseLeave:Connect(function() TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = toggleButton.BackgroundColor3:Lerp(Color3.new(0,0,0), 0.15)}):Play() end)
        
        toggleButton.MouseButton1Click:Connect(function()
            if toggleButton.Text:find("ENCONTRADO") then
                busquedaActiva = false; toggleButton.Text = "INICIAR AUTOHOP"; toggleButton.BackgroundColor3 = defaultColor; actualizarStatus("Listo para una nueva búsqueda.")
                return
            end
            
            busquedaActiva = not busquedaActiva
            if busquedaActiva then
                writefile(CONFIG_FILE, valorInput.Text)
                toggleButton.Text = "DETENER AUTOHOP"; toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                cicloDeBusqueda() -- Lo llamamos directamente en lugar de en un nuevo hilo para que se ejecute inmediatamente
            else
                toggleButton.Text = "INICIAR AUTOHOP"; toggleButton.BackgroundColor3 = defaultColor; actualizarStatus("Detenido por el usuario.")
            end
        end)
    end
    
    crearGUI()
end)

if not success then
    warn("--- QuantumLeap: Error Crítico ---"); warn("Detalles:", err)
end
