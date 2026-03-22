-- ============================================================
-- VRS_MECHANIC - ANIMATIONS CLIENT
-- ============================================================

local currentAnim = nil

local function playTrackedAnimation(ped, dict, name, flag)
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, flag or 1, 0, false, false, false)
    currentAnim = { dict = dict, name = name }
end

local function isLiftSupportContext(context)
    if type(context) ~= 'table' then
        return false
    end

    if context.forceLiftSupportAnimation or context.requiresLift then
        return true
    end

    return context.serviceArea == 'wheel'
        or context.serviceArea == 'underbody'
        or context.positionPreset == 'underbody_side'
        or context.positionPreset == 'specific_wheel'
        or context.positionPreset == 'nearest_wheel'
end

function VRS.ResolveServiceAnimation(vehicle, context, fallbackAnim)
    local animation = (type(context) == 'table' and context.animationSet) or fallbackAnim or 'repair'
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return animation
    end

    local liftState = VRS.GetLiftStateForVehicle and select(1, VRS.GetLiftStateForVehicle(vehicle)) or nil
    if not liftState or not isLiftSupportContext(context) then
        return animation
    end

    local minHeight = liftState.minHeight or Config.Lift.MinHeight or 0.0
    local currentHeight = liftState.height or minHeight
    if currentHeight <= (minHeight + 0.05) then
        return 'support_low'
    end

    return 'support_high'
end

function VRS.PlayServiceAnimation(vehicle, context, fallbackAnim)
    VRS.PlayAnimation(VRS.ResolveServiceAnimation(vehicle, context, fallbackAnim))
end

---@param animType string
function VRS.PlayAnimation(animType)
    VRS.StopAnimation()

    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end

    if animType == 'repair' or animType == 'engine_work' then
        playTrackedAnimation(ped, 'mini@repair', 'fixing_a_player', 1)

    elseif animType == 'support_low' then
        playTrackedAnimation(ped, 'mini@repair', 'fixing_a_ped', 1)

    elseif animType == 'support_high' then
        playTrackedAnimation(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1)

    elseif animType == 'inspect' or animType == 'diagnostic' then
        playTrackedAnimation(ped, 'amb@world_human_clipboard@male@idle_a', 'idle_c', 1)

    elseif animType == 'repair_wheel' or animType == 'wheel_work' then
        playTrackedAnimation(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1)

    elseif animType == 'underbody_work' then
        playTrackedAnimation(ped, 'mini@repair', 'fixing_a_ped', 1)

    elseif animType == 'body_work' then
        playTrackedAnimation(ped, 'mp_car_bomb', 'car_bomb_mechanic', 1)

    elseif animType == 'cleaning' then
        playTrackedAnimation(ped, 'timetable@floyd@clean_kitchen@base', 'base', 1)

    elseif animType == 'upgrade_install' then
        playTrackedAnimation(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1)

    elseif animType == 'tablet' then
        playTrackedAnimation(ped, 'amb@world_human_seat_wall_tablet@female@base', 'base', 49)
    end
end

--- Para animação atual
function VRS.StopAnimation()
    if not currentAnim then return end

    local ped = cache.ped
    if ped and DoesEntityExist(ped) then
        StopAnimTask(ped, currentAnim.dict, currentAnim.name, 1.0)
        ClearPedTasks(ped)
    end

    currentAnim = nil
end
