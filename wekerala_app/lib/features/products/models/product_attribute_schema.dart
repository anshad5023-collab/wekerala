// Category-based product attribute schema.
//
// Unlike kShopTypeProductSchema (which shows fields based on the shop type),
// this schema shows fields based on the category of the individual product.
//
// Example: a General Store owner adds a product in category "Mobile Phones"
// → the schema below shows Brand, Model, RAM, Storage, Battery, Color, Network.
//
// The values are stored in ProductModel.attributes (Map<String, dynamic>).

// ─── Field Types ─────────────────────────────────────────────────────────────

enum AttributeType {
  text,
  number,
  dropdown,
  chips, // multi-select chips (e.g. available sizes)
}

// ─── Field Definition ────────────────────────────────────────────────────────

class AttributeField {
  // Key stored in ProductModel.attributes map.
  final String key;

  // Label shown to the shop owner.
  final String label;

  // Optional Malayalam label shown as helper text.
  final String labelMl;

  final AttributeType type;

  // Options for dropdown or chips. Empty for text/number.
  final List<String> options;

  // Placeholder text for the field.
  final String hint;

  const AttributeField({
    required this.key,
    required this.label,
    this.labelMl = '',
    this.type = AttributeType.text,
    this.options = const [],
    this.hint = '',
  });
}

// ─── Category Schema Map ──────────────────────────────────────────────────────
//
// Keys are lowercase category keywords (matched with String.contains / toLowerCase).
// The matching logic in _CategoryAttributesSection walks this list and returns
// the first entry whose key appears anywhere in the selected category string.

class CategoryEntry {
  final String keyword;
  final List<AttributeField> fields;
  const CategoryEntry(this.keyword, this.fields);
}

