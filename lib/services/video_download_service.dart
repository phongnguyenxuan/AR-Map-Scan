import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/models/ar_location_model.dart';
import 'package:flutter_application_ar/network/api_source.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

@pragma('vm:entry-point')
class VideoDownloadService {
  static const String downloadTaskId = 'downloadVideos';
  static const String videoDirectory = 'videos';

  // Thêm các biến để theo dõi tiến trình tải xuống cho nhiều video
  static final Map<String, int> _downloadProgress = {};
  static final Map<String, DownloadStatus> _downloadStatus = {};
  static final Map<String, CancelToken> _cancelTokens = {};

  // Throttle progress updates để tránh spam
  static final Map<String, int> _lastEmittedProgress = {};

  // Stream controller để phát tiến trình tải xuống
  static final _downloadProgressController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get downloadProgress =>
      _downloadProgressController.stream;

  static final Dio _dio = Dio();

  // Download video cho một AR location cụ thể (tuần tự từng video)
  static Future<bool> downloadVideosByArLocation(
    int culturalSiteId,
    int arLocationId, {
    String? pinImageUrl,
    int? maxVideos, // Giới hạn số video download (null = download tất cả)
  }) async {
    final api = sl.get<ApiSource>();
    final videos = await api.getVideoByArLocationId(
      culturalSiteId,
      arLocationId,
    );

    debugPrint(
      'DEBUG: AR Location $arLocationId has ${videos.length} videos from API',
    );
    for (int i = 0; i < videos.length; i++) {
      final video = videos[i];
      debugPrint(
        'DEBUG: Video $i: ID=${video.id}, URL=${video.videoUrl}, Sort=${video.sortOrder}',
      );
    }

    // Filter out invalid videos
    final validVideos = videos.where((video) {
      final videoUrl = video.videoUrl;
      final isValid =
          videoUrl != null &&
          videoUrl.isNotEmpty &&
          Uri.tryParse(videoUrl)?.hasAbsolutePath == true;
      if (!isValid) {
        debugPrint(
          'DEBUG: Filtering out invalid video: ID=${video.id}, URL=$videoUrl',
        );
      }
      return isValid;
    }).toList();

    debugPrint(
      'DEBUG: After filtering: ${validVideos.length} valid videos out of ${videos.length}',
    );

    if (validVideos.isEmpty) {
      debugPrint('DEBUG: No valid videos found for AR location $arLocationId');
      return false;
    }

    // Apply maxVideos limit if specified
    final videosToDownload = maxVideos != null && maxVideos > 0
        ? validVideos.take(maxVideos).toList()
        : validVideos;

    debugPrint(
      'DEBUG: Will download ${videosToDownload.length} videos (maxVideos: $maxVideos)',
    );

    final directory = await getApplicationDocumentsDirectory();
    final videoDir = Directory(
      '${directory.path}/$videoDirectory/$culturalSiteId/$arLocationId',
    );

    // Tạo thư mục nếu chưa tồn tại
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }

    final locationKey = '${culturalSiteId}_$arLocationId';
    int completedVideos = 0;
    int totalVideos = videosToDownload.length;

    // Kiểm tra xem tất cả video đã tồn tại chưa
    int existingVideos = 0;
    for (int i = 0; i < videosToDownload.length; i++) {
      final video = videosToDownload[i];
      final videoUrl = video.videoUrl;
      final videoId = video.id;

      if (videoUrl != null && Uri.tryParse(videoUrl)?.hasAbsolutePath == true) {
        final fileName = 'video_${videoId}_${videoUrl.split('/').last}';
        final localPath = '${videoDir.path}/$fileName';
        if (File(localPath).existsSync()) {
          existingVideos++;
        }
      }
    }

    // Nếu tất cả video đã tồn tại, emit completed status ngay
    if (existingVideos == totalVideos) {
      _downloadProgressController.add({
        'locationKey': locationKey,
        'currentVideo': totalVideos,
        'totalVideos': totalVideos,
        'overallProgress': 100,
        'status': DownloadStatus.completed,
      });
      debugPrint('DEBUG: All videos already exist for location $locationKey');
      return true;
    }

    // Emit thông tin bắt đầu download
    _downloadProgressController.add({
      'locationKey': locationKey,
      'currentVideo': 0,
      'totalVideos': totalVideos,
      'overallProgress': 0,
      'status': DownloadStatus.downloading,
    });

