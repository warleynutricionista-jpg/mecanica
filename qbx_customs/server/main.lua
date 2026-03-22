lib.versionCheck('Qbox-project/qbx_customs')

local access = require 'server.services.access'
local billing = require 'server.services.billing'
local persistence = require 'server.services.persistence'
local pricing = require 'shared.pricing'

local activeSessions = {}

local function clearSession(source)
    activeSessions[source] = nil
end

local function getSession(source)
    return activeSessions[source]
end

lib.callback.register('qbx_customs:server:openSession', function(source, payload)
    if activeSessions[source] then
        return { ok = false, reason = 'busy' }
    end

    if type(payload) ~= 'table' then
        return { ok = false, reason = 'zoneInvalid' }
    end

    local zoneIndex = tonumber(payload.zoneIndex)
    local canOpen, zoneOrReason = access.canOpen(source, zoneIndex)
    if not canOpen then
        return { ok = false, reason = zoneOrReason }
    end

    local record, plateReason, normalizedPlate = persistence.resolveVehicleRecord(payload.plate)
    if plateReason then
        return { ok = false, reason = plateReason }
    end

    activeSessions[source] = {
        zoneIndex = zoneIndex,
        zoneId = zoneOrReason.id,
        plate = normalizedPlate,
        vehicleNetId = tonumber(payload.vehicleNetId) or 0,
        vehicleId = record and record.id or nil,
    }

    return {
        ok = true,
        zoneId = zoneOrReason.id,
        plate = normalizedPlate,
        persisted = record ~= nil,
    }
end)

lib.callback.register('qbx_customs:server:checkout', function(source, payload)
    local session = getSession(source)
    if not session then
        return { ok = false, reason = 'noSession' }
    end

    if type(payload) ~= 'table' then
        return { ok = false, reason = 'invalidProps' }
    end

    if payload.zoneIndex ~= session.zoneIndex then
        return { ok = false, reason = 'zoneInvalid' }
    end

    local props, normalizeReason = persistence.normalizeProps(payload.props)
    if not props then
        return { ok = false, reason = normalizeReason }
    end

    if props.plate ~= session.plate then
        return { ok = false, reason = 'invalidPlate' }
    end

    local amount = 0
    local account = nil
    if not access.isFreeAction(source, session.zoneIndex, payload.serviceType or 'mod') then
        amount = pricing.get(payload.priceKey, payload.priceLevel, { bodyHealth = payload.bodyHealth })
        local charged, chargeResult = billing.charge(source, amount)
        if not charged then
            return { ok = false, reason = chargeResult }
        end
        account = chargeResult
    end

    local saved, saveReason = persistence.save(session.vehicleNetId, props)
    if not saved then
        if amount > 0 then
            billing.refund(source, amount, account)
        end
        return { ok = false, reason = saveReason }
    end

    if amount > 0 then
        billing.notifySuccess(source, amount, account)
    end

    return {
        ok = true,
        amount = amount,
        free = amount == 0,
    }
end)

RegisterNetEvent('qbx_customs:server:closeSession', function()
    clearSession(source)
end)

AddEventHandler('playerDropped', function()
    clearSession(source)
end)
