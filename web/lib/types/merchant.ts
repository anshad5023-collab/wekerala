export type ActionMode = 'inquire' | 'order' | 'book';
export type UserRole = 'merchant' | 'customer';
export type OrderStatus = 'pending' | 'confirmed' | 'ready' | 'delivered' | 'cancelled';
export type BookingStatus = 'pending' | 'confirmed' | 'completed' | 'cancelled';
export type SubscriptionStatus = 'trial' | 'active' | 'expired' | 'none';

export interface MigrationMeta {
  sourceCollection: string;
  sourceId: string;
  migratedAt: string;
  migratedBy: string;
}

export interface UserDoc {
  uid: string;
  phone?: string;
  role: UserRole;
  isAdmin: boolean;
  merchantIds?: string[];
  activeMerchantId?: string;
  requiresPhoneLink?: boolean;
  createdAt: string;
}

export interface Merchant {
  merchantId: string;
  ownerId: string;
  category: string;
  name: string;
  nameMl: string;
  slug: string;
  district: string;
  phone: string;
  actionMode: ActionMode;
  isActive: boolean;
  isApproved: boolean;
  createdAt: string;
  subcategory?: string;
  town?: string;
  locality?: string;
  address?: string;
  whatsApp?: string;
  bannerUrl?: string;
  logoUrl?: string;
  about?: string;
  aboutMl?: string;
  tagline?: string;
  taglineMl?: string;
  photos?: string[];
  serviceTypes?: string[];
  serviceTagIds?: string[];
  deliveryEnabled?: boolean;
  minOrderValue?: number;
  deliveryCharge?: number;
  deliveryTimeEstimate?: string;
  paymentMethods?: string[];
  upiId?: string;
  isVerified?: boolean;
  isFeatured?: boolean;
  subscriptionStatus?: SubscriptionStatus;
  trialStartDate?: string;
  trialEndDate?: string;
  totalOrders?: number;
  updatedAt?: string;
  legacyShopId?: string;
  requiresPhoneLink?: boolean;
  _migrationMeta?: MigrationMeta;
}

export interface SubdomainMapping {
  merchantId: string;
  createdAt: string;
}

export interface ProductVariant {
  variantId: string;
  name: string;
  price: number;
  offerPrice?: number;
  stock?: number;
}

export interface MerchantProduct {
  productId: string;
  nameEn: string;
  nameMl?: string;
  category: string;
  price: number;
  offerPrice?: number;
  unit: string;
  minQty?: number;
  imageUrl?: string;
  imageSource?: 'auto' | 'owner' | 'placeholder';
  isHidden?: boolean;
  isOutOfStock?: boolean;
  hasVariants?: boolean;
  variants?: ProductVariant[];
  orderCount?: number;
  createdAt: string;
  updatedAt?: string;
  _migrationMeta?: MigrationMeta;
}

export interface OrderItem {
  productId: string;
  nameEn: string;
  price: number;
  quantity: number;
}

export interface MerchantOrder {
  orderId: string;
  customerName: string;
  customerPhone: string;
  items: OrderItem[];
  totalAmount: number;
  status: OrderStatus;
  address?: string;
  notes?: string;
  createdAt: string;
  updatedAt?: string;
  _migrationMeta?: MigrationMeta;
}

export interface MerchantService {
  serviceId: string;
  name: string;
  nameMl?: string;
  description?: string;
  price?: number;
  duration?: number;
  isAvailable: boolean;
  createdAt: string;
}

export interface MerchantBooking {
  bookingId: string;
  serviceId: string;
  customerName: string;
  customerPhone: string;
  scheduledAt: string;
  status: BookingStatus;
  notes?: string;
  createdAt: string;
}

export interface MerchantInquiry {
  inquiryId: string;
  customerName: string;
  customerPhone: string;
  message: string;
  isRead: boolean;
  createdAt: string;
}
