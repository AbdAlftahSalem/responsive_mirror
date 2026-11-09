import 'package:flutter/widgets.dart';

/// Tiny string table, enough for an English / Arabic demo.
const _strings = <String, Map<String, String>>{
  'title': {'en': 'Mirror Shop', 'ar': 'متجر المرآة'},
  'add_product': {'en': 'Add product', 'ar': 'إضافة منتج'},
  'add_to_cart': {'en': 'Add to cart', 'ar': 'أضف إلى السلة'},
  'name': {'en': 'Name', 'ar': 'الاسم'},
  'price': {'en': 'Price', 'ar': 'السعر'},
  'save': {'en': 'Save', 'ar': 'حفظ'},
  'required': {'en': 'Required', 'ar': 'مطلوب'},
  'number': {'en': 'Enter a number', 'ar': 'أدخل رقماً'},
  'language': {'en': 'العربية', 'ar': 'English'},
  'description': {
    'en': 'Handmade in small batches. Every piece is a little different, '
        'which is what makes it yours.',
    'ar': 'مصنوع يدوياً بكميات صغيرة. كل قطعة مختلفة قليلاً، '
        'وهذا ما يجعلها لك.',
  },
};

String tr(BuildContext context, String key) {
  final lang = Localizations.localeOf(context).languageCode;
  final entry = _strings[key];
  if (entry == null) return key;
  return entry[lang] ?? entry['en']!;
}

bool isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';
