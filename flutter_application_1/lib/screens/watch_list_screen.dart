import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import 'watch_movie_screen.dart'; // Import để chuyển trang xem phim

class WatchListScreen extends StatefulWidget {
  const WatchListScreen({super.key});

  @override
  State<WatchListScreen> createState() => _WatchListScreenState();
}

class _WatchListScreenState extends State<WatchListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _watchList = [];
  bool _isLoading = true;
  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _loadWatchList();
  }

  Future<void> _loadWatchList() async {
    try {
      final list = await _apiService.fetchWatchList();
      setState(() {
        _watchList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeItem(int id, int index) async {
    try {
      await _apiService.removeFromWatchList(id);
      if (!mounted)
        return; // Kiểm tra màn hình còn tồn tại không trước khi dùng setState/context
      setState(() {
        _watchList.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã xóa khỏi danh sách theo dõi")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lỗi khi xóa")));
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
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Danh Sách Của Tôi",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadWatchList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : _watchList.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 80, color: Colors.white24),
                  SizedBox(height: 10),
                  Text(
                    "Chưa có phim nào trong danh sách",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 cột giống Netflix
                childAspectRatio: 0.65, // Tỉ lệ khung hình dọc
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _watchList.length,
              itemBuilder: (context, index) {
                final item = _watchList[index];
                return Stack(
                  children: [
                    // Ảnh bìa + Click event
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WatchMovieScreen(
                              phimId: item['phimId'],
                              isSeries: item['isSeries'],
                              tapSo: null,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: NetworkImage(
                              _getFormattedImageUrl(item['hinhAnh']),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Nút xóa (Góc trên phải)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeItem(item['id'], index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Tên phim (Góc dưới)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Text(
                        item['tenPhim'] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
