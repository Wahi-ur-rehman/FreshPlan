// lib/models/pantry_item.dart
// ─────────────────────────────────────────────────────────────────────────────
// Using plain Dart classes (no codegen needed for simplicity).
// In production, add freezed annotations and run build_runner.
// ─────────────────────────────────────────────────────────────────────────────

class PantryItem {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String storageLocation;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final DateTime? purchaseDate;
  final String? brand;
  final String? notes;
  final String? barcode;
  final String? imageUrl;
  final bool isStaple;
  final double? caloriesPer100g;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PantryItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.storageLocation,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.purchaseDate,
    this.brand,
    this.notes,
    this.barcode,
    this.imageUrl,
    this.isStaple = false,
    this.caloriesPer100g,
    required this.createdAt,
    required this.updatedAt,
  });

  ExpiryStatus get expiryStatus {
    if (expiryDate == null) return ExpiryStatus.fresh;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    final daysLeft = expiry.difference(today).inDays;
    if (daysLeft < 0) return ExpiryStatus.expired;
    if (daysLeft <= 3) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.fresh;
  }

  int get daysUntilExpiry {
    if (expiryDate == null) return 999;
    final now = DateTime.now();
    return expiryDate!.difference(now).inDays;
  }

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String? ?? 'other',
    storageLocation: json['storage_location'] as String? ?? 'pantry',
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String? ?? 'pcs',
    expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
    purchaseDate: json['purchase_date'] != null ? DateTime.parse(json['purchase_date']) : null,
    brand: json['brand'] as String?,
    notes: json['notes'] as String?,
    barcode: json['barcode'] as String?,
    imageUrl: json['image_url'] as String?,
    isStaple: json['is_staple'] as bool? ?? false,
    caloriesPer100g: json['calories_per_100g'] != null ? (json['calories_per_100g'] as num).toDouble() : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'category': category,
    'storage_location': storageLocation,
    'quantity': quantity,
    'unit': unit,
    'expiry_date': expiryDate?.toIso8601String().split('T').first,
    'purchase_date': purchaseDate?.toIso8601String().split('T').first,
    'brand': brand,
    'notes': notes,
    'barcode': barcode,
    'image_url': imageUrl,
    'is_staple': isStaple,
    'calories_per_100g': caloriesPer100g,
  };

  Map<String, dynamic> toInsertJson() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  PantryItem copyWith({
    String? id, String? userId, String? name, String? category,
    String? storageLocation, double? quantity, String? unit,
    DateTime? expiryDate, DateTime? purchaseDate, String? brand,
    String? notes, String? barcode, String? imageUrl, bool? isStaple,
    double? caloriesPer100g, DateTime? createdAt, DateTime? updatedAt,
  }) => PantryItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    category: category ?? this.category,
    storageLocation: storageLocation ?? this.storageLocation,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    expiryDate: expiryDate ?? this.expiryDate,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    brand: brand ?? this.brand,
    notes: notes ?? this.notes,
    barcode: barcode ?? this.barcode,
    imageUrl: imageUrl ?? this.imageUrl,
    isStaple: isStaple ?? this.isStaple,
    caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum ExpiryStatus { fresh, expiringSoon, expired }

