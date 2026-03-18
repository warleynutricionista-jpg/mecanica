if (Config.Framework == "auto" and GetResourceState("qbx_core") == "started") or Config.Framework == "Qbox" then
  local function refreshPlayerData()
    Globals.PlayerData = exports.qbx_core:GetPlayerData() or {}
  end

  local function refreshMechanicState()
    refreshPlayerData()
    TriggerEvent("jg-mechanic:client:refresh-mechanic-zones-and-blips")
  end

  refreshPlayerData()

  RegisterNetEvent("QBCore:Client:OnPlayerLoaded", refreshMechanicState)
  RegisterNetEvent("QBCore:Client:OnPlayerUnload", refreshMechanicState)
  RegisterNetEvent("qbx_core:client:playerLoggedOut", refreshMechanicState)

  RegisterNetEvent("QBCore:Client:OnJobUpdate", function(job)
    Globals.PlayerData = Globals.PlayerData or {}
    Globals.PlayerData.job = job
    TriggerEvent("jg-mechanic:client:refresh-mechanic-zones-and-blips")
  end)

  RegisterNetEvent("QBCore:Client:SetDuty", function(onDuty)
    Globals.PlayerData = Globals.PlayerData or {}
    Globals.PlayerData.job = Globals.PlayerData.job or {}
    Globals.PlayerData.job.onduty = onDuty
    TriggerEvent("jg-mechanic:client:refresh-mechanic-zones-and-blips")
  end)

  RegisterNetEvent("QBCore:Client:OnGangUpdate", function(gang)
    Globals.PlayerData = Globals.PlayerData or {}
    Globals.PlayerData.gang = gang
    TriggerEvent("jg-mechanic:client:refresh-mechanic-zones-and-blips")
  end)
end
