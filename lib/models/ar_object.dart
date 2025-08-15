class ARObject {
  final String id;
  final String type;
  final String? content;
  final String? imagePath;
  final String? modelPath;
  final double scale;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double positionX;
  final double positionY;
  final double positionZ;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ARObject({
    required this.id,
    required this.type,
    this.content,
    this.imagePath,
    this.modelPath,
    this.scale = 1.0,
    this.rotationX = 0.0,
    this.rotationY = 0.0,
    this.rotationZ = 0.0,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.positionZ = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory ARObject.fromJson(Map<String, dynamic> json) {
    return ARObject(
      id: json['objectId'] ?? json['id'] ?? '',
      type: json['objectType'] ?? json['type'] ?? 'unknown',
      content: json['content'],
      imagePath: json['imagePath'],
      modelPath: json['modelPath'],
      scale: (json['scale'] ?? 1.0).toDouble(),
      rotationX: (json['rotationX'] ?? 0.0).toDouble(),
      rotationY: (json['rotationY'] ?? 0.0).toDouble(),
      rotationZ: (json['rotationZ'] ?? 0.0).toDouble(),
      positionX: (json['positionX'] ?? 0.0).toDouble(),
      positionY: (json['positionY'] ?? 0.0).toDouble(),
      positionZ: (json['positionZ'] ?? 0.0).toDouble(),
      createdAt: json['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num).toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'objectId': id,
      'objectType': type,
      'content': content,
      'imagePath': imagePath,
      'modelPath': modelPath,
      'scale': scale,
      'rotationX': rotationX,
      'rotationY': rotationY,
      'rotationZ': rotationZ,
      'positionX': positionX,
      'positionY': positionY,
      'positionZ': positionZ,
      'timestamp': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  ARObject copyWith({
    String? id,
    String? type,
    String? content,
    String? imagePath,
    String? modelPath,
    double? scale,
    double? rotationX,
    double? rotationY,
    double? rotationZ,
    double? positionX,
    double? positionY,
    double? positionZ,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ARObject(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      modelPath: modelPath ?? this.modelPath,
      scale: scale ?? this.scale,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      rotationZ: rotationZ ?? this.rotationZ,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      positionZ: positionZ ?? this.positionZ,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ARObject(id: $id, type: $type, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ARObject && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum ARObjectType {
  text('text'),
  image('image'),
  model('model'),
  video('video');

  const ARObjectType(this.value);
  final String value;

  static ARObjectType fromString(String value) {
    return ARObjectType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ARObjectType.text,
    );
  }
}
