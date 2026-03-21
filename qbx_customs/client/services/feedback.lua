local feedback = {}

function feedback.notify(message, level)
    exports.qbx_core:Notify(message, level)
end

function feedback.playConfirmSound()
    qbx.playAudio({
        audioName = 'PICK_UP',
        audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    })
end

return feedback