// Ordered list of category keyword → fields mappings.
// The screen matches the first entry whose keyword appears in the typed category
// (case-insensitive). More specific keywords should come before general ones.
const List<CategoryEntry> kCategoryAttributeSchema = [
  // ── Mobile Phones / Smartphones ────────────────────────────────────────────
  CategoryEntry('mobile', [
    AttributeField(
      key: 'brand',
      label: 'Brand',
      labelMl: 'ബ്രാൻഡ്',
      hint: 'e.g. Samsung, Apple, OnePlus, Redmi',
    ),
    AttributeField(
      key: 'model',
      label: 'Model',
      labelMl: 'മോഡൽ',
      hint: 'e.g. Galaxy A55, iPhone 15, Nord CE 4',
    ),
    AttributeField(
      key: 'ram',
      label: 'RAM',
      labelMl: 'റാം',
      hint: 'e.g. 4GB, 6GB, 8GB',
    ),
    AttributeField(
      key: 'storage',
      label: 'Storage',
      labelMl: 'സ്റ്റോറേജ്',
      hint: 'e.g. 64GB, 128GB, 256GB',
    ),
    AttributeField(
      key: 'battery',
      label: 'Battery',
      labelMl: 'ബാറ്ററി',
      hint: 'e.g. 5000mAh, 4500mAh',
    ),
    AttributeField(
      key: 'color',
      label: 'Color',
      labelMl: 'നിറം',
      hint: 'e.g. Midnight Black, Glacier Blue',
    ),
    AttributeField(
      key: 'network',
      label: 'Network',
      labelMl: 'നെറ്റ്‌വർക്ക്',
      type: AttributeType.dropdown,
      options: ['4G', '5G', '4G + WiFi Calling', '5G + WiFi 6', 'WiFi Only'],
    ),
  ]),

  // ── Smartphones (alias) ────────────────────────────────────────────────────
  CategoryEntry('smartphone', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Samsung, Apple, OnePlus'),
    AttributeField(key: 'model', label: 'Model', labelMl: 'മോഡൽ', hint: 'e.g. Galaxy A55, iPhone 15'),
    AttributeField(key: 'ram', label: 'RAM', labelMl: 'റാം', hint: 'e.g. 8GB'),
    AttributeField(key: 'storage', label: 'Storage', labelMl: 'സ്റ്റോറേജ്', hint: 'e.g. 128GB'),
    AttributeField(key: 'battery', label: 'Battery', labelMl: 'ബാറ്ററി', hint: 'e.g. 5000mAh'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം', hint: 'e.g. Midnight Black'),
    AttributeField(
      key: 'network',
      label: 'Network',
      labelMl: 'നെറ്റ്‌വർക്ക്',
      type: AttributeType.dropdown,
      options: ['4G', '5G', '4G + WiFi Calling', '5G + WiFi 6', 'WiFi Only'],
    ),
  ]),

  // ── Laptops ────────────────────────────────────────────────────────────────
  CategoryEntry('laptop', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. HP, Dell, Lenovo, Asus'),
    AttributeField(key: 'model', label: 'Model', labelMl: 'മോഡൽ', hint: 'e.g. Pavilion 15, IdeaPad Slim 3'),
    AttributeField(key: 'processor', label: 'Processor', labelMl: 'പ്രൊസസ്സർ', hint: 'e.g. Intel i5 12th Gen, Ryzen 5'),
    AttributeField(key: 'ram', label: 'RAM', labelMl: 'റാം', hint: 'e.g. 8GB, 16GB DDR5'),
    AttributeField(key: 'storage', label: 'Storage', labelMl: 'സ്റ്റോറേജ്', hint: 'e.g. 512GB SSD, 1TB HDD'),
    AttributeField(key: 'display', label: 'Display Size', labelMl: 'ഡിസ്പ്ലേ', hint: 'e.g. 15.6 inch FHD'),
    AttributeField(key: 'os', label: 'OS', labelMl: 'ഓപ്പറേറ്റിംഗ് സിസ്റ്റം', type: AttributeType.dropdown,
        options: ['Windows 11', 'Windows 10', 'macOS', 'Ubuntu / Linux', 'FreeDOS']),
  ]),

  // ── Headphones / Earphones ────────────────────────────────────────────────
  CategoryEntry('headphone', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. boAt, Sony, JBL, Boat'),
    AttributeField(key: 'model', label: 'Model', labelMl: 'മോഡൽ', hint: 'e.g. Rockerz 255 Pro+'),
    AttributeField(key: 'connectivity', label: 'Connectivity', labelMl: 'കണക്ടിവിറ്റി',
        type: AttributeType.dropdown,
        options: ['Wired 3.5mm', 'Bluetooth', 'Type-C', 'USB-A', 'True Wireless (TWS)']),
    AttributeField(key: 'battery', label: 'Battery Life', labelMl: 'ബാറ്ററി', hint: 'e.g. 40 hours playback'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം', hint: 'e.g. Black, White, Red'),
  ]),

  // ── Earphones / Earbuds (alias for headphone match) ───────────────────────
  CategoryEntry('earbud', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. boAt, Sony, Noise'),
    AttributeField(key: 'model', label: 'Model', labelMl: 'മോഡൽ'),
    AttributeField(key: 'connectivity', label: 'Connectivity', labelMl: 'കണക്ടിവിറ്റി',
        type: AttributeType.dropdown,
        options: ['True Wireless (TWS)', 'Bluetooth', 'Wired 3.5mm', 'Type-C']),
    AttributeField(key: 'battery', label: 'Battery Life (per charge)', labelMl: 'ബാറ്ററി',
        hint: 'e.g. 8 hours + 30 hours with case'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
  ]),

  // ── Earphones (alias) ─────────────────────────────────────────────────────
  CategoryEntry('earphone', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. boAt, Sony, JBL'),
    AttributeField(key: 'model', label: 'Model', labelMl: 'മോഡൽ'),
    AttributeField(key: 'connectivity', label: 'Connectivity', labelMl: 'കണക്ടിവിറ്റി',
        type: AttributeType.dropdown,
        options: ['Wired 3.5mm', 'Type-C', 'Bluetooth']),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
  ]),

  // ── TV / Television ───────────────────────────────────────────────────────
  CategoryEntry('tv', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Sony, LG, Samsung, Mi'),
    AttributeField(key: 'screen_size', label: 'Screen Size', labelMl: 'സ്ക്രീൻ വലിപ്പം', hint: 'e.g. 43 inch, 55 inch'),
    AttributeField(key: 'resolution', label: 'Resolution', labelMl: 'റെസലൂഷൻ',
        type: AttributeType.dropdown,
        options: ['HD Ready (720p)', 'Full HD (1080p)', '4K UHD', '8K']),
    AttributeField(key: 'smart_tv', label: 'Smart TV', labelMl: 'സ്മാർട്ട് ടിവി',
        type: AttributeType.dropdown, options: ['Yes — Android TV', 'Yes — WebOS', 'Yes — TizenOS', 'No']),
    AttributeField(key: 'panel_type', label: 'Panel Type', labelMl: 'പാനൽ തരം',
        type: AttributeType.dropdown,
        options: ['LED', 'OLED', 'QLED', 'AMOLED', 'IPS']),
  ]),

  // ── Refrigerator / Fridge ────────────────────────────────────────────────
  CategoryEntry('fridge', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. LG, Samsung, Whirlpool'),
    AttributeField(key: 'capacity', label: 'Capacity (Litres)', labelMl: 'ശേഷി', hint: 'e.g. 260L, 450L'),
    AttributeField(key: 'fridge_type', label: 'Type', labelMl: 'തരം',
        type: AttributeType.dropdown,
        options: ['Single Door', 'Double Door', 'French Door', 'Side-by-Side', 'Mini Fridge']),
    AttributeField(key: 'star_rating', label: 'Star Rating', labelMl: 'ഊർജ്ജ നക്ഷത്ര റേറ്റിംഗ്',
        type: AttributeType.dropdown, options: ['1 Star', '2 Star', '3 Star', '4 Star', '5 Star']),
    AttributeField(key: 'color', label: 'Color / Finish', labelMl: 'നിറം', hint: 'e.g. Silver, Black, Red'),
  ]),

  // ── Washing Machine ───────────────────────────────────────────────────────
  CategoryEntry('washing', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. LG, Samsung, IFB'),
    AttributeField(key: 'capacity', label: 'Capacity (kg)', labelMl: 'ശേഷി', hint: 'e.g. 7kg, 8kg, 10kg'),
    AttributeField(key: 'wash_type', label: 'Type', labelMl: 'തരം',
        type: AttributeType.dropdown,
        options: ['Front Load', 'Top Load', 'Semi-Automatic']),
    AttributeField(key: 'star_rating', label: 'Star Rating', labelMl: 'ഊർജ്ജ നക്ഷത്ര റേറ്റിംഗ്',
        type: AttributeType.dropdown, options: ['1 Star', '2 Star', '3 Star', '4 Star', '5 Star']),
  ]),

  // ── AC / Air Conditioner ──────────────────────────────────────────────────
  CategoryEntry('ac', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Daikin, Voltas, LG'),
    AttributeField(key: 'capacity_ton', label: 'Capacity (Ton)', labelMl: 'ശേഷി', hint: 'e.g. 1.0, 1.5, 2.0'),
    AttributeField(key: 'ac_type', label: 'Type', labelMl: 'തരം',
        type: AttributeType.dropdown,
        options: ['Split AC', 'Window AC', 'Portable AC', 'Cassette AC']),
    AttributeField(key: 'star_rating', label: 'Star Rating', labelMl: 'ഊർജ്ജ നക്ഷത്ര',
        type: AttributeType.dropdown, options: ['2 Star', '3 Star', '4 Star', '5 Star']),
    AttributeField(key: 'inverter', label: 'Inverter AC', labelMl: 'ഇൻവർട്ടർ',
        type: AttributeType.dropdown, options: ['Yes', 'No']),
  ]),

  // ── Shoes / Footwear ─────────────────────────────────────────────────────
  CategoryEntry('shoe', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Nike, Adidas, Bata, Red Tape'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['4', '5', '6', '7', '8', '9', '10', '11', '12']),
    AttributeField(key: 'material', label: 'Material', labelMl: 'മെറ്റീരിയൽ',
        hint: 'e.g. Leather, Synthetic, Canvas, Mesh'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം', hint: 'e.g. Black, White, Brown'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
    AttributeField(key: 'closure', label: 'Closure Type', labelMl: 'ക്ലോഷർ',
        type: AttributeType.dropdown,
        options: ['Lace-up', 'Slip-on', 'Velcro', 'Zip', 'Buckle']),
  ]),

  // ── Footwear (alias) ─────────────────────────────────────────────────────
  CategoryEntry('footwear', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Bata, Khadim, Action'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['4', '5', '6', '7', '8', '9', '10', '11', '12']),
    AttributeField(key: 'material', label: 'Material', labelMl: 'മെറ്റീരിയൽ', hint: 'e.g. Leather, EVA, PVC'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
  ]),

  // ── Sandals / Slippers ────────────────────────────────────────────────────
  CategoryEntry('sandal', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Paragon, Relaxo, Bata'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['4', '5', '6', '7', '8', '9', '10', '11']),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
  ]),

  // ── Slipper (alias) ───────────────────────────────────────────────────────
  CategoryEntry('slipper', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Paragon, Relaxo, Bata'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['4', '5', '6', '7', '8', '9', '10', '11']),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
  ]),

  // ── Clothing / Garments (generic) ────────────────────────────────────────
  CategoryEntry('cloth', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Peter England, Arrow, Zara'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', 'Free Size']),
    AttributeField(key: 'material', label: 'Material / Fabric', labelMl: 'തുണി / ഫാബ്രിക്',
        hint: 'e.g. Cotton, Polyester, Silk, Linen'),
    AttributeField(key: 'color', label: 'Color / Print', labelMl: 'നിറം / പ്രിന്റ്',
        hint: 'e.g. Navy Blue, Floral Print'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
    AttributeField(key: 'care_instructions', label: 'Care Instructions', labelMl: 'പരിചരണ നിർദ്ദേശങ്ങൾ',
        hint: 'e.g. Hand wash only, Dry clean'),
  ]),

  // ── Shirt ─────────────────────────────────────────────────────────────────
  CategoryEntry('shirt', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Peter England, Van Heusen'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്',
        hint: 'e.g. Cotton, Linen, Check, Stripes'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'fit', label: 'Fit', labelMl: 'ഫിറ്റ്',
        type: AttributeType.dropdown,
        options: ['Regular Fit', 'Slim Fit', 'Loose Fit', 'Oversized']),
    AttributeField(key: 'sleeve', label: 'Sleeve', labelMl: 'കൈ',
        type: AttributeType.dropdown,
        options: ['Full Sleeve', 'Half Sleeve', 'Sleeveless']),
  ]),

  // ── T-Shirt ───────────────────────────────────────────────────────────────
  CategoryEntry('t-shirt', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. H&M, Gap, Roadster'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്', hint: 'e.g. 100% Cotton, Jersey'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
    AttributeField(key: 'sleeve', label: 'Sleeve', labelMl: 'കൈ',
        type: AttributeType.dropdown,
        options: ['Half Sleeve', 'Full Sleeve', 'Sleeveless', 'Raglan']),
  ]),

  // ── Saree / Sari ─────────────────────────────────────────────────────────
  CategoryEntry('saree', [
    AttributeField(key: 'brand', label: 'Brand / Weaver', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Kumbakonam, Handloom'),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്',
        hint: 'e.g. Pure Silk, Cotton, Chiffon, Georgette, Kasavu'),
    AttributeField(key: 'color', label: 'Color / Border', labelMl: 'നിറം / ബോർഡർ',
        hint: 'e.g. Red with Gold Border, Cream Kasavu'),
    AttributeField(key: 'length', label: 'Length (metres)', labelMl: 'നീളം', hint: 'e.g. 5.5m, 6.3m'),
    AttributeField(key: 'care_instructions', label: 'Care', labelMl: 'പരിചരണം',
        hint: 'e.g. Dry clean only, Hand wash'),
  ]),

  // ── Pants / Trousers ─────────────────────────────────────────────────────
  CategoryEntry('pant', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Levi\'s, Allen Solly'),
    AttributeField(key: 'sizes', label: 'Available Waist Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['28', '30', '32', '34', '36', '38', '40', '42']),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്',
        hint: 'e.g. Denim, Cotton, Khaki, Formal'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'fit', label: 'Fit', labelMl: 'ഫിറ്റ്',
        type: AttributeType.dropdown,
        options: ['Regular Fit', 'Slim Fit', 'Skinny', 'Relaxed', 'Wide Leg']),
  ]),

  // ── Jeans ─────────────────────────────────────────────────────────────────
  CategoryEntry('jean', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Levi\'s, Spykar, Lee'),
    AttributeField(key: 'sizes', label: 'Available Waist Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['28', '30', '32', '34', '36', '38', '40']),
    AttributeField(key: 'color', label: 'Wash / Color', labelMl: 'നിറം',
        hint: 'e.g. Dark Wash, Light Blue, Black, Distressed'),
    AttributeField(key: 'fit', label: 'Fit', labelMl: 'ഫിറ്റ്',
        type: AttributeType.dropdown,
        options: ['Slim Fit', 'Skinny', 'Regular Fit', 'Bootcut', 'Loose']),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Men', 'Women', 'Kids', 'Unisex']),
  ]),

  // ── Dress / Kurta / Kurti ────────────────────────────────────────────────
  CategoryEntry('kurta', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്',
        hint: 'e.g. Cotton, Rayon, Silk'),
    AttributeField(key: 'color', label: 'Color / Print', labelMl: 'നിറം'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Women', 'Men', 'Kids']),
  ]),

  // ── Dress ─────────────────────────────────────────────────────────────────
  CategoryEntry('dress', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['XS', 'S', 'M', 'L', 'XL', 'XXL']),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'length', label: 'Length / Type', labelMl: 'ദൈർഘ്യം',
        type: AttributeType.dropdown,
        options: ['Mini', 'Midi', 'Maxi', 'Knee Length', 'Flared', 'Bodycon']),
  ]),

  // ── Men's Wear ────────────────────────────────────────────────────────────
  CategoryEntry("men", [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
    AttributeField(key: 'material', label: 'Fabric / Material', labelMl: 'ഫാബ്രിക്',
        hint: 'e.g. Cotton, Linen, Polyester'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'care_instructions', label: 'Care', labelMl: 'പരിചരണം',
        hint: 'e.g. Machine wash, Hand wash'),
  ]),

  // ── Women's Wear ──────────────────────────────────────────────────────────
  CategoryEntry('women', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'sizes', label: 'Available Sizes', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'Free Size']),
    AttributeField(key: 'material', label: 'Fabric / Material', labelMl: 'ഫാബ്രിക്'),
    AttributeField(key: 'color', label: 'Color / Print', labelMl: 'നിറം'),
    AttributeField(key: 'care_instructions', label: 'Care', labelMl: 'പരിചരണം'),
  ]),

  // ── Kids' Wear ────────────────────────────────────────────────────────────
  CategoryEntry('kid', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'sizes', label: 'Available Sizes (Age / CM)', labelMl: 'ലഭ്യമായ സൈസുകൾ',
        type: AttributeType.chips,
        options: ['0-6m', '6-12m', '1-2y', '2-3y', '3-4y', '4-5y', '5-6y', '6-7y', '7-8y', '8-10y', '10-12y']),
    AttributeField(key: 'material', label: 'Fabric', labelMl: 'ഫാബ്രിക്',
        hint: 'e.g. Soft Cotton, Fleece'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Boys', 'Girls', 'Unisex']),
  ]),

  // ── Grocery / Food ────────────────────────────────────────────────────────
  CategoryEntry('grocery', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്',
        hint: 'e.g. Aashirvaad, Amul, Fortune, Local'),
    AttributeField(key: 'pack_size', label: 'Pack / Weight', labelMl: 'അളവ്',
        hint: 'e.g. 500g, 1kg, 5L, 250ml'),
    AttributeField(key: 'ingredients', label: 'Ingredients (optional)', labelMl: 'ചേരുവകൾ',
        hint: 'e.g. Wheat, Sugar, Salt'),
    AttributeField(key: 'allergens', label: 'Allergens (optional)', labelMl: 'അലർജി ഘടകങ്ങൾ',
        hint: 'e.g. Contains Gluten, Nuts, Dairy'),
    AttributeField(key: 'shelf_life', label: 'Shelf Life', labelMl: 'ഉപയോഗ കാലാവധി',
        hint: 'e.g. 6 months, 1 year, 3 days'),
  ]),

  // ── Food ──────────────────────────────────────────────────────────────────
  CategoryEntry('food', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. MTR, Maggi, KTC'),
    AttributeField(key: 'pack_size', label: 'Pack / Weight', labelMl: 'അളവ്',
        hint: 'e.g. 200g, 500ml, Family Pack'),
    AttributeField(key: 'ingredients', label: 'Key Ingredients', labelMl: 'ചേരുവകൾ'),
    AttributeField(key: 'allergens', label: 'Allergens', labelMl: 'അലർജി ഘടകങ്ങൾ',
        hint: 'e.g. Contains Gluten, May contain Nuts'),
    AttributeField(key: 'shelf_life', label: 'Shelf Life', labelMl: 'ഉപയോഗ കാലാവധി'),
    AttributeField(key: 'is_veg', label: 'Veg / Non-Veg', labelMl: 'സസ്യഹാരം',
        type: AttributeType.dropdown, options: ['Veg', 'Non-Veg', 'Egg', 'Vegan']),
  ]),

  // ── Snacks ────────────────────────────────────────────────────────────────
  CategoryEntry('snack', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Haldiram, Lay\'s, Balaji'),
    AttributeField(key: 'pack_size', label: 'Pack Size', labelMl: 'അളവ്', hint: 'e.g. 50g, 200g'),
    AttributeField(key: 'flavour', label: 'Flavour', labelMl: 'ഫ്ലേവർ',
        hint: 'e.g. Masala, Salted, Cheese, Plain'),
    AttributeField(key: 'allergens', label: 'Allergens', labelMl: 'അലർജി ഘടകങ്ങൾ'),
    AttributeField(key: 'is_veg', label: 'Veg / Non-Veg', labelMl: 'സസ്യഹാരം',
        type: AttributeType.dropdown, options: ['Veg', 'Non-Veg', 'Egg']),
  ]),

  // ── Beverages / Drinks ────────────────────────────────────────────────────
  CategoryEntry('beverage', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Amul, Tropicana, Nescafé'),
    AttributeField(key: 'volume', label: 'Volume / Pack Size', labelMl: 'അളവ്', hint: 'e.g. 500ml, 1L, 2L'),
    AttributeField(key: 'flavour', label: 'Flavour / Variant', labelMl: 'ഫ്ലേവർ',
        hint: 'e.g. Mango, Mixed Fruit, Plain'),
    AttributeField(key: 'is_veg', label: 'Veg / Non-Veg', labelMl: 'സസ്യഹാരം',
        type: AttributeType.dropdown, options: ['Veg', 'Non-Veg']),
  ]),

  // ── Drink (alias) ─────────────────────────────────────────────────────────
  CategoryEntry('drink', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'volume', label: 'Volume / Pack Size', labelMl: 'അളവ്', hint: 'e.g. 500ml, 1L'),
    AttributeField(key: 'flavour', label: 'Flavour', labelMl: 'ഫ്ലേവർ'),
  ]),

  // ── Dairy ─────────────────────────────────────────────────────────────────
  CategoryEntry('dairy', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Milma, Amul, Nandini'),
    AttributeField(key: 'pack_size', label: 'Pack Size', labelMl: 'അളവ്', hint: 'e.g. 500ml, 1L, 400g'),
    AttributeField(key: 'fat_percent', label: 'Fat %', labelMl: 'കൊഴുപ്പ് %',
        hint: 'e.g. 3.5%, Toned, Double Toned, Full Cream'),
  ]),

  // ── Medicine / Pharma (when category typed in general store) ─────────────
  CategoryEntry('medicine', [
    AttributeField(key: 'manufacturer', label: 'Manufacturer', labelMl: 'നിർമ്മാതാവ്',
        hint: 'e.g. Sun Pharma, Cipla, Alkem'),
    AttributeField(key: 'composition', label: 'Composition / Generic Name', labelMl: 'ഘടകങ്ങൾ',
        hint: 'e.g. Paracetamol 500mg, Amoxicillin'),
    AttributeField(key: 'strength', label: 'Strength / Dosage', labelMl: 'ശക്തി',
        hint: 'e.g. 500mg, 250mg/5ml'),
    AttributeField(key: 'form', label: 'Medicine Form', labelMl: 'മരുന്നിന്റെ രൂപം',
        type: AttributeType.dropdown,
        options: ['Tablet', 'Capsule', 'Syrup', 'Drops', 'Ointment / Cream',
            'Injection', 'Inhaler', 'Powder', 'Gel', 'Spray']),
    AttributeField(key: 'schedule', label: 'Schedule', labelMl: 'ഷെഡ്യൂൾ',
        type: AttributeType.dropdown,
        options: ['OTC (Over the Counter)', 'Prescription Required', 'H Schedule', 'X Schedule']),
  ]),

  // ── Pharma (alias) ────────────────────────────────────────────────────────
  CategoryEntry('pharma', [
    AttributeField(key: 'manufacturer', label: 'Manufacturer', labelMl: 'നിർമ്മാതാവ്'),
    AttributeField(key: 'composition', label: 'Composition', labelMl: 'ഘടകങ്ങൾ'),
    AttributeField(key: 'strength', label: 'Strength', labelMl: 'ശക്തി'),
    AttributeField(key: 'form', label: 'Form', labelMl: 'രൂപം',
        type: AttributeType.dropdown,
        options: ['Tablet', 'Capsule', 'Syrup', 'Drops', 'Ointment / Cream', 'Injection']),
    AttributeField(key: 'schedule', label: 'Schedule', labelMl: 'ഷെഡ്യൂൾ',
        type: AttributeType.dropdown,
        options: ['OTC (Over the Counter)', 'Prescription Required', 'H Schedule']),
  ]),

  // ── Tablet (medicine tab — avoid matching electronic tablet) ─────────────
  // Note: "tablet" alone is too generic; handled by 'medicine' keyword match.

  // ── Furniture ─────────────────────────────────────────────────────────────
  CategoryEntry('furniture', [
    AttributeField(key: 'material', label: 'Material', labelMl: 'മെറ്റീരിയൽ',
        hint: 'e.g. Teak Wood, Plywood, Metal, MDF'),
    AttributeField(key: 'color', label: 'Color / Finish', labelMl: 'നിറം',
        hint: 'e.g. Walnut Brown, White Gloss'),
    AttributeField(key: 'dimensions', label: 'Dimensions (L × W × H)', labelMl: 'അളവുകൾ',
        hint: 'e.g. 180 × 90 × 75 cm'),
    AttributeField(key: 'assembly', label: 'Assembly', labelMl: 'അസംബ്ലി',
        type: AttributeType.dropdown, options: ['Pre-assembled', 'Assembly Required']),
  ]),

  // ── Cosmetics / Beauty ────────────────────────────────────────────────────
  CategoryEntry('cosmetic', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Lakme, Maybelline, Lotus'),
    AttributeField(key: 'shade', label: 'Shade / Color', labelMl: 'ഷേഡ്',
        hint: 'e.g. Nude 03, Cherry Red, Natural'),
    AttributeField(key: 'skin_type', label: 'For Skin Type', labelMl: 'ചർമ്മ തരം',
        type: AttributeType.dropdown,
        options: ['All Skin Types', 'Oily', 'Dry', 'Combination', 'Sensitive', 'Normal']),
    AttributeField(key: 'volume', label: 'Volume / Net Weight', labelMl: 'അളവ്',
        hint: 'e.g. 30ml, 200g, 50gm'),
  ]),

  // ── Beauty (alias) ────────────────────────────────────────────────────────
  CategoryEntry('beauty', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്'),
    AttributeField(key: 'shade', label: 'Shade / Color', labelMl: 'ഷേഡ്'),
    AttributeField(key: 'skin_type', label: 'For Skin Type', labelMl: 'ചർമ്മ തരം',
        type: AttributeType.dropdown,
        options: ['All Skin Types', 'Oily', 'Dry', 'Combination', 'Sensitive']),
    AttributeField(key: 'volume', label: 'Volume / Net Weight', labelMl: 'അളവ്'),
  ]),

  // ── Jewellery ────────────────────────────────────────────────────────────
  CategoryEntry('jewel', [
    AttributeField(key: 'material', label: 'Material', labelMl: 'മെറ്റീരിയൽ',
        type: AttributeType.dropdown,
        options: ['Gold', 'Silver', 'Platinum', 'Artificial / Imitation', 'Stainless Steel', 'Brass']),
    AttributeField(key: 'purity', label: 'Purity / Karat', labelMl: 'ശുദ്ധത',
        hint: 'e.g. 22K, 18K, 916, 925 Silver'),
    AttributeField(key: 'weight_g', label: 'Weight (grams)', labelMl: 'ഭാരം (ഗ്രാം)',
        type: AttributeType.number, hint: 'e.g. 4.5'),
    AttributeField(key: 'gemstone', label: 'Stone / Gemstone', labelMl: 'കല്ല്',
        hint: 'e.g. Diamond, Ruby, None, CZ'),
    AttributeField(key: 'gender', label: 'For', labelMl: 'ആർക്ക്',
        type: AttributeType.dropdown, options: ['Women', 'Men', 'Kids', 'Unisex']),
  ]),

  // ── Books / Stationery ───────────────────────────────────────────────────
  CategoryEntry('book', [
    AttributeField(key: 'author', label: 'Author', labelMl: 'എഴുത്തുകാരൻ',
        hint: 'e.g. Paulo Coelho, O.V. Vijayan'),
    AttributeField(key: 'publisher', label: 'Publisher', labelMl: 'പ്രസാധകർ',
        hint: 'e.g. DC Books, Penguin, Oxford'),
    AttributeField(key: 'language', label: 'Language', labelMl: 'ഭാഷ',
        type: AttributeType.dropdown,
        options: ['Malayalam', 'English', 'Hindi', 'Tamil', 'Kannada', 'Other']),
    AttributeField(key: 'pages', label: 'Pages', labelMl: 'പേജുകൾ',
        type: AttributeType.number, hint: 'e.g. 320'),
    AttributeField(key: 'edition', label: 'Edition / Year', labelMl: 'പതിപ്പ്',
        hint: 'e.g. 3rd Edition 2023'),
  ]),

  // ── Toys ─────────────────────────────────────────────────────────────────
  CategoryEntry('toy', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Fisher-Price, Funskool'),
    AttributeField(key: 'age_group', label: 'Suitable Age', labelMl: 'അനുയോജ്യ പ്രായം',
        hint: 'e.g. 3+ years, 6-12 months'),
    AttributeField(key: 'material', label: 'Material', labelMl: 'മെറ്റീരിയൽ',
        hint: 'e.g. Plastic, Wood, Soft Fabric, Metal'),
    AttributeField(key: 'battery_required', label: 'Battery Required', labelMl: 'ബാറ്ററി ആവശ്യം',
        type: AttributeType.dropdown, options: ['Yes', 'No']),
  ]),

  // ── Sports Equipment ─────────────────────────────────────────────────────
  CategoryEntry('sport', [
    AttributeField(key: 'brand', label: 'Brand', labelMl: 'ബ്രാൻഡ്', hint: 'e.g. Yonex, SG, Cosco, Nike'),
    AttributeField(key: 'sport_type', label: 'Sport / Activity', labelMl: 'കായിക ഇനം',
        hint: 'e.g. Cricket, Badminton, Football, Gym'),
    AttributeField(key: 'material', label: 'Material', labelMl: 'മെറ്റീരിയൽ',
        hint: 'e.g. Carbon Fibre, Leather, Rubber'),
    AttributeField(key: 'color', label: 'Color', labelMl: 'നിറം'),
  ]),
];

// ─── Helper to Look Up Fields for a Category ─────────────────────────────────

/// Returns the [AttributeField] list for [category], or an empty list if no
/// schema matches. Matching is case-insensitive substring on the keyword.
List<AttributeField> getAttributeFields(String category) {
  if (category.trim().isEmpty) return [];
  final lower = category.toLowerCase();
  for (final entry in kCategoryAttributeSchema) {
    if (lower.contains(entry.keyword)) {
      return entry.fields;
    }
  }
  return [];
}
