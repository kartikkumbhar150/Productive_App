enum ProductivityType { productive, neutral, wasted }

class TimeSlot {
  final String? id;
  final String date;
  final String timeRange; // e.g., '09:00-09:20'
  final String taskSelected;
  final String category;
  final ProductivityType type;

  TimeSlot({
    this.id,
    required this.date,
    required this.timeRange,
    required this.taskSelected,
    required this.category,
    required this.type,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['_id'],
      date: json['date'],
      timeRange: json['timeRange'],
      taskSelected: json['taskSelected'],
      category: json['category'],
      type: ProductivityType.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == json['productivityType'].toString().toLowerCase(),
          orElse: () => ProductivityType.neutral),
    );
  }

  Map<String, dynamic> toJson() {
    final typeName = type.toString().split('.').last;
    final capitalizedType = typeName[0].toUpperCase() + typeName.substring(1);
    return {
      'date': date,
      'timeRange': timeRange,
      'taskSelected': taskSelected,
      'category': category,
      'productivityType': capitalizedType,
    };
  }
}
