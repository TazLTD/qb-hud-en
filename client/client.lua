local QBCore = exports['qb-core']:GetCoreObject()
local hunger = 100
local thirst = 100
local stress = 0
local seatbeltOn = false
local istalking = false
local radioActive = false
local resetpausemenu = false
local huddata = {}
local config = Config
local speedMultiplier = config.UseMPH and 2.23694 or 3.6
local seatbeltOn = false
local cruiseOn = false
local showAltitude = false
local showSeatbelt = false
local cashAmount = 0
local bankAmount = 0
local playerDead = false
local showMenu = false
local showCircleB = false
local showSquareB = false
local Menu = config.Menu
local CinematicHeight = 0.2
local w = 0
local radioActive = false

RegisterCommand('hud', function()
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'hudmenu',
        show = true,
        settings = huddata
    })
end)

AddEventHandler("pma-voice:radioActive", function(data)
    radioActive = data
end)

RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function() -- Triggered in smallresources
    seatbeltOn = not seatbeltOn
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst) -- Triggered in qb-core
    hunger = newHunger
    thirst = newThirst
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress) -- Add this event with adding stress elsewhere
    stress = newStress
end)

-- Stress Gain

if not config.DisableStress then
    CreateThread(function() -- Speeding
        while true do
            if LocalPlayer.state.isLoggedIn then
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    local vehClass = GetVehicleClass(veh)
                    local speed = GetEntitySpeed(veh) * speedMultiplier
                    local vehHash = GetEntityModel(veh)
                    if config.VehClassStress[tostring(vehClass)] and not config.WhitelistedVehicles[vehHash] then
                        local stressSpeed
                        if vehClass == 8 then -- Motorcycle exception for seatbelt
                            stressSpeed = config.MinimumSpeed
                        else
                            stressSpeed = seatbeltOn and config.MinimumSpeed or config.MinimumSpeedUnbuckled
                        end
                        if speed >= stressSpeed then
                            TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                        end
                    end
                end
            end
            Wait(10000)
        end
    end)

    CreateThread(function() -- Shooting
        while true do
            if LocalPlayer.state.isLoggedIn then
                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= `WEAPON_UNARMED` then
                    if IsPedShooting(ped) and not config.WhitelistedWeaponStress[weapon] then
                        if math.random() < config.StressChance then
                            TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                        end
                    end
                else
                    Wait(1000)
                end
            end
            Wait(0)
        end
    end)
end


local stressThreshold = 1 -- Adjust the stress threshold as needed
local pulseSoundPlaying = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check the stress level every second (you can adjust the interval)

        if Config.EnableHeartbeatSound and stress > stressThreshold and not pulseSoundPlaying then
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "Pulse", 0.03) -- Play the sound
            pulseSoundPlaying = true
        elseif stress <= stressThreshold and pulseSoundPlaying then
            pulseSoundPlaying = false
            -- You can add logic to stop the sound here if needed
        end
    end
end)


-- Stress Screen Effects

local function GetBlurIntensity(stresslevel)
    for _, v in pairs(config.Intensity['blur']) do
        if stresslevel >= v.min and stresslevel <= v.max then
            return v.intensity
        end
    end
    return 1500
end

local function GetEffectInterval(stresslevel)
    for _, v in pairs(config.EffectInterval) do
        if stresslevel >= v.min and stresslevel <= v.max then
            return v.timeout
        end
    end
    return 60000
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local effectInterval = GetEffectInterval(stress)
        if stress >= 100 then
            local BlurIntensity = GetBlurIntensity(stress)
            local FallRepeat = math.random(2, 4)
            local RagdollTimeout = FallRepeat * 1750
            TriggerScreenblurFadeIn(1000.0)
            Wait(BlurIntensity)
            TriggerScreenblurFadeOut(1000.0)

            if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                SetPedToRagdollWithFall(ped, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end

            Wait(1000)
            for _ = 1, FallRepeat, 1 do
                Wait(750)
                DoScreenFadeOut(200)
                Wait(1000)
                DoScreenFadeIn(200)
                TriggerScreenblurFadeIn(1000.0)
                Wait(BlurIntensity)
                TriggerScreenblurFadeOut(1000.0)
            end
        elseif stress >= config.MinimumStress then
            local BlurIntensity = GetBlurIntensity(stress)
            TriggerScreenblurFadeIn(1000.0)
            Wait(BlurIntensity)
            TriggerScreenblurFadeOut(1000.0)
        end
        Wait(effectInterval)
    end
end)

