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

const iconBasePath = 'assets/renzu-icons';
const initialState = {
  isOpen: false,
  currentView: null,
  payload: null,
  previewRequest: null,
  openToken: 0,
};

const uiState = { ...initialState };
let failsafeTimer = 0;

const formatMoney = (value) => `${uiState.payload?.currency ?? 'R$'}${Number(value || 0).toLocaleString('pt-BR')}`;

function post(event, data = {}) {
  fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).catch(() => {
    closeUI();
  });
}

function clearFailsafe() {
  if (failsafeTimer) {
    window.clearTimeout(failsafeTimer);
    failsafeTimer = 0;
  }
}

function setClosedAttributes() {
  body.classList.remove('ui-active');
  app.dataset.open = 'false';
  app.setAttribute('aria-hidden', 'true');
}

function setOpenAttributes() {
  body.classList.add('ui-active');
  app.dataset.open = 'true';
  app.setAttribute('aria-hidden', 'false');
}

function clearView() {
  categoriesEl.replaceChildren();
  optionsEl.replaceChildren();
  choicesEl.replaceChildren();
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
  emptyOptionsEl.classList.add('hidden');
  emptyChoicesEl.classList.add('hidden');
}

function resetState() {
  clearFailsafe();
  uiState.isOpen = false;
  uiState.currentView = null;
  uiState.payload = null;
  uiState.previewRequest = null;
  uiState.openToken += 1;
}

function closeUI() {
  resetState();
  setClosedAttributes();
  clearView();
}

function hardResetUI(reason = 'hard-reset') {
  closeUI();
  if (reason === 'message-close' || reason === 'message-reset') {
    return;
  }

  post('close');
}

function scheduleFailsafe(expectedToken) {
  clearFailsafe();
  failsafeTimer = window.setTimeout(() => {
    if (!uiState.isOpen || expectedToken !== uiState.openToken) {
      return;
    }

    const hasRenderableContent = Boolean(
      uiState.payload
      && uiState.payload.locale
      && Array.isArray(uiState.payload.categories)
      && categoriesEl.childElementCount === uiState.payload.categories.length
    );

    if (!hasRenderableContent) {
      hardResetUI('render-timeout');
    }
  }, 1500);
}

