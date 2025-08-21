// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ar_location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArData _$ArDataFromJson(Map<String, dynamic> json) => ArData(
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => ArLocation.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ArDataToJson(ArData instance) => <String, dynamic>{
  'items': instance.items?.map((e) => e.toJson()).toList(),
};

ArLocation _$ArLocationFromJson(Map<String, dynamic> json) => ArLocation(
  id: (json['id'] as num?)?.toInt(),
  type: json['type'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  coordinates: json['coordinates'] == null
      ? null
      : Coordinates.fromJson(json['coordinates'] as Map<String, dynamic>),
  pinImageUrl: json['pinImageUrl'] as String?,
  mediaShowcases: (json['mediaShowcases'] as List<dynamic>?)
      ?.map((e) => MediaShowcase.fromJson(e as Map<String, dynamic>))
      .toList(),
  socialShowcases: (json['socialShowcases'] as List<dynamic>?)
      ?.map((e) => SocialShowcase.fromJson(e as Map<String, dynamic>))
      .toList(),
  arLocationTranslations: (json['arLocationTranslations'] as List<dynamic>?)
      ?.map((e) => ArLocationTranslation.fromJson(e as Map<String, dynamic>))
      .toList(),
  culturalSite: json['culturalSite'] == null
      ? null
      : CulturalSite.fromJson(json['culturalSite'] as Map<String, dynamic>),
  arLocationVideos: (json['arLocationVideos'] as List<dynamic>?)
      ?.map((e) => ArLocationVideo.fromJson(e as Map<String, dynamic>))
      .toList(),
  children: (json['children'] as List<dynamic>?)
      ?.map((e) => ArLocation.fromJson(e as Map<String, dynamic>))
      .toList(),
  isActive: json['isActive'] as bool?,
);

Map<String, dynamic> _$ArLocationToJson(
  ArLocation instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'coordinates': instance.coordinates?.toJson(),
  'pinImageUrl': instance.pinImageUrl,
  'mediaShowcases': instance.mediaShowcases?.map((e) => e.toJson()).toList(),
  'socialShowcases': instance.socialShowcases?.map((e) => e.toJson()).toList(),
  'arLocationTranslations': instance.arLocationTranslations
      ?.map((e) => e.toJson())
      .toList(),
  'culturalSite': instance.culturalSite?.toJson(),
  'arLocationVideos': instance.arLocationVideos
      ?.map((e) => e.toJson())
      .toList(),
  'children': instance.children?.map((e) => e.toJson()).toList(),
  'isActive': instance.isActive,
};

Coordinates _$CoordinatesFromJson(Map<String, dynamic> json) => Coordinates(
  x: (json['x'] as num?)?.toDouble(),
  y: (json['y'] as num?)?.toDouble(),
  z: (json['z'] as num?)?.toDouble(),
);

Map<String, dynamic> _$CoordinatesToJson(Coordinates instance) =>
    <String, dynamic>{'x': instance.x, 'y': instance.y, 'z': instance.z};

MediaShowcase _$MediaShowcaseFromJson(Map<String, dynamic> json) =>
    MediaShowcase(
      id: (json['id'] as num?)?.toInt(),
      url: json['url'] as String?,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$MediaShowcaseToJson(MediaShowcase instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'type': instance.type,
    };

SocialShowcase _$SocialShowcaseFromJson(Map<String, dynamic> json) =>
    SocialShowcase(
      id: (json['id'] as num?)?.toInt(),
      url: json['url'] as String?,
    );

Map<String, dynamic> _$SocialShowcaseToJson(SocialShowcase instance) =>
    <String, dynamic>{'id': instance.id, 'url': instance.url};

ArLocationTranslation _$ArLocationTranslationFromJson(
  Map<String, dynamic> json,
) => ArLocationTranslation(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  description: json['description'] as String?,
  audioUrl: json['audioUrl'] as String?,
  languageCode: json['languageCode'] as String?,
);

Map<String, dynamic> _$ArLocationTranslationToJson(
  ArLocationTranslation instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'audioUrl': instance.audioUrl,
  'languageCode': instance.languageCode,
};

CulturalSite _$CulturalSiteFromJson(Map<String, dynamic> json) => CulturalSite(
  id: (json['id'] as num?)?.toInt(),
  code: json['code'] as String?,
  mapImageUrl: json['mapImageUrl'] as String?,
  coverImageUrl: json['coverImageUrl'] as String?,
  isActive: json['isActive'] as bool?,
  isFree: json['isFree'] as bool?,
  culturalSiteTranslations: (json['culturalSiteTranslations'] as List<dynamic>?)
      ?.map((e) => CulturalSiteTranslation.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CulturalSiteToJson(CulturalSite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'mapImageUrl': instance.mapImageUrl,
      'coverImageUrl': instance.coverImageUrl,
      'isActive': instance.isActive,
      'isFree': instance.isFree,
      'culturalSiteTranslations': instance.culturalSiteTranslations
          ?.map((e) => e.toJson())
          .toList(),
    };

CulturalSiteTranslation _$CulturalSiteTranslationFromJson(
  Map<String, dynamic> json,
) => CulturalSiteTranslation(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  description: json['description'] as String?,
  languageCode: json['languageCode'] as String?,
);

Map<String, dynamic> _$CulturalSiteTranslationToJson(
  CulturalSiteTranslation instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'languageCode': instance.languageCode,
};

ArLocationVideo _$ArLocationVideoFromJson(Map<String, dynamic> json) =>
    ArLocationVideo(
      id: (json['id'] as num?)?.toInt(),
      videoUrl: json['videoUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ArLocationVideoToJson(ArLocationVideo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'videoUrl': instance.videoUrl,
      'sortOrder': instance.sortOrder,
    };