Citizen.CreateThread(function()
    TriggerServerEvent('qb-hud:get:data')

    DisplayRadar(false)

    while not GetVehiclePedIsIn(GetPlayerPed(-1), false) do
        Citizen.Wait(1000)
    end
end)

RegisterNetEvent('qb-hud:get:data', function(data)
    huddata = data

    LoadMap()
    Citizen.Wait(2000)
    LoadMap()

    huddata = data

    while true do
        if LocalPlayer.state.isLoggedIn and not IsPauseMenuActive() and IsScreenFadedIn() then
            local ped = GetPlayerPed(-1)
            local playerId = PlayerId()
            local oxygen = GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10
            local inveh = IsPedInAnyVehicle(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            local proxmity = nil
            local stamina = 100 - GetPlayerSprintStaminaRemaining(PlayerId())

            if not istalking and NetworkIsPlayerTalking(PlayerId()) == 1 then
                istalking = true

                SendNUIMessage({
                    action = 'updateStatusHud',
                    show = true,
                    talking = {
                        talking = istalking,
                        radio = radioActive,
                    },
                })
            elseif istalking and NetworkIsPlayerTalking(PlayerId()) == false then
                istalking = false

                SendNUIMessage({
                    action = 'updateStatusHud',
                    show = true,
                    talking = {
                        talking = istalking,
                        radio = radioActive,
                    },
                })
            end

            if LocalPlayer.state['proximity'] then
                proxmity = LocalPlayer.state['proximity'].distance
            end

            SendNUIMessage({
                action = 'UpdateProximity',
                proxmity = tonumber(proxmity),
            })

            if inveh then
                local speed = math.floor(GetEntitySpeed(veh) * 3.6)

                if speed == 0 then
                    speed = 1
                end

                PauseMenuReset()

                DisplayRadar(true)

                SendNUIMessage({
                    action = 'updateStatusHud',
                    show = true,
                    talking = nil,
                    health = GetEntityHealth(ped) - 100,
                    armour = GetPedArmour(ped),
                    hunger = hunger,
                    thirst = thirst,
                    stress = stress,
                    oxygen = oxygen,
                    speed = speed,
                    alt = math.floor(GetEntityHeightAboveGround(veh)),
                    fuel = GetVehicleFuelLevel(veh),
                    stamina = stamina,
                })

                SendNUIMessage({
                    action = 'car',
                    show = true,
                })

                SendNUIMessage({
                    action = 'seatbelt',
                    toggle = seatbeltOn,
                })

                SendNUIMessage({
                    action = 'air',
                    show = IsPedInAnyHeli(ped) or IsPedInAnyPlane(ped)
                })
            else
                DisplayRadar(false)

                SendNUIMessage({
                    action = 'updateStatusHud',
                    show = true,
                    talking = nil,
                    health = GetEntityHealth(ped) - 100,
                    armour = GetPedArmour(ped),
                    hunger = hunger,
                    thirst = thirst,
                    stress = stress,
                    oxygen = oxygen,
                    speed = 1,
                    stamina = stamina,
                })

                SendNUIMessage({
                    action = 'car',
                    show = false,
                })

                SendNUIMessage({
                    action = 'seatbelt',
                    toggle = false,
                })

                SendNUIMessage({
                    action = 'air',
                    show = false
                })
            end
        else
            SendNUIMessage({
                action = 'updateStatusHud',
                show = false,
            })
        end

        Citizen.Wait(250)
    end
end)

function PauseMenuReset()
    if not resetpausemenu then
        Citizen.CreateThread(function()
            local count = 0

            resetpausemenu = true

            ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'),0,-1)

            while 10 > count do
                count = count + 1

                if IsPauseMenuActive() then
                    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'),0,-1)
                end

                Citizen.Wait(100)
            end
        end)
    end
end

function LoadMap()
    local defaultAspectRatio = 1920/1080 -- Don't change this.
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX/resolutionY
    local minimapOffset = 0

    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio-aspectRatio)/3.6)-0.008
    end

    SetBlipAlpha(GetNorthRadarBlip(), 0)

    Citizen.CreateThread(function()
        SetBlipAlpha(GetNorthRadarBlip(), 0)

        if huddata.minimap == 2 then
            RequestStreamedTextureDict("circlemap", false)
            while not HasStreamedTextureDictLoaded("circlemap") do
                Wait(100)
            end

            --AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
            --AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "circlemap", "radarmasksm")

            SetMinimapClipType(1)
            SetMinimapComponentPosition("minimap", "L", "B", 0.025 - 0.03, -0.03, 0.153, 0.21)
            SetMinimapComponentPosition("minimap_mask", "L", "B", 0.135 - 0.03, 0.12, 0.093, 0.164)
            SetMinimapComponentPosition("minimap_blur", "L", "B", 0.012 - 0.03, 0.022, 0.256, 0.337)
        else
            RequestStreamedTextureDict("squaremap", false)
            while not HasStreamedTextureDictLoaded("squaremap") do
                Wait(0)
            end

            local minimap = RequestScaleformMovie("minimap")

            while not HasScaleformMovieLoaded(minimap) do
                Wait(0)
            end

            --AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
            --AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")

            SetMinimapComponentPosition("minimap", "L", "B", -0.0045, 0.002, 0.150, 0.188888)
            SetMinimapComponentPosition("minimap_mask", "L", "B", 0.020, 0.032, 0.111, 0.159)
            SetMinimapComponentPosition("minimap_blur", "L", "B", -0.03, 0.002, 0.266, 0.237)
        end
    end)
