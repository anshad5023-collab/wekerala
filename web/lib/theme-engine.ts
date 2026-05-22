export type LayoutVariant = 'clean' | 'dark' | 'warm' | 'neopop' | 'editorial' | 'carousel' | 'luxury' | 'festival' | 'restaurant';

export interface ThemeConfig {
  id: string;
  name: string;
  description: string;
  tag: string;
  layout: LayoutVariant;
  defaults: { primaryColor: string; secondaryColor: string; fontFamily: string; bgColor: string; textColor: string };
}

export interface SocialLinks {
  instagram: string;
  facebook: string;
  youtube: string;
  twitter: string;
}

export interface CouponCode {
  code: string;
  discountPercent: number;
  active: boolean;
}

export interface WebsiteConfig {
  themeId: string;
  siteName: string;
  tagline: string;
  aboutText: string;
  primaryColor: string;
  secondaryColor: string;
  fontFamily: string;
  sections: string[];
  whatsappEnabled: boolean;
  whatsappNumber: string;
  customHtml: string;
  banners: string[];
  storeHoursText: string;
  storeHoursEnabled: boolean;
  // Pages
  customAbout: string;
  customContact: string;
  customPrivacy: string;
  customShipping: string;
  customReturn: string;
  showAboutPage: boolean;
  showContactPage: boolean;
  showPrivacyPage: boolean;
  showShippingPage: boolean;
  showReturnPage: boolean;
  // Social
  socialLinks: SocialLinks;
  // Announcement bar
  announcementBar: string;
  announcementBarEnabled: boolean;
  announcementBarColor: string;
  // SEO
  seoTitle: string;
  seoDescription: string;
  // Offers / coupons
  couponCodes: CouponCode[];
  primaryButtonText: string;
  // Delivery
  deliveryCharge: number;
  freeDeliveryAbove: number;
  minOrderAmount: number;
  // Branding
  logoUrl: string;
  faviconUrl: string;
  // Plugins
  googleAnalyticsId: string;
  facebookPixelId: string;
  tawkPropertyId: string;
  reviewsEnabled: boolean;
  isPublished?: boolean;
  publishedAt?: string;
}

