import 'package:hive/hive.dart';

part 'password_model.g.dart';

@HiveType(typeId: 0)
class PasswordModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String username;

  @HiveField(3)
  String password;

  @HiveField(4)
  String? url;

  @HiveField(5)
  DateTime createdDate;

  @HiveField(6)
  DateTime? lastModified;

  @HiveField(7)
  String category;

  PasswordModel({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    required this.createdDate,
    this.lastModified,
    this.category = 'General', // Default category
  });
}