end

RegisterNUICallback('closeui', function(data, cb)
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'hudmenu',
        show = false,
        settings = {}
    })

    cb('ok')
end)

RegisterNUICallback('SaveHudSettings', function(data, cb)
    SetNuiFocus(false, false)

    huddata = data.settings

    TriggerServerEvent('qb-hud:update', huddata)

    SendNUIMessage({
        action = 'hudmenu',
        show = false,
        settings = {}
    })

    LoadMap()
    Citizen.Wait(500)
    LoadMap()
    resetpausemenu = false

    cb('ok')
end)

-- Speedometer shits
-- Function to draw time
function drawTime()
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    local timeText = string.format("%02d:%02d", hour, minute)

    drawTxt(timeText, 4, timeColorText, 0.4, timePosX, timePosY)
end

-- Function to draw location
local screenPosX = 0.170
local screenPosY = 0.805
local locationAlwaysOn = false
local locationColorText = {255, 255, 255}
local directions = {
    [0] = 'North', [1] = 'Northwest', [2] = 'West', [3] = 'Southwest',
    [4] = 'South', [5] = 'Southeast', [6] = 'East', [7] = 'Northeast', [8] = 'North'
}
local zones = { ['AIRP'] = "Los Santos International Airport", ['ALAMO'] = "Alamo Sea", ['ALTA'] = "Alta", ['ARMYB'] = "Fort Zancudo", ['BANHAMC'] = "Banham Canyon Dr", ['BANNING'] = "Banning", ['BEACH'] = "Vespucci Beach", ['BHAMCA'] = "Banham Canyon", ['BRADP'] = "Braddock Pass", ['BRADT'] = "Braddock Tunnel", ['BURTON'] = "Burton", ['CALAFB'] = "Calafia Bridge", ['CANNY'] = "Raton Canyon", ['CCREAK'] = "Cassidy Creek", ['CHAMH'] = "Chamberlain Hills", ['CHIL'] = "Vinewood Hills", ['CHU'] = "Chumash", ['CMSW'] = "Chiliad Mountain State Wilderness", ['CYPRE'] = "Cypress Flats", ['DAVIS'] = "Davis", ['DELBE'] = "Del Perro Beach", ['DELPE'] = "Del Perro", ['DELSOL'] = "La Puerta", ['DESRT'] = "Grand Senora Desert", ['DOWNT'] = "Downtown", ['DTVINE'] = "Downtown Vinewood", ['EAST_V'] = "East Vinewood", ['EBURO'] = "El Burro Heights", ['ELGORL'] = "El Gordo Lighthouse", ['ELYSIAN'] = "Elysian Island", ['GALFISH'] = "Galilee", ['GOLF'] = "GWC and Golfing Society", ['GRAPES'] = "Grapeseed", ['GREATC'] = "Great Chaparral", ['HARMO'] = "Harmony", ['HAWICK'] = "Hawick", ['HORS'] = "Vinewood Racetrack", ['HUMLAB'] = "Humane Labs and Research", ['JAIL'] = "Bolingbroke Penitentiary", ['KOREAT'] = "Little Seoul", ['LACT'] = "Land Act Reservoir", ['LAGO'] = "Lago Zancudo", ['LDAM'] = "Land Act Dam", ['LEGSQU'] = "Legion Square", ['LMESA'] = "La Mesa", ['LOSPUER'] = "La Puerta", ['MIRR'] = "Mirror Park", ['MORN'] = "Morningwood", ['MOVIE'] = "Richards Majestic", ['MTCHIL'] = "Mount Chiliad", ['MTGORDO'] = "Mount Gordo", ['MTJOSE'] = "Mount Josiah", ['MURRI'] = "Murrieta Heights", ['NCHU'] = "North Chumash", ['NOOSE'] = "N.O.O.S.E", ['OCEANA'] = "Pacific Ocean", ['PALCOV'] = "Paleto Cove", ['PALETO'] = "Paleto Bay", ['PALFOR'] = "Paleto Forest", ['PALHIGH'] = "Palomino Highlands", ['PALMPOW'] = "Palmer-Taylor Power Station", ['PBLUFF'] = "Pacific Bluffs", ['PBOX'] = "Pillbox Hill", ['PROCOB'] = "Procopio Beach", ['RANCHO'] = "Rancho", ['RGLEN'] = "Richman Glen", ['RICHM'] = "Richman", ['ROCKF'] = "Rockford Hills", ['RTRAK'] = "Redwood Lights Track", ['SANAND'] = "San Andreas", ['SANCHIA'] = "San Chianski Mountain Range", ['SANDY'] = "Sandy Shores", ['SKID'] = "Mission Row", ['SLAB'] = "Stab City", ['STAD'] = "Maze Bank Arena", ['STRAW'] = "Strawberry", ['TATAMO'] = "Tataviam Mountains", ['TERMINA'] = "Terminal", ['TEXTI'] = "Textile City", ['TONGVAH'] = "Tongva Hills", ['TONGVAV'] = "Tongva Valley", ['VCANA'] = "Vespucci Canals", ['VESP'] = "Vespucci", ['VINE'] = "Vinewood", ['WINDF'] = "Ron Alternates Wind Farm", ['WVINE'] = "West Vinewood", ['ZANCUDO'] = "Zancudo River", ['ZP_ORT'] = "Port of South Los Santos", ['ZQ_UAR'] = "Davis Quartz" }

