# vrs_mechanic

Guia completo de instalação, configuração e validação do recurso `vrs_mechanic` para servidores Qbox/QBX com `ox_lib`, `ox_target`, `ox_inventory` e `oxmysql`.

---

## 1. Visão geral

O `vrs_mechanic` entrega:

- HUB de mecânica no **F12**.
- Tablet operacional com **OS**, preços, cobrança, funcionários, histórico e integração com loja.
- Loja de peças com **categorias**, **preços configuráveis**, compra por quantidade e entrega via `ox_inventory`.
- Elevador completo com **colocar veículo**, **subir**, **descer**, **retirar**, **diagnosticar** e **iniciar serviço**.
- Integração com oficinas próprias e oficinas públicas/self-service.
- Fluxo validado no servidor para evitar exploits básicos de compra e acesso.

---

## 2. Estrutura de arquivos importante

### Arquivos principais do recurso

- `fxmanifest.lua`
- `config/shared.lua`
- `config/shops.lua`
- `config/items.lua`
- `config/panel.lua`
- `client/tablet.lua`
- `client/shop.lua`
- `client/duty.lua`
- `client/target.lua`
- `server/shop.lua`
- `server/lifts.lua`
- `sql/vrs_mechanic.sql`
- `web/index.html`
- `web/app.js`
- `web/style.css`

### Assets da interface

Os cards visuais da loja agora são renderizados apenas com HTML/CSS/ícones, sem dependência de imagens binárias locais.


---

## 3. Dependências obrigatórias

Garanta que estes recursos estejam instalados e funcionando antes do `vrs_mechanic`:

1. `qbx_core`
2. `ox_lib`
3. `oxmysql`
4. `ox_inventory`
5. `ox_target`

### Dependências opcionais mas recomendadas

- `qb-management` se você quiser repassar parte da cobrança para o cofre/society da oficina.

> Se `qb-management` não existir, o script faz fallback e entrega o valor diretamente ao mecânico em cobranças com society habilitada.

---

## 4. Ordem de start recomendada no servidor