    // Download từng video tuần tự
    for (int i = 0; i < videosToDownload.length; i++) {
      final video = videosToDownload[i];
      final videoUrl = video.videoUrl;
      final videoId = video.id;

      // Validate URL
      if (videoUrl == null ||
          !(Uri.tryParse(videoUrl)?.hasAbsolutePath == true)) {
        debugPrint('DEBUG: Invalid video URL: $videoUrl');
        continue;
      }

      final fileName = 'video_${videoId}_${videoUrl.split('/').last}';
      final localPath = '${videoDir.path}/$fileName';

      debugPrint('DEBUG: Checking file exists: $localPath');

      if (!File(localPath).existsSync()) {
        debugPrint(
          'DEBUG: Starting download video ${i + 1}/$totalVideos: $videoUrl',
        );

        try {
          final taskId = '${locationKey}_video_$i';

          // Download file sử dụng Dio
          await _downloadFileStatic(
            videoUrl,
            localPath,
            taskId,
            locationKey: locationKey,
            currentVideoIndex: i + 1,
            totalVideos: totalVideos,
          );

          completedVideos++;
          debugPrint('DEBUG: Completed video ${i + 1}/$totalVideos');

          // Lưu thông tin video đã download
          final downloadedVideo = ArLocationVideo(
            id: videoId,
            videoUrl: videoUrl,
            sortOrder: video.sortOrder,
          );

          await _saveDownloadedVideoInfo(
            downloadedVideo,
            culturalSiteId,
            arLocationId,
          );
        } catch (e) {
          debugPrint('DEBUG: Error downloading video ${i + 1}: $e');
          // Emit error status
          _downloadProgressController.add({
            'locationKey': locationKey,
            'currentVideo': i + 1,
            'totalVideos': totalVideos,
            'overallProgress': (completedVideos / totalVideos * 100).round(),
            'status': DownloadStatus.failed,
            'error': e.toString(),
          });
          return false;
        }
      } else {
        completedVideos++;
        debugPrint(
          'DEBUG: Video ${i + 1}/$totalVideos already exists, skipping',
        );
      }

      // Emit progress update sau mỗi video
      final overallProgress = (completedVideos / totalVideos * 100).round();
      final currentStatus = completedVideos == totalVideos
          ? DownloadStatus.completed
          : DownloadStatus.downloading;

      _downloadProgressController.add({
        'locationKey': locationKey,
        'currentVideo': i + 1,
        'totalVideos': totalVideos,
        'overallProgress': overallProgress,
        'status': currentStatus,
      });

      // Nếu đã hoàn thành, thoát sớm
      if (currentStatus == DownloadStatus.completed) {
        debugPrint('DEBUG: All videos completed for location $locationKey');
        break;
      }
    }

