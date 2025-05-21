local isIndicatorActive = false
local previousHeading = 0
local headingCheckThreshold = 70 -- Degrees needed to turn before auto-deactivating indicator

local function isIndicating(vehicle, type)
  if not Entity(vehicle).state.indicate then return false end
  local state = Entity(vehicle).state.indicate

  if state[1] and state[2] and type == "hazards" then return true end
  if state[1] and not state[2] and type == "right" then return true end
  if not state[1] and state[2] and type == "left" then return true end

  return false
end

local function indicate(type)
  local ped = PlayerPedId()
  if not IsPedInAnyVehicle(ped) then return false end
  local vehicle = GetVehiclePedIsIn(ped)
  
  local value = {}
  if type == "left" and not isIndicating(vehicle, "left") then 
    value = {false, true}
    isIndicatorActive = "left"
    previousHeading = GetEntityHeading(vehicle)
  elseif type == "right" and not isIndicating(vehicle, "right") then 
    value = {true, false}
    isIndicatorActive = "right"
    previousHeading = GetEntityHeading(vehicle)
  elseif type == "hazards" and not isIndicating(vehicle, "hazards") then 
    value = {true, true}
    isIndicatorActive = "hazards"
  else 
    value = {false, false}
    isIndicatorActive = false
  end

  TriggerServerEvent("jg-vehicleindicators:server:set-state", VehToNet(vehicle), value)
end

local function checkTurnCompletion()
  if not isIndicatorActive or isIndicatorActive == "hazards" then return end
  
  local ped = PlayerPedId()
  if not IsPedInAnyVehicle(ped) then 
    isIndicatorActive = false
    return 
  end
  
  local vehicle = GetVehiclePedIsIn(ped)
  local currentHeading = GetEntityHeading(vehicle)
  
  local headingDiff = math.abs(currentHeading - previousHeading)
  if headingDiff > 180 then
    headingDiff = 360 - headingDiff
  end
  
  if (isIndicatorActive == "left" and headingDiff >= headingCheckThreshold) or
     (isIndicatorActive == "right" and headingDiff >= headingCheckThreshold) then
    indicate("off")
  end
end

AddStateBagChangeHandler("indicate", nil, function(bagName, key, data)
  local entity = GetEntityFromStateBagName(bagName)
  if entity == 0 then return end
  for i, status in ipairs(data) do
    SetVehicleIndicatorLights(entity, i - 1, status)
  end
end)

RegisterCommand("indicate_left", function() indicate("left") end)
RegisterKeyMapping('indicate_left', 'Vehicle indicate left', 'keyboard', 'LEFT')

RegisterCommand("indicate_right", function() indicate("right") end)
RegisterKeyMapping('indicate_right', 'Vehicle indicate right', 'keyboard', 'RIGHT')

RegisterCommand("hazards", function() indicate("hazards") end)
RegisterKeyMapping('hazards', 'Vehicle hazards', 'keyboard', 'UP')

local brakeLightsOn = false

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    checkTurnCompletion()
  end
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
      local vehicle = GetVehiclePedIsIn(ped, false)

      if GetPedInVehicleSeat(vehicle, -1) == ped then
        local speed = GetEntitySpeed(vehicle) * 3.6

        if speed < 1.0 and not isIndicatorActive then
          SetVehicleBrakeLights(vehicle, true)
        end
      end
    else
      Citizen.Wait(1000)
    end
  end
end)