export const THEMES: ThemeConfig[] = [
  {
    id: 'modern', name: 'Modern', description: 'Clean & minimal white design', tag: 'Minimal', layout: 'clean',
    defaults: { primaryColor: '#283618', secondaryColor: '#dda15e', fontFamily: 'Poppins', bgColor: '#ffffff', textColor: '#1a1a1a' },
  },
  {
    id: 'bold', name: 'Bold', description: 'Dark & powerful', tag: 'Dark', layout: 'dark',
    defaults: { primaryColor: '#7c3aed', secondaryColor: '#a78bfa', fontFamily: 'Space Grotesk', bgColor: '#1a1a2e', textColor: '#ffffff' },
  },
  {
    id: 'traditional', name: 'Traditional', description: 'Kerala heritage & warmth', tag: 'Kerala', layout: 'warm',
    defaults: { primaryColor: '#283618', secondaryColor: '#dda15e', fontFamily: 'Poppins', bgColor: '#fef9f0', textColor: '#283618' },
  },
  {
    id: 'amaze', name: 'Amaze', description: 'NeoPOP — vibrant D2C brand', tag: 'D2C', layout: 'neopop',
    defaults: { primaryColor: '#ff6b35', secondaryColor: '#ff3e6c', fontFamily: 'Outfit', bgColor: '#0a0a0a', textColor: '#ffffff' },
  },
  {
    id: 'helsinki', name: 'Helsinki', description: 'Editorial — fashion & clothing', tag: 'Fashion', layout: 'editorial',
    defaults: { primaryColor: '#1a1a1a', secondaryColor: '#888888', fontFamily: 'Playfair Display', bgColor: '#f5f5f5', textColor: '#1a1a1a' },
  },
  {
    id: 'mana', name: 'Mana', description: 'Ultra-minimal & fast', tag: 'Minimal', layout: 'editorial',
    defaults: { primaryColor: '#2563eb', secondaryColor: '#93c5fd', fontFamily: 'Inter', bgColor: '#ffffff', textColor: '#111827' },
  },
  {
    id: 'oxford', name: 'Oxford', description: 'Dark luxury — premium brands', tag: 'Premium', layout: 'luxury',
    defaults: { primaryColor: '#d4af37', secondaryColor: '#b8962e', fontFamily: 'Raleway', bgColor: '#0d0d0d', textColor: '#f5e6c8' },
  },
  {
    id: 'catalyst', name: 'Catalyst', description: 'Carousel + category tabs', tag: 'Catalog', layout: 'carousel',
    defaults: { primaryColor: '#e11d48', secondaryColor: '#fb7185', fontFamily: 'Nunito', bgColor: '#ffffff', textColor: '#111827' },
  },
  {
    id: 'festival', name: 'Festival', description: 'Bright Kerala festive colours', tag: 'Kerala', layout: 'festival',
    defaults: { primaryColor: '#ff8c00', secondaryColor: '#22c55e', fontFamily: 'Poppins', bgColor: '#fff8e7', textColor: '#1a1a1a' },
  },
  {
    id: 'zenith', name: 'Zenith', description: 'B2B style — large catalogs', tag: 'B2B', layout: 'festival',
    defaults: { primaryColor: '#0f766e', secondaryColor: '#14b8a6', fontFamily: 'DM Sans', bgColor: '#f0fdf4', textColor: '#134e4a' },
  },
  {
    id: 'restaurant', name: 'Restaurant', description: 'Swiggy-style menu for hotels & restaurants', tag: 'Food', layout: 'restaurant',
    defaults: { primaryColor: '#FC8019', secondaryColor: '#FF4D2B', fontFamily: 'Poppins', bgColor: '#FFFFFF', textColor: '#3E4152' },
  },
];

export const GOOGLE_FONTS = [
  'Poppins', 'Inter', 'Playfair Display', 'Montserrat', 'Roboto',
  'Raleway', 'Nunito', 'DM Sans', 'Space Grotesk', 'Outfit',
  'Lato', 'Open Sans', 'Josefin Sans', 'Bebas Neue', 'Sora',
];

export function getTheme(id: string): ThemeConfig {
  return THEMES.find(t => t.id === id) ?? THEMES[0];
}

export function defaultConfig(themeId = 'modern', shopData?: { shopName?: string; ownerPhone?: string }): WebsiteConfig {
  const theme = getTheme(themeId);
  return {
    themeId,
    siteName: shopData?.shopName ?? '',
    tagline: '',
    aboutText: '',
    primaryColor: theme.defaults.primaryColor,
    secondaryColor: theme.defaults.secondaryColor,
    fontFamily: theme.defaults.fontFamily,
    sections: ['hero', 'products', 'about', 'contact'],
    whatsappEnabled: true,
    whatsappNumber: shopData?.ownerPhone ?? '',
    customHtml: '',
    banners: [],
    storeHoursText: '',
    storeHoursEnabled: false,
    customAbout: '',
    customContact: '',
    customPrivacy: '',
    customShipping: '',
    customReturn: '',
    showAboutPage: false,
    showContactPage: false,
    showPrivacyPage: false,
    showShippingPage: false,
    showReturnPage: false,
    socialLinks: { instagram: '', facebook: '', youtube: '', twitter: '' },
    announcementBar: '',
    announcementBarEnabled: false,
    announcementBarColor: '',
    seoTitle: '',
    seoDescription: '',
    couponCodes: [],
    primaryButtonText: 'Order Now',
    deliveryCharge: 0,
    freeDeliveryAbove: 0,
    minOrderAmount: 0,
    logoUrl: '',
    faviconUrl: '',
    googleAnalyticsId: '',
    facebookPixelId: '',
    tawkPropertyId: '',
    reviewsEnabled: false,
  };
}