    debugPrint(
      'DEBUG: Completed downloading all videos for location $locationKey',
    );
    return true;
  }

  // Method mới để download file sử dụng Dio
  static Future<void> _downloadFileStatic(
    String url,
    String savePath,
    String taskId, {
    String? locationKey,
    int? currentVideoIndex,
    int? totalVideos,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;
    _downloadStatus[taskId] = DownloadStatus.downloading;

    try {
      final response = await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          // Kiểm tra nếu task đã completed thì không log nữa
          if (total != -1 &&
              _downloadStatus[taskId] == DownloadStatus.downloading) {
            final progress = ((received / total) * 100).round();
            final lastProgress = _lastEmittedProgress[taskId] ?? -1;

            // Chỉ emit khi progress thay đổi ít nhất 1% hoặc là lần đầu
            if (progress != lastProgress &&
                (progress - lastProgress).abs() >= 1) {
              _downloadProgress[taskId] = progress;
              _lastEmittedProgress[taskId] = progress;

              // Emit progress cho từng video
              final progressData = <String, dynamic>{
                'id': taskId,
                'status': DownloadStatus.downloading,
                'progress': progress,
              };

              // Thêm thông tin location nếu có
              if (locationKey != null &&
                  currentVideoIndex != null &&
                  totalVideos != null) {
                progressData.addAll({
                  'locationKey': locationKey,
                  'currentVideo': currentVideoIndex,
                  'totalVideos': totalVideos,
                  'videoProgress': progress,
                });
              }

              _downloadProgressController.add(progressData);

              debugPrint(
                'DEBUG: Video $currentVideoIndex/$totalVideos - Progress: $progress%',
              );
            }
          }
        },
      );

      if (response.statusCode == 200) {
        _downloadStatus[taskId] = DownloadStatus.completed;
        _downloadProgress[taskId] = 100;

        final completedData = <String, dynamic>{
          'id': taskId,
          'status': DownloadStatus.completed,
          'progress': 100,
        };

        if (locationKey != null &&
            currentVideoIndex != null &&
            totalVideos != null) {
          completedData.addAll({
            'locationKey': locationKey,
            'currentVideo': currentVideoIndex,
            'totalVideos': totalVideos,
            'videoProgress': 100,
          });
        }

        _downloadProgressController.add(completedData);

        debugPrint(
          'DEBUG: Video $currentVideoIndex/$totalVideos completed successfully',
        );

        // Cleanup task ngay sau khi completed
        _downloadStatus.remove(taskId);
        _downloadProgress.remove(taskId);
        _lastEmittedProgress.remove(taskId);
        debugPrint('DEBUG: Cleaned up task $taskId after completion');
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _downloadStatus[taskId] = DownloadStatus.cancelled;
        debugPrint('DEBUG: Download cancelled for $taskId');
      } else {
        _downloadStatus[taskId] = DownloadStatus.failed;
        debugPrint('DEBUG: Download error: $e');

        // Xóa file nếu download thất bại
        final file = File(savePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final errorData = <String, dynamic>{
        'id': taskId,
        'status': _downloadStatus[taskId]!,
        'progress': _downloadProgress[taskId] ?? 0,
      };

      if (locationKey != null &&
          currentVideoIndex != null &&
          totalVideos != null) {
        errorData.addAll({
          'locationKey': locationKey,
          'currentVideo': currentVideoIndex,
          'totalVideos': totalVideos,
          'error': e.toString(),
        });
      }

      _downloadProgressController.add(errorData);

      rethrow;
    } finally {
      // Cleanup cancel token
      _cancelTokens.remove(taskId);

      // Cleanup status and progress nếu còn
      _downloadStatus.remove(taskId);
      _downloadProgress.remove(taskId);
      _lastEmittedProgress.remove(taskId);
    }
  }

  // Các method này không cần thiết với HTTP download
  static Future<void> resumeAllTasks() async {
    // HTTP download không cần resume tasks
    debugPrint('DEBUG: Resume tasks not needed for HTTP download');
  }

  // Method để retry failed downloads
  static Future<void> retryFailedTasks() async {
    // HTTP download tự động retry trong từng download call
    debugPrint('DEBUG: Retry tasks not needed for HTTP download');
  }

  static Future<void> _saveDownloadedVideoInfo(
    ArLocationVideo video,
    int culturalSiteId,
    int arLocationId,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/$videoDirectory/$culturalSiteId/$arLocationId/downloaded_videos.json',
    );

    List<Map<String, dynamic>> videos = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      videos = List<Map<String, dynamic>>.from(jsonDecode(content));
    }

    videos.add(video.toJson());
    await file.writeAsString(jsonEncode(videos));
  }

  static Future<List<ArLocationVideo>> loadDownloadedVideos(
    int culturalSiteId,
    int arLocationId,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final videoDir =
        '${directory.path}/$videoDirectory/$culturalSiteId/$arLocationId';
    final jsonFile = File('$videoDir/downloaded_videos.json');

    if (await jsonFile.exists()) {
      final content = await jsonFile.readAsString();
      final videos = List<Map<String, dynamic>>.from(jsonDecode(content));

      final filteredVideos = videos
          .where(
            (v) =>
                v['culturalSiteId'] == culturalSiteId &&
                v['arLocationId'] == arLocationId,
          )
          .toList();

      return filteredVideos.map((v) => ArLocationVideo.fromJson(v)).toList();
    }
    return [];
  }

  // Kiểm tra xem AR location này đã có video được download chưa (không cần videoUrls)
  static Future<bool> hasDownloadedVideos(
    int culturalSiteId,
    int arLocationId,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final videoDir = Directory(
      '${directory.path}/$videoDirectory/$culturalSiteId/$arLocationId',
    );

    if (!await videoDir.exists()) {
      return false;
    }

    final files = await videoDir
        .list()
        .where(
          (file) => file.path.endsWith('.mp4') || file.path.endsWith('.mov'),
        )
        .toList();

    return files.isNotEmpty;
  }

  // Kiểm tra tất cả video của AR location đã được download chưa
  static Future<bool> areAllVideosDownloaded(
    int culturalSiteId,
    int arLocationId,
    List<String> videoUrls,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final videoDir =
        '${directory.path}/$videoDirectory/$culturalSiteId/$arLocationId';

    print('DEBUG: Checking if all videos downloaded in: $videoDir');

    final dir = Directory(videoDir);
    if (!await dir.exists()) {
      print('DEBUG: Video directory does not exist');
      return false;
    }

    final files = await dir.list().toList();
    print('DEBUG: Found ${files.length} files in directory');

    for (String videoUrl in videoUrls) {
      final fileName = videoUrl.split('/').last;
      final videoFile = files.firstWhereOrNull(
        (file) => file.path.contains(fileName) && file.path.contains('video_'),
      );

      if (videoFile == null) {
        print('DEBUG: Video file not found for URL: $videoUrl');
        return false;
      } else {
        print('DEBUG: Found video file: ${videoFile.path}');
      }
    }

    print('DEBUG: All videos are downloaded');
    return true;
  }

  // Method để get task status by AR location (đơn giản hóa cho HTTP download)
  static Future<Map<String, Map<String, dynamic>>> getTaskStatusByLocation(
    int culturalSiteId,
    int arLocationId,
  ) async {
    // Với HTTP download, status được track qua _downloadStatus
    Map<String, Map<String, dynamic>> taskStatus = {};

    _downloadStatus.forEach((taskId, status) {
      taskStatus[taskId] = {
        'status': status,
        'progress': _downloadProgress[taskId] ?? 0,
      };
    });

    return taskStatus;
  }

  // Kiểm tra có video nào đang download không
  static Future<bool> isAnyVideoDownloading(
    int culturalSiteId,
    int arLocationId,
  ) async {
    // Kiểm tra trong _downloadStatus có task nào đang downloading không
    return _downloadStatus.values.any(
      (status) => status == DownloadStatus.downloading,
    );
  }

  // Tính tổng progress của tất cả video trong AR location
  static Future<int> getOverallProgress(
    int culturalSiteId,
    int arLocationId,
  ) async {
    if (_downloadProgress.isEmpty) return 0;

    int totalProgress = 0;
    int count = 0;

    _downloadProgress.forEach((taskId, progress) {
      totalProgress += progress;
      count++;
    });

    return count > 0 ? (totalProgress / count).round() : 0;
  }

  // Lấy tất cả task IDs cho một AR location
  static Future<List<String>> getTaskIds(
    int culturalSiteId,
    int arLocationId,
  ) async {
    // Trả về danh sách taskIds hiện có
    return _downloadStatus.keys.toList();
  }

  // Method để clear download status cho một location
  static void clearLocationStatus(String locationKey) {
    // Remove tất cả taskIds liên quan đến location này
    final keysToRemove = _downloadStatus.keys
        .where((taskId) => taskId.startsWith(locationKey))
        .toList();

    debugPrint(
      'DEBUG: Clearing status for location $locationKey, found ${keysToRemove.length} tasks',
    );

    for (final key in keysToRemove) {
      _downloadStatus.remove(key);
      _downloadProgress.remove(key);
      _lastEmittedProgress.remove(key);
      final token = _cancelTokens.remove(key);
      if (token != null && !token.isCancelled) {
        token.cancel();
      }
      debugPrint('DEBUG: Cleared task $key');
    }
  }

  // Get local video path for AR location
  static Future<String?> getLocalVideoPath(
    int culturalSiteId,
    int arLocationId,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final videoDir = Directory(
        '${directory.path}/$videoDirectory/$culturalSiteId/$arLocationId',
      );

      if (!await videoDir.exists()) {
        debugPrint(
          'DEBUG: Video directory does not exist for location $arLocationId',
        );
        return null;
      }

      // Tìm video file đầu tiên trong thư mục
      final files = await videoDir
          .list()
          .where(
            (file) =>
                file.path.endsWith('.mp4') ||
                file.path.endsWith('.mov') ||
                file.path.endsWith('.m4v'),
          )
          .toList();

      if (files.isEmpty) {
        debugPrint('DEBUG: No video files found for location $arLocationId');
        return null;
      }

      // Sắp xếp files theo tên để get video đầu tiên
      files.sort((a, b) => a.path.compareTo(b.path));
      final firstVideoPath = files.first.path;

      debugPrint('DEBUG: Found local video: $firstVideoPath');
      return firstVideoPath;
    } catch (e) {
      debugPrint('DEBUG: Error getting local video path: $e');
      return null;
    }
  }

  // Debug method để check active downloads
  static void debugActiveDownloads() {
    debugPrint('DEBUG: Active downloads: ${_downloadStatus.length}');
    debugPrint('DEBUG: Active progress: ${_downloadProgress.length}');
    debugPrint('DEBUG: Active tokens: ${_cancelTokens.length}');
    _downloadStatus.forEach((taskId, status) {
      debugPrint('DEBUG: Task $taskId: $status');
    });
  }

  static void dispose() {
    // Hủy tất cả cancel tokens
    _cancelTokens.forEach((key, token) {
      if (!token.isCancelled) {
        token.cancel();
      }
    });
    _cancelTokens.clear();
    _downloadProgressController.close();
  }
}
