local Locale = {}

Locale.UI = {
    -- Geral
    confirm = 'Confirmar',
    cancel = 'Cancelar',
    close = 'Fechar',
    back = 'Voltar',
    save = 'Salvar',
    delete = 'Excluir',
    edit = 'Editar',
    create = 'Criar',
    search = 'Buscar',
    loading = 'Carregando...',
    none = 'Nenhum',
    yes = 'Sim',
    no = 'Não',

    -- Partes do veículo
    parts = {
        engine       = 'Motor',
        body         = 'Carroceria',
        oil          = 'Óleo',
        radiator     = 'Radiador',
        brakes       = 'Freios',
        clutch       = 'Embreagem',
        axle         = 'Eixo',
        battery      = 'Bateria',
        suspension   = 'Suspensão',
        transmission = 'Transmissão',
        fuel_tank    = 'Tanque de Combustível',
        tyre         = 'Pneu',
    },

    -- Status
    status = {
        good     = 'Bom',
        warning  = 'Atenção',
        critical = 'Crítico',
        broken   = 'Quebrado',
    },

    -- Diagnóstico
    diagnostic = {
        title = 'Diagnóstico do Veículo',
        subtitle = 'Relatório completo de condição',
        plate = 'Placa',
        model = 'Modelo',
        mileage = 'Quilometragem',
        overall = 'Estado Geral',
        part_status = '%s: %d%%',
        needs_replacement = 'Necessita troca',
        needs_repair = 'Necessita reparo',
        ok = 'Em bom estado',
        open_repair = 'Abrir menu de reparos',
        create_work_order = 'Criar ordem de serviço',
    },

    -- Reparos
    repair = {
        title = 'Reparos',
        subtitle = 'Selecione o reparo desejado',
        repairing = 'Reparando %s...',
        success = '%s reparado(a) com sucesso!',
        failed = 'Reparo cancelado.',
        no_items = 'Você não tem os materiais necessários.',
        not_in_zone = 'Você precisa estar em uma oficina para isso.',
        not_on_duty = 'Você não está em serviço.',
        not_mechanic = 'Você não é mecânico.',
        vehicle_too_far = 'Veículo muito longe.',
        no_vehicle = 'Nenhum veículo próximo.',
        already_full = '%s já está em perfeito estado.',
        street_repair = 'Reparo de Rua',
        street_repair_desc = 'Reparo emergencial limitado',
        shop_repair = 'Reparo de Oficina',
        shop_repair_desc = 'Reparo profissional completo',
        materials_needed = 'Materiais: %s',
        max_street = '(máximo %d%%)',
        cooldown = 'Aguarde antes de reparar novamente.',
        skill_failed = 'Você falhou no procedimento.',
    },

    -- Oficina
    shop = {
        title = 'Oficina - %s',
        services = 'Serviços',
        diagnostic = 'Diagnóstico',
        diagnostic_desc = 'Verificar estado do veículo',
        repair = 'Reparos',
        repair_desc = 'Reparar subsistemas do veículo',
        oil_change = 'Troca de Óleo',
        oil_change_desc = 'Trocar óleo do motor',
        tyre_change = 'Troca de Pneus',
        tyre_change_desc = 'Trocar pneus do veículo',
        upgrades = 'Upgrades',
        upgrades_desc = 'Instalar melhorias no veículo',
        wash = 'Lavagem',
        wash_desc = 'Lavar o veículo',
        lift_place = 'Colocar no Elevador',
        lift_remove = 'Retirar do Elevador',
        lift_occupied = 'Elevador ocupado.',
        lift_empty = 'Elevador vazio.',
        no_vehicle_near = 'Nenhum veículo próximo ao elevador.',
    },

    -- Duty
    duty = {
        on = 'Você entrou em serviço.',
        off = 'Você saiu de serviço.',
        toggle = 'Alternar Serviço',
        toggle_desc = 'Entrar/sair de serviço',
    },

    -- Cobrança
    billing = {
        title = 'Cobrança',
        send = 'Enviar Cobrança',
        send_desc = 'Cobrar jogador próximo',
        amount = 'Valor',
        description = 'Descrição',
        success = 'Cobrança de R$ %s enviada!',
        received = 'Você recebeu uma cobrança de R$ %s de %s.',
        paid = 'Cobrança paga com sucesso.',
        insufficient = 'Dinheiro insuficiente.',
        invalid_amount = 'Valor inválido.',
        no_player = 'Nenhum jogador próximo.',
        too_far = 'Jogador muito longe.',
    },

    -- Tablet
    tablet = {
        title = 'Tablet - %s',
        dashboard = 'Painel',
        work_orders = 'Ordens de Serviço',
        employees = 'Funcionários',
        pricing = 'Preços',
        inventory = 'Estoque',
        logs = 'Histórico',
        settings = 'Configurações',
    },

    -- Ordens de serviço
    work_order = {
        title = 'Ordem de Serviço',
        new = 'Nova OS',
        id = 'OS #%d',
        plate = 'Placa',
        model = 'Modelo',
        owner = 'Proprietário',
        mechanic = 'Mecânico',
        problems = 'Problemas',
        materials = 'Materiais',
        budget = 'Orçamento',
        notes = 'Observações',
        status_open = 'Aberta',
        status_progress = 'Em Andamento',
        status_waiting = 'Aguardando Peça',
        status_done = 'Concluída',
        status_delivered = 'Entregue',
        created = 'Criada em',
        updated = 'Atualizada em',
        no_orders = 'Nenhuma ordem de serviço.',
    },

    -- Upgrades
    upgrade = {
        title = 'Upgrades',
        subtitle = 'Melhorias disponíveis',
        installing = 'Instalando %s...',
        success = '%s instalado com sucesso!',
        failed = 'Instalação cancelada.',
        engine_v6 = 'Motor V6',
        engine_v8 = 'Motor V8',
        turbo = 'Turbo',
        ecu_stage1 = 'ECU Estágio 1',
        ecu_stage2 = 'ECU Estágio 2',
        nitrous = 'Nitro',
        brakes_sport = 'Freios Esportivos',
        suspension_sport = 'Suspensão Esportiva',
    },

    -- Stash
    stash = {
        title = 'Estoque - %s',
    },

    -- Management
    management = {
        title = 'Gerenciamento - %s',
        employees = 'Funcionários',
        hire = 'Contratar',
        fire = 'Demitir',
        promote = 'Promover',
        demote = 'Rebaixar',
        online = 'Online',
        offline = 'Offline',
        pricing = 'Preços dos Serviços',
        price_updated = 'Preço atualizado.',
        revenue = 'Faturamento',
        total_orders = 'Total de OS',
        completed_orders = 'OS Concluídas',
    },

    -- Target
    target = {
        lift = '[E] Elevador',
        duty_point = '[E] Serviço',
        stash_point = '[E] Estoque',
        shop_point = '[E] Loja',
        vehicle_interact = 'Interagir com Veículo',
    },

    -- Notificações gerais
    notify = {
        oil_low = 'Nível de óleo baixo!',
        oil_critical = 'ATENÇÃO: Óleo crítico! Motor em risco!',
        engine_overheat = 'Motor superaquecendo!',
        battery_fail = 'Bateria fraca - falha na ignição.',
        brakes_worn = 'Freios desgastados!',
        no_permission = 'Você não tem permissão para isso.',
        action_cooldown = 'Aguarde antes de fazer isso novamente.',
    },
}

return Locale
