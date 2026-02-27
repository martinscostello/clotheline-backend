// Default Data for First-Time Launch (Offline / Empty Cache Fallback)

const Map<String, dynamic> kDefaultContent = {
  "id": "default_welcome",
  "brandText": "Welcome to",
  "heroCarousel": [
    {
      "imageUrl": "assets/images/banner_1.jpg", // Ensure this asset exists or use a reliable placeholder URL if allowable
      "title": "Welcome to Clotheline",
      "tagLine": "Premium Laundry Service",
      "titleColor": "0xFFFFFFFF",
      "tagLineColor": "0xFFEEEEEE"
    },
    {
      "imageUrl": "assets/images/banner_2.jpg",
      "title": "Fast & Reliable",
      "tagLine": "We care for your clothes",
      "titleColor": "0xFFFFFFFF",
      "tagLineColor": "0xFFEEEEEE"
    }
  ],
  "homeGridServices": [], 
  "productAds": [],
  "productCategories": ["All"],
  "contactAddress": "123 Laundry St",
  "contactPhone": "555-0123"
};

const List<Map<String, dynamic>> kDefaultProducts = [
  {
    "_id": "placeholder_1",
    "name": "Premium Detergent",
    "description": "High quality laundry detergent for all fabrics.",
    "price": 15.00,
    "imageUrls": ["assets/images/product_1.jpg"],
    "category": "Supplies",
    "inStock": true,
    "discountPercentage": 0,
    "isFeatured": true
  },
  {
    "_id": "placeholder_2",
    "name": "Fabric Softener",
    "description": "Makes your clothes feel soft and smell fresh.",
    "price": 8.50,
    "imageUrls": ["assets/images/product_2.jpg"],
    "category": "Supplies",
    "inStock": true,
    "discountPercentage": 10,
    "isFeatured": true
  },
   {
    "_id": "placeholder_3",
    "name": "Laundry Bag",
    "description": "Durable mesh bag for delicates.",
    "price": 5.00,
    "imageUrls": ["assets/images/product_3.jpg"],
    "category": "Accessories",
    "inStock": true,
    "discountPercentage": 0,
    "isFeatured": true
  }
];
