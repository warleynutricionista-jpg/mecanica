const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qbx_customs';
const body = document.body;
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
let isOpen = false;
let previewRequest = null;
const iconBasePath = 'assets/renzu-icons';

const formatMoney = (value) => `${state?.currency ?? 'R$'}${Number(value || 0).toLocaleString('pt-BR')}`;

function post(event, data = {}) {
  fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
}

function setVisibility(visible) {
  isOpen = visible;
  body.classList.toggle('nui-open', visible);
  app.classList.toggle('is-open', visible);
  app.classList.toggle('hidden', !visible);
}

function clearView() {
  categoriesEl.innerHTML = '';
  optionsEl.innerHTML = '';
  choicesEl.innerHTML = '';
  emptyOptionsEl.textContent = '';
  emptyChoicesEl.textContent = '';
  breadcrumbEl.textContent = '';
  titleEl.textContent = '';
  vehicleNameEl.textContent = '';
  vehicleClassEl.textContent = '';
  vehiclePlateEl.textContent = '';
  selectedLabelEl.textContent = '';
  selectedPriceEl.textContent = '';
  sessionLabelEl.textContent = '';
  sessionTotalEl.textContent = '';
  hintLabelEl.textContent = '';
  optionsTitleEl.textContent = '';
  optionsSubtitleEl.textContent = '';
  previewTitleEl.textContent = '';
  previewSubtitleEl.textContent = '';
  statusChipEl.className = 'status-chip';
  statusChipEl.textContent = '';
  optionNameEl.textContent = '';
  optionGroupEl.textContent = '';
  applyBtn.disabled = true;
}

function closeView() {
  previewRequest = null;
  state = null;
  setVisibility(false);
  clearView();
}

function schedulePreview(choiceId) {
  if (!isOpen || !state?.currentOption || !choiceId) return;
  if (previewRequest === choiceId) return;

  previewRequest = choiceId;
  window.requestAnimationFrame(() => {
    if (!isOpen || previewRequest !== choiceId || !state?.currentOption) return;
    post('previewChoice', { optionId: state.currentOption, choiceId });
  });
}

function createIcon(asset, fallback) {
  const wrapper = document.createElement('span');
  wrapper.className = 'item-icon';

  const fallbackNode = document.createElement('span');
  fallbackNode.className = 'icon-fallback';
  fallbackNode.textContent = fallback ?? '•';
  wrapper.appendChild(fallbackNode);

  if (!asset) return wrapper;

  const image = new Image();
  image.alt = '';
  image.className = 'icon-image hidden';
  image.src = `${iconBasePath}/${asset}.svg`;
  image.addEventListener('load', () => {
    fallbackNode.classList.add('hidden');
    image.classList.remove('hidden');
  });
  image.addEventListener('error', () => {
    image.remove();
  });

  wrapper.appendChild(image);
  return wrapper;
}

function createInfoMain(title, description, className = 'item-main') {
  const container = document.createElement('div');
  container.className = className;

  const strong = document.createElement('strong');
  strong.textContent = title;
  container.appendChild(strong);

  const text = document.createElement('p');
  text.textContent = description;
  container.appendChild(text);

  return container;
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

    const head = document.createElement('div');
    head.className = 'item-head';
    head.appendChild(createIcon(category.asset, category.icon));
    head.appendChild(createInfoMain(category.label, category.description));

    const badge = document.createElement('span');
    badge.className = 'badge';
    badge.textContent = category.count;
    head.appendChild(badge);

    button.appendChild(head);
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

    const head = document.createElement('div');
    head.className = 'item-head';
    head.appendChild(createIcon(option.asset, option.icon));
    head.appendChild(createInfoMain(option.label, `${option.group} · ${option.currentLabel}`));
    head.appendChild(createInfoMain(formatMoney(option.price), `${option.choiceCount} ${state.locale.variations}`, 'choice-main'));

    button.appendChild(head);
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

  previewTitleEl.textContent = option?.label ?? state.locale.previewFallback;
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

    const head = document.createElement('div');
    head.className = 'choice-head';
    head.appendChild(createInfoMain(entry.label, entry.installed ? state.locale.installedHint : entry.isAction ? state.locale.actionHint : state.locale.preview, 'choice-main'));
    head.appendChild(createInfoMain(formatMoney(entry.price), statusLabel(entry), 'choice-main'));

    button.appendChild(head);
    button.addEventListener('mouseenter', () => schedulePreview(entry.id));
    button.addEventListener('focus', () => schedulePreview(entry.id));
    button.addEventListener('click', () => {
      schedulePreview(entry.id);
      if (entry.isAction) {
        post('installChoice', { optionId: state.currentOption, choiceId: entry.id });
      }
    });
    choicesEl.appendChild(button);
  });

  applyBtn.disabled = !option || !choice || !!choice.blocked || !!choice.installed;
}

function render(payload) {
  if (!payload?.visible) {
    closeView();
    return;
  }

  state = payload;
  previewRequest = null;
  setVisibility(true);
  renderCategories();
  renderOptions();
  renderChoices();
}

window.addEventListener('message', (event) => {
  const payload = event.data;
  if (!payload || !payload.action) return;

  if (payload.action === 'close') {
    closeView();
    return;
  }

  if (payload.action === 'open') {
    render(payload);
    return;
  }

  if (payload.action === 'sync' && isOpen) {
    render(payload);
  }
});

window.addEventListener('keydown', (event) => {
  if (!isOpen) return;

  if (event.key === 'Escape') {
    post('close');
  }
});

document.addEventListener('visibilitychange', () => {
  if (document.hidden && state?.visible) {
    post('focusLost');
  }
});

window.addEventListener('blur', () => {
  if (state?.visible) {
    post('focusLost');
  }
});

applyBtn.addEventListener('click', () => {
  if (!isOpen || !state?.currentOption || !state?.currentChoice) return;
  post('installChoice', { optionId: state.currentOption, choiceId: state.currentChoice });
});

restoreBtn.addEventListener('click', () => {
  if (!isOpen) return;
  post('restorePreview');
});

closeBtn.addEventListener('click', () => {
  if (!isOpen) return;
  post('close');
});

closeView();
