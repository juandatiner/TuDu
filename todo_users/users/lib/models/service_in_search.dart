class ServiceInSearch {
  final int id;
  final String title;
  final String description;
  final int timeQuantity;
  final String timeUnit;
  final String budget;
  final String workerInfo;
  final bool assigned;
  final String status;
  final String createdAt;

  ServiceInSearch({
    required this.id,
    required this.title,
    required this.description,
    required this.timeQuantity,
    required this.timeUnit,
    required this.budget,
    required this.workerInfo,
    required this.assigned,
    required this.status,
    required this.createdAt,
  });

  factory ServiceInSearch.fromJson(Map<String, dynamic> json) {
    return ServiceInSearch(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      timeQuantity: json['time_quantity'],
      timeUnit: json['time_unit'],
      budget: json['budget'],
      workerInfo: json['worker_info'],
      assigned: json['assigned'] == 1,
      status: json['status'] ??
          (json['assigned'] == 1 ? 'En Proceso' : 'En Espera'),
      createdAt: json['created_at'],
    );
  }
}
