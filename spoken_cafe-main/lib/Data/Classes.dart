class Teacher {
  String? password;
  String? name;
  String? surname;
  String? phone;
  String? email;
  String? avatar;

  Teacher({
    this.password,
    this.name,
    this.surname,
    this.phone,
    this.email,
    this.avatar,
  });

  // Convert Teacher object to JSON
  Map<String, dynamic> toJson() {
    return {
      'password': password,
      'name': name,
      'surname': surname,
      'phone': phone,
      'email': email,
      'avatar': avatar,
    };
  }
}

class Student {
  final String username;
  final String password;
  final String name;
  final String surname;
  final String phone;
  final String email;
  final String avatar;

  Student({
    required this.username,
    required this.password,
    required this.name,
    required this.surname,
    required this.phone,
    required this.email,
    required this.avatar,
  });

  // Convert Student object to JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'name': name,
      'surname': surname,
      'phone': phone,
      'email': email,
      'avatar': avatar,
    };
  }
}

// Define the Lessons class
class Lessons {
  final String lessonStatus;
  final String lessonDateTime;
  final String lessonDifficulty;
  final String lessonDescription;
  final String teachername;
  final String teacherDescription;
  final String locationName;
  final String locationAddress;
  final String topicTitle;
  final String studentLimit;

  Lessons({
    required this.lessonStatus,
    required this.lessonDateTime,
    required this.lessonDifficulty,
    required this.lessonDescription,
    required this.teachername,
    required this.teacherDescription,
    required this.locationName,
    required this.locationAddress,
    required this.topicTitle,
    required this.studentLimit,
  });

  factory Lessons.fromJson(Map<String, dynamic> json) {
    return Lessons(
      lessonStatus: json['lessonStatus'],
      lessonDateTime: json['lessonDateTime'],
      lessonDifficulty: json['lessonDifficulty'],
      lessonDescription: json['lessonDescription'],
      teachername: json['teachername'],
      teacherDescription: json['teacherDescription'],
      locationName: json['locationName'],
      locationAddress: json['locationAddress'],
      topicTitle: json['topicTitle'],
      studentLimit: json['studentLimit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lessonStatus': lessonStatus,
      'lessonDateTime': lessonDateTime,
      'lessonDifficulty': lessonDifficulty,
      'lessonDescription': lessonDescription,
      'teachername': teachername,
      'teacherDescription': teacherDescription,
      'locationName': locationName,
      'locationAddress': locationAddress,
      'topicTitle': topicTitle,
      'studentLimit': studentLimit,
    };
  }
}
