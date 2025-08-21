import 'package:json_annotation/json_annotation.dart';

part 'ar_location_model.g.dart';

@JsonSerializable(explicitToJson: true)
class ArData {
  final List<ArLocation>? items;

  ArData({this.items});

  factory ArData.fromJson(Map<String, dynamic> json) => _$ArDataFromJson(json);
  Map<String, dynamic> toJson() => _$ArDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ArLocation {
  final int? id;
  final String? type;
  final double? latitude;
  final double? longitude;
  final Coordinates? coordinates;
  final String? pinImageUrl;
  final List<MediaShowcase>? mediaShowcases;
  final List<SocialShowcase>? socialShowcases;
  final List<ArLocationTranslation>? arLocationTranslations;
  final CulturalSite? culturalSite;
  final List<ArLocationVideo>? arLocationVideos;
  final List<ArLocation>? children;
  final bool? isActive;
  ArLocation({
    this.id,
    this.type,
    this.latitude,
    this.longitude,
    this.coordinates,
    this.pinImageUrl,
    this.mediaShowcases,
    this.socialShowcases,
    this.arLocationTranslations,
    this.culturalSite,
    this.arLocationVideos,
    this.children,
    this.isActive,
  });

  factory ArLocation.fromJson(Map<String, dynamic> json) =>
      _$ArLocationFromJson(json);
  Map<String, dynamic> toJson() => _$ArLocationToJson(this);
}

@JsonSerializable()
class Coordinates {
  final double? x;
  final double? y;
  final double? z;

  Coordinates({this.x, this.y, this.z});

  factory Coordinates.fromJson(Map<String, dynamic> json) =>
      _$CoordinatesFromJson(json);
  Map<String, dynamic> toJson() => _$CoordinatesToJson(this);
}

@JsonSerializable()
class MediaShowcase {
  final int? id;
  final String? url;
  final String? type;

  MediaShowcase({this.id, this.url, this.type});

  factory MediaShowcase.fromJson(Map<String, dynamic> json) =>
      _$MediaShowcaseFromJson(json);
  Map<String, dynamic> toJson() => _$MediaShowcaseToJson(this);
}

@JsonSerializable()
class SocialShowcase {
  final int? id;
  final String? url;

  SocialShowcase({this.id, this.url});

  factory SocialShowcase.fromJson(Map<String, dynamic> json) =>
      _$SocialShowcaseFromJson(json);
  Map<String, dynamic> toJson() => _$SocialShowcaseToJson(this);
}

@JsonSerializable()
class ArLocationTranslation {
  final int? id;
  final String? name;
  final String? description;
  final String? audioUrl;
  final String? languageCode;

  ArLocationTranslation({
    this.id,
    this.name,
    this.description,
    this.audioUrl,
    this.languageCode,
  });

  factory ArLocationTranslation.fromJson(Map<String, dynamic> json) =>
      _$ArLocationTranslationFromJson(json);
  Map<String, dynamic> toJson() => _$ArLocationTranslationToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CulturalSite {
  final int? id;
  final String? code;
  final String? mapImageUrl;
  final String? coverImageUrl;
  final bool? isActive;
  final bool? isFree;
  final List<CulturalSiteTranslation>? culturalSiteTranslations;

  CulturalSite({
    this.id,
    this.code,
    this.mapImageUrl,
    this.coverImageUrl,
    this.isActive,
    this.isFree,
    this.culturalSiteTranslations,
  });

  factory CulturalSite.fromJson(Map<String, dynamic> json) =>
      _$CulturalSiteFromJson(json);
  Map<String, dynamic> toJson() => _$CulturalSiteToJson(this);
}

@JsonSerializable()
class CulturalSiteTranslation {
  final int? id;
  final String? name;
  final String? description;
  final String? languageCode;

  CulturalSiteTranslation({
    this.id,
    this.name,
    this.description,
    this.languageCode,
  });

  factory CulturalSiteTranslation.fromJson(Map<String, dynamic> json) =>
      _$CulturalSiteTranslationFromJson(json);
  Map<String, dynamic> toJson() => _$CulturalSiteTranslationToJson(this);
}

@JsonSerializable()
class ArLocationVideo {
  final int? id;
  final String? videoUrl;
  final int? sortOrder;

  ArLocationVideo({this.id, this.videoUrl, this.sortOrder});

  factory ArLocationVideo.fromJson(Map<String, dynamic> json) =>
      _$ArLocationVideoFromJson(json);
  Map<String, dynamic> toJson() => _$ArLocationVideoToJson(this);
}