local pedInVeh = true
local timeText = ""
local locationText = ""
local streetText = ""
local currentFuel = 0.0

-- Function to draw text
function drawTxt(content, font, colour, scale, x, y)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    SetTextEntry("STRING")
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    AddTextComponentString(content)
    DrawText(x, y)
end

-- Function to draw location
function drawLocation()
    local player = GetPlayerPed(-1)
    local position = GetEntityCoords(player)
    local heading = directions[math.floor((GetEntityHeading(player) + 22.5) / 45.0)]
    local zoneNameFull = zones[GetNameOfZone(position.x, position.y, position.z)]
    local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(position.x, position.y, position.z))

    locationText = " " .. heading
    streetText = " " .. (streetName or "N/A")
    zoneText = " " .. (zoneNameFull or "N/A")
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local player = GetPlayerPed(-1)
        local position = GetEntityCoords(player)
        local vehicle = GetVehiclePedIsIn(player, false)

        if IsPedInAnyVehicle(player, false) then
            pedInVeh = true
        else
            pedInVeh = false
        end

        if pedInVeh or locationAlwaysOn then
            -- Use HTML-style text formatting for style changes
            drawTxt("<i>" .. timeText .. "</i>", 4, locationColorText, 0.4, screenPosX, screenPosY + 0.048)
            drawTxt("<font color='#FFFEFE'>" .. locationText .. "</font>", 4, locationColorText, 0.5, screenPosX, screenPosY + 0.075)
            drawTxt("<font color='#FFFEFE'>" .. streetText .. "</font>", 4, locationColorText, 0.5, screenPosX, screenPosY + 0.100)
            drawTxt("<font color='#FFFEFE'>" .. zoneText .. "</font>", 4, locationColorText, 0.5, screenPosX, screenPosY + 0.125)

            local vehicleClass = GetVehicleClass(vehicle)
            if pedInVeh and GetIsVehicleEngineRunning(vehicle) and vehicleClass ~= 13 then
                local prevSpeed = currSpeed
                currSpeed = GetEntitySpeed(vehicle)

                SetPedConfigFlag(PlayerPedId(), 32, true)

                if (GetPedInVehicleSeat(vehicle, -1) == player) then
                    if IsControlJustReleased(0, cruiseInput) and (enableController or GetLastInputMethod(0)) then
                        cruiseIsOn = not cruiseIsOn
                        cruiseSpeed = currSpeed
                    end
                    local maxSpeed = cruiseIsOn and cruiseSpeed or GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
                    SetEntityMaxSpeed(vehicle, maxSpeed)
                else
                    cruiseIsOn = false
                end
            end
        end
    end
