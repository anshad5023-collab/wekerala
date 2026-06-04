export type Category = string;
export type UnitType = 'perKg' | 'perPiece' | 'perLitre' | 'perPack';

export interface Product {
  id: string;
  name: {
    en: string;
    ml: string;
  };
  price: number;
  offerPrice: number;
  unit: UnitType;
  category: string;
  image: string;
  isOutOfStock: boolean;
  description?: string; // optional long description for product detail sheet
}

export interface AiSettings {
  enabled: boolean;
  shareProductPrices?: boolean;
  shareStockStatus?: boolean;
  answerDelivery?: boolean;
  answerHours?: boolean;
  replyLanguage?: 'auto' | 'english' | 'malayalam';
  customNote?: string;
}

export interface Shop {
  shopId: string;
  shopName: string;
  shopNameMl: string;
  ownerWhatsApp: string;
  logoUrl: string;
  bannerImageUrl: string;
  categories: string[];
  isOpen: boolean;
  minOrderAmount: number;
  deliveryCharge: number;
  deliveryEnabled: boolean;
  themeColor?: string;
  deliveryTimeEstimate?: string;
  promotionalBanner?: string;
  announcementText?: string;
  featuredProductIds?: string[];
  productLayout?: 'grid2' | 'grid3' | 'list';
  shopArea?: string;
  shopType?: string;
  isApproved?: boolean;
  aiSettings?: AiSettings;
  upiId?: string;
  paymentMethods?: string[];
}

export interface ShopData extends Shop {
  shopId: string;
}

function mapUnit(unit: string): UnitType {
  if (unit === 'kg' || unit === 'g') return 'perKg';
  if (unit === 'piece') return 'perPiece';
  if (unit === 'litre' || unit === 'ml') return 'perLitre';
  return 'perPack';
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function firestoreToProduct(data: Record<string, any>, id: string): Product {
  // If the product has variants, pick the lowest variant price as the display price
  let price = (data['price'] as number) ?? 0;
  let offerPrice = (data['offerPrice'] as number) ?? 0;

  if (data['hasVariants'] && Array.isArray(data['variants']) && data['variants'].length > 0) {
    const variantPrices = data['variants']
      .map((v: Record<string, number>) => v['price'] ?? 0)
      .filter((p: number) => p > 0);
    if (variantPrices.length > 0 && price === 0) {
      price = Math.min(...variantPrices);
    }
    const offerPrices = data['variants']
      .map((v: Record<string, number>) => v['offerPrice'] ?? 0)
      .filter((p: number) => p > 0 && p < price);
    if (offerPrices.length > 0 && offerPrice === 0) {
      offerPrice = Math.min(...offerPrices);
    }
  }

  return {
    id: data['productId'] ?? id,
    name: { en: data['nameEn'] ?? '', ml: data['nameMl'] ?? '' },
    price,
    offerPrice,
    unit: mapUnit(data['unit'] ?? 'piece'),
    category: data['category'] ?? '',
    image: data['imageUrl'] ?? '',
    isOutOfStock: data['isOutOfStock'] ?? false,
    description: data['description'] as string | undefined,
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function firestoreToShop(raw: Record<string, any>, shopId: string): ShopData {
  return {
    shopId,
    shopName: raw['shopName'] ?? '',
    shopNameMl: raw['shopNameMl'] ?? '',
    ownerWhatsApp: raw['ownerWhatsApp'] ?? raw['ownerPhone'] ?? '',
    logoUrl: raw['logoUrl'] ?? '',
    bannerImageUrl: raw['bannerImageUrl'] ?? '',
    categories: Array.isArray(raw['categories']) ? raw['categories'] : [],
    isOpen: raw['isOpen'] ?? raw['isActive'] ?? false,
    // Flutter app uses minOrderValue; web uses minOrderAmount — handle both
    minOrderAmount: raw['minOrderAmount'] ?? raw['minOrderValue'] ?? 0,
    deliveryCharge: raw['deliveryCharge'] ?? raw['deliveryFee'] ?? 0,
    deliveryEnabled: raw['deliveryEnabled'] ?? (raw['deliveryType'] === 'delivery' || raw['deliveryType'] === 'both'),
    themeColor: raw['themeColor'],
    deliveryTimeEstimate: raw['deliveryTimeEstimate'],
    promotionalBanner: raw['promotionalBanner'],
    announcementText: raw['announcementText'],
    featuredProductIds: raw['featuredProductIds'],
    productLayout: raw['productLayout'],
    shopArea: raw['shopArea'] ?? raw['district'],
    shopType: raw['shopType'],
    isApproved: raw['isApproved'] ?? raw['linkActive'] ?? true,
    upiId: raw['upiId'],
    paymentMethods: Array.isArray(raw['paymentMethods']) ? raw['paymentMethods'] : undefined,
  };
}

export async function fetchShopData(shopId: string): Promise<{ shop: ShopData; products: Product[] }> {
  const response = await fetch(`/api/shop?shopId=${shopId}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch shop data: ${response.status}`);
  }
  const { shop: rawShop, products: rawProducts } = await response.json();
  const shop = firestoreToShop(rawShop, shopId);
  const products = (rawProducts ?? []).map((p: Record<string, unknown>) =>
    firestoreToProduct(p as Record<string, any>, p.id as string)
  );
  return { shop, products };
}
