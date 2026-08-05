class Category {
  final int id;
  final String name;
  final String reviewStatus;

  Category({required this.id, required this.name, this.reviewStatus = 'approved'});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      reviewStatus: json['review_status'] ?? 'approved',
    );
  }
}

class Service {
  final int id;
  final String name;
  final String? description;
  final int? categoryId;
  final String reviewStatus;

  Service({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    this.reviewStatus = 'approved',
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      categoryId: json['category_id'],
      reviewStatus: json['review_status'] ?? 'approved',
    );
  }
}
