import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../models/movie_detail_model.dart';
import '../models/home_model.dart'; // Để dùng MovieItem
import 'watch_movie_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final bool isSeries; // true = Phim bộ, false = Phim lẻ

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    required this.isSeries,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Future<MovieDetailResponse> _movieDetail;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isDescriptionExpanded = false; // Trạng thái xem thêm mô tả
  bool _isFollowing = false; // Trạng thái theo dõi phim

  // State cho bình luận
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isDataLoaded = false; // Để đảm bảo chỉ load comment từ API 1 lần
  bool _isSendingComment = false;
  String? _currentUserId; // Lưu ID user hiện tại để check quyền xóa

  // Lưu index của tập đang chọn (mặc định là 0 - tập đầu tiên)
  int _currentEpisodeIndex = 0;

  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
    _loadData();
    _checkFollowStatus();
  }

  // Lấy thông tin user hiện tại để biết comment nào là của mình
  Future<void> _checkCurrentUser() async {
    final userInfo = await ApiService().getUserInfo();
    if (userInfo != null && mounted) {
      // Giả sử key ID trong userInfo là 'id' hoặc 'Id'
      setState(() => _currentUserId = userInfo['id']?.toString());
    }
  }

  void _loadData() {
    // Gọi API tương ứng dựa trên loại phim
    if (widget.isSeries) {
      _movieDetail = ApiService().getPhimBoDetail(widget.movieId);
    } else {
      _movieDetail = ApiService().getPhimLeDetail(widget.movieId);
    }
  }

  // Kiểm tra xem phim đã có trong danh sách chưa
  Future<void> _checkFollowStatus() async {
    try {
      final isFollow = await ApiService().checkIsFollowing(
        idPhimBo: widget.isSeries ? widget.movieId : null,
        idPhimLe: !widget.isSeries ? widget.movieId : null,
      );
      if (mounted) setState(() => _isFollowing = isFollow);
    } catch (e) {
      debugPrint("Lỗi check follow: $e");
    }
  }

  // Hàm xử lý URL ảnh để tránh lỗi 2 dấu gạch chéo (//) và format đúng
  String _getFormattedImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;

    // Bỏ dấu / ở cuối base url nếu có
    String cleanBase = imageBaseUrl.endsWith('/')
        ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
        : imageBaseUrl;

    // Đảm bảo path bắt đầu bằng /
    String cleanPath = path.startsWith('/') ? path : "/$path";

    return "$cleanBase$cleanPath";
  }

  // Hàm khởi tạo video player
  void _initializeVideo(String videoUrl) {
    // Hủy controller cũ nếu có
    _videoController?.dispose();
    setState(() {
      _isVideoInitialized = false;
    });

    // Nếu link rỗng thì không làm gì
    if (videoUrl.isEmpty) return;

    // Xử lý link video (Demo chỉ chạy link .mp4 trực tiếp)
    // Nếu là Youtube cần dùng gói youtube_player_flutter
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.play(); // Tự động phát
        }
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // Hàm gửi bình luận
  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSendingComment = true);

    try {
      // Xác định ID phim (Bộ hoặc Lẻ)
      int? idPhimBo;
      int? idPhimLe;
      if (widget.isSeries) {
        idPhimBo = widget.movieId;
      } else {
        idPhimLe = widget.movieId;
      }

      final newComment = await ApiService().addComment(
        content: _commentController.text.trim(),
        idPhimBo: idPhimBo,
        idPhimLe: idPhimLe,
        // Nếu muốn comment vào tập phim cụ thể, cần lấy ID tập phim từ list tapPhims
        // idTapPhim: ...
      );

      // API C# trả về comment nhưng thiếu userId (chỉ có user object).
      // Ta cần gán userId hiện tại vào để UI hiển thị nút Xóa ngay lập tức.
      final commentWithAuth = Comment(
        id: newComment.id,
        noiDung: newComment.noiDung,
        thoiGian: newComment.thoiGian,
        isLiked: newComment.isLiked,
        likeCount: newComment.likeCount,
        userId: _currentUserId, // Gán ID của chính mình vào
        user: newComment.user,
        replies: [],
      );

      setState(() {
        _comments.insert(0, commentWithAuth); // Thêm vào đầu danh sách
        _commentController.clear();
      });

      // Ẩn bàn phím
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  // Hàm like bình luận
  Future<void> _handleLike(int index) async {
    final comment = _comments[index];
    try {
      final result = await ApiService().toggleLikeComment(comment.id);
      setState(() {
        // Cập nhật trạng thái like cục bộ
        _comments[index] = Comment(
          id: comment.id,
          noiDung: comment.noiDung,
          thoiGian: comment.thoiGian,
          isLiked: result.isLiked,
          likeCount: result.likeCount,
          userId: comment.userId,
          user: comment.user,
          replies: comment.replies,
        );
      });
    } catch (e) {
      debugPrint("Lỗi like: $e");
    }
  }

  // Hàm xử lý thêm vào danh sách theo dõi
  Future<void> _toggleFollow() async {
    // Nếu đã theo dõi rồi thì tạm thời chỉ thông báo (vì API xóa cần ID bản ghi HopPhim chứ không phải ID phim)
    if (_isFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phim đã có trong danh sách của bạn")),
      );
      return;
    }

    try {
      await ApiService().addToWatchList(
        idPhimBo: widget.isSeries ? widget.movieId : null,
        idPhimLe: !widget.isSeries ? widget.movieId : null,
      );
      setState(() => _isFollowing = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã thêm vào danh sách theo dõi")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  // Hàm xóa bình luận
  Future<void> _deleteComment(int commentId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bạn có chắc muốn xóa bình luận này?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm) {
      try {
        await ApiService().deleteComment(commentId);
        setState(() {
          _comments.removeWhere((c) => c.id == commentId);
          // Xóa trong replies nếu là comment con
          for (var c in _comments) {
            c.replies.removeWhere((r) => r.id == commentId);
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
        }
      }
    }
  }

  // Hàm hiển thị dialog trả lời
  void _showReplyDialog(int parentId) {
    final TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Trả lời", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: replyController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nhập nội dung...",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              if (replyController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  final reply = await ApiService().replyComment(
                    content: replyController.text.trim(),
                    parentId: parentId,
                  );
                  setState(() {
                    final index = _comments.indexWhere((c) => c.id == parentId);
                    if (index != -1) {
                      final replyWithAuth = Comment(
                        id: reply.id,
                        parentId: parentId,
                        noiDung: reply.noiDung,
                        thoiGian: reply.thoiGian,
                        isLiked: reply.isLiked,
                        likeCount: reply.likeCount,
                        userId: _currentUserId,
                        user: reply.user,
                        replies: [],
                      );
                      _comments[index].replies.add(replyWithAuth);
                    }
                  });
                } catch (e) {
                  debugPrint("Lỗi reply: $e");
                }
              }
            },
            child: const Text("Gửi", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: FutureBuilder<MovieDetailResponse>(
        future: _movieDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Lỗi: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text(
                "Không tìm thấy phim",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!;
          final phim = data.movie;
          final tapPhims = data.episodes;
          final related = data.relatedMovies;

          // Khởi tạo danh sách comment (chỉ làm 1 lần khi có data)
          if (!_isDataLoaded) {
            _comments = List.from(
              data.comments,
            ); // Copy ra list riêng để sửa đổi
            _isDataLoaded = true;
          }

          if (phim == null) {
            return const Center(
              child: Text(
                "Lỗi: Không tìm thấy dữ liệu phim",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Logic khởi tạo video lần đầu tiên (chỉ chạy 1 lần khi có data)
          if (_videoController == null) {
            String initialLink = "";
            if (widget.isSeries && tapPhims.isNotEmpty) {
              initialLink = tapPhims[0].linkPhim;
            } else {
              initialLink = phim.link ?? "";
            }
            // Chỉ init nếu có link và là file mp4 (để tránh lỗi crash với link youtube)
            if (initialLink.endsWith(".mp4")) {
              _initializeVideo(initialLink);
            }
          }

          return CustomScrollView(
            slivers: [
              // 1. App Bar & Video Player Area
              SliverAppBar(
                expandedHeight: 250.0, // Giảm chiều cao chút cho cân đối
                floating: false,
                pinned: true,
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildVideoOrPoster(phim),
                ),
              ),

              // 2. Nội dung chi tiết
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề phim
                      Text(
                        phim.tenPhim,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900, // Đậm hơn
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Thông tin Meta (Năm, Điểm, Thời lượng)
                      Row(
                        children: [
                          const Text(
                            "Độ phù hợp: ",
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            "${phim.matchScore}%",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            phim.nam,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              phim.quocGia,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              "HD",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Nút Play & Download
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () async {
                            // 1. Xác định tập phim (nếu là phim bộ)
                            int? currentTap;
                            if (widget.isSeries && tapPhims.isNotEmpty) {
                              currentTap = tapPhims[_currentEpisodeIndex].soTap;
                            }

                            // 2. Gọi API thêm vào lịch sử (Không await để chuyển trang nhanh, hoặc await nếu muốn chắc chắn)
                            // Sử dụng try-catch để lỗi mạng không chặn việc xem phim
                            try {
                              await ApiService().addToHistory(
                                idPhimBo: widget.isSeries
                                    ? widget.movieId
                                    : null,
                                idPhimLe: !widget.isSeries
                                    ? widget.movieId
                                    : null,
                                tap: currentTap,
                              );
                            } catch (e) {
                              debugPrint("Lỗi thêm lịch sử: $e");
                            }

                            // 3. Chuyển trang
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WatchMovieScreen(
                                  phimId: widget.movieId,
                                  isSeries: widget.isSeries,
                                  tapSo: currentTap,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.play_arrow, size: 28),
                              SizedBox(width: 8),
                              Text(
                                "Phát",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF2B2B2B,
                            ), // Màu xám đậm
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isFollowing ? Icons.check : Icons.add,
                                size: 24,
                                color: _isFollowing ? Colors.red : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isFollowing ? "Đã theo dõi" : "Danh sách",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mô tả phim
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isDescriptionExpanded = !_isDescriptionExpanded;
                          });
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              phim.noiDung,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.4,
                                fontSize: 14,
                              ),
                              maxLines: _isDescriptionExpanded ? null : 3,
                              overflow: _isDescriptionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                            if (phim.noiDung.length > 100)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  _isDescriptionExpanded
                                      ? "Thu gọn"
                                      : "Xem thêm",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cast & Genre
                      Text(
                        "Diễn viên: ${phim.dienVien}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Thể loại: ${phim.theLoai}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Row (My List, Rate, Share)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionIcon(Icons.add, "Danh sách"),
                          _buildActionIcon(
                            Icons.thumb_up_alt_outlined,
                            "Đánh giá",
                          ),
                          _buildActionIcon(Icons.share, "Chia sẻ"),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- DANH SÁCH TẬP (Nếu là phim bộ) ---
                      if (widget.isSeries && tapPhims.isNotEmpty) ...[
                        const Text(
                          "Các tập",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: tapPhims.length,
                            itemBuilder: (context, index) {
                              final tap = tapPhims[index];
                              final isSelected = _currentEpisodeIndex == index;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentEpisodeIndex = index;
                                    // Chuyển video sang tập mới
                                    String newLink = tap.linkPhim;
                                    if (newLink.endsWith(".mp4")) {
                                      _initializeVideo(newLink);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 50,
                                  margin: const EdgeInsets.only(right: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE50914)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : Colors.grey,
                                    ),
                                    /*
                                    border: isSelected
                                        ? Border.all(color: Colors.white)
                                        : null,
                                    */
                                  ),
                                  child: Text(
                                    "${tap.soTap}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Divider(color: Colors.grey),
                      // --- PHIM CÙNG THỂ LOẠI ---
                      _buildRelatedSection("Cùng thể loại", related),

                      const SizedBox(height: 24),

                      // --- BÌNH LUẬN ---
                      const Text(
                        "Bình luận",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Input bình luận
                      _buildCommentInput(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // 3. Danh sách bình luận (Dùng SliverList để tránh lỗi RenderFlex)
              if (_comments.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Chưa có bình luận nào.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCommentItem(index),
                    childCount: _comments.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  // Helper widget cho các nút icon nhỏ (Danh sách, Đánh giá...)
  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  // Widget hiển thị Video Player hoặc Poster nếu không có video
  Widget _buildVideoOrPoster(MovieInfo phim) {
    if (_isVideoInitialized && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      // Hiển thị Poster khi chưa play hoặc đang loading
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _getFormattedImageUrl(phim.img),
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Container(color: Colors.grey[900]),
          ),
          // Gradient overlay để hòa vào nền đen bên dưới
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
                stops: const [0.6, 0.9, 1.0],
              ),
            ),
          ),
          // Nút Play ở giữa
          Center(
            child: IconButton(
              icon: const Icon(
                Icons.play_circle_outline,
                size: 70,
                color: Colors.white,
              ),
              onPressed: () {
                // Logic play nếu cần trigger thủ công
              },
            ),
          ),
        ],
      );
    }
  }

  // Widget danh sách phim liên quan
  Widget _buildRelatedSection(String title, List<MovieItem> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final movie = list[index];
              return GestureDetector(
                onTap: () {
                  // Chuyển sang phim khác (Push replacement để load lại trang này với ID mới)
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailScreen(
                        movieId: movie.id,
                        isSeries:
                            movie.isSeries ??
                            false, // Dùng cờ chính xác từ Backend
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 105,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: _getFormattedImageUrl(movie.img),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[800]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.tenPhim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget nhập bình luận
  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Viết bình luận...",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[900],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isSendingComment ? null : _postComment,
          icon: _isSendingComment
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.red,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.send, color: Color(0xFFE50914)),
        ),
      ],
    );
  }

  // Widget hiển thị từng item bình luận (Redesign để tránh lỗi overflow)
  Widget _buildCommentItem(int index) {
    final cmt = _comments[index];
    final user = cmt.user;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: (user?.avarta != null)
                ? NetworkImage(_getFormattedImageUrl(user!.avarta))
                : null,
            child: (user?.avarta == null)
                ? const Icon(Icons.person, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          // Nội dung chính
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên + Thời gian
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user?.fullName ?? "Người dùng",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      cmt.thoiGian,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Nội dung comment
                Text(
                  cmt.noiDung,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Action Bar (Like, Reply, Delete)
                Row(
                  children: [
                    // Nút Like
                    GestureDetector(
                      onTap: () => _handleLike(index),
                      child: Row(
                        children: [
                          Icon(
                            cmt.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: cmt.isLiked ? Colors.red : Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          if (cmt.likeCount > 0)
                            Text(
                              "${cmt.likeCount}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Nút Trả lời
                    GestureDetector(
                      onTap: () => _showReplyDialog(cmt.id),
                      child: const Text(
                        "Trả lời",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Nút Xóa
                    if (_currentUserId != null &&
                        cmt.userId.toString() == _currentUserId) ...[
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => _deleteComment(cmt.id),
                        child: const Text(
                          "Xóa",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),

                // Hiển thị Replies (Đệ quy đơn giản)
                if (cmt.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Column(
                      children: cmt.replies
                          .map((reply) => _buildReplyItem(reply))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget con cho Reply
  Widget _buildReplyItem(Comment reply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[800],
            backgroundImage: (reply.user?.avarta != null)
                ? NetworkImage(_getFormattedImageUrl(reply.user!.avarta))
                : null,
            child: (reply.user?.avarta == null)
                ? const Icon(Icons.person, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reply.user?.fullName ?? "Người dùng",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_currentUserId != null &&
                        reply.userId.toString() == _currentUserId)
                      GestureDetector(
                        onTap: () => _deleteComment(reply.id),
                        child: const Text(
                          "Xóa",
                          style: TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.noiDung,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
