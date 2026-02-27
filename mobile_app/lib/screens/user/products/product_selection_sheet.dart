import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';

class ProductSelectionSheet extends StatefulWidget {
  final StoreProduct product;
  const ProductSelectionSheet({super.key, required this.product});

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  ProductVariant? _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      _selectedVariant = widget.product.variants[0];
    }
  }

  double get _currentPrice => _selectedVariant?.price ?? widget.product.price;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Image + Price + Selected Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pic
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  image: DecorationImage(
                    image: widget.product.imagePath.startsWith('http') 
                        ? NetworkImage(widget.product.imagePath) 
                        : AssetImage(widget.product.imagePath) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text("₦", style: TextStyle(color: Color(0xFFFF5722), fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(_currentPrice.toStringAsFixed(0), style: const TextStyle(color: Color(0xFFFF5722), fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.product.stockLevel < 10 ? "Only ${widget.product.stockLevel} left" : "In Stock",
                      style: TextStyle(color: widget.product.stockLevel < 10 ? Colors.red : Colors.green, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _selectedVariant != null ? "Selected: ${_selectedVariant!.name}" : "Select a variant",
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: textColor)),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          // Variants Grid
          if (widget.product.variants.isNotEmpty) ...[
            Text("Variants", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.product.variants.map((v) {
                final isSelected = _selectedVariant?.id == v.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedVariant = v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF5722).withOpacity(0.1) : (isDark ? Colors.white10 : Colors.grey.shade100),
                      border: Border.all(color: isSelected ? const Color(0xFFFF5722) : Colors.transparent),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      v.name,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFF5722) : textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Quantity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Quantity", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, size: 18, color: textColor), 
                      onPressed: () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1)
                    ),
                    Text("$_quantity", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.add, size: 18, color: textColor), 
                      onPressed: () => setState(() => _quantity = _quantity + 1)
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                // Add to Cart Logic
                final storeItem = StoreCartItem(
                  product: widget.product,
                  variant: _selectedVariant,
                  quantity: _quantity
                );
                
                // Use the CartService Singleton
                CartService().addStoreItem(storeItem);

                Navigator.pop(context);
                
                // Show Success & Offer Checkut

              },
              child: const Text("Confirm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
