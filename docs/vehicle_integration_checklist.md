# Vehicle Integration Checklist

## qbx_lockpick
- [ ] lockpick em veículo normal
- [ ] lockpick em veículo em reparo
- [ ] lockpick em veículo no elevador
- [ ] hotwire respeitando bloqueio mecânico

## qbx_vehiclefailure
- [ ] dano normal sem disputa com vrs_mechanic
- [ ] repair kit fora da oficina
- [ ] repair kit bloqueado em lift/serviço
- [ ] engine health sem oscillation entre sistemas

## qbx_vehiclepush
- [ ] empurrar veículo normal
- [ ] bloquear push em lift
- [ ] bloquear push em serviço
- [ ] evitar spam de evento

## qbx_vehicleradio
- [ ] rádio com ignição normal
- [ ] rádio bloqueado sem energia
- [ ] rádio bloqueado durante serviço quando aplicável
- [ ] rádio não reativa indevidamente estados do veículo

## qbx_vehicles
- [ ] guardar veículo normal
- [ ] bloquear guardar veículo em lift/serviço
- [ ] criar/restaurar snapshot mecânico
- [ ] remover vehicle status ao deletar veículo

## combinados
- [ ] falha mecânica + lockpick
- [ ] lift + push
- [ ] oficina + rádio + persistência
- [ ] restart do resource
- [ ] restart do servidor
- [ ] streaming in/out
