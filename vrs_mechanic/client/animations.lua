-- ============================================================
-- VRS_MECHANIC - ANIMATIONS CLIENT
-- ============================================================

local currentAnim = nil

--- Toca animação de reparo
---@param animType string 'repair'|'inspect'|'repair_wheel'
function VRS.PlayAnimation(animType)
    VRS.StopAnimation()

    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end

    if animType == 'repair' then
        lib.requestAnimDict('mini@repair')
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_player', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'mini@repair', name = 'fixing_a_player' }

    elseif animType == 'inspect' then
        lib.requestAnimDict('amb@world_human_clipboard@male@idle_a')
        TaskPlayAnim(ped, 'amb@world_human_clipboard@male@idle_a', 'idle_c', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'amb@world_human_clipboard@male@idle_a', name = 'idle_c' }

    elseif animType == 'repair_wheel' then
        lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
        TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 8.0, -8.0, -1, 1, 0, false, false, false)
        currentAnim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer' }
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
