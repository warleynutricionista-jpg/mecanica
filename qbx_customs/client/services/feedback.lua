local feedback = {}

function feedback.notify(message, level)
    if not message or message == '' then
        return
    end

    exports.qbx_core:Notify(message, level or 'inform')
end

function feedback.playConfirmSound()
    if qbx and qbx.playAudio then
        qbx.playAudio({
            audioName = 'PICK_UP',
            audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
        })
    end
end

return feedback
