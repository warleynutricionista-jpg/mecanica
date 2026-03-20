local ActionHelper = {}

function ActionHelper:Notify(description, ntype)
    lib.notify({ description = description, type = ntype or 'inform' })
end

function ActionHelper:RunProgress(data)
    return lib.progressBar({
        label = data.label,
        duration = data.duration,
        position = 'bottom',
        canCancel = data.canCancel ~= false,
        useWhileDead = false,
        disable = data.disable or { move = true, combat = true },
        anim = data.anim
    })
end

function ActionHelper:PlayMechanicAnim()
    return {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer'
    }
end

function ActionHelper:CancelServerAction(token)
    if token then
        TriggerServerEvent('mm_carkeys:server:cancelAction', token)
    end
end

return ActionHelper
