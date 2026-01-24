import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../models/home_model.dart';
import 'watch_movie_screen.dart'; // Import trang xem phim của bạn
import 'home_screen.dart';
import 'news_screen.dart';
import 'ranking_screen.dart';
import 'more_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();

  List<MovieItem> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Xử lý logic tìm kiếm sau khi ngừng gõ 500ms
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
        setState(() {}); // Cập nhật UI để hiện nút Xóa
      } else {
        setState(() {
          _results = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final movies = await _apiService.searchMovies(query);
      setState(() {
        _results = movies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Xử lý lỗi nếu cần
    }
  }

  String _getFormattedImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    // Logic ghép URL giống màn hình WatchMovie
    String cleanBase = imageBaseUrl.endsWith('/')
        ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
        : imageBaseUrl;
    String cleanPath = path.startsWith('/') ? path : "/$path";
    return "$cleanBase$cleanPath";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0, // Giảm khoảng cách giữa nút back và thanh search
        title: Container(
          height: 45,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: _controller,
            onChanged: _onSearchChanged,
            autofocus: true,
            cursorColor: const Color(0xFFE50914), // Đổi sang màu đỏ thương hiệu
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: "Tìm tên phim...",
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged("");
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    if (_results.isEmpty && _controller.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_off, size: 80, color: Colors.white12),
            SizedBox(height: 16),
            Text(
              "Không tìm thấy kết quả nào.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.manage_search_rounded, size: 100, color: Colors.white10),
            SizedBox(height: 16),
            Text(
              "Nhập tên phim để bắt đầu tìm kiếm",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      itemBuilder: (context, index) {
        final movie = _results[index];
        return GestureDetector(
          onTap: () {
            // Chuyển sang màn hình xem phim
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WatchMovieScreen(
                  phimId: movie.id,
                  isSeries: movie.isSeries ?? false,
                  tapSo: null,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Ảnh Poster
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: _getFormattedImageUrl(movie.img),
                    width: 120,
                    height: 80, // Dạng landscape thumbnail lớn hơn chút
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[850]),
                    errorWidget: (context, url, error) => Container(
                      width: 120,
                      height: 80,
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tên phim & Loại
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.tenPhim,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (movie.isSeries ?? false)
                              ? const Color(0xFFE50914).withOpacity(
                                  0.2,
                                ) // Đỏ nhạt
                              : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (movie.isSeries ?? false) ? "PHIM BỘ" : "PHIM LẺ",
                          style: TextStyle(
                            color: (movie.isSeries ?? false)
                                ? const Color(0xFFE50914)
                                : Colors.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Nút play icon
                const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white10,
                    radius: 18,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF121212),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: 1, // Index của Search là 1 -> Sáng màu trắng
      onTap: (index) {
        if (index == 1) return; // Đang ở Search thì không làm gì

        if (index == 0) {
          // Về trang chủ: Xóa stack để về Home sạch sẽ
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else if (index == 3) {
          // Qua trang News: Thay thế trang hiện tại
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NewsScreen()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RankingScreen()),
          );
        } else if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MoreScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: "Tìm kiếm"),
        BottomNavigationBarItem(
          icon: Icon(Icons.star_border),
          label: "Bảng xếp hạng",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "News"),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Thêm"),
      ],
    );
  }
}
