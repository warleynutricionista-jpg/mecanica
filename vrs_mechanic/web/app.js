const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vrs_mechanic';

const state = {
    open: false,
    shopId: null,
    shopLabel: 'Oficina',
    activeTab: 'dashboard',
    data: {},
};

const statusLabels = {
    open: 'Aberta',
    progress: 'Em andamento',
    waiting: 'Aguardando peça',
    done: 'Concluída',
    delivered: 'Entregue',
};


const serviceLabels = {
    engine: 'Motor',
    body: 'Carroceria',
    oil: 'Óleo',
    radiator: 'Radiador',
    brakes: 'Freios',
    clutch: 'Embreagem',
    axle: 'Eixo',
    battery: 'Bateria',
    suspension: 'Suspensão',
    transmission: 'Transmissão',
    fuel_tank: 'Tanque de combustível',
    tyre: 'Pneu',
};

const tabTitles = {
    dashboard: 'Painel da oficina',
    orders: 'Ordens de serviço',
    shop: 'Loja e estoque',
    employees: 'Funcionários',
    pricing: 'Tabela de preços',
    billing: 'Cobrança rápida',
    logs: 'Histórico financeiro',
};

const shopThemes = {
    engine: 'theme-engine',
    brakes: 'theme-brakes',
    radiator: 'theme-radiator',
    suspension: 'theme-suspension',
    transmission: 'theme-transmission',
    clutch: 'theme-clutch',
    axle: 'theme-axle',
    electrical: 'theme-electrical',
    fluids: 'theme-fluids',
    tools: 'theme-tools',
    upgrades: 'theme-upgrades',
    nitrous: 'theme-nitrous',
};

function qs(selector) {
    return document.querySelector(selector);
}

function money(value) {
    return `R$ ${Math.floor(Number(value) || 0).toLocaleString('pt-BR')}`;
}

function formatDate(value) {
    if (!value) return 'Sem data';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return `${date.toLocaleDateString('pt-BR')} ${date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}`;
}

function nui(eventName, payload = {}) {
    return fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    })
        .then((response) => response.json())
        .catch(() => ({ success: false }));
}

function showTab(tab) {
    state.activeTab = tab;
    document.querySelectorAll('.tab-panel').forEach((panel) => {
        panel.classList.toggle('active', panel.id === `tab-${tab}`);
    });

    document.querySelectorAll('.nav-btn').forEach((button) => {
        button.classList.toggle('active', button.dataset.tab === tab);
    });

    qs('#tab-title').textContent = tabTitles[tab] || 'Painel';
}

function renderDashboard() {
    const stats = state.data.stats || {};
    qs('#stat-total-orders').textContent = stats.totalOrders || 0;
    qs('#stat-completed').textContent = stats.completedOrders || 0;
    qs('#stat-revenue').textContent = money(stats.revenue || 0);
    qs('#stat-employees').textContent = stats.employeeCount || 0;

    const summary = [
        ['Loja vinculada', state.shopLabel],
        ['Permissão atual', state.data.permissionLevel || 'basic'],
        ['Acesso à loja', state.data.canAccessShop ? 'Liberado' : 'Indisponível'],
        ['Ordens pendentes', Math.max((stats.totalOrders || 0) - (stats.completedOrders || 0), 0)],
    ];

    qs('#dashboard-summary').innerHTML = summary
        .map(([label, value]) => `<div class="summary-item"><span>${label}</span><strong>${value}</strong></div>`)
        .join('');
}

