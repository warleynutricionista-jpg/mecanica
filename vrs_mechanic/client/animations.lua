-- ============================================================
-- VRS_MECHANIC - ANIMATIONS CLIENT
-- ============================================================

local currentAnim = nil

---@param animType string
function VRS.PlayAnimation(animType)
    VRS.StopAnimation()

    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end

    if animType == 'repair' or animType == 'engine_work' then
        lib.requestAnimDict('mini@repair')
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_player', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'mini@repair', name = 'fixing_a_player' }

    elseif animType == 'inspect' or animType == 'diagnostic' then
        lib.requestAnimDict('amb@world_human_clipboard@male@idle_a')
        TaskPlayAnim(ped, 'amb@world_human_clipboard@male@idle_a', 'idle_c', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'amb@world_human_clipboard@male@idle_a', name = 'idle_c' }

    elseif animType == 'repair_wheel' or animType == 'wheel_work' then
        lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
        TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer' }

    elseif animType == 'underbody_work' then
        lib.requestAnimDict('mini@repair')
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'mini@repair', name = 'fixing_a_ped' }

    elseif animType == 'body_work' then
        lib.requestAnimDict('mp_car_bomb')
        TaskPlayAnim(ped, 'mp_car_bomb', 'car_bomb_mechanic', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'mp_car_bomb', name = 'car_bomb_mechanic' }

    elseif animType == 'cleaning' then
        lib.requestAnimDict('timetable@floyd@clean_kitchen@base')
        TaskPlayAnim(ped, 'timetable@floyd@clean_kitchen@base', 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'timetable@floyd@clean_kitchen@base', name = 'base' }

    elseif animType == 'upgrade_install' then
        lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
        TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer' }

    elseif animType == 'tablet' then
        lib.requestAnimDict('amb@world_human_seat_wall_tablet@female@base')
        TaskPlayAnim(ped, 'amb@world_human_seat_wall_tablet@female@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)
        currentAnim = { dict = 'amb@world_human_seat_wall_tablet@female@base', name = 'base' }
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
