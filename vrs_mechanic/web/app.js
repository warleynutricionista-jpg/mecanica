// ============================================================
// VRS_MECHANIC - TABLET APP (NUI)
// ============================================================

let currentData = {};
let isManager = false;

const partLabels = {
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
    fuel_tank: 'Tanque',
    tyre: 'Pneu',
};

const statusLabels = {
    open: 'Aberta',
    progress: 'Em Andamento',
    waiting: 'Aguardando Peça',
    done: 'Concluída',
    delivered: 'Entregue',
};

// ============================================================
// NUI MESSAGE HANDLER
// ============================================================

window.addEventListener('message', function (event) {
    const msg = event.data;

    switch (msg.action) {
        case 'open':
            document.getElementById('tablet').classList.remove('hidden');
            document.getElementById('shop-name').textContent = msg.shopLabel || 'Oficina';
            break;

        case 'close':
            document.getElementById('tablet').classList.add('hidden');
            break;

        case 'loadData':
            currentData = msg.data || {};
            isManager = msg.data.isManager || false;

            if (currentData.player) {
                document.getElementById('player-name').textContent = currentData.player.name;
            }

            updateDashboard();
            loadOrders();
            loadEmployees();
            loadPricing();
            break;
    }
});

// ============================================================
// TABS
// ============================================================

function switchTab(tabName) {
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));

    const panel = document.getElementById('tab-' + tabName);
    const btn = document.querySelector('[data-tab="' + tabName + '"]');
    if (panel) panel.classList.add('active');
    if (btn) btn.classList.add('active');

    // Load data on tab switch
    if (tabName === 'orders') loadOrders();
    if (tabName === 'employees') loadEmployees();
    if (tabName === 'pricing') loadPricing();
    if (tabName === 'billing') loadNearbyPlayers();
    if (tabName === 'logs') loadBillingHistory();
}

// ============================================================
// DASHBOARD
// ============================================================

function updateDashboard() {
    const stats = currentData.stats || {};
    document.getElementById('stat-total-orders').textContent = stats.totalOrders || 0;
    document.getElementById('stat-completed').textContent = stats.completedOrders || 0;
    document.getElementById('stat-revenue').textContent = 'R$ ' + formatMoney(stats.revenue || 0);
    document.getElementById('stat-employees').textContent = stats.employeeCount || 0;
}

// ============================================================
// ORDERS
// ============================================================

function loadOrders() {
    const filter = document.getElementById('order-filter');
    const status = filter ? filter.value : '';

    fetchNUI('getWorkOrders', { status: status }).then(orders => {
        const container = document.getElementById('orders-list');
        if (!orders || orders.length === 0) {
            container.innerHTML = '<p class="empty-msg">Nenhuma ordem de serviço.</p>';
            return;
        }

        container.innerHTML = orders.map(order => {
            const statusClass = 'status-' + (order.status || 'open');
            const statusLabel = statusLabels[order.status] || order.status;
            const problems = order.problems || [];
            const problemsText = problems.map(p => p.label || p.part).join(', ') || 'N/A';

            return '<div class="list-card">' +
                '<div class="card-info">' +
                '<div class="card-title">OS #' + order.id + ' - ' + order.plate + '</div>' +
                '<div class="card-subtitle">' + problemsText + ' | R$ ' + formatMoney(order.budget || 0) + '</div>' +
                '<div class="card-subtitle">Mecânico: ' + (order.mechanic_name || 'N/A') + '</div>' +
                '</div>' +
                '<div class="card-actions">' +
                '<span class="status-badge ' + statusClass + '">' + statusLabel + '</span>' +
                (isManager ? buildOrderActions(order) : '') +
                '</div>' +
                '</div>';
        }).join('');
    });
}

function buildOrderActions(order) {
    const nextStatus = {
        open: 'progress',
        progress: 'done',
        waiting: 'progress',
        done: 'delivered',
    };

    const next = nextStatus[order.status];
    if (!next) return '';

    const nextLabel = statusLabels[next] || next;
    return '<button class="btn btn-sm btn-success" onclick="updateOrderStatus(' +
        order.id + ', \'' + next + '\')">' +
        '<i class="fas fa-arrow-right"></i> ' + nextLabel + '</button>';
}

function updateOrderStatus(orderId, status) {
    fetchNUI('updateOrderStatus', { orderId: orderId, status: status }).then(result => {
        if (result && result.success) {
            loadOrders();
        }
    });
}

// ============================================================
// EMPLOYEES
// ============================================================

