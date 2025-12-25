// Category model
class CategoryModel {
  final int id;
  final int wooId;
  final String name;
  final String? slug;
  final int? parentId;
  final String? description;
  final String? imageUrl;
  final List<CategoryModel> children;

  CategoryModel({
    required this.id,
    required this.wooId,
    required this.name,
    this.slug,
    this.parentId,
    this.description,
    this.imageUrl,
    this.children = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      wooId: json['woo_id'],
      name: json['name'],
      slug: json['slug'],
      parentId: json['parent_id'],
      description: json['description'],
      imageUrl: json['image_url'],
      children: (json['children'] as List<dynamic>?)
          ?.map((child) => CategoryModel.fromJson(child))
          .toList() ?? [],
    );
  }

  bool get hasChildren => children.isNotEmpty;
}

