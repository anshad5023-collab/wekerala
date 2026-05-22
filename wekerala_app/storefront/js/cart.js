function key(slug) {
  return `cart_${slug}`;
}

export function getCart(slug) {
  try {
    return JSON.parse(localStorage.getItem(key(slug))) || [];
  } catch {
    return [];
  }
}

function saveCart(slug, items) {
  localStorage.setItem(key(slug), JSON.stringify(items));
}

export function addItem(slug, item) {
  const cart = getCart(slug);
  const idx = cart.findIndex(
    (i) => i.productId === item.productId && i.variantId === (item.variantId || '')
  );
  if (idx >= 0) {
    cart[idx].qty += item.qty;
  } else {
    cart.push({ ...item, variantId: item.variantId || '' });
  }
  saveCart(slug, cart);
}

export function updateQty(slug, productId, variantId, qty) {
  let cart = getCart(slug);
  if (qty <= 0) {
    cart = cart.filter(
      (i) => !(i.productId === productId && i.variantId === (variantId || ''))
    );
  } else {
    const idx = cart.findIndex(
      (i) => i.productId === productId && i.variantId === (variantId || '')
    );
    if (idx >= 0) cart[idx].qty = qty;
  }
  saveCart(slug, cart);
}

export function removeItem(slug, productId, variantId) {
  const cart = getCart(slug).filter(
    (i) => !(i.productId === productId && i.variantId === (variantId || ''))
  );
  saveCart(slug, cart);
}

export function clearCart(slug) {
  localStorage.removeItem(key(slug));
}

export function getTotal(slug) {
  return getCart(slug).reduce((sum, i) => sum + i.price * i.qty, 0);
}

export function getItemCount(slug) {
  return getCart(slug).reduce((sum, i) => sum + i.qty, 0);
}
