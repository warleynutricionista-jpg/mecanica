# qbx_customs

Reescrita completa do recurso `qbx_customs` para bases Qbox com `qbx_core`, `ox_lib`, `oxmysql` e integração com `qbx_vehicles`.

## Diagnóstico da versão anterior

A auditoria da versão anterior mostrou problemas estruturais que comprometiam estabilidade e compatibilidade:

- persistência limitada ao dono do veículo, quebrando fluxo de oficina para veículos de terceiros;
- cobrança e persistência desacopladas, permitindo inconsistência entre pagamento e aplicação;
- arquitetura espalhada entre várias camadas pequenas com responsabilidades sobrepostas;
- risco de preview residual, câmera residual e fechamento inconsistente em perda de foco/contexto;
- dependência de callbacks fragmentados para zone, vehicle props e fechamento sem trilha de sessão no servidor;
- menus reconstruídos em múltiplos pontos sem uma sessão server-side para validar a operação final.

## Nova arquitetura

A nova estrutura foi reduzida para módulos com responsabilidade explícita:

- `config/shared.lua`: zonas, política de cobrança, preços e permissões.
- `config/client.lua`: catálogo base, labels, câmera e classes.
- `shared/pricing.lua`: cálculo centralizado de preço para cosméticos, performance e reparo.
- `client/session.lua`: estado único da sessão ativa.
- `client/services/access.lua`: validação client-side de zona, job, duty e classe/modelo.
- `client/services/vehicle.lua`: snapshot, restore, preview e captura de propriedades.
- `client/camera.lua`: câmera orbital isolada, sem NUI fullscreen.
- `client/catalog.lua`: catálogo dinâmico baseado no veículo atual.
- `client/menu.lua`: UI principal em `ox_lib` com contexts e watcher de fechamento.
- `client/main.lua`: orquestra abertura, preview, checkout, rollback e fechamento.
- `client/zones.lua`: zonas, text UI e integração externa `mri_Qbox:customs:client`.
- `server/services/access.lua`: política de acesso server-side.
- `server/services/billing.lua`: cobrança, estorno e notificação.
- `server/services/persistence.lua`: persistência via `qbx_vehicles` com fallback SQL preservando `vrsMechanic`.
- `server/main.lua`: sessão server-side, abertura, checkout atômico e limpeza.

## Compatibilidade Qbox

O recurso final foi alinhado com a base desta pasta:

- `qbx_core` para player/job/money/notify;
- `ox_lib` para locale, callbacks, text UI e context menus;
- `oxmysql` para fallback de persistência;
- `qbx_vehicles` para `SaveVehicle` quando a entidade existe no servidor;
- preservação de dados extras como `vrsMechanic` em fallback SQL, evitando perda de integração com a mecânica.

## Fluxo operacional

1. O client valida zona, veículo, banco do motorista e acesso.
2. O server abre uma sessão única por source e valida persistência do veículo.
3. O client gera preview sempre a partir do snapshot confirmado.
4. Ao aplicar, o server cobra, persiste e só confirma quando tudo conclui com sucesso.
5. Se a persistência falhar, o server estorna a cobrança.
6. Ao fechar, o client restaura preview pendente, encerra câmera, fecha menu e limpa sessão server-side.

## Ajustes manuais recomendados

- revisar `config/shared.lua` para jobs gratuitos (`freeRepairJobs`, `freeModJobs`) e restrições específicas de cada oficina;
- traduzir `locales/en.json`, `de.json` e `fr.json`, que foram sincronizados temporariamente com `pt-br.json` nesta reescrita;
- habilitar `allowTemporaryVehicles = true` apenas se a sua base realmente usar veículos sem registro em `player_vehicles`.

## Checklist técnico

- [x] abre corretamente por zona;
- [x] valida banco do motorista;
- [x] valida sessão única no servidor;
- [x] preview sempre parte do estado confirmado;
- [x] cancelar preview restaura propriedades anteriores;
- [x] aplicação chama cobrança + persistência no mesmo fluxo;
- [x] persistência tenta `qbx_vehicles` antes do fallback SQL;
- [x] falha de persistência gera estorno;
- [x] fechamento limpa câmera, menu, preview e sessão server-side;
- [x] reinício do resource restaura o snapshot confirmado no client.
