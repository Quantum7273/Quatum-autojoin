--[[
=========================================================================================================================
    QuantumLeap v8.5 - Edición Élite
    Versión: 8.5 (Interfaz Mejorada + Lógica de Salto Inteligente)
    Objetivo: Una experiencia de usuario superior con animaciones, una interfaz pulida y un algoritmo de salto
              que prioriza servidores con alta probabilidad de contener lo que buscas.
=========================================================================================================================
]]

local success, err = pcall(function()
    -- =====================================================================================================================
    --  VERIFICACIÓN DE CAPACIDADES
    -- =====================================================================================================================
    if not isfile or not writefile or not readfile then
        warn("QuantumLeap v8.5 requiere un ejecutor con capacidad de leer/escribir archivos (readfile/writefile).")
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
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")

    local LocalPlayer = Players.LocalPlayer
    local PlaceID = game.PlaceId
    local CONFIG_FILE = "QuantumLeap_Config.txt"

    local busquedaActiva = false
    local gui -- Variable para la interfaz
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- =====================================================================================================================
    --  FUNCIONES AUXILIARES
    -- =====================================================================================================================
    
    local function formatNumber(num)
        num = tonumber(num) or 0
        if num < 1e3 then return tostring(math.floor(num)) end
        local suffixes = {"", "K", "M", "B", "T"} -- Añade más si es necesario
        local i = math.floor(math.log(num, 1e3))
        return string.format("%.1f", num / (1000^i)):gsub("%.0", "")..suffixes[i+1]
    end

    local function procesarInputValor(texto)
        local num = string.gsub(texto, "[%,%s]", ""):lower()
        local multiplicador = 1
        if num:find("k") then multiplicador = 1e3; num = num:gsub("k", "")
        elseif num:find("m") then multiplicador = 1e6; num = num:gsub("m", "")
        elseif num:find("b") then multiplicador = 1e9; num = num:gsub("b", "") 
        elseif num:find("t") then multiplicador = 1e12; num = num:gsub("t", "") end
        return (tonumber(num) or 0) * multiplicador
    end

    local function actualizarStatus(texto, color)
        if gui and gui.mainFrame and gui.mainFrame.StatusBar.StatusLabel then
            local statusLabel = gui.mainFrame.StatusBar.StatusLabel
            local flash = gui.mainFrame.StatusBar.StatusFlash
            
            statusLabel.Text = texto
            statusLabel.TextColor3 = color or Color3.new(1, 1, 1)
            
            -- Pequeño efecto de flash para dar feedback
            flash.Visible = true
            flash.BackgroundColor3 = color or Color3.new(1,1,1)
            TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {BackgroundTransparency = 1}):Play()
            task.delay(0.5, function()
                flash.Visible = false
                flash.BackgroundTransparency = 0
            end)
        end
    end

    -- =====================================================================================================================
    --  LÓGICA PRINCIPAL (BÚSQUEDA Y SALTO)
    -- =====================================================================================================================
    
    local function escanearServidor(valorMinimo)
        -- Usar task.desynchronize() para que el escaneo no cause lag si el workspace es muy grande
        task.desynchronize() 
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj.Name == "CONTENEDOR_DE_INFO" or obj:FindFirstChild("Part") then -- Se puede optimizar si los objetos tienen un nombre común
                local part = obj:FindFirstChild("Part") or obj
                local info = part:FindFirstChild("Info")
                if info then
                    local generation = info:FindFirstChild("Generation")
                    if generation and generation.Value >= valorMinimo then
                        task.synchronize() -- Volver al hilo principal antes de retornar
                        return info
                    end
                end
            end
        end
        task.synchronize() -- Asegurarse de volver al hilo principal
        return nil
    end
    
    -- *** LÓGICA DE SALTO MEJORADA ***
    local function saltarDeServidor()
        actualizarStatus("Buscando servidores...", Color3.fromRGB(120, 180, 255))
        local servidores = {}
        local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Desc&limit=100"
        
        local getSuccess, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)

        if getSuccess and response and response.data then
            for _, server in pairs(response.data) do
                -- Filtramos servidores que no estén llenos y que no sean el nuestro
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(servidores, server)
                end
            end
        else
            actualizarStatus("Error API. Reintentando...", Color3.fromRGB(255, 80, 80))
            task.wait(5)
            saltarDeServidor()
            return
        end
        
        if #servidores > 0 then
            -- *** PRIORIDAD A SERVIDORES LLENOS ***
            -- La API ya nos da los servidores ordenados por jugadores (sortOrder=Desc), así que los primeros son los más llenos.
            -- Seleccionamos uno de los 10 más llenos para tener variedad y no intentar entrar siempre al mismo.
            local indiceMaximo = math.min(10, #servidores)
            local servidorElegido = servidores[math.random(1, indiceMaximo)]
            
            actualizarStatus("Saltando a un servidor con "..servidorElegido.playing.." jugadores.", Color3.fromRGB(100, 255, 180))
            task.wait(1.5)
            TeleportService:TeleportToPlaceInstance(PlaceID, servidorElegido.id, LocalPlayer)
        else
            actualizarStatus("No hay servidores disponibles.", Color3.fromRGB(255, 100, 100))
            busquedaActiva = false -- Detener si no hay a dónde ir
        end
    end

    local function cicloDeBusqueda()
        while busquedaActiva do
            local valorMinimo = procesarInputValor(gui.mainFrame.ValorInput.Text)
            actualizarStatus("Buscando > "..formatNumber(valorMinimo).."/s", Color3.fromRGB(255, 255, 150))
            
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
                break -- Salir del bucle
            else
                if not busquedaActiva then break end -- Verificar si el usuario canceló
                actualizarStatus("Servidor vacío. Saltando...", Color3.fromRGB(255, 180, 100))
                task.wait(2)
                saltarDeServidor()
                -- El script terminará aquí porque el teletransporte corta su ejecución.
                -- El bucle es útil en caso de que el teletransporte falle y se quiera reintentar.
            end
            task.wait(1) -- Pequeña pausa entre ciclos si no se salta
        end
    end

    -- =====================================================================================================================
    --  INTERFAZ GRÁFICA (GUI) MEJORADA
    -- =====================================================================================================================
    local function crearGUI()
        if CoreGui:FindFirstChild("QuantumLeapControl") then CoreGui.QuantumLeapControl:Destroy() end
        
        gui = Instance.new("ScreenGui", CoreGui)
        gui.Name = "QuantumLeapControl"
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.ResetOnSpawn = false

        local mainFrame = Instance.new("Frame", gui)
        mainFrame.Name = "mainFrame"
        mainFrame.Size = UDim2.new(0, 300, 0, 155)
        mainFrame.Position = UDim2.new(0.5, -150, 0.5, -77)
        mainFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
        mainFrame.BorderSizePixel = 0
        mainFrame.Draggable = true
        mainFrame.Active = true

        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
        local mainStroke = Instance.new("UIStroke", mainFrame)
        mainStroke.Color = Color3.fromRGB(80, 85, 100)
        mainStroke.Thickness = 1.5

        -- Header
        local header = Instance.new("Frame", mainFrame)
        header.Size = UDim2.new(1, 0, 0, 35)
        header.BackgroundColor3 = Color3.fromRGB(45, 48, 56)
        header.BorderSizePixel = 0
        
        local titleLabel = Instance.new("TextLabel", header)
        titleLabel.Size = UDim2.new(1, -40, 1, 0)
        titleLabel.Position = UDim2.new(0, 15, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "QuantumLeap <b>v8.5</b>"
        titleLabel.RichText = true
        titleLabel.Font = Enum.Font.SourceSans
        titleLabel.TextColor3 = Color3.new(1, 1, 1)
        titleLabel.TextSize = 18
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local closeButton = Instance.new("TextButton", header)
        closeButton.Size = UDim2.new(0, 35, 1, 0)
        closeButton.Position = UDim2.new(1, -35, 0, 0)
        closeButton.BackgroundTransparency = 1
        closeButton.Text = "✕"
        closeButton.Font = Enum.Font.SourceSansBold
        closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        closeButton.TextSize = 16
        closeButton.MouseButton1Click:Connect(function() gui:Destroy() end)
        
        -- Status Bar
        local statusBar = Instance.new("Frame", mainFrame)
        statusBar.Name = "StatusBar"
        statusBar.Size = UDim2.new(1, -20, 0, 25)
        statusBar.Position = UDim2.new(0, 10, 0, 45)
        statusBar.BackgroundTransparency = 1

        local statusFlash = Instance.new("Frame", statusBar)
        statusFlash.Name = "StatusFlash"
        statusFlash.Size = UDim2.new(1, 0, 1, 0)
        statusFlash.BackgroundColor3 = Color3.new(1,1,1)
        statusFlash.BackgroundTransparency = 1
        statusFlash.Visible = false
        statusFlash.ZIndex = 0
        Instance.new("UICorner", statusFlash).CornerRadius = UDim.new(0, 6)
        
        local statusLabel = Instance.new("TextLabel", statusBar)
        statusLabel.Name = "StatusLabel"
        statusLabel.Size = UDim2.new(1, 0, 1, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "Estado: Inactivo"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.Font = Enum.Font.SourceSans
        statusLabel.TextSize = 15
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.ZIndex = 1

        -- Input Box
        local valorInput = Instance.new("TextBox", mainFrame)
        valorInput.Name = "ValorInput"
        valorInput.Size = UDim2.new(1, -20, 0, 35)
        valorInput.Position = UDim2.new(0, 10, 0, 70)
        valorInput.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
        valorInput.TextColor3 = Color3.new(1, 1, 1)
        valorInput.PlaceholderText = "Generación Mínima (ej: 10m, 50b...)"
        valorInput.Font = Enum.Font.SourceSansBold
        valorInput.TextSize = 16
        Instance.new("UICorner", valorInput).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", valorInput).Color = Color3.fromRGB(60, 65, 80)
        
        -- Main Button
        local toggleButton = Instance.new("TextButton", mainFrame)
        toggleButton.Name = "ToggleButton"
        toggleButton.Size = UDim2.new(1, -20, 0, 38)
        toggleButton.Position = UDim2.new(0, 10, 1, -48)
        local defaultColor = Color3.fromRGB(0, 170, 85)
        toggleButton.BackgroundColor3 = defaultColor
        toggleButton.Text = "INICIAR AUTOHOP"
        toggleButton.Font = Enum.Font.SourceSansBold
        toggleButton.TextColor3 = Color3.new(1, 1, 1)
        toggleButton.TextSize = 18
        Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)
        
        -- Cargar configuración guardada
        if isfile(CONFIG_FILE) then valorInput.Text = readfile(CONFIG_FILE)
        else valorInput.Text = "10m" end

        -- Eventos
        valorInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                writefile(CONFIG_FILE, valorInput.Text)
                actualizarStatus("Configuración guardada.", Color3.fromRGB(150, 255, 150))
                valorInput:ReleaseFocus()
            end
        end)
        
        -- Efecto Hover para el botón
        toggleButton.MouseEnter:Connect(function()
            TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = toggleButton.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.15)}):Play()
        end)
        toggleButton.MouseLeave:Connect(function()
            TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = toggleButton.BackgroundColor3:Lerp(Color3.new(0,0,0), 0.15)}):Play()
        end)

        toggleButton.MouseButton1Click:Connect(function()
            -- Si está en modo encontrado, un click lo reinicia
            if toggleButton.Text:find("ENCONTRADO") then
                busquedaActiva = false
                toggleButton.Text = "INICIAR AUTOHOP"
                toggleButton.BackgroundColor3 = defaultColor
                actualizarStatus("Listo para una nueva búsqueda.")
                return
            end
            
            busquedaActiva = not busquedaActiva
            if busquedaActiva then
                writefile(CONFIG_FILE, valorInput.Text) -- Guardar al iniciar
                toggleButton.Text = "DETENER AUTOHOP"
                toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                task.spawn(cicloDeBusqueda)
            else
                toggleButton.Text = "INICIAR AUTOHOP"
                toggleButton.BackgroundColor3 = defaultColor
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
