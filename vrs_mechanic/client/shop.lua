-- ============================================================
-- VRS_MECHANIC - PARTS SHOP CLIENT
-- ============================================================

local currentShopCatalog = nil

local function notifyError(description)
    lib.notify({ title = 'Loja de Peças', description = description, type = 'error' })
end

local function getCategoryById(categoryId)
    if not currentShopCatalog or not currentShopCatalog.categories then return nil end
    for _, category in ipairs(currentShopCatalog.categories) do
        if category.id == categoryId then
            return category
        end
    end
end

local function getItemsForCategory(categoryId)
    if not currentShopCatalog or not currentShopCatalog.items then return {} end

    local items = {}
    for _, item in ipairs(currentShopCatalog.items) do
        if item.category == categoryId then
            items[#items + 1] = item
        end
    end
    return items
end

local function purchaseItem(shopId, item)
    local input = lib.inputDialog(('Comprar - %s'):format(item.label), {
        {
            type = 'number',
            label = 'Quantidade',
            description = ((item.stock and item.stock > 0) and ('Disponível: %d | Valor unitário: R$ %s'):format(item.stock, VRS.FormatMoney(item.price or 0)) or ('Disponibilidade imediata | Valor unitário: R$ %s'):format(VRS.FormatMoney(item.price or 0))),
            default = 1,
            min = 1,
            max = (item.stock and item.stock > 0)
                and math.min(Config.PartsShop.maxPurchaseQuantity or 20, item.stock)
                or (Config.PartsShop.maxPurchaseQuantity or 20),
            required = true,
        },
    })

    if not input then return end

    local quantity = math.floor(tonumber(input[1]) or 0)
    if quantity < 1 then
        notifyError('Quantidade inválida.')
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:purchasePartsItem', false, shopId, item.name, quantity)
    if result and result.success then
        lib.notify({
            title = 'Loja de Peças',
            description = ('%dx %s comprado(s) por R$ %s.'):format(quantity, result.itemLabel or item.label, VRS.FormatMoney(result.totalPrice or 0)),
            type = 'success',
        })
        VRS.OpenPartsShop(shopId, item.category)
        return
    end

    local reason = result and result.reason or 'unknown'
    local messages = {
        cooldown = 'Aguarde alguns instantes antes de comprar novamente.',
        no_access = 'Você não tem acesso a esta loja.',
        not_on_duty = 'Você precisa estar em serviço para usar esta loja.',
        insufficient_funds = 'Saldo insuficiente para concluir a compra.',
        inventory_full = 'Seu inventário não tem espaço suficiente.',
        insufficient_stock = 'Quantidade indisponível no estoque configurado.',
        item_not_available = 'Este item não está disponível neste contexto.',
        invalid_quantity = 'Quantidade inválida.',
        payment_failed = 'Não foi possível processar o pagamento.',
        inventory_add_failed = 'Não foi possível entregar o item ao inventário.',
    }

    notifyError(messages[reason] or 'Não foi possível concluir a compra.')
end

local function openCategoryMenu(shopId, categoryId)
    local category = getCategoryById(categoryId)
    if not category then
        notifyError('Categoria não encontrada.')
        return
    end

    local items = getItemsForCategory(categoryId)
    if #items == 0 then
        lib.notify({ title = 'Loja de Peças', description = 'Nenhum item disponível nesta categoria.', type = 'inform' })
        return
    end

    local options = {}
    for _, item in ipairs(items) do
        local stockText = (item.stock or 0) > 0 and tostring(item.stock) or 'Sob consulta'
        options[#options + 1] = {
            title = ('%s %s'):format(item.icon or category.icon or '🧩', item.label),
            description = item.description,
            metadata = {
                { label = 'Preço', value = ('R$ %s'):format(VRS.FormatMoney(item.price or 0)) },
                { label = 'Disponibilidade', value = stockText },
                { label = 'Acesso', value = item.workshopOnly and 'Exclusivo da oficina' or 'Público / Operacional' },
            },
            onSelect = function()
                purchaseItem(shopId, item)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_parts_shop_items',
        title = ('Loja - %s'):format(category.label),
        menu = 'vrs_parts_shop_categories',
        options = options,
    })

    lib.showContext('vrs_parts_shop_items')
end

function VRS.OpenPartsShop(shopId, preferredCategory)
    if not Config.PartsShop.enabled then
        notifyError('A loja de peças está desativada na configuração.')
        return
    end

    local response = lib.callback.await('vrs_mechanic:server:getPartsCatalog', false, shopId)
    if not response or not response.success then
        local reason = response and response.reason or 'unknown'
        local messages = {
            no_access = 'Você não tem acesso a esta loja.',
            not_on_duty = 'Você precisa estar em serviço para usar esta loja da oficina.',
            shop_not_found = 'Loja não encontrada ou indisponível.',
        }
        notifyError(messages[reason] or 'Não foi possível carregar a loja.')
        return
    end

    currentShopCatalog = response.data

    if preferredCategory then
        openCategoryMenu(shopId, preferredCategory)
        return
    end

    local options = {}
    for _, category in ipairs(currentShopCatalog.categories or {}) do
        options[#options + 1] = {
            title = ('%s %s'):format(category.icon or '🧩', category.label),
            description = category.description,
            metadata = {
                { label = 'Itens disponíveis', value = tostring(category.count or 0) },
                { label = 'Loja', value = currentShopCatalog.shopLabel or 'Oficina' },
                { label = 'Pagamento', value = currentShopCatalog.currencyLabel or 'carteira' },
            },
            onSelect = function()
                openCategoryMenu(shopId, category.id)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_parts_shop_categories',
        title = ('Loja de Peças - %s'):format(currentShopCatalog.shopLabel or 'Oficina'),
        description = currentShopCatalog.public and 'Atendimento público disponível.' or 'Loja operacional da oficina.',
        options = options,
    })

    lib.showContext('vrs_parts_shop_categories')
end