function renderOrders() {
    const filter = qs('#order-filter').value;
    const orders = (state.data.orders || []).filter((order) => !filter || order.status === filter);
    const container = qs('#orders-list');

    if (!orders.length) {
        container.innerHTML = '<div class="empty-state">Nenhuma ordem de serviço encontrada.</div>';
        return;
    }

    container.innerHTML = orders.map((order) => {
        const problems = (order.problems || []).map((item) => item.label || item.part).filter(Boolean).join(', ') || 'Sem itens detalhados';
        const nextStatusMap = { open: 'progress', progress: 'done', waiting: 'progress', done: 'delivered' };
        const nextStatus = nextStatusMap[order.status];
        const actionButton = state.data.isManager && nextStatus
            ? `<button class="secondary-btn" onclick="window.updateOrderStatus(${order.id}, '${nextStatus}')">Avançar para ${statusLabels[nextStatus]}</button>`
            : '';

        return `
            <article class="list-card">
                <div>
                    <div class="list-title">OS #${order.id} · ${order.plate || 'Sem placa'}</div>
                    <div class="list-subtitle">${order.model || 'Modelo não informado'} · ${problems}</div>
                    <div class="list-subtitle">Responsável: ${order.mechanic_name || 'N/D'} · Orçamento: ${money(order.budget || 0)}</div>
                </div>
                <div class="list-actions">
                    <span class="badge status-${order.status || 'open'}">${statusLabels[order.status] || order.status}</span>
                    ${actionButton}
                </div>
            </article>
        `;
    }).join('');
}

function renderShop() {
    const catalog = state.data.shopCatalog;
    const categoriesContainer = qs('#shop-categories');
    const previewContainer = qs('#shop-items-preview');
    const openButton = qs('#shop-open-btn');

    if (!catalog) {
        qs('#shop-summary-text').textContent = 'Loja operacional indisponível para o seu perfil atual.';
        categoriesContainer.innerHTML = '<div class="empty-state">Sem catálogo disponível.</div>';
        previewContainer.innerHTML = '';
        openButton.disabled = true;
        return;
    }

    openButton.disabled = false;
    qs('#shop-summary-text').textContent = `${catalog.public ? 'Loja pública' : 'Loja da oficina'} · pagamento via ${catalog.currencyLabel}.`;

    categoriesContainer.innerHTML = (catalog.categories || []).map((category) => `
        <article class="shop-card ${shopThemes[category.id] || 'theme-generic'}" data-category="${category.id}">
            <div class="shop-card-media">
                <span class="shop-card-icon">${category.icon || '🧩'}</span>
                <small>${category.label}</small>
            </div>
            <div class="shop-card-body">
                <strong>${category.icon || '🧩'} ${category.label}</strong>
                <p>${category.description || 'Sem descrição.'}</p>
                <small>${category.count || 0} item(ns) configurado(s)</small>
            </div>
        </article>
    `).join('');

    const previewItems = (catalog.items || []).slice(0, 6);
    previewContainer.innerHTML = previewItems.map((item) => `
        <article class="list-card compact">
            <div>
                <div class="list-title">${item.icon || '🧩'} ${item.label}</div>
                <div class="list-subtitle">${item.description || 'Sem descrição.'}</div>
            </div>
            <div class="list-actions vertical">
                <span class="badge neutral">${money(item.price)}</span>
                <button class="secondary-btn" onclick="window.openPartsShop('${item.category}')">Comprar</button>
            </div>
        </article>
    `).join('');

    document.querySelectorAll('.shop-card').forEach((card) => {
        card.addEventListener('click', () => window.openPartsShop(card.dataset.category));
    });
}

function renderEmployees() {
    const employees = state.data.employees || [];
    const container = qs('#employees-list');
    const hireButton = qs('#hire-employee-btn');
    const employeeTarget = qs('#employee-target');
    if (hireButton) hireButton.disabled = !state.data.isManager;
    if (employeeTarget) employeeTarget.disabled = !state.data.isManager;

    if (!employees.length) {
        container.innerHTML = '<div class="empty-state">Nenhum funcionário vinculado à oficina.</div>';
        return;
    }

    container.innerHTML = employees.map((employee) => `
        <article class="list-card">
            <div>
                <div class="list-title">${employee.online ? '🟢' : '⚪'} ${employee.name}</div>
                <div class="list-subtitle">Grade: ${employee.grade} · Contratado em ${formatDate(employee.hiredAt)}</div>
            </div>
            <div class="list-actions">
                ${state.data.isManager ? `<button class="secondary-btn danger" onclick="window.fireEmployee('${employee.citizenid}')">Demitir</button>` : ''}
            </div>
        </article>
    `).join('');
}

