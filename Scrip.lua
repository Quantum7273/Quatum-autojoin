--[[
=========================================================================================================================
    QuantumLeap v9.1 - Edición Infalible
    Versión: 9.1 (Lógica de Salto Garantizado + Failsafe)
    Objetivo: Corregir el fallo de atasco. Esta versión introduce un plan de emergencia que asegura
              que el script SIEMPRE saltará a otro servidor si existe al menos una opción disponible.
=========================================================================================================================
]]

local success, err = pcall(function()
    if not isfile or not writefile or not readfile or not game:GetService("HttpService") then
        warn("QuantumLeap v9.1 requiere un ejecutor con read/write file y HttpService.")
        return
    end

    -- Servicios y Variables Globales (Sin cambios)
    local CoreGui, TeleportService, HttpService, Players, Workspace, TweenService = game:GetService("CoreGui"), game:GetService("TeleportService"), game:GetService("HttpService"), game:GetService("Players"), game:GetService("Workspace"), game:GetService("TweenService")
    local LocalPlayer, PlaceID = Players.LocalPlayer, game.PlaceId
    local CONFIG_FILE, LOG_FILE = "QuantumLeap_Config.txt", "QuantumLeap_Log.json"
    local busquedaActiva, gui, logbookData = false, nil, {}
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- Gestión del Diario de Abordo y Funciones Auxiliares (Sin cambios)
    local function guardarLogbook() local s, e = pcall(HttpService.JSONEncode, HttpService, logbookData); if s then writefile(LOG_FILE, e) else warn("QL: No se pudo codificar el logbook.") end end
    local function cargarLogbook() if isfile(LOG_FILE) then local c = readfile(LOG_FILE); local s, d = pcall(HttpService.JSONDecode, HttpService, c); if s and type(d) == "table" then logbookData = d else logbookData = {} end else logbookData = {} end end
    local function formatNumber(num) num = tonumber(num) or 0; if num < 1e3 then return tostring(math.floor(num)) end; local suffixes = {"", "K", "M", "B", "T", "Q"}; local i = math.floor(math.log(num, 1e3)); return string.format("%.1f", num / (1000^i)):gsub("%.0", "")..suffixes[i+1] end
    local function procesarInputValor(texto) local num = string.gsub(texto, "[%,%s]", ""):lower(); local multiplicador = 1; if num:find("k") then multiplicador = 1e3; num = num:gsub("k", "") elseif num:find("m") then multiplicador = 1e6; num = num:gsub("m", "") elseif num:find("b") then multiplicador = 1e9; num = num:gsub("b", "") elseif num:find("t") then multiplicador = 1e12; num = num:gsub("t", "") elseif num:find("q") then multiplicador = 1e15; num = num:gsub("q", "") end; return (tonumber(num) or 0) * multiplicador end
    local function actualizarStatus(texto, color) if gui and gui.mainFrame and gui.mainFrame.StatusBar.StatusLabel then local statusLabel = gui.mainFrame.StatusBar.StatusLabel; statusLabel.Text = texto; statusLabel.TextColor3 = color or Color3.new(1, 1, 1) end end

    -- Lógica de Escaneo (Sin cambios)
    local function escanearServidor(valorMinimo) local mE, mG = nil, 0; for _, obj in pairs(Workspace:GetChildren()) do local p = obj:FindFirstChild("Part") or (obj:IsA("BasePart") and obj); if p then local i = p:FindFirstChild("Info"); if i then local g = i:FindFirstChild("Generation"); if g and g.Value >= valorMinimo and g.Value > mG then mG = g.Value; mE = i end end end end; return mE, mG end

    -- =====================================================================================================================
    --  LÓGICA DE SALTO INFALIBLE (v9.1)
    -- =====================================================================================================================
    local function saltarDeServidor()
        actualizarStatus("Consultando diario de abordo...", Color3.fromRGB(120, 180, 255))
        local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Desc&limit=100"
        
        local getSuccess, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not (getSuccess and response and response.data) then
            actualizarStatus("Error API. Reintentando...", Color3.fromRGB(255, 80, 80)); task.wait(5)
            if busquedaActiva then saltarDeServidor() end
            return
        end
        
        local servidores = response.data
        local candidatosVirgenes, candidatosPrometedores, candidatosGenericos = {}, {}, {}
        -- *** EL PLAN DE EMERGENCIA ***
        local candidatosDeEmergencia = {}
        
        local TIEMPO_REVISITAR_ENCONTRADO = 1800 -- 30 mins
        local TIEMPO_EVITAR_VACIO = 600 -- 10 mins

        for _, server in pairs(servidores) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                local logEntry = logbookData[server.id]
                local esCandidato = true -- Asumimos que es un candidato hasta que se demuestre lo contrario
                
                if not logEntry then
                    table.insert(candidatosVirgenes, server)
                else
                    local tiempoTranscurrido = os.time() - logEntry.last_visit
                    if logEntry.status == "Encontrado" and tiempoTranscurrido > TIEMPO_REVISITAR_ENCONTRADO then
                        table.insert(candidatosPrometedores, server)
                    elseif logEntry.status == "Vacio" and tiempoTranscurrido > TIEMPO_EVITAR_VACIO then
                        table.insert(candidatosGenericos, server)
                    else
                        -- Este servidor fue visitado recientemente y no es prometedor. Se marca para emergencia.
                        esCandidato = false
                        table.insert(candidatosDeEmergencia, server)
                    end
                end
            end
        end
        
        local servidorElegido, motivo = nil, ""
        
        if #candidatosVirgenes > 0 then
            servidorElegido = candidatosVirgenes[math.random(1, #candidatosVirgenes)]; motivo = "Explorando servidor desconocido..."
        elseif #candidatosPrometedores > 0 then
            servidorElegido = candidatosPrometedores[math.random(1, #candidatosPrometedores)]; motivo = "Revisitando un lugar prometedor..."
        elseif #candidatosGenericos > 0 then
            servidorElegido = candidatosGenericos[math.random(1, #candidatosGenericos)]; motivo = "Dando una segunda oportunidad..."
        
        -- *** ¡AQUÍ ESTÁ LA MAGIA! EL FAILSAFE ***
        elseif #candidatosDeEmergencia > 0 then
            -- Si todo lo demás falla, elegimos el servidor MÁS LLENO de la lista de emergencia.
            -- La lista ya viene ordenada por la API, así que el primero es el mejor.
            servidorElegido = candidatosDeEmergencia[1]
            motivo = "Plan de emergencia: Revisitando servidor..."
        end

        if servidorElegido then
            actualizarStatus(motivo, Color3.fromRGB(100, 255, 180))
            task.wait(1)
            actualizarStatus("Saltando a servidor con "..servidorElegido.playing.." jugadores...", Color3.fromRGB(100, 255, 180))
            guardarLogbook(); task.wait(1)
            TeleportService:TeleportToPlaceInstance(PlaceID, servidorElegido.id, LocalPlayer)
        else
            -- Este caso ahora es prácticamente imposible, a menos que no haya OTROS servidores en todo el juego.
            actualizarStatus("No hay ningún otro servidor disponible.", Color3.fromRGB(255, 100, 100))
            task.wait(15)
            if busquedaActiva then saltarDeServidor() end
        end
    end

    -- Ciclo de Búsqueda y GUI (Sin cambios, la lógica central se corrigió en `saltarDeServidor`)
    local function cicloDeBusqueda() if not busquedaActiva then return end; task.wait(1); actualizarStatus("Analizando servidor actual...", Color3.fromRGB(255, 255, 150)); local valorMinimo = procesarInputValor(gui.mainFrame.ValorInput.Text); local infoEncontrada, genValue = escanearServidor(valorMinimo); local currentServerLog = { last_visit = os.time(), best_gen = 0 }; if infoEncontrada then local nombre = "Desconocido"; local overhead = infoEncontrada:FindFirstChild("AnimalOverhead"); if overhead and overhead:FindFirstChild("DisplayName") then nombre = overhead.DisplayName.Value end; actualizarStatus("¡ENCONTRADO!: "..nombre.." ("..formatNumber(genValue).."/s)", Color3.fromRGB(0, 255, 127)); gui.mainFrame.ToggleButton.Text = "ENCONTRADO (REINICIAR)"; gui.mainFrame.ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 100, 50); busquedaActiva = false; currentServerLog.status = "Encontrado"; currentServerLog.best_gen = genValue; else currentServerLog.status = "Vacio"; if not busquedaActiva then return end; actualizarStatus("Servidor vacío. Preparando salto...", Color3.fromRGB(255, 180, 100)); task.wait(2); saltarDeServidor(); end; logbookData[game.JobId] = currentServerLog; end
    local function crearGUI() cargarLogbook(); if CoreGui:FindFirstChild("QuantumLeapControl") then CoreGui.QuantumLeapControl:Destroy() end; gui = Instance.new("ScreenGui", CoreGui); gui.Name = "QuantumLeapControl"; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.ResetOnSpawn = false; local mainFrame = Instance.new("Frame", gui); mainFrame.Name = "mainFrame"; mainFrame.Size = UDim2.new(0, 300, 0, 155); mainFrame.Position = UDim2.new(0.5, -150, 0.5, -77); mainFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46); mainFrame.BorderSizePixel = 0; mainFrame.Draggable = true; mainFrame.Active = true; Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8); local mainStroke = Instance.new("UIStroke", mainFrame); mainStroke.Color = Color3.fromRGB(80, 85, 100); mainStroke.Thickness = 1.5; local header = Instance.new("Frame", mainFrame); header.Size = UDim2.new(1, 0, 0, 35); header.BackgroundColor3 = Color3.fromRGB(45, 48, 56); header.BorderSizePixel = 0; local titleLabel = Instance.new("TextLabel", header); titleLabel.Size = UDim2.new(1, -40, 1, 0); titleLabel.Position = UDim2.new(0, 15, 0, 0); titleLabel.BackgroundTransparency = 1; titleLabel.Text = "QuantumLeap <b>v9.1</b>"; titleLabel.RichText = true; titleLabel.Font = Enum.Font.SourceSans; titleLabel.TextColor3 = Color3.new(1, 1, 1); titleLabel.TextSize = 18; titleLabel.TextXAlignment = Enum.TextXAlignment.Left; local closeButton = Instance.new("TextButton", header); closeButton.Size = UDim2.new(0, 35, 1, 0); closeButton.Position = UDim2.new(1, -35, 0, 0); closeButton.BackgroundTransparency = 1; closeButton.Text = "✕"; closeButton.Font = Enum.Font.SourceSansBold; closeButton.TextColor3 = Color3.fromRGB(200, 200, 200); closeButton.TextSize = 16; closeButton.MouseButton1Click:Connect(function() busquedaActiva = false; guardarLogbook(); gui:Destroy() end); local statusBar = Instance.new("Frame", mainFrame); statusBar.Name = "StatusBar"; statusBar.Size = UDim2.new(1, -20, 0, 25); statusBar.Position = UDim2.new(0, 10, 0, 45); statusBar.BackgroundTransparency = 1; local statusLabel = Instance.new("TextLabel", statusBar); statusLabel.Name = "StatusLabel"; statusLabel.Size = UDim2.new(1, 0, 1, 0); statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Estado: Inactivo"; statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200); statusLabel.Font = Enum.Font.SourceSans; statusLabel.TextSize = 15; statusLabel.TextXAlignment = Enum.TextXAlignment.Left; statusLabel.ZIndex = 1; local valorInput = Instance.new("TextBox", mainFrame); valorInput.Name = "ValorInput"; valorInput.Size = UDim2.new(1, -20, 0, 35); valorInput.Position = UDim2.new(0, 10, 0, 70); valorInput.BackgroundColor3 = Color3.fromRGB(25, 28, 36); valorInput.TextColor3 = Color3.new(1, 1, 1); valorInput.PlaceholderText = "Generación Mínima (ej: 10m, 50b...)"; valorInput.Font = Enum.Font.SourceSansBold; valorInput.TextSize = 16; Instance.new("UICorner", valorInput).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", valorInput).Color = Color3.fromRGB(60, 65, 80); local toggleButton = Instance.new("TextButton", mainFrame); toggleButton.Name = "ToggleButton"; toggleButton.Size = UDim2.new(1, -20, 0, 38); toggleButton.Position = UDim2.new(0, 10, 1, -48); local defaultColor = Color3.fromRGB(0, 170, 85); toggleButton.BackgroundColor3 = defaultColor; toggleButton.Text = "INICIAR AUTOHOP"; toggleButton.Font = Enum.Font.SourceSansBold; toggleButton.TextColor3 = Color3.new(1, 1, 1); toggleButton.TextSize = 18; Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8); if isfile(CONFIG_FILE) then valorInput.Text = readfile(CONFIG_FILE) else valorInput.Text = "10m" end; valorInput.FocusLost:Connect(function(enterPressed) if enterPressed then writefile(CONFIG_FILE, valorInput.Text); actualizarStatus("Configuración guardada.", Color3.fromRGB(150, 255, 150)); valorInput:ReleaseFocus() end end); toggleButton.MouseEnter:Connect(function() TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = toggleButton.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.15)}):Play() end); toggleButton.MouseLeave:Connect(function() TweenService:Create(toggleButton, tweenInfo, {BackgroundColor3 = toggleButton.BackgroundColor3:Lerp(Color3.new(0,0,0), 0.15)}):Play() end); toggleButton.MouseButton1Click:Connect(function() if toggleButton.Text:find("ENCONTRADO") then busquedaActiva = false; toggleButton.Text = "INICIAR AUTOHOP"; toggleButton.BackgroundColor3 = defaultColor; actualizarStatus("Listo para una nueva búsqueda."); return end; busquedaActiva = not busquedaActiva; if busquedaActiva then writefile(CONFIG_FILE, valorInput.Text); toggleButton.Text = "DETENER AUTOHOP"; toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50); cicloDeBusqueda() else toggleButton.Text = "INICIAR AUTOHOP"; toggleButton.BackgroundColor3 = defaultColor; actualizarStatus("Detenido por el usuario."); guardarLogbook() end end); end
    
    crearGUI()
end)

if not success then warn("--- QuantumLeap: Error Crítico ---"); warn("Detalles:", err) end
