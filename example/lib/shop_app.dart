import 'package:flutter/material.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'store.dart';

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirror Shop',
      debugShowCheckedModeBanner: false,
      // Lets the mirror replay push/pop on every device.
      navigatorObservers: [ResponsiveMirror.navigatorObserverOf(context)],
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F51B5),
        brightness: Brightness.dark,
      ),
      routes: {'/add': (_) => const AddProductPage()},
      home: const HomePage(),
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
          title: const Text('Mirror Shop'),
          actions: [
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
          label: const Text('Add product'),
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final products = store.products;
          if (constraints.maxWidth < 600) {
            return ListView.separated(
              key: const ValueKey('products'),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => ProductTile(product: products[i]),
            );
          }
          final columns = (constraints.maxWidth / 260).floor().clamp(2, 6);
          return GridView.builder(
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
      title: Text(product.name),
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
                  Text(product.name,
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
        Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('\$${product.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        const Text(
          'Handmade in small batches. Every piece is a little different, '
          'which is what makes it yours.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('add_to_cart'),
          onPressed: () => store.addToCart(product),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Add to cart'),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
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
      appBar: AppBar(title: const Text('Add product')),
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
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('price_field'),
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter a number'
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('save_product'),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