function renderPricing() {
    const prices = state.data.prices || {};
    const container = qs('#pricing-list');
    const entries = Object.entries(prices);

    if (!entries.length) {
        container.innerHTML = '<div class="empty-state">Nenhum preço configurado.</div>';
        return;
    }

    container.innerHTML = entries.map(([service, price]) => `
        <div class="price-row">
            <div>
                <strong>${serviceLabels[service] || service}</strong>
                <p class="muted">Valor operacional configurado para este serviço.</p>
            </div>
            <div class="inline-field compact">
                <input class="field compact" type="number" id="price-${service}" value="${price}" ${state.data.isManager ? '' : 'disabled'}>
                ${state.data.isManager ? `<button class="secondary-btn" onclick="window.savePrice('${service}')">Salvar</button>` : ''}
            </div>
        </div>
    `).join('');
}

function renderLogs() {
    const logs = state.data.billingHistory || [];
    const container = qs('#logs-list');

    if (!logs.length) {
        container.innerHTML = '<div class="empty-state">Nenhum registro financeiro encontrado.</div>';
        return;
    }

    container.innerHTML = logs.map((log) => `
        <article class="list-card">
            <div>
                <div class="list-title">${log.service_type || 'Serviço'} · ${money(log.amount || 0)}</div>
                <div class="list-subtitle">${log.mechanic_name || 'Sem mecânico'} ${log.customer_name ? `· Cliente: ${log.customer_name}` : ''}</div>
                <div class="list-subtitle">${formatDate(log.created_at)}</div>
            </div>
        </article>
    `).join('');
}

function populateNearbyPlayers(players) {
    const billingSelect = qs('#billing-target');
    const employeeSelect = qs('#employee-target');
    billingSelect.innerHTML = '';
    if (employeeSelect) employeeSelect.innerHTML = '';

    if (!players.length) {
        billingSelect.innerHTML = '<option value="">Nenhum jogador próximo</option>';
        if (employeeSelect) employeeSelect.innerHTML = '<option value="">Nenhum candidato próximo</option>';
        return;
    }

    players.forEach((player) => {
        const billingOption = document.createElement('option');
        billingOption.value = player.id;
        billingOption.textContent = `${player.name} (ID ${player.id})`;
        billingSelect.appendChild(billingOption);

        if (employeeSelect) {
            const employeeOption = document.createElement('option');
            employeeOption.value = player.id;
            employeeOption.textContent = `${player.name} (ID ${player.id})`;
            employeeSelect.appendChild(employeeOption);
        }
    });
}

function renderAll() {
    qs('#shop-name').textContent = state.shopLabel;
    qs('#shop-mode').textContent = state.data.canAccessShop ? 'Painel operacional e comercial' : 'Painel operacional';
    qs('#player-name').textContent = state.data.player?.name || 'Operador';
    qs('#player-role').textContent = `${state.data.player?.gradeName || 'Equipe'} · ${state.data.player?.onduty ? 'Em serviço' : 'Fora de serviço'}`;
    renderDashboard();
    renderOrders();
    renderShop();
    renderEmployees();
    renderPricing();
    renderLogs();
}

window.updateOrderStatus = async (orderId, status) => {
    const result = await nui('updateOrderStatus', { orderId, status });
    if (result?.success) await nui('refreshTablet');
};

window.savePrice = async (service) => {
    const value = Number(qs(`#price-${service}`).value);
    if (Number.isNaN(value) || value < 0) return;
    await nui('updatePrice', { service, price: value });
    await nui('refreshTablet');
};

