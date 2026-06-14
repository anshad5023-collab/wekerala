/// Per-shop-type product attribute schema.
///
/// Each shop type defines a list of [ProductFieldSpec] entries.
/// These become dynamic form fields in AddProductScreen and are
/// stored under products/{id}.attributes in Firestore.

enum ProductFieldType { text, number, dropdown }

class ProductFieldSpec {
  final String key;
  final String labelEn;
  final String labelMl;
  final ProductFieldType type;
  final List<String> options;
  final String hint;
  final bool required;

  const ProductFieldSpec({
    required this.key,
    required this.labelEn,
    required this.labelMl,
    this.type = ProductFieldType.text,
    this.options = const [],
    this.hint = '',
    this.required = false,
  });
}

const Map<String, List<ProductFieldSpec>> kShopTypeProductSchema = {
  'Pharmacy': [
    ProductFieldSpec(
      key: 'manufacturer',
      labelEn: 'Manufacturer',
      labelMl: 'നിർമ്മാതാവ്',
      hint: 'e.g. Sun Pharma, Cipla, Alkem',
    ),
    ProductFieldSpec(
      key: 'composition',
      labelEn: 'Composition / Generic Name',
      labelMl: 'ഘടകങ്ങൾ / ജനറിക് പേര്',
      hint: 'e.g. Paracetamol, Metformin HCl',
    ),
    ProductFieldSpec(
      key: 'strength',
      labelEn: 'Strength / Dosage',
      labelMl: 'ശക്തി / ഡോസ്',
      hint: 'e.g. 500mg, 10mg/5ml, 250mcg',
    ),
    ProductFieldSpec(
      key: 'form',
      labelEn: 'Medicine Form',
      labelMl: 'മരുന്നിന്റെ രൂപം',
      type: ProductFieldType.dropdown,
      options: [
        'Tablet', 'Capsule', 'Syrup', 'Drops', 'Ointment / Cream',
        'Injection', 'Inhaler', 'Powder', 'Gel', 'Spray', 'Patch', 'Suppository',
      ],
    ),
    ProductFieldSpec(
      key: 'schedule',
      labelEn: 'Schedule / OTC',
      labelMl: 'ഷെഡ്യൂൾ',
      type: ProductFieldType.dropdown,
      options: ['OTC (Over the Counter)', 'Prescription Required', 'H Schedule', 'X Schedule'],
    ),
  ],

  'Textile': [
    ProductFieldSpec(
      key: 'fabric',
      labelEn: 'Fabric / Material',
      labelMl: 'തുണിത്തരം / മെറ്റീരിയൽ',
      hint: 'e.g. Cotton, Silk, Polyester, Khadi, Linen',
    ),
    ProductFieldSpec(
      key: 'gender',
      labelEn: 'For',
      labelMl: 'ആർക്ക് വേണ്ടി',
      type: ProductFieldType.dropdown,
      options: ['Men', 'Women', 'Kids', 'Unisex'],
    ),
    ProductFieldSpec(
      key: 'sizes',
      labelEn: 'Available Sizes',
      labelMl: 'ലഭ്യമായ സൈസുകൾ',
      hint: 'e.g. S, M, L, XL  or  28-36  or  Free Size',
    ),
    ProductFieldSpec(
      key: 'color',
      labelEn: 'Colour / Print',
      labelMl: 'നിറം / പ്രിന്റ്',
      hint: 'e.g. Red, Navy Blue Stripes, Floral Print',
    ),
    ProductFieldSpec(
      key: 'care_instructions',
      labelEn: 'Care Instructions',
      labelMl: 'പരിചരണ നിർദ്ദേശങ്ങൾ',
      hint: 'e.g. Hand wash, Dry clean only, Machine wash cold',
    ),
  ],

  'Electronics': [
    ProductFieldSpec(
      key: 'brand',
      labelEn: 'Brand',
      labelMl: 'ബ്രാൻഡ്',
      hint: 'e.g. Samsung, Philips, Bosch, OnePlus',
    ),
    ProductFieldSpec(
      key: 'model_number',
      labelEn: 'Model Number / SKU',
      labelMl: 'മോഡൽ നമ്പർ',
      hint: 'e.g. SM-A135F, MH-1701',
    ),
    ProductFieldSpec(
      key: 'warranty_months',
      labelEn: 'Warranty (months)',
      labelMl: 'വാറന്റി (മാസങ്ങൾ)',
      type: ProductFieldType.number,
      hint: 'e.g. 12',
    ),
    ProductFieldSpec(
      key: 'compatible_with',
      labelEn: 'Compatible With',
      labelMl: 'പൊരുത്തപ്പെടുന്നത്',
      hint: 'e.g. All Android, iPhone 13/14, Universal',
    ),
    ProductFieldSpec(
      key: 'power_watts',
      labelEn: 'Power (Watts)',
      labelMl: 'പവർ (വാട്ട്)',
      hint: 'e.g. 1200W — for appliances only',
    ),
  ],

  'Hotel / Restaurant': [
    ProductFieldSpec(
      key: 'is_veg',
      labelEn: 'Veg / Non-Veg',
      labelMl: 'സസ്യഹാരം / മാംസഹാരം',
      type: ProductFieldType.dropdown,
      options: ['Veg', 'Non-Veg', 'Egg', 'Vegan'],
      required: true,
    ),
    ProductFieldSpec(
      key: 'spice_level',
      labelEn: 'Spice Level',
      labelMl: 'എരിവ് നില',
      type: ProductFieldType.dropdown,
      options: ['Mild', 'Medium', 'Hot', 'Extra Hot'],
    ),
    ProductFieldSpec(
      key: 'prep_time_min',
      labelEn: 'Prep Time (minutes)',
      labelMl: 'തയ്യാറാകാൻ ആവശ്യമായ സമയം (മിനിറ്റ്)',
      type: ProductFieldType.number,
      hint: 'e.g. 15',
    ),
    ProductFieldSpec(
      key: 'serves',
      labelEn: 'Serves (persons)',
      labelMl: 'എത്ര പേർക്ക്',
      type: ProductFieldType.number,
      hint: 'e.g. 2',
    ),
    ProductFieldSpec(
      key: 'allergens',
      labelEn: 'Allergens',
      labelMl: 'അലർജി ഘടകങ്ങൾ',
      hint: 'e.g. Nuts, Dairy, Gluten, Shellfish',
    ),
  ],

  'Bakery': [
    ProductFieldSpec(
      key: 'is_veg',
      labelEn: 'Veg / Non-Veg',
      labelMl: 'സസ്യഹാരം / മാംസഹാരം',
      type: ProductFieldType.dropdown,
      options: ['Veg', 'Non-Veg', 'Egg', 'Vegan'],
      required: true,
    ),
    ProductFieldSpec(
      key: 'shelf_life_days',
      labelEn: 'Shelf Life (days)',
      labelMl: 'ഉപയോഗ കാലാവധി (ദിവസം)',
      type: ProductFieldType.number,
      hint: 'e.g. 3',
    ),
    ProductFieldSpec(
      key: 'weight_g',
      labelEn: 'Weight (grams)',
      labelMl: 'ഭാരം (ഗ്രാം)',
      type: ProductFieldType.number,
      hint: 'e.g. 500',
    ),
    ProductFieldSpec(
      key: 'serving_temp',
      labelEn: 'Best Served',
      labelMl: 'ഏറ്റവും നല്ലത്',
      type: ProductFieldType.dropdown,
      options: ['Hot', 'Cold', 'Room Temperature'],
    ),
    ProductFieldSpec(
      key: 'allergens',
      labelEn: 'Allergens',
      labelMl: 'അലർജി ഘടകങ്ങൾ',
      hint: 'e.g. Gluten, Dairy, Eggs, Nuts',
    ),
  ],

  'Meat & Fish': [
    ProductFieldSpec(
      key: 'cut_type',
      labelEn: 'Cut / Preparation',
      labelMl: 'മുറിക്കൽ / തയ്യാറാക്കൽ',
      hint: 'e.g. Full, Half, Boneless, Curry Cut, Cleaned',
    ),
    ProductFieldSpec(
      key: 'is_cleaned',
      labelEn: 'Cleaned & Ready',
      labelMl: 'ശുദ്ധമാക്കി തയ്യാറാക്കിയത്',
      type: ProductFieldType.dropdown,
      options: ['Yes', 'No'],
    ),
    ProductFieldSpec(
      key: 'source',
      labelEn: 'Source / Origin',
      labelMl: 'ഉറവിടം',
      hint: 'e.g. Local Farm, Kerala Coastal, Imported',
    ),
    ProductFieldSpec(
      key: 'min_weight_g',
      labelEn: 'Min Order Weight (grams)',
      labelMl: 'കുറഞ്ഞ ഓർഡർ ഭാരം (ഗ്രാം)',
      type: ProductFieldType.number,
      hint: 'e.g. 250',
    ),
  ],

  'Grocery': [
    ProductFieldSpec(
      key: 'brand',
      labelEn: 'Brand',
      labelMl: 'ബ്രാൻഡ്',
      hint: 'e.g. Aashirvaad, Amul, Fortune, Nestlé',
    ),
    ProductFieldSpec(
      key: 'pack_size',
      labelEn: 'Pack / Volume Size',
      labelMl: 'പാക്ക് / അളവ്',
      hint: 'e.g. 500g, 1kg, 5L, 200ml',
    ),
    ProductFieldSpec(
      key: 'country_of_origin',
      labelEn: 'Country / Origin',
      labelMl: 'ഉത്ഭവ രാജ്യം',
      hint: 'e.g. India, Organic Kerala, Imported',
    ),
  ],

  'Vegetable & Fruit': [
    ProductFieldSpec(
      key: 'variety',
      labelEn: 'Variety',
      labelMl: 'ഇനം',
      hint: 'e.g. Kerala Nadan, Hybrid, Organic',
    ),
    ProductFieldSpec(
      key: 'origin',
      labelEn: 'Origin / Farm',
      labelMl: 'ഉറവിടം / ഫാം',
      hint: 'e.g. Wayanad, Palakkad, Local',
    ),
    ProductFieldSpec(
      key: 'grade',
      labelEn: 'Grade',
      labelMl: 'ഗ്രേഡ്',
      type: ProductFieldType.dropdown,
      options: ['Premium', 'Standard', 'Economy'],
    ),
  ],

  'Stationery': [
    ProductFieldSpec(
      key: 'brand',
      labelEn: 'Brand',
      labelMl: 'ബ്രാൻഡ്',
      hint: 'e.g. Camlin, Classmate, Staedtler, Cello',
    ),
    ProductFieldSpec(
      key: 'color',
      labelEn: 'Colour',
      labelMl: 'നിറം',
      hint: 'e.g. Blue, Black, Assorted, Multi-colour',
    ),
    ProductFieldSpec(
      key: 'pack_contains',
      labelEn: 'Pack Contains',
      labelMl: 'പാക്കിൽ ഉള്ളത്',
      hint: 'e.g. 10 pens, Set of 12, Single piece',
    ),
  ],

  'Fancy Store': [
    ProductFieldSpec(
      key: 'color',
      labelEn: 'Colour / Shade',
      labelMl: 'നിറം / ഷേഡ്',
      hint: 'e.g. Rose Gold, Silver, Multicolour',
    ),
    ProductFieldSpec(
      key: 'material',
      labelEn: 'Material',
      labelMl: 'മെറ്റീരിയൽ',
      hint: 'e.g. Acrylic, Metal, Cloth, Plastic',
    ),
    ProductFieldSpec(
      key: 'occasion',
      labelEn: 'Occasion / Use',
      labelMl: 'അവസരം / ഉപയോഗം',
      hint: 'e.g. Wedding, Birthday, Daily, Festival',
    ),
  ],

  'General Store': [
    ProductFieldSpec(
      key: 'brand',
      labelEn: 'Brand',
      labelMl: 'ബ്രാൻഡ്',
      hint: 'e.g. Himalaya, Dabur, Nirma',
    ),
    ProductFieldSpec(
      key: 'pack_size',
      labelEn: 'Pack / Volume',
      labelMl: 'പാക്ക് / അളവ്',
      hint: 'e.g. 200ml, 1kg, 100g',
    ),
  ],
};
