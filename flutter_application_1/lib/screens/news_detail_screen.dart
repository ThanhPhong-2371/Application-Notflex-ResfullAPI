import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart'; // Cần thêm package này
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class NewsDetailScreen extends StatefulWidget {
  final int newsId;
  const NewsDetailScreen({super.key, required this.newsId});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>> _detailFuture;
  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _detailFuture = _apiService.fetchNewsDetail(widget.newsId);
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Lỗi: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!['data'];
          final related = snapshot.data!['related'] as List<dynamic>;

          return CustomScrollView(
            slivers: [
              // Header ảnh co giãn
              SliverAppBar(
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF141414),
                leading: IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: _getFormattedImageUrl(data['hinhAnh']),
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[900]),
                  ),
                ),
              ),

              // Nội dung bài viết
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['tieuDe'] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(DateTime.parse(data['ngayCapNhat'])),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.visibility,
                            color: Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "${data['luotXem']} views",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey, height: 30),

                      // Render HTML Content
                      Html(
                        data: data['noiDung'] ?? "<p>Đang cập nhật...</p>",
                        style: {
                          "body": Style(
                            color: Colors.white70,
                            fontSize: FontSize(16),
                            lineHeight: LineHeight(1.6),
                          ),
                          "p": Style(margin: Margins.only(bottom: 10)),
                          "h2": Style(
                            color: Colors.white,
                            fontSize: FontSize(20),
                            fontWeight: FontWeight.bold,
                          ),
                          "img": Style(
                            width: Width(100, Unit.percent),
                            height: Height.auto(),
                          ),
                        },
                      ),

                      const SizedBox(height: 30),
                      const Text(
                        "Tin tức liên quan",
                        style: TextStyle(
                          color: Color(0xFFE50914),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tin liên quan
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: related.length,
                        itemBuilder: (context, index) {
                          final item = related[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: _getFormattedImageUrl(
                                  item['hinhAnh'],
                                ),
                                width: 80,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              item['tieuDe'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(DateTime.parse(item['ngayCapNhat'])),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      NewsDetailScreen(newsId: item['id']),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
