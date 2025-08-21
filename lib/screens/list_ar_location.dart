import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/models/ar_location_model.dart';
import 'package:flutter_application_ar/network/api_source.dart';
import 'package:flutter_application_ar/screens/ar_screen.dart';
import 'package:flutter_application_ar/services/video_download_service.dart';
import 'package:percent_indicator/flutter_percent_indicator.dart';

class ListArLocationScreen extends StatefulWidget {
  const ListArLocationScreen({super.key});

  @override
  State<ListArLocationScreen> createState() => _ListArLocationScreenState();
}

class _ListArLocationScreenState extends State<ListArLocationScreen> {
  final apiDataSource = sl.get<ApiSource>();
  ArData? _arLocation;
  bool _isLoading = true;

  // Track download progress cho từng location
  final Map<String, Map<String, dynamic>> _locationDownloadStatus = {};

  // Track để tránh spam debug log
  final Map<String, String> _lastLoggedStatus = {};

  late StreamSubscription _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _fetchArLocation();
    _listenToDownloadProgress();
  }

  @override
  void dispose() {
    _downloadSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchArLocation() async {
    final arLocation = await apiDataSource.getArLocation();
    setState(() {
      _arLocation = arLocation;
      _isLoading = false;
    });
  }

  void _listenToDownloadProgress() {
    _downloadSubscription = VideoDownloadService.downloadProgress.listen((
      data,
    ) {
      setState(() {
        // Handle progress updates cho từng location
        if (data.containsKey('locationKey')) {
          final locationKey = data['locationKey'];
          final status = data['status'] ?? DownloadStatus.pending;

          _locationDownloadStatus[locationKey] = {
            'currentVideo': data['currentVideo'] ?? 0,
            'totalVideos': data['totalVideos'] ?? 0,
            'overallProgress': data['overallProgress'] ?? 0,
            'status': status,
            'videoProgress': data['videoProgress'] ?? 0,
            'error': data['error'],
          };

          // Auto-clear status sau 3 giây khi completed
          if (status == DownloadStatus.completed) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _locationDownloadStatus.remove(locationKey);
                });
                VideoDownloadService.clearLocationStatus(locationKey);
              }
            });
          }
        }
      });
    });
  }

  String _getLocationKey(int culturalSiteId, int arLocationId) {
    return '${culturalSiteId}_$arLocationId';
  }

  Widget _buildDownloadProgress(String locationKey) {
    final status = _locationDownloadStatus[locationKey];
    if (status == null) return const SizedBox.shrink();

    final currentVideo = status['currentVideo'] ?? 0;
    final totalVideos = status['totalVideos'] ?? 0;
    final overallProgress = status['overallProgress'] ?? 0;
    final videoProgress = status['videoProgress'] ?? 0;
    final downloadStatus = status['status'] as DownloadStatus;

    // Debug log chỉ khi có thay đổi
    final currentStatusString =
        '$currentVideo/$totalVideos-$overallProgress%-$downloadStatus';
    if (_lastLoggedStatus[locationKey] != currentStatusString) {
      _lastLoggedStatus[locationKey] = currentStatusString;
      debugPrint(
        'DEBUG UI: $locationKey - Video $currentVideo/$totalVideos, Progress: $overallProgress%, Status: $downloadStatus',
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Video $currentVideo/$totalVideos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '$overallProgress%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearPercentIndicator(
            lineHeight: 10,
            percent: overallProgress / 100,
            progressColor: Colors.blue,
            backgroundColor: Colors.grey.shade300,
            animation: true,
            animationDuration: 1000,
            barRadius: const Radius.circular(10),
            padding: EdgeInsets.zero,
          ),
          if (downloadStatus == DownloadStatus.downloading &&
              currentVideo > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Đang tải video $currentVideo: $videoProgress%',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
          if (downloadStatus == DownloadStatus.completed) ...[
            const SizedBox(height: 4),
            const Text(
              '✅ Tải xuống hoàn tất!',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (downloadStatus == DownloadStatus.failed) ...[
            const SizedBox(height: 4),
            const Text(
              '❌ Tải xuống thất bại',
              style: TextStyle(
                fontSize: 10,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLocations = _arLocation?.items
        ?.where((element) => element.isActive == true)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('List AR Location'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: activeLocations?.length ?? 0,
              itemBuilder: (context, index) {
                final culturalSiteId =
                    activeLocations?[index].culturalSite?.id ?? 0;
                final arLocationId = activeLocations?[index].id ?? 0;
                final locationKey = _getLocationKey(
                  culturalSiteId,
                  arLocationId,
                );

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                    left: 12,
                    right: 12,
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final hasVideos =
                                await VideoDownloadService.hasDownloadedVideos(
                                  culturalSiteId,
                                  arLocationId,
                                );

                            // Kiểm tra nếu đang download
                            final currentStatus =
                                _locationDownloadStatus[locationKey];
                            final isDownloading =
                                currentStatus != null &&
                                currentStatus['status'] ==
                                    DownloadStatus.downloading;

                            if (isDownloading) {
                              // Đang download, không làm gì
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Video đang được tải xuống...'),
                                ),
                              );
                              return;
                            }

                            if (!hasVideos) {
                              // Clear status cũ trước khi bắt đầu download mới
                              final locationKey = _getLocationKey(
                                culturalSiteId,
                                arLocationId,
                              );
                              setState(() {
                                _locationDownloadStatus.remove(locationKey);
                              });
                              VideoDownloadService.clearLocationStatus(
                                locationKey,
                              );

                              // Bắt đầu download video cho AR location này (giới hạn 1 video)
                              try {
                                await VideoDownloadService.downloadVideosByArLocation(
                                  culturalSiteId,
                                  arLocationId,
                                  maxVideos: 1, // Chỉ download 1 video
                                );
                              } catch (e) {
                                print('ERROR: Failed to start download: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi tải xuống: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } else {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ARScreen(
                                      arData: _arLocation?.items?[index],
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  activeLocations?[index]
                                          .mediaShowcases
                                          ?.first
                                          .url ??
                                      '',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeLocations?[index]
                                              .arLocationTranslations
                                              ?.last
                                              .name ??
                                          '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      activeLocations?[index]
                                              .culturalSite
                                              ?.code ??
                                          '',
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<bool>(
                                      future:
                                          VideoDownloadService.hasDownloadedVideos(
                                            culturalSiteId,
                                            arLocationId,
                                          ),
                                      builder: (context, snapshot) {
                                        final hasVideos =
                                            snapshot.data ?? false;
                                        final currentStatus =
                                            _locationDownloadStatus[locationKey];
                                        final isDownloading =
                                            currentStatus != null &&
                                            currentStatus['status'] ==
                                                DownloadStatus.downloading;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasVideos
                                                ? Colors.green.shade100
                                                : isDownloading
                                                ? Colors.blue.shade100
                                                : Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            hasVideos
                                                ? '✅ Đã tải xuống'
                                                : isDownloading
                                                ? '⬇️ Đang tải...'
                                                : '📥 Chưa tải xuống',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasVideos
                                                  ? Colors.green.shade700
                                                  : isDownloading
                                                  ? Colors.blue.shade700
                                                  : Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Hiển thị progress bar nếu đang download
                        _buildDownloadProgress(locationKey),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