No seu `server.cfg`, use uma ordem parecida com esta:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_inventory
ensure ox_target
ensure vrs_mechanic
```

Se usar gerenciamento society externo:

```cfg
ensure qb-management
```

Coloque `qb-management` antes do `vrs_mechanic` se quiser garantir os repasses para a society.

---

## 5. Instalação do banco de dados (SQL)

### Arquivo SQL

Execute este arquivo no banco:

- `sql/vrs_mechanic.sql`

### Tabelas criadas

- `vrs_mechanic_vehicle_status`
- `vrs_mechanic_work_orders`
- `vrs_mechanic_employees`
- `vrs_mechanic_price_overrides`
- `vrs_mechanic_service_logs`
- `vrs_mechanic_shops`

### Como aplicar

Você pode:

- importar via HeidiSQL / DBeaver / phpMyAdmin;
- ou colar manualmente no console SQL do seu banco.

---

## 6. Itens necessários no ox_inventory

Você precisa cadastrar no `ox_inventory/data/items.lua` ou no método equivalente da sua base os itens abaixo.

### Ferramentas e kits

- `repairkit_basic`
- `repairkit_advanced`
- `mechanic_toolbox`
- `mechanic_tablet`
- `cleaning_kit`

### Peças e materiais

- `engine_parts`
- `radiator_parts`
- `brake_pads`
- `clutch_kit`
- `axle_parts`
- `suspension_parts`
- `transmission_parts`
- `spare_tyre`
- `copper`
- `steel`
- `plastic`
- `scrap_metal`
- `oil_can`
- `coolant`
- `battery`

### Upgrades

- `engine_upgrade_v6`
- `engine_upgrade_v8`
- `turbo_kit`
- `ecu_stage_1`
- `ecu_stage_2`
- `nitrous_tank`

### Observação importante

A loja de peças usa os nomes dos itens definidos em `config/items.lua`. Se você alterar um nome no inventário, altere o mesmo nome no arquivo de config.

---

## 7. Configuração de jobs

As permissões principais ficam em:

- `config/panel.lua`
- `config/shops.lua`

### Jobs permitidos no HUB/F12

Edite em `config/panel.lua`:

```lua
Config.Panel.jobs = { 'mechanic', 'mechanic2' }
```

### Job de cada oficina

Edite em `config/shops.lua`:

```lua
job = 'mechanic'
```

ou

```lua
job = 'mechanic2'
```

### Grades e gestão

No `config/panel.lua`:

- `Config.PanelAccess.managementGrades`
- `Config.PanelAccess.bossGrades`

No `config/shops.lua`:

- `managementGrades = { 3, 4 }`

> Se o jogador não tiver o job correto ou a grade correta, o tablet, gestão e outras áreas sensíveis serão bloqueados no servidor.

---

## 8. Configuração das oficinas

Tudo fica em `config/shops.lua`.

Cada oficina possui:

- `label`
- `type`
- `job`
- `zones`
- `lifts`
- `locations`
- `stash`
- `basePrices`
- `services`
- `partsShop`

### Tipos de oficina

- `owned`: oficina própria, exige job/permissão.
- `self-service`: oficina pública.

### Exemplo de loja por oficina

```lua
partsShop = {
    public = false,
    jobOnly = true,
    allowTabletAccess = true,
}
```

### Oficina pública

```lua
partsShop = {
    public = true,
    jobOnly = false,
    allowTabletAccess = false,
}
```

---

## 9. Configuração da loja de peças

A loja é controlada em:

- `config/items.lua`
- `config/shops.lua`
- `server/shop.lua`
- `client/shop.lua`

### Onde configurar categorias

Em `config/items.lua`, bloco:

```lua
Config.PartsShop.categories
```

### Onde configurar itens, preços e estoque

Em `config/items.lua`, bloco:

```lua
Config.PartsShop.items
```

Cada item aceita, por exemplo:

- `label`
- `category`
- `description`
- `price`
- `stock`
- `icon`
- `workshopOnly`
- `requiresFeature`

### Pagamento da loja

Em `config/items.lua`:

```lua
currency = 'money'
```

Você pode trocar para:

```lua
currency = 'bank'
```

### Segurança da loja

A compra é validada no servidor para:

- acesso por job/permissão;
- duty quando exigido;
- quantidade máxima;
- existência do item;
- saldo do jogador;
- espaço no inventário;
- restrição de item exclusivo da oficina;
- disponibilidade do módulo nitrous.

---

## 10. Configuração do HUB/F12

Arquivo:

- `config/panel.lua`

Parâmetros principais:

- `key = 'F12'`
- `requireDuty = true`
- `allowInVehicle = false`
- `allowOutsideShop = true`
- `allowManagementOutsideShop = false`
- `tabletToggleBehavior = 'close'`

### Validação do HUB

O HUB faz verificação de:

- job permitido;
- duty;
- estado do ped;
- pausa;
- cooldown de abertura.

---

## 11. Configuração do tablet

Arquivos relevantes:

- `config/shared.lua`
- `client/tablet.lua`
- `server/shop.lua`
- `web/index.html`
- `web/app.js`
- `web/style.css`

### Requisitos do tablet

No `config/shared.lua`:

```lua
Config.Tablet = {
    command = 'tablet',
    item = 'mechanic_tablet',
    requireJob = true,
    requireDuty = true,
}
```

### Como o tablet abre

- pelo HUB/F12;
- pelo comando configurado (`/tablet`);
- pelo target no ponto `locations.tablet`, se configurado.

### O que o tablet carrega

- painel principal;
- ordens de serviço;
- funcionários;
- tabela de preços;
- cobrança;
- histórico;
- resumo da loja de peças.

---

## 12. Configuração do elevador

Arquivos:

- `config/shared.lua`
- `config/shops.lua`
- `client/duty.lua`
- `server/lifts.lua`

### Níveis do elevador

Em `config/shared.lua`:

```lua
Config.Lift.levels = {
    { label = 'Base', zOffset = 0.0 },
    { label = 'Serviço', zOffset = 1.2 },
    { label = 'Alta', zOffset = 2.35 },
}
```

### Funções disponíveis

- colocar no elevador;
- subir;
- descer;
- retirar do elevador;
- diagnosticar no elevador;
- iniciar serviço no elevador.

### Regras principais

- valida job quando a oficina é `owned`;
- valida duty se configurado;
- bloqueia subida sem veículo quando `requireVehicleToRaise = true`;
- bloqueia retirada se o elevador não estiver abaixado;
- sincroniza estado entre clientes via evento de sync.

---

## 13. Stash / estoque da oficina

Arquivos:

- `client/duty.lua`
- `server/inventory.lua`
- `config/shops.lua`

### Configuração

Defina em cada oficina:

```lua
stash = {
    slots = 50,
    weight = 100000,
}
```

O script registra o stash automaticamente via `ox_inventory:RegisterStash`.

---

## 14. Assets visuais

### Tablet e NUI

A interface utiliza:

- `web/index.html`
- `web/app.js`
- `web/style.css`

### Imagens da loja

As categorias da loja usam os ícones configurados em `config/items.lua` e temas em `web/style.css`.

Se você quiser personalizar o visual, ajuste os ícones/labels em `config/items.lua` e os gradientes/classes em `web/style.css`.

---

## 15. Configuração de permissões por grade

### Painéis do HUB

Em `config/panel.lua`:

- `basic`
- `manager`
- `boss`

### Regras padrão

- `basic`: tablet, diagnóstico, OS, cobrança e serviços rápidos.
- `manager`: tudo acima + funcionários + stash.
- `boss`: tudo acima + gestão + configurações.

---

## 16. Validação com Qbox / ox stack

### Qbox / QBX

Valide:

- o jogador recebe corretamente `job.name`;
- `job.grade.level` existe;
- `job.onduty` atualiza ao alternar duty.

### ox_inventory

Valide:

- itens cadastrados;
- peso/slots compatíveis;
- `CanCarryItem` funcionando;
- stash registrado sem erro.

### ox_target

Valide:

- pontos de duty;
- stash;
- loja;
- tablet;
- elevador.

### ox_lib

Valide:

- context menus;
- inputDialog;
- progressBar;
- skillCheck;
- notify.

### oxmysql

Valide:

- conexão ativa;
- SQL aplicado;
- consultas retornando resultados.

---

## 17. Problemas comuns e correções

### Tablet não abre

Verifique:

1. se o jogador tem job permitido em `config/panel.lua`;
2. se está em duty quando `requireDuty = true`;
3. se possui o item `mechanic_tablet`, caso exigido;
4. se `web/index.html`, `web/app.js` e `web/style.css` estão sendo carregados;
5. se o `fxmanifest.lua` inclui `ui_page` e os arquivos da NUI.

### Locale não carrega

Verifique:

1. se `Config.Locale = 'pt-br'` está correto;
2. se `locales/pt-br.json` existe;
3. se `shared/locale.lua` está sendo carregado antes dos demais scripts.

### Loja não aparece

Verifique:

1. se a oficina tem `locations.shop` em `config/shops.lua`;
2. se `Config.PartsShop.enabled = true`;
3. se a oficina possui `partsShop` configurado;
4. se o jogador cumpre job/duty quando a loja não for pública.

### Elevador não sobe

Verifique:

1. se existe veículo corretamente posicionado;
2. se a oficina tem `lifts` configurados;
3. se o jogador tem acesso ao job da oficina;
4. se o elevador já não está no nível máximo.

### Stash não abre

Verifique:

1. se `stash` está configurado na oficina;
2. se `ox_inventory` iniciou antes do recurso;
3. se o jogador está em duty quando necessário.

### F12 não funciona

Verifique:

1. `Config.Panel.key`;
2. conflito com outro recurso usando F12;
3. se o jogador atende job/duty;
4. se não está em pause menu, morto ou em estado inválido.

### Job mechanic não reconhecido

Verifique:

1. o nome do job em `config/panel.lua`;
2. o nome do job em `config/shops.lua`;
3. se o job realmente existe no seu framework.

### NUI sem foco / teclado travado

Verifique:

1. se `SetNuiFocus(true, true)` ocorre na abertura;
2. se `SetNuiFocus(false, false)` ocorre no fechamento;
3. se não há erro JS impedindo o callback `close`.

### Item não encontrado no inventário

Verifique:

1. o nome exato do item em `config/items.lua`;
2. o cadastro correspondente no `ox_inventory`;
3. se não houve divergência de maiúsculas/minúsculas.

---

## 18. Checklist final de validação

### Loja

- [ ] o target da loja abre normalmente;
- [ ] não existe mais mensagem “em breve”;
- [ ] categorias aparecem;
- [ ] imagens aparecem;
- [ ] compra por quantidade funciona;
- [ ] item entra no inventário;
- [ ] saldo é validado no servidor;
- [ ] compra indevida sem acesso é bloqueada.

### Tablet

- [ ] abre pelo F12;
- [ ] abre pelo `/tablet`;
- [ ] abre pelo ponto físico do tablet;
- [ ] fecha com ESC;
- [ ] fecha sem travar teclado;
- [ ] bloqueia não mecânicos;
- [ ] mostra OS, preços, cobrança, histórico e resumo da loja.

### Elevador

- [ ] coloca o veículo;
- [ ] sobe;
- [ ] desce;
- [ ] retira o veículo;
- [ ] diagnóstico funciona;
- [ ] iniciar serviço funciona.

### Banco e integrações

- [ ] SQL importado com sucesso;
- [ ] sem erro de `oxmysql`;
- [ ] stash registrado;
- [ ] callbacks respondendo;
- [ ] jobs reconhecidos.

---

## 19. O que substituir ou editar no seu servidor

### Você precisa editar obrigatoriamente

1. `server.cfg`
2. cadastro de itens do `ox_inventory`
3. `config/shops.lua`
4. `config/panel.lua`
5. `config/shared.lua` se quiser alterar regras de tablet/elevador
6. SQL em `sql/vrs_mechanic.sql`

### Você normalmente não precisa mexer

- `server/shop.lua`
- `server/lifts.lua`
- `client/tablet.lua`
- `web/*`

Só altere esses arquivos se quiser customização adicional.

---

## 20. Fluxo rápido de teste após instalação

1. reinicie o servidor;
2. entre com um personagem com job de mecânico válido;
3. fique em duty;
4. vá até a oficina configurada;
5. teste o F12;
6. teste o tablet;
7. teste a loja;
8. coloque um carro no elevador;
9. suba e desça o elevador;
10. faça um diagnóstico;
11. compre uma peça e confirme o item no inventário.

---

## 21. Observações finais

- O recurso foi preparado para uso com **Qbox/QBX**.
- Todas as operações críticas novas deste refinamento foram puxadas para **validação server-side**.
- A interface do tablet e a loja foram ajustadas para um fluxo mais estável e pronto para produção.
