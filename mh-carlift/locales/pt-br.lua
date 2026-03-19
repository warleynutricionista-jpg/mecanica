--[[ ===================================================== ]] --
--[[             MH Car Lift Script por MaDHouSe           ]] --
--[[ ===================================================== ]] --
local Translations = {
    notify = {
        ['can_not_use_lift_insice_vehicle'] = "Você não pode usar o elevador se estiver dentro do veículo.",
        ['no_access'] = "Você não tem permissão para usar este elevador de carros."
    },
    menu = {
        ['menu_title'] = "Elevador Automotivo",
        ['elevator_up'] = "Subir elevador",
        ['elevator_down'] = "Descer elevador",
        ['elevator_stop'] = "Parar elevador",
        ['press_to_open'] = "[%{key}] - Menu do Elevador ID(%{id})",
        ['menu_close'] = "Fechar"
    }
}
Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})