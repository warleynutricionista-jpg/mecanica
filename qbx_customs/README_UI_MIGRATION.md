# qbx_customs UI migration audit

## Diagnóstico da tela preta

A causa raiz foi a arquitetura baseada em **NUI fullscreen persistente** do recurso anterior.

### Evidências da auditoria
- O recurso declarava `ui_page` e carregava um frontend HTML próprio em tempo integral.
- A abertura e atualização da interface dependiam de `SendNUIMessage(...)`.
- O fluxo de interação dependia de `RegisterNUICallback(...)` e `SetNuiFocus(...)`.
- O frontend antigo ocupava a tela inteira por design, com uma shell fullscreen escura em vez de usar componentes Ox/Qbox.
- O fechamento dependia da cooperação do frontend JS, o que deixava espaço para desync de foco, fechamento incompleto e overlay residual.
- O arquivo JS anterior ainda carregava restos de uma implementação incompleta/mista (`openUI`, `closeUI`, `hardResetUI`), o que reforçava o risco de inconsistência entre estado Lua e estado visual.

### Conclusão técnica
A tela preta não era um “glitch cosmético”, e sim um **efeito estrutural** da escolha arquitetural de manter uma NUI fullscreen como camada principal da UX. Em um ecossistema Qbox/QBCore com `ox_lib`, isso era a estratégia menos segura para um menu de customs desse tipo.

## Decisão arquitetural

A estratégia escolhida foi **remover completamente a NUI HTML** e migrar a interface principal para `ox_lib`.

### Motivos
1. `ox_lib` já cobre o fluxo principal com `lib.registerContext`, `lib.showContext`, `lib.hideContext`, `lib.alertDialog` e `lib.showTextUI`.
2. O fluxo de customs do recurso já é dominado por lógica Lua, preview em veículo e câmera em Lua; portanto o HTML não era estritamente necessário.
3. Eliminar `ui_page` remove a origem mais provável de overlay preto, focus stack preso, root visual residual e callbacks NUI inconsistentes.
4. A abordagem fica mais coerente com Qbox / QBCore / mri_Qbox, que naturalmente convivem melhor com Ox como camada de interface para menus utilitários.

## Nova arquitetura

### Padrão adotado
- **State-first, Lua-first**.
- `ox_lib` como camada principal de UI.
- Sem `ui_page`.
- Sem `SendNUIMessage`.
- Sem `RegisterNUICallback`.
- Sem `SetNuiFocus(true, true)`.
- Cleanup centralizado em funções únicas.

### Estado centralizado em Lua
O estado visual/interacional agora fica centralizado em Lua com os seguintes campos principais:
- `isCustomsOpen`
- `isPreviewActive`
- `isCameraActive`
- `currentCategory`
- `currentOption`
- `currentSelection`
- `isBusy`
- `hasFocus`
- `vehicleNetId`
- `vehicleEntity`
- `lastAppliedState`
- `previewState`

### Funções de blindagem
- `OpenCustomsUI()`
- `CloseCustomsUI()`
- `HardResetCustomsUI()`
- `SetCustomsFocus(state)`
- `ResetCustomsVisualState()`

### Fluxo atual
1. O jogador entra na zona e usa o `TextUI` já existente.
2. O cliente valida sessão/veículo/assento.
3. A sessão abre em Lua.
4. A câmera de preview é controlada em Lua.
5. Os menus são montados dinamicamente com `ox_lib`.
6. O preview aplica alterações temporárias no veículo em Lua.
7. A confirmação instala a modificação e atualiza o estado comprometido.
8. O fechamento executa cleanup completo e persistência final.

## Compatibilidade com Qbox / QBCore / mri_Qbox

Essa arquitetura é a mais adequada porque:
- aproveita o padrão Ox já presente no servidor;
- reduz dependência de frontend custom desnecessário;
- evita fullscreen NUI persistente;
- mantém preview/câmera/estado na camada cliente Lua, que é a camada correta para esse tipo de sistema em FiveM;
- simplifica suporte e reduz superfícies de erro em produção.

## Arquivos analisados
- `qbx_customs/fxmanifest.lua`
- `qbx_customs/client/ui.lua`
- `qbx_customs/client/main.lua`
- `qbx_customs/client/session.lua`
- `qbx_customs/client/actions.lua`
- `qbx_customs/client/ui_payload.lua`
- `qbx_customs/client/catalog.lua`
- `qbx_customs/client/catalog_builder/common.lua`
- `qbx_customs/client/catalog_builder/mods.lua`
- `qbx_customs/client/catalog_builder/wheels.lua`
- `qbx_customs/client/catalog_builder/appearance.lua`
- `qbx_customs/client/services/vehicle.lua`
- `qbx_customs/client/services/validator.lua`
- `qbx_customs/client/zones.lua`
- `qbx_customs/web/index.html` (removido)
- `qbx_customs/web/style.css` (removido)
- `qbx_customs/web/app.js` (removido)
- `qbx_customs/web/assets/renzu-icons/README.md` (removido)
- `qbx_customs/web/assets/renzu-icons/.gitkeep` (removido)

## Arquivos removidos
- `qbx_customs/web/index.html`
- `qbx_customs/web/style.css`
- `qbx_customs/web/app.js`
- `qbx_customs/web/assets/renzu-icons/README.md`
- `qbx_customs/web/assets/renzu-icons/.gitkeep`

## Arquivos criados
- `qbx_customs/README_UI_MIGRATION.md`

## Arquivos modificados
- `qbx_customs/fxmanifest.lua`
- `qbx_customs/client/ui.lua`
- `qbx_customs/client/main.lua`
- `qbx_customs/client/session.lua`
- `qbx_customs/client/services/vehicle.lua`

## Papel de cada arquivo relevante
- `qbx_customs/fxmanifest.lua`: remove a NUI do manifesto e deixa o recurso puramente Lua/Ox.
- `qbx_customs/client/ui.lua`: nova camada principal de UI state-first com `ox_lib`.
- `qbx_customs/client/main.lua`: orquestra abertura/fechamento, sessão, câmera, cleanup e persistência.
- `qbx_customs/client/session.lua`: guarda o estado durável da sessão de customs.
- `qbx_customs/client/services/vehicle.lua`: captura/restaura propriedades e sincroniza estado aplicado.
- `qbx_customs/README_UI_MIGRATION.md`: documento de auditoria, decisão arquitetural e checklist.

## Checklist final
- [x] Não existe `ui_page` em `fxmanifest.lua`.
- [x] Não existe HTML/CSS/JS de NUI ativo no recurso.
- [x] Não existe `SendNUIMessage(...)` no `qbx_customs`.
- [x] Não existe `RegisterNUICallback(...)` no `qbx_customs`.
- [x] Não existe `SetNuiFocus(true, true)` no `qbx_customs`.
- [x] O cleanup chama `SetNuiFocus(false, false)` e `SetNuiFocusKeepInput(false)` de forma centralizada.
- [x] A UI só abre por `OpenCustomsUI()` após validação de sessão.
- [x] O fechamento passa por `CloseCustomsUI()` / `HardResetCustomsUI()`.
- [x] Há cleanup em `onResourceStop`.
- [x] Há proteção contra fechamento inesperado via watcher do contexto Ox.
- [x] O preview continua em Lua e não depende de frontend HTML.
- [x] Não existe overlay fullscreen residual porque não existe mais página NUI fullscreen para o recurso.