window.fireEmployee = async (citizenid) => {
    await nui('fireEmployee', { citizenid });
    await nui('refreshTablet');
};

window.hireEmployee = async () => {
    const targetId = Number(qs('#employee-target')?.value);
    if (!targetId) return;
    await nui('hireEmployee', { targetId });
    await nui('refreshTablet');
};

window.openPartsShop = async (category) => {
    await nui('openPartsShop', { shopId: state.shopId, category });
};

window.addEventListener('message', async (event) => {
    const message = event.data || {};
    if (message.action === 'open') {
        state.open = true;
        state.shopId = message.shopId;
        state.shopLabel = message.shopLabel || 'Oficina';
        state.data = message.data || {};
        qs('#tablet').classList.remove('hidden');
        showTab('dashboard');
        renderAll();
        const players = await nui('getNearbyPlayers');
        populateNearbyPlayers(players || []);
    }

    if (message.action === 'hydrate') {
        state.data = message.data || {};
        renderAll();
        const players = await nui('getNearbyPlayers');
        populateNearbyPlayers(players || []);
    }

    if (message.action === 'close') {
        state.open = false;
        qs('#tablet').classList.add('hidden');
    }

    if (message.action === 'focusTab' && message.tab) {
        showTab(message.tab);
    }
});

document.querySelectorAll('.nav-btn').forEach((button) => {
    button.addEventListener('click', () => showTab(button.dataset.tab));
});

document.querySelectorAll('[data-open-tab]').forEach((button) => {
    button.addEventListener('click', () => showTab(button.dataset.openTab));
});

qs('#close-btn').addEventListener('click', () => nui('close'));
qs('#refresh-btn').addEventListener('click', () => nui('refreshTablet'));
qs('#reload-players-btn').addEventListener('click', async () => populateNearbyPlayers(await nui('getNearbyPlayers') || []));
qs('#hire-employee-btn')?.addEventListener('click', () => window.hireEmployee());
qs('#shop-open-btn').addEventListener('click', () => window.openPartsShop());
qs('#order-filter').addEventListener('change', renderOrders);
qs('#send-bill-btn').addEventListener('click', async () => {
    const targetId = Number(qs('#billing-target').value);
    const amount = Number(qs('#billing-amount').value);
    const description = qs('#billing-desc').value.trim();
    if (!targetId || !amount) return;
    await nui('sendBill', { targetId, amount, description: description || 'Serviço mecânico' });
    qs('#billing-amount').value = '';
    qs('#billing-desc').value = '';
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        if (liftState.open) {
            nui('closeLiftPanel');
        } else if (state.open) {
            nui('close');
        }
    }
});

/* ============================================ */
/* MINI PAINEL DO ELEVADOR                     */
/* ============================================ */

const liftState = {
    open: false,
    height: 0,
    maxHeight: 2.1,
    minHeight: 0,
    hasVehicle: false,
    vehiclePlate: null,
    moving: false,
    direction: null,
    heightLabel: 'Base',
    liftIndex: 1,
    shopLabel: 'Oficina',
    levels: [],
};