end)


Citizen.CreateThread(function()
    while true do
        if pedInVeh or locationAlwaysOn then
            local player = GetPlayerPed(-1)
            local position = GetEntityCoords(player)

            local hour = GetClockHours()
            local minute = GetClockMinutes()

            drawLocation()

            if pedInVeh then
                local vehicle = GetVehiclePedIsIn(player, false)
                if fuelShowPercentage then
                    currentFuel = 100 * GetVehicleFuelLevel(vehicle) / GetVehicleHandlingFloat(vehicle,"CHandlingData","fPetrolTankVolume")
                else
                    currentFuel = GetVehicleFuelLevel(vehicle)
                end
            end

            Citizen.Wait(1000)
        else
            Citizen.Wait(0)
        end
    end
end)


---- TIME SHIT
local timePosX = 0.004
local timePosY = 0.925
local timeColorText = {255, 255, 255}
local timeText = ""

Citizen.CreateThread(function()
    local lastMinute = -1  -- Initialize with an invalid value

    while true do
        Citizen.Wait(0)

        local hour = GetClockHours()
        local minute = GetClockMinutes()

        if minute ~= lastMinute then
            timeText = string.format("%02d:%02d", hour, minute)
            lastMinute = minute
        end

        Citizen.Wait(1000)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        drawTxt(timeText, 4, timeColorText, 0.4, timePosX, timePosY)
    end
end)

----- ID SHIT

local idPosX = 0.005  -- Adjust X coordinate as needed
local idPosY = 0.900  -- Adjust Y coordinate as needed
local idColorText = {255, 255, 255}  -- Text color (white in RGBA format)
local idDuration = 5000  -- Display duration in milliseconds (5 seconds)
local idText = ""

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerId = GetPlayerServerId(PlayerId())
        local newIdText = "" .. playerId

        if newIdText ~= idText then
            idText = newIdText
            Citizen.Wait(idDuration)  -- Wait for the specified duration
        end

        Citizen.Wait(1000)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        drawTxt(idText, 4, idColorText, 0.4, idPosX, idPosY)
    end
end)

function drawTxt(content, font, colour, scale, x, y)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], 255)
    SetTextEntry("STRING")
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    AddTextComponentString(content)
    DrawText(x, y)
end



