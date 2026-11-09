import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'l10n.dart';
import 'store.dart';

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => MaterialApp(
        title: 'Mirror Shop',
        debugShowCheckedModeBanner: false,
        // Lets the mirror replay push/pop on every device.
        navigatorObservers: [ResponsiveMirror.navigatorObserverOf(context)],
        // A mirror variant (e.g. Arabic · Dark) wins over the app's own choice.
        locale: ResponsiveMirror.localeOf(context) ?? locale,
        themeMode: ResponsiveMirror.themeModeOf(context) ?? ThemeMode.light,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF3F51B5),
          brightness: Brightness.dark,
        ),
        routes: {'/add': (_) => const AddProductPage()},
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'title')),
          actions: [
            TextButton.icon(
              key: const ValueKey('lang_toggle'),
              onPressed: () => appLocale.value =
                  appLocale.value.languageCode == 'ar'
                      ? const Locale('en')
                      : const Locale('ar'),
              icon: const Icon(Icons.translate),
              label: Text(tr(context, 'language')),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Badge(
                label: Text('${store.cartCount}'),
                isLabelVisible: store.cartCount > 0,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('add_product'),
          onPressed: () => Navigator.of(context).pushNamed('/add'),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'add_product')),
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final products = store.visibleProducts;
          if (constraints.maxWidth < 600) {
            return ListView.separated(
              key: const ValueKey('products'),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => ProductTile(product: products[i]),
            );
          }
          final wideDesktop = constraints.maxWidth >= 1200;
          final gridWidth = constraints.maxWidth - (wideDesktop ? 240 : 0);
          final columns = (gridWidth / 260).floor().clamp(2, 6);
          final grid = GridView.builder(
            key: const ValueKey('products'),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) => ProductCard(product: products[i]),
          );
          if (!wideDesktop) return grid;
          // Desktop-only side panel: on phones and tablets it does not exist,
          // so in isolated mode a tap here marks those devices "out of sync".
          return Row(children: [
            SizedBox(
              width: 240,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(tr(context, 'categories'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final c in ShopStore.categories)
                    ListTile(
                      key: ValueKey('filter_$c'),
                      selected: store.filter == c,
                      leading: const Icon(Icons.label_outline),
                      title: Text(c),
                      onTap: () => store.filter = c,
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: grid),
          ]);
        }),
      ),
    );
  }
}

void openProduct(BuildContext context, Product p) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    settings: RouteSettings(name: '/product/${p.id}'),
    builder: (_) => ProductPage(product: p),
  ));
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('product_${product.id}'),
      leading: CircleAvatar(
        backgroundColor: Color(product.colorValue),
        child: const Icon(Icons.local_mall, color: Colors.white),
      ),
      title: Text(product.localizedName(isArabic(context))),
      subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openProduct(context, product),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('product_${product.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProduct(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Color(product.colorValue),
                child:
                    const Icon(Icons.local_mall, color: Colors.white, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.localizedName(isArabic(context)),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('\$${product.price.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductPage extends StatelessWidget {
  const ProductPage({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final image = Container(
      height: 280,
      decoration: BoxDecoration(
        color: Color(product.colorValue),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.local_mall, color: Colors.white, size: 96),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.localizedName(isArabic(context)),
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('\$${product.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        // Deliberately NOT responsive: fine on tablets and desktops, overflows
        // on phones. responsive_mirror (v0.3) flags it with a red badge.
        const PromoStrip(),
        const SizedBox(height: 16),
        Text(tr(context, 'description')),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('add_to_cart'),
          onPressed: () => store.addToCart(product),
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(tr(context, 'add_to_cart')),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(product.localizedName(isArabic(context)))),
      body: ListView(
        key: const ValueKey('product_scroll'),
        padding: const EdgeInsets.all(24),
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: image),
                const SizedBox(width: 32),
                Expanded(child: info),
              ],
            )
          else ...[
            image,
            const SizedBox(height: 24),
            info,
          ],
        ],
      ),
    );
  }
}

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    store.addProduct(_name.text.trim(), double.parse(_price.text));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'add_product'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  key: const ValueKey('name_field'),
                  controller: _name,
                  decoration: InputDecoration(labelText: tr(context, 'name')),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr(context, 'required')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('price_field'),
                  controller: _price,
                  decoration: InputDecoration(labelText: tr(context, 'price')),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? tr(context, 'number')
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('save_product'),
                  onPressed: _save,
                  child: Text(tr(context, 'save')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A promo strip with a fixed-width message. It overflows on narrow screens on
/// purpose, to show the overflow report of responsive_mirror.
class PromoStrip extends StatelessWidget {
  const PromoStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined),
          const SizedBox(width: 8),
          SizedBox(width: 300, child: Text(tr(context, 'promo'))),
          const SizedBox(width: 8),
          Chip(label: Text(tr(context, 'free'))),
        ],
      ),
    );
  }
}
