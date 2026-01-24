import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import 'watch_movie_screen.dart'; // Import để chuyển trang xem phim

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _rankingList = [];
  bool _isLoading = true;

  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Mặc định lấy Top Tuần (hoặc API mặc định) vì đã bỏ Top Tháng
      final data = await _apiService.fetchTopRanking('week');

      if (mounted) {
        setState(() {
          _rankingList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Lỗi tải ranking: $e");
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Top Trending",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF400000), // Đỏ đậm ở trên cùng
              Colors.black,
              Colors.black,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              )
            : _buildRankingList(_rankingList),
      ),
    );
  }

  Widget _buildRankingList(List<dynamic> movies) {
    if (movies.isEmpty) {
      return const Center(
        child: Text("Chưa có dữ liệu", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      // Padding top lớn để tránh AppBar đè lên nội dung đầu
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final int rank = index + 1;

        // Logic màu sắc cho Top 3
        Color rankColor = Colors.white;
        double rankFontSize = 40;

        if (rank == 1) {
          rankColor = const Color(0xFFFFD700); // Vàng
          rankFontSize = 50;
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Bạc
          rankFontSize = 45;
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Đồng
          rankFontSize = 45;
        } else {
          rankColor = Colors.white.withOpacity(0.5);
          rankFontSize = 40;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WatchMovieScreen(
                  phimId: movie['id'] ?? movie['ID'],
                  isSeries: true, // Tạm thời hardcode hoặc lấy từ API nếu có
                  tapSo: null,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.95), // Nền card tối
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Rank Number (To, nằm đè lên góc ảnh hoặc bên cạnh)
                SizedBox(
                  width: 40,
                  child: Text(
                    "$rank",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: rankColor,
                      fontSize: rankFontSize,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      height: 1.0,
                      shadows: [
                        if (rank <= 3)
                          BoxShadow(
                            color: rankColor.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Ảnh bìa
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _getFormattedImageUrl(
                      movie['img'] ?? movie['Img'],
                    ),
                    width: 85,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[900]),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 16),

                // 3. Thông tin phim & Score
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movie['tenPhim'] ?? movie['TenPhim'] ?? "",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tags / Info
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildTag("HD", Colors.grey),
                          if (rank <= 3) _buildTag("HOT", Colors.red),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 4 Cục Stats (Score, View, Comment, Follow)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            Icons.star_rounded,
                            Colors.amber,
                            ((movie['score'] ?? movie['Score'] ?? 0) as num)
                                .toDouble()
                                .toStringAsFixed(1),
                            "Điểm",
                          ),
                          _buildStatItem(
                            Icons.remove_red_eye_rounded,
                            Colors.blue,
                            "${movie['luotXem'] ?? movie['LuotXem'] ?? 0}",
                            "Xem",
                          ),
                          _buildStatItem(
                            Icons.comment_rounded,
                            Colors.green,
                            "${movie['soBinhLuan'] ?? movie['SoBinhLuan'] ?? 0}",
                            "Bình luận",
                          ),
                          _buildStatItem(
                            Icons.favorite_rounded,
                            Colors.pink,
                            "${movie['soTheoDoi'] ?? movie['SoTheoDoi'] ?? 0}",
                            "Theo dõi",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
