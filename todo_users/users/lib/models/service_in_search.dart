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

  /// Formatea un número con separadores de miles (comas) y redondea a centenas
  static String _formatBudget(String budget) {
    // Eliminar comas y puntos existentes
    final numericValue = budget.replaceAll(',', '').replaceAll('.', '');
    if (numericValue.isEmpty) return budget;

    final number = double.tryParse(numericValue);
    if (number == null) return budget;

    // Redondear a centenas (últimos 2 dígitos a 0)
    final roundedNumber = (number / 100).round() * 100;

    // Formatear con separadores de miles
    return roundedNumber.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  factory ServiceInSearch.fromJson(Map<String, dynamic> json) {
    return ServiceInSearch(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      timeQuantity: json['time_quantity'],
      timeUnit: json['time_unit'],
      budget: _formatBudget(json['budget']?.toString() ?? '0'),
      workerInfo: json['worker_info'],
      assigned: json['assigned'] == 1,
      status: json['status'] ??
          (json['assigned'] == 1 ? 'En Proceso' : 'En Espera'),
      createdAt: json['created_at'],
    );
  }
}
