const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_customs';
const app = document.getElementById('app');
const categoriesEl = document.getElementById('categories');
const optionsEl = document.getElementById('options');
const choicesEl = document.getElementById('choices');
const emptyOptionsEl = document.getElementById('empty-options');
const emptyChoicesEl = document.getElementById('empty-choices');
const breadcrumbEl = document.getElementById('breadcrumb');
const titleEl = document.getElementById('title');
const vehicleNameEl = document.getElementById('vehicle-name');
const vehicleClassEl = document.getElementById('vehicle-class');
const vehiclePlateEl = document.getElementById('vehicle-plate');
const selectedLabelEl = document.getElementById('selected-label');
const selectedPriceEl = document.getElementById('selected-price');
const sessionLabelEl = document.getElementById('session-label');
const sessionTotalEl = document.getElementById('session-total');
const hintLabelEl = document.getElementById('hint-label');
const optionsTitleEl = document.getElementById('options-title');
const optionsSubtitleEl = document.getElementById('options-subtitle');
const previewTitleEl = document.getElementById('preview-title');
const previewSubtitleEl = document.getElementById('preview-subtitle');
const statusChipEl = document.getElementById('status-chip');
const optionNameEl = document.getElementById('option-name');
const optionGroupEl = document.getElementById('option-group');
const applyBtn = document.getElementById('apply-btn');
const restoreBtn = document.getElementById('restore-btn');
const closeBtn = document.getElementById('close-btn');

let state = null;

const formatMoney = (value) => `${state?.currency ?? 'R$'}${Number(value || 0).toLocaleString('pt-BR')}`;

function post(event, data = {}) {
  fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
}

function setVisibility(visible) {
  app.classList.toggle('hidden', !visible);
}

function activeCategory() {
  return state?.categories?.find((category) => category.id === state.currentCategory);
}

function activeOption() {
  return state?.options?.find((option) => option.id === state.currentOption);
}

function activeChoice() {
  return state?.choices?.find((choice) => choice.id === state.currentChoice);
}

function statusClass(choice) {
  if (!choice) return 'available';
  if (choice.blocked) return 'blocked';
  if (choice.installed) return 'installed';
  return 'available';
}

function statusLabel(choice) {
  if (!choice) return state.locale.available;
  if (choice.blocked) return state.locale.blocked;
  if (choice.installed) return state.locale.installed;
  return state.locale.available;
}

function renderCategories() {
  categoriesEl.innerHTML = '';
  state.categories.forEach((category) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `category ${category.id === state.currentCategory ? 'active' : ''} ${!category.enabled ? 'disabled' : ''}`;
    button.disabled = !category.enabled;
    button.innerHTML = `
      <div class="item-head">
        <span class="item-icon">${category.icon}</span>
        <div class="item-main">
          <strong>${category.label}</strong>
          <p>${category.description}</p>
        </div>
        <span class="badge">${category.count}</span>
      </div>`;
    button.addEventListener('click', () => post('selectCategory', { categoryId: category.id }));
    categoriesEl.appendChild(button);
  });
}

function renderOptions() {
  optionsEl.innerHTML = '';
  const category = activeCategory();
  optionsTitleEl.textContent = category?.label ?? state.locale.breadcrumbRoot;
  optionsSubtitleEl.textContent = category?.description ?? state.locale.emptyCategory;
  emptyOptionsEl.textContent = state.locale.noOptions;
  emptyOptionsEl.classList.toggle('hidden', state.options.length > 0);

  state.options.forEach((option) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `option ${option.id === state.currentOption ? 'active' : ''} ${option.disabled ? 'disabled' : ''}`;
    button.disabled = option.disabled;
    button.innerHTML = `
      <div class="item-head">
        <span class="item-icon">${option.icon}</span>
        <div class="item-main">
          <strong>${option.label}</strong>
          <p>${option.group} · ${option.currentLabel}</p>
        </div>
        <div class="choice-main">
          <strong>${formatMoney(option.price)}</strong>
          <p>${option.choiceCount} variações</p>
        </div>
      </div>`;
    button.addEventListener('click', () => post('selectOption', { optionId: option.id }));
    optionsEl.appendChild(button);
  });
}

function renderChoices() {
  choicesEl.innerHTML = '';
  const option = activeOption();
  const choice = activeChoice();
  const category = activeCategory();

  breadcrumbEl.textContent = `${state.locale.breadcrumbRoot} / ${category?.label ?? '-'} / ${option?.label ?? '-'}`;
  titleEl.textContent = state.locale.title;
  vehicleNameEl.textContent = state.vehicle.name;
  vehicleClassEl.textContent = state.vehicle.class;
  vehiclePlateEl.textContent = state.vehicle.plate;
  selectedLabelEl.textContent = state.locale.selectedPrice;
  sessionLabelEl.textContent = state.locale.sessionTotal;
  hintLabelEl.textContent = state.locale.hint;
  selectedPriceEl.textContent = formatMoney(state.selectedPrice);
  sessionTotalEl.textContent = formatMoney(state.sessionTotal);

  previewTitleEl.textContent = option?.label ?? 'Preview';
  previewSubtitleEl.textContent = option ? `${option.group} · ${formatMoney(option.price)}` : state.locale.emptyCategory;
  optionNameEl.textContent = option?.label ?? state.locale.emptyCategory;
  optionGroupEl.textContent = option ? `${option.group} · ${option.currentLabel}` : state.locale.noChoices;

  statusChipEl.className = `status-chip ${statusClass(choice)}`;
  statusChipEl.textContent = statusLabel(choice);

  emptyChoicesEl.textContent = state.locale.noChoices;
  emptyChoicesEl.classList.toggle('hidden', state.choices.length > 0);

  state.choices.forEach((entry) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `choice ${entry.id === state.currentChoice ? 'active' : ''} ${entry.blocked ? 'disabled' : ''}`;
    button.disabled = entry.blocked;
    button.innerHTML = `
      <div class="choice-head">
        <div class="choice-main">
          <strong>${entry.label}</strong>
          <p>${entry.installed ? state.locale.installedHint : entry.isAction ? state.locale.actionHint : state.locale.preview}</p>
        </div>
        <div class="choice-main">
          <strong>${formatMoney(entry.price)}</strong>
          <p>${statusLabel(entry)}</p>
        </div>
      </div>`;
    button.addEventListener('mouseenter', () => post('previewChoice', { optionId: state.currentOption, choiceId: entry.id }));
    button.addEventListener('focus', () => post('previewChoice', { optionId: state.currentOption, choiceId: entry.id }));
    button.addEventListener('click', () => {
      post('previewChoice', { optionId: state.currentOption, choiceId: entry.id });
      if (entry.isAction) {
        post('installChoice', { optionId: state.currentOption, choiceId: entry.id });
      }
    });
    choicesEl.appendChild(button);
  });

  applyBtn.disabled = !option || !choice || !!choice.blocked || !!choice.installed;
}

function render(payload) {
  state = payload;
  setVisibility(payload.visible);
  renderCategories();
  renderOptions();
  renderChoices();
}

window.addEventListener('message', (event) => {
  const payload = event.data;
  if (payload.action === 'open') {
    render(payload);
  }

  if (payload.action === 'close') {
    setVisibility(false);
    state = null;
  }
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    post('close');
  }
});

applyBtn.addEventListener('click', () => {
  if (!state?.currentOption || !state?.currentChoice) return;
  post('installChoice', { optionId: state.currentOption, choiceId: state.currentChoice });
});

restoreBtn.addEventListener('click', () => post('restorePreview'));
closeBtn.addEventListener('click', () => post('close'));
