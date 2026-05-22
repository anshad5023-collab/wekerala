class Festival {
  final String name;
  final String emoji;
  final String templateEn;
  final String templateMl;

  const Festival({
    required this.name,
    required this.emoji,
    required this.templateEn,
    required this.templateMl,
  });
}

const kFestivals = [
  Festival(
    name: 'Onam',
    emoji: '🌸',
    templateEn:
        'Happy Onam! 🌸🌼\n\nWishing you and your family a joyful and prosperous Onam. May this harvest festival bring happiness and abundance to your home.\n\nThank you for being our valued customer. Visit us for special Onam offers!\n\n- {shopName}',
    templateMl:
        'ഓണാശംസകൾ! 🌸🌼\n\nനിങ്ങൾക്കും കുടുംബത്തിനും സന്തോഷകരവും സമൃദ്ധവുമായ ഓണം ആശംസിക്കുന്നു. ഈ വിള ഉത്സവം നിങ്ങളുടെ വീടിന് സന്തോഷവും സമൃദ്ധിയും കൊണ്ടുവരട്ടെ.\n\nഞങ്ങളുടെ വിലയേറിയ ഉപഭോക്താവ് ആയതിന് നന്ദി. ഓണം ഓഫറുകൾക്കായി സന്ദർശിക്കൂ!\n\n- {shopName}',
  ),
  Festival(
    name: 'Vishu',
    emoji: '🌼',
    templateEn:
        'Happy Vishu! 🌼✨\n\nWishing you a bright and blessed Vishu. May the Vishukkani bring you prosperity, good health, and happiness throughout the year.\n\nWith warm regards,\n{shopName}',
    templateMl:
        'വിഷു ആശംസകൾ! 🌼✨\n\nതിളക്കമേറിയ ഒരു വിഷു ആശംസിക്കുന്നു. വിഷുക്കണി നിങ്ങൾക്ക് ഐശ്വര്യം, ആരോഗ്യം, സന്തോഷം എന്നിവ കൊണ്ടുവരട്ടെ.\n\nസ്നേഹത്തോടെ,\n{shopName}',
  ),
  Festival(
    name: 'Eid',
    emoji: '🌙',
    templateEn:
        'Eid Mubarak! 🌙⭐\n\nWishing you and your family a joyful Eid filled with love, happiness, and togetherness. May Allah bless you with peace and prosperity.\n\nWarm wishes,\n{shopName}',
    templateMl:
        'ഈദ് മുബാറക്! 🌙⭐\n\nനിങ്ങൾക്കും കുടുംബത്തിനും സ്നേഹവും സന്തോഷവും ഒരുമയും നിറഞ്ഞ ഈദ് ആശംസിക്കുന്നു. അല്ലാഹു നിങ്ങൾക്ക് സമാധാനവും സമൃദ്ധിയും നൽകട്ടെ.\n\nആശംസകളോടെ,\n{shopName}',
  ),
  Festival(
    name: 'Christmas',
    emoji: '🎄',
    templateEn:
        'Merry Christmas! 🎄🎅\n\nWishing you a wonderful Christmas filled with joy, love, and warmth. May this festive season bring peace and happiness to you and your loved ones.\n\nSeason\'s Greetings,\n{shopName}',
    templateMl:
        'ക്രിസ്മസ് ആശംസകൾ! 🎄🎅\n\nസന്തോഷവും സ്നേഹവും ഊഷ്മളതയും നിറഞ്ഞ ഒരു ക്രിസ്മസ് ആശംസിക്കുന്നു. ഈ ഉത്സവ കാലം നിങ്ങൾക്കും പ്രിയപ്പെട്ടവർക്കും സമാധാനവും സന്തോഷവും നൽകട്ടെ.\n\nആശംസകളോടെ,\n{shopName}',
  ),
  Festival(
    name: 'Diwali',
    emoji: '🪔',
    templateEn:
        'Happy Diwali! 🪔✨\n\nWishing you a dazzling Diwali! May the festival of lights bring brightness, success, and happiness into your life.\n\nWith warm wishes,\n{shopName}',
    templateMl:
        'ദീപാവലി ആശംസകൾ! 🪔✨\n\nദീപോത്സവം നിങ്ങളുടെ ജീവിതത്തിൽ വെളിച്ചവും വിജയവും സന്തോഷവും കൊണ്ടുവരട്ടെ.\n\nആശംസകളോടെ,\n{shopName}',
  ),
  Festival(
    name: 'New Year',
    emoji: '🎉',
    templateEn:
        'Happy New Year! 🎉🥂\n\nWishing you a fantastic new year filled with new opportunities, success, and joy. Thank you for your continued support!\n\nWith gratitude,\n{shopName}',
    templateMl:
        'പുതുവർഷ ആശംസകൾ! 🎉🥂\n\nപുതിയ അവസരങ്ങളും വിജയവും സന്തോഷവും നിറഞ്ഞ ഒരു പുതുവർഷം ആശംസിക്കുന്നു. നിരന്തര പിന്തുണക്ക് നന്ദി!\n\nനന്ദിയോടെ,\n{shopName}',
  ),
  Festival(
    name: 'Ramadan',
    emoji: '🕌',
    templateEn:
        'Ramadan Kareem! 🕌🌙\n\nWishing you a blessed and peaceful Ramadan. May this holy month bring you closer to your goals and fill your heart with gratitude.\n\n{shopName}',
    templateMl:
        'റമദാൻ കരീം! 🕌🌙\n\nഅനുഗ്രഹകരവും സമാധാനപൂർണ്ണവുമായ ഒരു റമദാൻ ആശംสിക്കുന്നു. ഈ വിശുദ്ധ മാസം നിങ്ങളെ ലക്ഷ്യങ്ങളോട് അടുപ്പിക്കട്ടെ.\n\n{shopName}',
  ),
  Festival(
    name: 'Thiruvonam',
    emoji: '🛶',
    templateEn:
        'Happy Thiruvonam! 🛶🌸\n\nWishing you and your family the very best on this auspicious day of Onam. May your life be as colourful as the pookalam!\n\n{shopName}',
    templateMl:
        'തിരുവോണ ആശംസകൾ! 🛶🌸\n\nഈ ശുഭദിനത്തിൽ നിങ്ങൾക്കും കുടുംബത്തിനും ഏറ്റവും നല്ലത് ആശംസിക്കുന്നു. നിങ്ങളുടെ ജീവിതം പൂക്കളം പോലെ വർണ്ണമയമാകട്ടെ!\n\n{shopName}',
  ),
];