function schedulePreview(choiceId) {
  if (!uiState.isOpen || !uiState.payload?.currentOption || !choiceId) return;
  if (uiState.previewRequest === choiceId) return;

  uiState.previewRequest = choiceId;
  const currentToken = uiState.openToken;
  window.requestAnimationFrame(() => {
    if (!uiState.isOpen || currentToken !== uiState.openToken || uiState.previewRequest !== choiceId || !uiState.payload?.currentOption) return;
    post('previewChoice', { optionId: uiState.payload.currentOption, choiceId });
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
  return uiState.payload?.categories?.find((category) => category.id === uiState.payload.currentCategory);
}

function activeOption() {
  return uiState.payload?.options?.find((option) => option.id === uiState.payload.currentOption);
}

function activeChoice() {
  return uiState.payload?.choices?.find((choice) => choice.id === uiState.payload.currentChoice);
}

function statusClass(choice) {
  if (!choice) return 'available';
  if (choice.blocked) return 'blocked';
  if (choice.installed) return 'installed';
  return 'available';
}

function statusLabel(choice) {
  if (!choice) return uiState.payload.locale.available;
  if (choice.blocked) return uiState.payload.locale.blocked;
  if (choice.installed) return uiState.payload.locale.installed;
  return uiState.payload.locale.available;
}

function renderCategories() {
  categoriesEl.replaceChildren();
  uiState.payload.categories.forEach((category) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `category ${category.id === uiState.payload.currentCategory ? 'active' : ''} ${!category.enabled ? 'disabled' : ''}`;
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
  optionsEl.replaceChildren();
  const category = activeCategory();
  optionsTitleEl.textContent = category?.label ?? uiState.payload.locale.breadcrumbRoot;
  optionsSubtitleEl.textContent = category?.description ?? uiState.payload.locale.emptyCategory;
  emptyOptionsEl.textContent = uiState.payload.locale.noOptions;
  emptyOptionsEl.classList.toggle('hidden', uiState.payload.options.length > 0);

  uiState.payload.options.forEach((option) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `option ${option.id === uiState.payload.currentOption ? 'active' : ''} ${option.disabled ? 'disabled' : ''}`;
    button.disabled = option.disabled;

    const head = document.createElement('div');
    head.className = 'item-head';
    head.appendChild(createIcon(option.asset, option.icon));
    head.appendChild(createInfoMain(option.label, `${option.group} · ${option.currentLabel}`));
    head.appendChild(createInfoMain(formatMoney(option.price), `${option.choiceCount} ${uiState.payload.locale.variations}`, 'choice-main'));

    button.appendChild(head);
    button.addEventListener('click', () => post('selectOption', { optionId: option.id }));
    optionsEl.appendChild(button);
  });
}

function renderChoices() {
  choicesEl.replaceChildren();
  const option = activeOption();
  const choice = activeChoice();
  const category = activeCategory();

  breadcrumbEl.textContent = `${uiState.payload.locale.breadcrumbRoot} / ${category?.label ?? '-'} / ${option?.label ?? '-'}`;
  titleEl.textContent = uiState.payload.locale.title;
  vehicleNameEl.textContent = uiState.payload.vehicle.name;
  vehicleClassEl.textContent = uiState.payload.vehicle.class;
  vehiclePlateEl.textContent = uiState.payload.vehicle.plate;
  selectedLabelEl.textContent = uiState.payload.locale.selectedPrice;
  sessionLabelEl.textContent = uiState.payload.locale.sessionTotal;
  hintLabelEl.textContent = uiState.payload.locale.hint;
  selectedPriceEl.textContent = formatMoney(uiState.payload.selectedPrice);
  sessionTotalEl.textContent = formatMoney(uiState.payload.sessionTotal);

  previewTitleEl.textContent = option?.label ?? uiState.payload.locale.previewFallback;
  previewSubtitleEl.textContent = option ? `${option.group} · ${formatMoney(option.price)}` : uiState.payload.locale.emptyCategory;
  optionNameEl.textContent = option?.label ?? uiState.payload.locale.emptyCategory;
  optionGroupEl.textContent = option ? `${option.group} · ${option.currentLabel}` : uiState.payload.locale.noChoices;

  statusChipEl.className = `status-chip ${statusClass(choice)}`;
  statusChipEl.textContent = statusLabel(choice);

  emptyChoicesEl.textContent = uiState.payload.locale.noChoices;
  emptyChoicesEl.classList.toggle('hidden', uiState.payload.choices.length > 0);

  uiState.payload.choices.forEach((entry) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `choice ${entry.id === uiState.payload.currentChoice ? 'active' : ''} ${entry.blocked ? 'disabled' : ''}`;
    button.disabled = entry.blocked;

    const head = document.createElement('div');
    head.className = 'choice-head';
    head.appendChild(createInfoMain(entry.label, entry.installed ? uiState.payload.locale.installedHint : entry.isAction ? uiState.payload.locale.actionHint : uiState.payload.locale.preview, 'choice-main'));
    head.appendChild(createInfoMain(formatMoney(entry.price), statusLabel(entry), 'choice-main'));

    button.appendChild(head);
    button.addEventListener('mouseenter', () => schedulePreview(entry.id));
    button.addEventListener('focus', () => schedulePreview(entry.id));
    button.addEventListener('click', () => {
      schedulePreview(entry.id);
      if (entry.isAction) {
        post('installChoice', { optionId: uiState.payload.currentOption, choiceId: entry.id });
      }
    });
    choicesEl.appendChild(button);
  });

  applyBtn.disabled = !option || !choice || !!choice.blocked || !!choice.installed;
}

function renderUI(payload) {
  uiState.payload = payload;
  uiState.previewRequest = null;
  renderCategories();
  renderOptions();
  renderChoices();
}

function openUI(payload) {
  if (!payload || payload.visible !== true) {
    hardResetUI('invalid-open-payload');
    return;
  }

  resetState();
  uiState.payload = payload;
  uiState.currentView = payload.currentView ?? 'main';
  uiState.isOpen = true;
  setOpenAttributes();
  renderUI(payload);
  scheduleFailsafe(uiState.openToken);
}

window.openUI = openUI;
window.closeUI = closeUI;
window.hardResetUI = hardResetUI;

window.addEventListener('message', (event) => {
  const payload = event.data;
  if (!payload || !payload.action) return;

  if (payload.action === 'close') {
    closeUI();
    return;
  }

  if (payload.action === 'hardReset') {
    closeUI();
    return;
  }

  if (payload.action === 'open') {
    openUI(payload);
    return;
  }

  if (payload.action === 'sync' && uiState.isOpen) {
    renderUI(payload);
    scheduleFailsafe(uiState.openToken);
  }
});

window.addEventListener('keydown', (event) => {
  if (!uiState.isOpen) return;

  if (event.key === 'Escape') {
    post('close');
  }
});

document.addEventListener('visibilitychange', () => {
  if (document.hidden && uiState.isOpen) {
    post('focusLost');
  }
});

window.addEventListener('blur', () => {
  if (uiState.isOpen) {
    post('focusLost');
  }
});

applyBtn.addEventListener('click', () => {
  if (!uiState.isOpen || !uiState.payload?.currentOption || !uiState.payload?.currentChoice) return;
  post('installChoice', { optionId: uiState.payload.currentOption, choiceId: uiState.payload.currentChoice });
});

restoreBtn.addEventListener('click', () => {
  if (!uiState.isOpen) return;
  post('restorePreview');
});

closeBtn.addEventListener('click', () => {
  if (!uiState.isOpen) return;
  post('close');
});

window.addEventListener('load', () => {
  closeUI();
  post('uiReady');
});
