import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import để chỉnh màu thanh trạng thái
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../models/home_model.dart';
import '../models/movie_detail_model.dart';

class WatchMovieScreen extends StatefulWidget {
  final int phimId;
  final int? tapSo;
  final bool isSeries;

  const WatchMovieScreen({
    super.key,
    required this.phimId,
    this.tapSo,
    required this.isSeries,
  });

  @override
  State<WatchMovieScreen> createState() => _WatchMovieScreenState();
}

class _WatchMovieScreenState extends State<WatchMovieScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isLocked = false;
  bool _isPlatformSupported = true;
  String? _errorMessage;
  String? _videoUrl;
  String _tenPhim = "";
  List<dynamic> _dsTap = [];
  int _currentTap = 1;
  int _currentTapId = 0;
  List<Comment> _comments = [];
  List<MovieItem> _relatedMovies = [];
  final TextEditingController _commentController = TextEditingController();
  String? _currentUserId;

  final String cloudName = "ddr6fc5dp";
  final String playerProfile = "tap2";

  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ??
      "https://largegreyroof19.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    // Chỉnh màu thanh trạng thái trong suốt để mất vạch đen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _checkCurrentUser();
    _loadVideoData();
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

  Future<void> _checkCurrentUser() async {
    final userInfo = await ApiService().getUserInfo();
    if (userInfo != null && mounted) {
      setState(() => _currentUserId = userInfo['id']?.toString());
    }
  }

  Future<void> _loadVideoData() async {
    try {
      final api = ApiService();
      final data = await api.fetchVideoData(
        widget.phimId,
        widget.isSeries,
        widget.tapSo,
      );

      setState(() {
        if (widget.isSeries) {
          _tenPhim = data['phim']['tenPhim'];
          _currentTap = data['tapHienTai']['tapSo'];
          _currentTapId = data['tapHienTai']['idTapPhim'];
          _isLocked = data['tapHienTai']['isLocked'];
          _dsTap = data['danhSachTap'];

          String publicId = data['tapHienTai']['linkVideo'] ?? "";
          int startTime = data['userData']['thoiGianDaXem'] ?? 0;

          _videoUrl =
              "https://player.cloudinary.com/embed/?cloud_name=$cloudName&public_id=$publicId&profile=$playerProfile&fluid=true&start_offset=$startTime&autoplay=true&muted=true";
        } else {
          _tenPhim = data['phim']['tenPhim'];
          _isLocked = data['isLocked'];
          String link = data['phim']['linkVideo'] ?? "";
          _videoUrl =
              "https://player.cloudinary.com/embed/?cloud_name=$cloudName&public_id=$link&profile=$playerProfile&fluid=true&autoplay=true&muted=true";
        }

        final commentsData = data['Comments'] ?? data['comments'];
        if (commentsData != null) {
          // 1. Parse toàn bộ danh sách phẳng từ API
          final allComments = (commentsData as List)
              .map((e) => Comment.fromJson(e))
              .toList();

          // 2. Tạo Map để tra cứu nhanh theo ID
          final Map<int, Comment> commentMap = {
            for (var c in allComments) c.id: c,
          };

          // 3. Lọc và gom nhóm: Chỉ giữ lại comment cha (parentId == null) ở list chính
          _comments = [];
          for (var c in allComments) {
            if (c.parentId == null) {
              _comments.add(c);
            } else if (commentMap.containsKey(c.parentId)) {
              // Nếu là con, add vào list replies của cha
              commentMap[c.parentId]!.replies.add(c);
            }
          }

          // 4. Sắp xếp lại các câu trả lời (Replies) theo thứ tự cũ -> mới (ID tăng dần)
          // Để cuộc hội thoại hiển thị tự nhiên từ trên xuống dưới
          for (var c in _comments) {
            c.replies.sort((a, b) => a.id.compareTo(b.id));
          }
        }

        if (data['Related'] != null && data['Related'] is List) {
          _relatedMovies = (data['Related'] as List).map((e) {
            return MovieItem(
              id: e['ID'] ?? e['id'] ?? 0,
              tenPhim: e['TenPhim'] ?? e['tenPhim'] ?? "",
              img: e['Img'] ?? e['img'] ?? "",
              isSeries: widget.isSeries,
            );
          }).toList();
        }

        if (!_isLocked) {
          _initWebView();
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Lỗi tải phim: $e");
      setState(() => _isLoading = false);
    }
  }

  void _initWebView() {
    if (!kIsWeb && (!Platform.isAndroid && !Platform.isIOS)) {
      setState(() => _isPlatformSupported = false);
      return;
    }

    try {
      final controller = WebViewController();
      if (!kIsWeb) {
        controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        controller.setBackgroundColor(const Color(0xFF000000));
      }
      try {
        controller.setNavigationDelegate(
          NavigationDelegate(onPageFinished: (String url) {}),
        );
      } catch (e) {
        /* Ignore */
      }

      controller.loadRequest(Uri.parse(_videoUrl!));
      _webViewController = controller;
    } catch (e) {
      _errorMessage = "Lỗi trình phát: $e";
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    try {
      final api = ApiService();
      final newComment = await api.addComment(
        content: _commentController.text,
        idPhimBo: widget.isSeries ? widget.phimId : null,
        idPhimLe: !widget.isSeries ? widget.phimId : null,
        idTapPhim: widget.isSeries ? _currentTapId : null,
      );

      final commentWithAuth = Comment(
        id: newComment.id,
        parentId: newComment.parentId,
        noiDung: newComment.noiDung,
        thoiGian: newComment.thoiGian,
        isLiked: newComment.isLiked,
        likeCount: newComment.likeCount,
        userId: _currentUserId,
        user: newComment.user,
        replies: [],
      );

      setState(() {
        _comments.insert(0, commentWithAuth);
        _commentController.clear();
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  // Hàm like bình luận
  Future<void> _handleLike(int index) async {
    final comment = _comments[index];
    try {
      final result = await ApiService().toggleLikeComment(comment.id);
      setState(() {
        _comments[index] = Comment(
          id: comment.id,
          parentId: comment.parentId,
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
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng màu nền tối hoàn toàn để hòa với video
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Column(
        children: [
          // 1. PHẦN HEADER VIDEO (Đã sửa để không bị vạch đen)
          _buildVideoSection(),

          // 2. PHẦN NỘI DUNG CUỘN BÊN DƯỚI
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thông tin phim
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tenPhim,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            if (widget.isSeries) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Tập $_currentTap",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Danh sách tập (Nếu là phim bộ)
                      if (widget.isSeries && _dsTap.isNotEmpty)
                        _buildEpisodeList()
                      else if (!widget.isSeries)
                        _buildSingleMovieInfo(),

                      const SizedBox(height: 24),
                      _buildRelatedMovies(), // Phim liên quan

                      const Divider(
                        color: Colors.white10,
                        thickness: 1,
                        height: 40,
                      ),

                      // Phần bình luận
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Bình luận",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCommentInput(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Danh sách bình luận (Dùng SliverList)
                if (_comments.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          "Chưa có bình luận nào.",
                          style: TextStyle(color: Colors.grey),
                        ),
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
            ),
          ),
        ],
      ),
    );
  }

  // Widget Video Player + Nút Back tùy chỉnh
  Widget _buildVideoSection() {
    return Container(
      color: Colors.black, // Nền đen cho video area
      child: SafeArea(
        bottom: false, // Chỉ cần safe area ở trên (tránh tai thỏ)
        child: Stack(
          children: [
            // Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    )
                  : _isLocked
                  ? _buildLockedScreen()
                  : _isPlatformSupported
                  ? (_errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : (_webViewController != null
                              ? WebViewWidget(controller: _webViewController!)
                              : const SizedBox()))
                  : const Center(
                      child: Text(
                        "Không hỗ trợ nền tảng này",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),

            // Nút Back nằm đè lên Video (Thay thế AppBar)
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            "Danh sách tập",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        SizedBox(
          height: 50, // Chiều cao danh sách tập
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dsTap.length,
            itemBuilder: (context, index) {
              final tap = _dsTap[index];
              bool isActive = tap['tapSo'] == _currentTap;
              return GestureDetector(
                onTap: () {
                  if (isActive) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WatchMovieScreen(
                        phimId: widget.phimId,
                        tapSo: tap['tapSo'],
                        isSeries: true,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  margin: const EdgeInsets.only(right: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFE50914)
                        : const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(4), // Bo góc nhẹ
                    border: isActive ? null : Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    "${tap['tapSo']}",
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMovieInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            "Thời lượng",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "90 Phút",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedMovies() {
    if (_relatedMovies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Text(
            "Đề xuất cho bạn",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _relatedMovies.length,
            itemBuilder: (context, index) {
              final movie = _relatedMovies[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WatchMovieScreen(
                        phimId: movie.id,
                        isSeries: movie.isSeries ?? widget.isSeries,
                        tapSo: null,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: _getFormattedImageUrl(movie.img),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[900]),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        movie.tenPhim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
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

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Thêm bình luận...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF2B2B2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _postComment,
            icon: const Icon(Icons.send, color: Color(0xFFE50914)),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị từng item bình luận (Redesign)
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
            backgroundImage: (user?.avarta != null && user!.avarta!.isNotEmpty)
                ? NetworkImage(_getFormattedImageUrl(user.avarta))
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                        cmt.userId == _currentUserId) ...[
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

                // Hiển thị Replies
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
                Text(
                  reply.user?.fullName ?? "Người dùng",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildLockedScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF141414), Color(0xFF1F1F1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, color: Color(0xFFE50914), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            "Nội dung Premium",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {}, // Thêm action mở màn hình mua gói
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE50914),
            ),
            child: const Text("Nâng cấp ngay"),
          ),
        ],
      ),
    );
  }
}
