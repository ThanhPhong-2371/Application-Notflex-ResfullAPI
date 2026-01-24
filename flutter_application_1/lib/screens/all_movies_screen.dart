import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';
import 'movie_detail_screen.dart';

class AllMoviesScreen extends StatefulWidget {
  final String title;
  final String apiEndpoint; // Ví dụ: "xemtatcaphimle"

  const AllMoviesScreen({
    super.key,
    required this.title,
    required this.apiEndpoint,
  });

  @override
  State<AllMoviesScreen> createState() => _AllMoviesScreenState();
}

class _AllMoviesScreenState extends State<AllMoviesScreen> {
  final List<MovieItem> _movies = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  final ScrollController _scrollController = ScrollController();
  final String imageBaseUrl = dotenv.env['IMAGE_URL'] ?? "";

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _currentPage < _totalPages) {
      _loadMovies();
    }
  }

  Future<void> _loadMovies() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService().fetchPagedMovies(
        widget.apiEndpoint,
        _currentPage,
      );

      setState(() {
        _movies.addAll(response.data);
        _totalPages = response.pageCount;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _movies.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 cột
                childAspectRatio: 0.65, // Tỷ lệ poster
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _movies.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _movies.length) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  );
                }

                final movie = _movies[index];
                return GestureDetector(
                  onTap: () {
                    // SỬA LỖI: Xóa các dòng khai báo cũ bị trùng, chỉ giữ lại dòng này:
                    bool isSeries =
                        movie.isSeries ??
                        widget.apiEndpoint.toLowerCase().contains("phimbo");

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailScreen(
                          movieId: movie.id,
                          isSeries: isSeries,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: "$imageBaseUrl${movie.img}",
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[900]),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.tenPhim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