function updateLiftUI() {
    const panel = qs('#lift-panel');
    if (!liftState.open) {
        panel.classList.add('hidden');
        return;
    }
    panel.classList.remove('hidden');

    // Título
    qs('#lift-title').textContent = `ELEVADOR #${liftState.liftIndex}`;
    qs('#lift-shop-label').textContent = liftState.shopLabel;

    // LED
    const led = qs('#lift-led');
    led.className = 'lift-led';
    if (liftState.moving) {
        led.classList.add('moving');
    } else if (!liftState.hasVehicle) {
        led.classList.add('empty');
    }

    // Status
    qs('#lift-vehicle-status').textContent = liftState.hasVehicle
        ? (liftState.vehiclePlate || 'No elevador')
        : 'Sem veículo';

    qs('#lift-height-display').textContent = `${liftState.height.toFixed(2)}m`;

    // Barra de altura
    const range = liftState.maxHeight - liftState.minHeight;
    const percent = range > 0 ? ((liftState.height - liftState.minHeight) / range * 100) : 0;
    qs('#lift-height-fill').style.width = `${Math.min(percent, 100)}%`;
    qs('#lift-height-label').textContent = liftState.heightLabel;

    // Botões ativos
    const btnUp = qs('#lift-btn-up');
    const btnDown = qs('#lift-btn-down');
    const btnStop = qs('#lift-btn-stop');

    btnUp.classList.toggle('active', liftState.moving && liftState.direction === 'up');
    btnDown.classList.toggle('active', liftState.moving && liftState.direction === 'down');
    btnStop.classList.toggle('active', false);

    // Indicador de movimento
    const indicator = qs('#lift-movement-indicator');
    if (liftState.moving) {
        indicator.classList.remove('hidden');
        qs('#lift-movement-text').textContent = liftState.direction === 'up'
            ? 'Elevador subindo...'
            : 'Elevador descendo...';
    } else {
        indicator.classList.add('hidden');
    }
}

function renderLiftPresets() {
    const grid = qs('#lift-presets-grid');
    if (!liftState.levels || !liftState.levels.length) {
        grid.innerHTML = '';
        return;
    }

    grid.innerHTML = liftState.levels.map((level) => {
        const isCurrent = Math.abs(liftState.height - level.zOffset) < 0.08;
        return `<button class="lift-preset-btn ${isCurrent ? 'current' : ''}"
                    onclick="window.liftPreset(${level.zOffset})"
                    title="${level.label} (${level.zOffset.toFixed(2)}m)">
                    ${level.label}
                </button>`;
    }).join('');
}

window.liftPreset = (height) => {
    nui('liftAction', { action: 'preset', height });
};

// Lift panel event listeners
qs('#lift-btn-up').addEventListener('click', () => nui('liftAction', { action: 'up' }));
qs('#lift-btn-down').addEventListener('click', () => nui('liftAction', { action: 'down' }));
qs('#lift-btn-stop').addEventListener('click', () => nui('liftAction', { action: 'stop' }));
qs('#lift-close-btn').addEventListener('click', () => nui('closeLiftPanel'));

// Handle lift panel messages
window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'openLiftPanel') {
        liftState.open = true;
        liftState.height = msg.height || 0;
        liftState.maxHeight = msg.maxHeight || 2.1;
        liftState.minHeight = msg.minHeight || 0;
        liftState.hasVehicle = msg.hasVehicle || false;
        liftState.vehiclePlate = msg.vehiclePlate;
        liftState.moving = msg.moving || false;
        liftState.direction = msg.direction;
        liftState.heightLabel = msg.heightLabel || 'Base';
        liftState.liftIndex = msg.liftIndex || 1;
        liftState.shopLabel = msg.shopLabel || 'Oficina';
        liftState.levels = msg.levels || [];
        updateLiftUI();
        renderLiftPresets();
    }

    if (msg.action === 'updateLiftPanel') {
        liftState.height = msg.height !== undefined ? msg.height : liftState.height;
        liftState.hasVehicle = msg.hasVehicle !== undefined ? msg.hasVehicle : liftState.hasVehicle;
        liftState.vehiclePlate = msg.vehiclePlate !== undefined ? msg.vehiclePlate : liftState.vehiclePlate;
        liftState.moving = msg.moving !== undefined ? msg.moving : liftState.moving;
        liftState.direction = msg.direction !== undefined ? msg.direction : liftState.direction;
        liftState.heightLabel = msg.heightLabel !== undefined ? msg.heightLabel : liftState.heightLabel;
        updateLiftUI();
        renderLiftPresets();
    }

    if (msg.action === 'closeLiftPanel') {
        liftState.open = false;
        updateLiftUI();
    }
});
