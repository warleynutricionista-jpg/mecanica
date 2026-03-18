# Diagnóstico do erro de parsing do `jg-mechanic`

## Causa raiz

O erro `syntax error near '<\1>'` **não está sendo causado por UTF-16, BOM, CRLF ou caracteres invisíveis no início dos arquivos**.

A auditoria dos arquivos mostrou que **40 arquivos `.lua` do resource não estão em texto Lua puro**: eles começam com a assinatura binária `FXAP`, que identifica arquivos **protegidos pelo FiveM Asset Escrow**.

Em outras palavras:

- esses arquivos **não são fonte Lua legível**;
- eles **não devem ser convertidos para UTF-8**;
- eles **não devem ser editados como texto**;
- quando o FiveM tenta tratá-los como Lua puro, o parser quebra logo no byte inicial e gera erros como `syntax error near '<\1>'`.

## O que foi validado

A auditoria confirmou que:

- `fxmanifest.lua` está em texto puro e os globs resolvem corretamente os caminhos do resource;
- os arquivos Lua em texto puro do resource estão em UTF-8 legível;
- não foram encontrados arquivos `.lua` em UTF-16;
- não foram encontrados arquivos `.lua` substituídos por HTML/XML/JSON puro;
- os arquivos que falham são blobs `FXAP` de escrow, não arquivos de texto corrompidos.

## Arquivos afetados

Os arquivos abaixo estão em formato `FXAP` protegido:

- `shared/constants.lua`
- `shared/main.lua`
- `client/cl-admin.lua`
- `client/cl-cameras.lua`
- `client/cl-carlift.lua`
- `client/cl-dyno.lua`
- `client/cl-employees.lua`
- `client/cl-fixing.lua`
- `client/cl-invoice.lua`
- `client/cl-lightcontroller.lua`
- `client/cl-main.lua`
- `client/cl-management.lua`
- `client/cl-minigames.lua`
- `client/cl-mods.lua`
- `client/cl-nitrous.lua`
- `client/cl-orders.lua`
- `client/cl-servicing.lua`
- `client/cl-shops-stashes.lua`
- `client/cl-stancer.lua`
- `client/cl-tablet.lua`
- `client/cl-tuning.lua`
- `server/sv-admin.lua`
- `server/sv-carlift.lua`
- `server/sv-dyno.lua`
- `server/sv-employees.lua`
- `server/sv-fixing.lua`
- `server/sv-initsql.lua`
- `server/sv-invoice.lua`
- `server/sv-locations.lua`
- `server/sv-main.lua`
- `server/sv-management.lua`
- `server/sv-mods.lua`
- `server/sv-nitrous.lua`
- `server/sv-orders.lua`
- `server/sv-servicing.lua`
- `server/sv-shops-stashes.lua`
- `server/sv-tablet.lua`
- `server/sv-tuning.lua`
- `server/sv-vehicleprops.lua`
- `server/sv-version-check.lua`

## Correção correta

Como os arquivos protegidos não podem ser reconstruídos a partir dos blobs `FXAP`, a correção real é restaurar o pacote oficial do escrow e garantir que o ambiente consiga executá-lo.

### Faça isto no servidor

1. **Baixe novamente o `jg-mechanic` pela entrega oficial do vendedor / Keymaster / Tebex**.
2. **Substitua a pasta atual inteira do resource** por uma cópia oficial íntegra.
3. **Não renomeie, converta, “salve novamente” nem abra os blobs `FXAP` em editores que alterem encoding**.
4. **Atualize os artifacts do FXServer** para uma build atual que suporte Asset Escrow normalmente.
5. **Confirme que a licença/entitlement do asset está vinculada à conta/servidor correto**.
6. **Garanta que o resource está sendo iniciado pelo nome correto `jg-mechanic`** e sem ter sido reempacotado por ferramentas que removam arquivos ocultos ou metadata da entrega original.

## Compatibilidade básica com Qbox/QBX

A base textual restante do resource mostra que o script já foi configurado para Qbox/QBX:

- `Config.Framework = "Qbox"`;
- dependência de `qbx_core` no `fxmanifest.lua`;
- bridge específica em `framework/qbx/cl-qbx.lua`.

Ou seja, o erro de parsing atual **acontece antes de qualquer incompatibilidade funcional com Qbox**: primeiro é preciso restaurar a execução normal dos arquivos escrowados.

## Ferramenta incluída no repositório

Foi adicionada a ferramenta local `tools/audit_jg_mechanic.py`, que gera um relatório reproduzível para confirmar:

- quais `.lua` são blobs `FXAP`;
- quais arquivos estão em texto puro;
- se existe BOM/UTF-16/NUL-byte em arquivos legíveis;
- se os globs do `fxmanifest.lua` continuam apontando para arquivos existentes.

Uso:

```bash
python3 tools/audit_jg_mechanic.py
python3 tools/audit_jg_mechanic.py --json
```

## Conclusão objetiva

Se o seu log continua mostrando `syntax error near '<\1>'` nos arquivos acima, o problema não é de encoding de texto: **o servidor está tentando interpretar blobs `FXAP` do Asset Escrow como Lua normal**.

A forma correta de resolver é **restaurar a distribuição oficial do asset e validar entitlement/artifacts**, não editar os arquivos binários protegidos.