function loadEmployees() {
    fetchNUI('getEmployees', {}).then(employees => {
        const container = document.getElementById('employees-list');
        if (!employees || employees.length === 0) {
            container.innerHTML = '<p class="empty-msg">Nenhum funcionário cadastrado.</p>';
            return;
        }

        container.innerHTML = employees.map(emp => {
            const onlineClass = emp.online ? 'on' : 'off';
            const onlineText = emp.online ? 'Online' : 'Offline';

            return '<div class="list-card">' +
                '<div class="card-info">' +
                '<div class="card-title">' +
                '<span class="online-dot ' + onlineClass + '"></span>' +
                emp.name + '</div>' +
                '<div class="card-subtitle">Cargo: ' + emp.grade + ' | ' + onlineText + '</div>' +
                '</div>' +
                (isManager ? '<div class="card-actions">' +
                    '<button class="btn btn-sm btn-danger" onclick="fireEmployee(\'' + emp.citizenid + '\')">' +
                    '<i class="fas fa-user-minus"></i></button>' +
                    '</div>' : '') +
                '</div>';
        }).join('');
    });
}

function fireEmployee(citizenid) {
    if (!confirm('Tem certeza que deseja demitir este funcionário?')) return;
    fetchNUI('fireEmployee', { citizenid: citizenid }).then(result => {
        if (result && result.success) {
            loadEmployees();
        }
    });
}

// ============================================================
// PRICING
// ============================================================

function loadPricing() {
    fetchNUI('getPrices', {}).then(prices => {
        const container = document.getElementById('pricing-list');
        if (!prices || Object.keys(prices).length === 0) {
            container.innerHTML = '<p class="empty-msg">Nenhum preço configurado.</p>';
            return;
        }

        container.innerHTML = Object.entries(prices).map(([service, price]) => {
            const label = partLabels[service] || service;
            return '<div class="price-row">' +
                '<span class="price-label">' + label + '</span>' +
                '<div style="display:flex;gap:6px;align-items:center">' +
                '<span>R$</span>' +
                '<input type="number" class="price-input" value="' + price + '" ' +
                'id="price-' + service + '" ' +
                (isManager ? '' : 'disabled') + '>' +
                (isManager ? '<button class="btn btn-sm btn-success" onclick="savePrice(\'' +
                    service + '\')"><i class="fas fa-save"></i></button>' : '') +
                '</div></div>';
        }).join('');
    });
}

function savePrice(service) {
    const input = document.getElementById('price-' + service);
    if (!input) return;
    const price = parseFloat(input.value);
    if (isNaN(price) || price < 0) return;

    fetchNUI('updatePrice', { service: service, price: price }).then(result => {
        if (result && result.success) {
            input.style.borderColor = '#4caf50';
            setTimeout(() => { input.style.borderColor = ''; }, 1500);
        }
    });
}

// ============================================================
// BILLING
// ============================================================

function loadNearbyPlayers() {
    fetchNUI('getNearbyPlayers', {}).then(players => {
        const select = document.getElementById('billing-target');
        select.innerHTML = '';

        if (!players || players.length === 0) {
            select.innerHTML = '<option value="">Nenhum jogador próximo</option>';
            return;
        }

        players.forEach(p => {
            const opt = document.createElement('option');
            opt.value = p.id;
            opt.textContent = p.name + ' (ID: ' + p.id + ')';
            select.appendChild(opt);
        });
    });
}

function sendBill() {
    const targetId = document.getElementById('billing-target').value;
    const amount = parseFloat(document.getElementById('billing-amount').value);
    const desc = document.getElementById('billing-desc').value;

    if (!targetId || isNaN(amount) || amount <= 0) return;

    fetchNUI('sendBill', {
        targetId: parseInt(targetId),
        amount: amount,
        description: desc || 'Serviço mecânico',
    }).then(result => {
        if (result && result.success) {
            document.getElementById('billing-amount').value = '';
            document.getElementById('billing-desc').value = '';
        }
    });
}

// ============================================================
// LOGS
// ============================================================

function loadBillingHistory() {
    fetchNUI('getBillingHistory', {}).then(logs => {
        const container = document.getElementById('logs-list');
        if (!logs || logs.length === 0) {
            container.innerHTML = '<p class="empty-msg">Nenhum registro.</p>';
            return;
        }

        container.innerHTML = logs.map(log => {
            return '<div class="list-card">' +
                '<div class="card-info">' +
                '<div class="card-title">' + (log.service_type || 'N/A') +
                ' - R$ ' + formatMoney(log.amount || 0) + '</div>' +
                '<div class="card-subtitle">' +
                'Mecânico: ' + (log.mechanic_name || 'N/A') +
                (log.customer_name ? ' | Cliente: ' + log.customer_name : '') +
                '</div>' +
                '<div class="card-subtitle">' + formatDate(log.created_at) + '</div>' +
                '</div></div>';
        }).join('');
    });
}

// ============================================================
// UTILITIES
// ============================================================

function fetchNUI(event, data) {
    return fetch('https://vrs_mechanic/' + event, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).then(resp => resp.json()).catch(() => null);
}

function closeTablet() {
    fetchNUI('close', {});
    document.getElementById('tablet').classList.add('hidden');
}

function formatMoney(amount) {
    return Math.floor(amount).toLocaleString('pt-BR');
}

function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    try {
        const d = new Date(dateStr);
        return d.toLocaleDateString('pt-BR') + ' ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    } catch {
        return dateStr;
    }
}

// Close on ESC
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
        closeTablet();
    }
});
