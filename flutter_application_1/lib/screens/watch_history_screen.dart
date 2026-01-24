import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import 'watch_movie_screen.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _historyList = [];
  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await ApiService().fetchHistory();
      if (mounted) {
        setState(() {
          _historyList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Lỗi tải lịch sử: $e")),
        // );
      }
    }
  }

  Future<void> _deleteHistory(int id) async {
    try {
      await ApiService().deleteHistory(id);
      setState(() {
        _historyList.removeWhere((item) => item['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Đã xóa khỏi lịch sử")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Lỗi xóa lịch sử")));
      }
    }
  }

  String _getFormattedImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    String cleanBase = imageBaseUrl.endsWith('/')
        ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
        : imageBaseUrl;
    String cleanPath = path.startsWith('/') ? path : "/$path";
    return "$cleanBase$cleanPath";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text(
          "Lịch sử xem",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : _historyList.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    "Bạn chưa xem phim nào",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _historyList.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = _historyList[index];
                return Dismissible(
                  key: Key(item['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) => _deleteHistory(item['id']),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WatchMovieScreen(
                            phimId: item['phimId'],
                            isSeries: item['isSeries'] ?? false,
                            tapSo: item['tapSo'],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // Ảnh Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: _getFormattedImageUrl(item['hinhAnh']),
                            width: 120,
                            height: 68,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[900]),
                            errorWidget: (context, url, error) =>
                                Container(color: Colors.grey[900]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Thông tin
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['tenPhim'] ?? "Không có tên",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (item['isSeries'] == true &&
                                  item['tapSo'] != null)
                                Text(
                                  "Đang xem: Tập ${item['tapSo']}",
                                  style: const TextStyle(
                                    color: Color(0xFFE50914),
                                    fontSize: 12,
                                  ),
                                )
                              else
                                const Text(
                                  "Phim Lẻ",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Nút xóa
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => _deleteHistory(item['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
