--[[
=========================================================================================================================
    QuantumLeap v6.1 - Pathfinder Edition
    Versión: 6.1 (Lógica de Pausa Inteligente y Creación de Lista)
    Objetivo: El script de server hop más eficiente para un solo dispositivo.
=========================================================================================================================
]]

local success, err = pcall(function()

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

    local busquedaActiva = false
    local busquedaPausada = false
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

    local function addServerToList(info, jobId)
        local scrollingFrame = gui.mainFrame.ResultsFrame.ScrollingFrame
        if scrollingFrame:FindFirstChild(jobId) then return end -- Prevenir duplicados

        local template = scrollingFrame.Template
        local newEntry = template:Clone()
        newEntry.Name = jobId
        local nombre = "Desconocido"
        local overhead = info:FindFirstChild("AnimalOverhead")
        if overhead and overhead:FindFirstChild("DisplayName") then nombre = overhead.DisplayName.Value end
        
        local generation = info.Generation.Value
        newEntry.InfoLabel.Text = string.format("%s (%s/s)", nombre, formatNumber(generation))
        newEntry.Visible = true
        newEntry.Parent = scrollingFrame

        newEntry.JoinButton.MouseButton1Click:Connect(function()
            busquedaActiva = false
            busquedaPausada = false
            actualizarStatus("Uniéndose al servidor guardado...", Color3.fromRGB(100, 180, 255))
            TeleportService:TeleportToPlaceInstance(PlaceID, jobId)
        end)
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
        actualizarStatus("Buscando nuevo servidor...")
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
            actualizarStatus("Saltando a otro servidor...")
            TeleportService:TeleportToPlaceInstance(PlaceID, servidores[math.random(1, #servidores)], LocalPlayer)
        else
            actualizarStatus("No hay servidores disponibles.", Color3.fromRGB(255, 100, 100))
            busquedaActiva = false
        end
    end

    local function iniciarBusqueda()
        local valorMinimo = procesarInputValor(gui.mainFrame.ValorInput.Text)
        actualizarStatus("Buscando > "..formatNumber(valorMinimo).."/s")

        while busquedaActiva do
            if busquedaPausada then
                task.wait(1)
                continue
            end

            local infoEncontrada = escanearServidor(valorMinimo)
            if infoEncontrada then
                busquedaPausada = true
                local nombre = "Desconocido"
                local overhead = infoEncontrada:FindFirstChild("AnimalOverhead")
                if overhead and overhead:FindFirstChild("DisplayName") then nombre = overhead.DisplayName.Value end
                
                actualizarStatus("¡ENCONTRADO!: "..nombre..". ¿Qué hacemos?", Color3.fromRGB(0, 255, 127))
                gui.mainFrame.ChoiceFrame.Visible = true
                gui.mainFrame.ToggleButton.Visible = false

                -- Esperar a que el usuario tome una decisión
                local decisionTomada = false
                local stayConnection, continueConnection
                
                stayConnection = gui.mainFrame.ChoiceFrame.StayButton.MouseButton1Click:Connect(function()
                    decisionTomada = true
                    busquedaActiva = false
                    busquedaPausada = false
                end)
                
                continueConnection = gui.mainFrame.ChoiceFrame.ContinueButton.MouseButton1Click:Connect(function()
                    decisionTomada = true
                    addServerToList(infoEncontrada, game.JobId)
                    busquedaPausada = false
                    saltarDeServidor()
                end)

                repeat task.wait() until decisionTomada
                
                stayConnection:Disconnect()
                continueConnection:Disconnect()
                gui.mainFrame.ChoiceFrame.Visible = false
                gui.mainFrame.ToggleButton.Visible = true

            else
                if not busquedaActiva then break end
                saltarDeServidor()
                busquedaActiva = false -- Se detiene después de un salto para que el script se reinicie
            end
        end
        
        if gui and gui.Parent and not busquedaActiva then
            gui.mainFrame.ToggleButton.Text = "BUSCAR"
            gui.mainFrame.ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 85)
            actualizarStatus("Detenido")
        end
    end

    -- =====================================================================================================================
    --  CREACIÓN DE LA INTERFAZ GRÁFICA (GUI)
    -- =====================================================================================================================
    local function crearGUI()
        if gui and gui.Parent then gui:Destroy() end
        
        gui = Instance.new("ScreenGui", CoreGui)
        gui.Name = "QuantumLeapPathfinder"
        gui.ResetOnSpawn = false

        local mainFrame = Instance.new("Frame", gui)
        mainFrame.Name = "mainFrame"
        mainFrame.Size = UDim2.new(0, 350, 0, 400)
        mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
        mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        mainFrame.Draggable = true
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
        
        -- (El resto de la GUI es similar, con la adición del 'ChoiceFrame')
        local titleBar = Instance.new("Frame", mainFrame)
        titleBar.Size = UDim2.new(1, 0, 0, 40)
        titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        local titleLabel = Instance.new("TextLabel", titleBar)
        titleLabel.Size = UDim2.new(1, 0, 1, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "QuantumLeap v6.1 🔥"
        titleLabel.TextColor3 = Color3.new(1, 1, 1)
        titleLabel.Font = Enum.Font.SourceSansBold
        titleLabel.TextSize = 18

        local statusLabel = Instance.new("TextLabel", mainFrame)
        statusLabel.Name = "Status"
        statusLabel.Size = UDim2.new(1, -20, 0, 20)
        statusLabel.Position = UDim2.new(0, 10, 0, 45)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "Estado: Inactivo"
        statusLabel.TextColor3 = Color3.new(1, 1, 1)
        statusLabel.Font = Enum.Font.SourceSans
        statusLabel.TextSize = 14
        
        local valorInput = Instance.new("TextBox", mainFrame)
        valorInput.Name = "ValorInput"
        valorInput.Size = UDim2.new(1, -20, 0, 30)
        valorInput.Position = UDim2.new(0, 10, 0, 70)
        valorInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        valorInput.TextColor3 = Color3.new(1, 1, 1)
        valorInput.Text = "10m"
        valorInput.PlaceholderText = "Generación Mínima/s"
        Instance.new("UICorner", valorInput).CornerRadius = UDim.new(0, 6)
        
        local resultsFrame = Instance.new("Frame", mainFrame)
        resultsFrame.Name = "ResultsFrame"
        resultsFrame.Size = UDim2.new(1, -20, 1, -160)
        resultsFrame.Position = UDim2.new(0, 10, 0, 105)
        resultsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        Instance.new("UICorner", resultsFrame).CornerRadius = UDim.new(0, 8)
        
        local scrollingFrame = Instance.new("ScrollingFrame", resultsFrame)
        scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
        scrollingFrame.BackgroundTransparency = 1
        scrollingFrame.BorderSizePixel = 0
        Instance.new("UIListLayout", scrollingFrame).Padding = UDim.new(0, 5)

        local template = Instance.new("Frame", scrollingFrame)
        template.Name = "Template"
        template.Size = UDim2.new(1, 0, 0, 35)
        template.BackgroundTransparency = 1
        template.Visible = false
        local infoLabel = Instance.new("TextLabel", template)
        infoLabel.Name = "InfoLabel"
        infoLabel.Size = UDim2.new(1, -85, 1, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.new(1,1,1)
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        local joinButton = Instance.new("TextButton", template)
        joinButton.Name = "JoinButton"
        joinButton.Size = UDim2.new(0, 80, 1, -5)
        joinButton.Position = UDim2.new(1, -80, 0, 0)
        joinButton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
        joinButton.Text = "Unirse"
        joinButton.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", joinButton).CornerRadius = UDim.new(0, 6)

        local toggleButton = Instance.new("TextButton", mainFrame)
        toggleButton.Name = "ToggleButton"
        toggleButton.Size = UDim2.new(1, -20, 0, 40)
        toggleButton.Position = UDim2.new(0, 10, 1, -50)
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 85)
        toggleButton.Text = "BUSCAR"
        toggleButton.Font = Enum.Font.SourceSansBold
        Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)
        
        local choiceFrame = Instance.new("Frame", mainFrame)
        choiceFrame.Name = "ChoiceFrame"
        choiceFrame.Size = UDim2.new(1, -20, 0, 40)
        choiceFrame.Position = UDim2.new(0, 10, 1, -50)
        choiceFrame.BackgroundTransparency = 1
        choiceFrame.Visible = false
        local stayButton = Instance.new("TextButton", choiceFrame)
        stayButton.Name = "StayButton"
        stayButton.Size = UDim2.new(0.48, 0, 1, 0)
        stayButton.BackgroundColor3 = Color3.fromRGB(0, 170, 85)
        stayButton.Text = "QUEDARME AQUÍ"
        stayButton.Font = Enum.Font.SourceSansBold
        stayButton.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", stayButton).CornerRadius = UDim.new(0, 8)
        local continueButton = Instance.new("TextButton", choiceFrame)
        continueButton.Name = "ContinueButton"
        continueButton.Size = UDim2.new(0.48, 0, 1, 0)
        continueButton.Position = UDim2.new(0.52, 0, 0, 0)
        continueButton.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        continueButton.Text = "GUARDAR Y SEGUIR"
        continueButton.Font = Enum.Font.SourceSansBold
        continueButton.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", continueButton).CornerRadius = UDim.new(0, 8)

        toggleButton.MouseButton1Click:Connect(function()
            if not busquedaActiva then
                busquedaActiva = true
                toggleButton.Text = "DETENER"
                toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                task.spawn(iniciarBusqueda)
            else
                busquedaActiva = false
            end
        end)
    end

    crearGUI()
end)

if not success then
    warn("--- QuantumLeap: Error Crítico al Iniciar ---")
    warn("El script no pudo ejecutarse. Esto puede deberse a un problema del ejecutor o a una actualización del juego.")
    warn("Detalles del error:", err)
    warn("-------------------------------------------------")
end