// ─────────────────────────────────────────────────────────────────────────────
// Recipe
// ─────────────────────────────────────────────────────────────────────────────
class Recipe {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final int? prepTimeMins;
  final int? cookTimeMins;
  final int servings;
  final String? cuisine;
  final String? difficulty;
  final List<String> tags;
  final NutritionInfo? nutritionInfo;
  final String? imageUrl;
  final bool aiGenerated;
  final bool isFavourite;
  final int wasteSavedG;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.ingredients,
    required this.instructions,
    this.prepTimeMins,
    this.cookTimeMins,
    this.servings = 2,
    this.cuisine,
    this.difficulty,
    this.tags = const [],
    this.nutritionInfo,
    this.imageUrl,
    this.aiGenerated = true,
    this.isFavourite = false,
    this.wasteSavedG = 0,
    required this.createdAt,
  });

  int get totalTimeMins => (prepTimeMins ?? 0) + (cookTimeMins ?? 0);

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredientsRaw = json['ingredients'];
    List<RecipeIngredient> ingredients = [];
    if (ingredientsRaw is List) {
      ingredients = ingredientsRaw
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final instructionsRaw = json['instructions'];
    List<String> instructions = [];
    if (instructionsRaw is List) {
      instructions = instructionsRaw.map((e) => e.toString()).toList();
    }

    final tagsRaw = json['tags'];
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    }

    return Recipe(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      ingredients: ingredients,
      instructions: instructions,
      prepTimeMins: json['prep_time_mins'] as int?,
      cookTimeMins: json['cook_time_mins'] as int?,
      servings: json['servings'] as int? ?? 2,
      cuisine: json['cuisine'] as String?,
      difficulty: json['difficulty'] as String?,
      tags: tags,
      nutritionInfo: json['nutrition_info'] != null
          ? NutritionInfo.fromJson(json['nutrition_info'] as Map<String, dynamic>)
          : null,
      imageUrl: json['image_url'] as String?,
      aiGenerated: json['ai_generated'] as bool? ?? true,
      isFavourite: json['is_favourite'] as bool? ?? false,
      wasteSavedG: json['waste_saved_g'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Recipe copyWith({bool? isFavourite}) => Recipe(
    id: id, userId: userId, title: title, description: description,
    ingredients: ingredients, instructions: instructions,
    prepTimeMins: prepTimeMins, cookTimeMins: cookTimeMins,
    servings: servings, cuisine: cuisine, difficulty: difficulty,
    tags: tags, nutritionInfo: nutritionInfo, imageUrl: imageUrl,
    aiGenerated: aiGenerated, isFavourite: isFavourite ?? this.isFavourite,
    wasteSavedG: wasteSavedG, createdAt: createdAt,
  );
}

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final String? notes;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.notes,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
    unit: json['unit'] as String? ?? 'pcs',
    notes: json['notes'] as String?,
  );
}

class NutritionInfo {
  final double? caloriesPerServing;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;

  const NutritionInfo({
    this.caloriesPerServing,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) => NutritionInfo(
    caloriesPerServing: (json['calories_per_serving'] as num?)?.toDouble(),
    proteinG: (json['protein_g'] as num?)?.toDouble(),
    carbsG: (json['carbs_g'] as num?)?.toDouble(),
    fatG: (json['fat_g'] as num?)?.toDouble(),
    fiberG: (json['fiber_g'] as num?)?.toDouble(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shopping Item
// ─────────────────────────────────────────────────────────────────────────────
class ShoppingItem {
  final String id;
  final String listId;
  final String userId;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final double? estimatedPrice;
  final String status;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.listId,
    required this.userId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.estimatedPrice,
    required this.status,
    this.notes,
    required this.sortOrder,
    required this.createdAt,
  });

  bool get isPurchased => status == 'purchased';
  bool get isInCart => status == 'in_cart';

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    listId: json['list_id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String? ?? 'pcs',
    category: json['category'] as String? ?? 'other',
    estimatedPrice: json['estimated_price'] != null ? (json['estimated_price'] as num).toDouble() : null,
    status: json['status'] as String? ?? 'pending',
    notes: json['notes'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  ShoppingItem copyWith({String? status}) => ShoppingItem(
    id: id, listId: listId, userId: userId, name: name,
    quantity: quantity, unit: unit, category: category,
    estimatedPrice: estimatedPrice, status: status ?? this.status,
    notes: notes, sortOrder: sortOrder, createdAt: createdAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// User Profile
// ─────────────────────────────────────────────────────────────────────────────
class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int householdSize;
  final List<String> dietaryPrefs;
  final List<String> allergens;
  final int sustainabilityScore;
  final int totalWasteSavedG;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.householdSize = 2,
    this.dietaryPrefs = const [],
    this.allergens = const [],
    this.sustainabilityScore = 0,
    this.totalWasteSavedG = 0,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      householdSize: json['household_size'] as int? ?? 2,
      dietaryPrefs: parseList(json['dietary_prefs']),
      allergens: parseList(json['allergens']),
      sustainabilityScore: json['sustainability_score'] as int? ?? 0,
      totalWasteSavedG: json['total_waste_saved_g'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'household_size': householdSize,
    'dietary_prefs': dietaryPrefs,
    'allergens': allergens,
  };
}
