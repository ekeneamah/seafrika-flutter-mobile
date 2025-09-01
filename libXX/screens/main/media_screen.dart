import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/widgets/media_grid_item.dart';
import 'dart:typed_data';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  List<AssetEntity> _media = [];
  List<AssetEntity> _filteredMedia = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  AssetType? _selectedType;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMedia() {
    setState(() {
      _filteredMedia = _media.where((media) {
        final matchesType =
            _selectedType == null || media.type == _selectedType;
        final matchesDate = _dateRange == null ||
            (media.createDateTime.isAfter(_dateRange!.start) &&
                media.createDateTime.isBefore(_dateRange!.end));
        return matchesType && matchesDate;
      }).toList();
    });
  }

  Future<void> _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Media'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<AssetType?>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Media Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All'),
                ),
                const DropdownMenuItem(
                  value: AssetType.image,
                  child: Text('Images'),
                ),
                const DropdownMenuItem(
                  value: AssetType.video,
                  child: Text('Videos'),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() => _dateRange = picked);
                }
              },
              icon: const Icon(Icons.date_range),
              label: Text(_dateRange == null
                  ? 'Select Date Range'
                  : '${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = null;
                _dateRange = null;
              });
              _filterMedia();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _filterMedia();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMedia() async {
    try {
      final PermissionState state =
          await PhotoManager.requestPermissionExtend();
      if (!state.hasAccess) {
        setState(() {
          _error = 'Permission denied';
          _isLoading = false;
        });
        return;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          videoOption: const FilterOption(
            durationConstraint: DurationConstraint(max: Duration(seconds: 60)),
          ),
        ),
      );

      if (albums.isEmpty) {
        setState(() {
          _error = 'No media found';
          _isLoading = false;
        });
        return;
      }

      final List<AssetEntity> media = await albums[0].getAssetListPaged(
        page: 0,
        size: 80,
      );

      setState(() {
        _media = media;
        _filteredMedia = media;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<DateTime, List<AssetEntity>> _groupMediaByDate(List<AssetEntity> media) {
    final grouped = <DateTime, List<AssetEntity>>{};
    for (final item in media) {
      final date = DateTime(
        item.createDateTime.year,
        item.createDateTime.month,
        item.createDateTime.day,
      );
      grouped.putIfAbsent(date, () => []).add(item);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: MediaSearchDelegate(
                  media: _media,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : FutureBuilder<Map<DateTime, List<AssetEntity>>>(
                  future: Future.value(_groupMediaByDate(
                      _filteredMedia.isEmpty ? _media : _filteredMedia)),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final groupedMedia = snapshot.data!;
                    if (groupedMedia.isEmpty) {
                      return const Center(child: Text('No media found'));
                    }

                    return ListView.builder(
                      itemCount: groupedMedia.length,
                      itemBuilder: (context, index) {
                        final date = groupedMedia.keys.elementAt(index);
                        final media = groupedMedia[date]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: media.length,
                              itemBuilder: (context, index) {
                                final item = media[index];
                                return FutureBuilder<Uint8List?>(
                                  future: item.originBytes,
                                  builder: (context, snapshot) {
                                    final fileSize = snapshot.data?.length ?? 0;
                                    return MediaGridItem(
                                      id: item.id,
                                      type: item.type == AssetType.video
                                          ? 'video'
                                          : 'image',
                                      thumbnail: item.thumbnailData,
                                      timestamp: item.createDateTime,
                                      fileSize: _formatFileSize(fileSize),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.mediaDetail,
                                          arguments: {'media': item},
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class MediaSearchDelegate extends SearchDelegate {
  final List<AssetEntity> media;

  MediaSearchDelegate({
    required this.media,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredMedia = media.where((media) {
      final timestamp = media.createDateTime.toString().toLowerCase();
      final type = media.type.toString().toLowerCase();
      final searchLower = query.toLowerCase();
      return timestamp.contains(searchLower) || type.contains(searchLower);
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredMedia.length,
      itemBuilder: (context, index) {
        final media = filteredMedia[index];
        return MediaGridItem(
          id: media.id,
          type: media.type == AssetType.video ? 'video' : 'image',
          thumbnail: media.thumbnailData,
          timestamp: media.createDateTime,
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.mediaDetail,
              arguments: {'media': media},
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}
