import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'profile_screen.dart';
import 'all_movies_screen.dart';
import 'movie_detail_screen.dart';
import 'search_screen.dart';
import 'news_screen.dart';
import 'more_screen.dart';
import 'ranking_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeDataResponse> _homeData;
  bool _isLoggedIn = false;
  String? _userAvatar; // Biến lưu đường dẫn avatar
  bool _isBottomNavVisible = true;
  final int _currentBottomNavIndex = 0; // Index cho BottomNavBar
  // ĐƯỜNG DẪN ẢNH GỐC (Bạn cần kiểm tra lại folder chứa ảnh trên server là /images hay /uploads)
  // Mẹo: Thử đổi 'Images' thành 'images' (chữ thường) và đảm bảo server đã có app.UseStaticFiles()
  // SỬA: Dùng http:// thay vì https:// để tránh lỗi chứng chỉ SSL trên Android Emulator
  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ??
      "https://largegreyroof19.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    // Giả sử đã có token, nếu API cần đăng nhập, bạn phải xử lý auth trước
    _checkLoginStatus();
    // Không gọi API ngay với token rác, để _checkLoginStatus tự gọi sau
    // _homeData = ApiService().fetchHomeData(token: "YOUR_JWT_TOKEN_HERE");
    _homeData = Future.error(
      "Đang tải dữ liệu...",
    ); // Placeholder để chờ checkLogin
  }

  Future<void> _checkLoginStatus() async {
    final token = await ApiService().getToken();
    final userInfo = await ApiService().getUserInfo();

    if (token != null && mounted) {
      setState(() {
        _isLoggedIn = true;
        if (userInfo != null) {
          _userAvatar = userInfo['avarta'];
        }
      });

      // SỬA: Gọi lại API lấy phim với token vừa lấy được để Backend biết là ai
      _homeData = ApiService().fetchHomeData(token: token);
      // Gọi setState lần nữa để FutureBuilder build lại với data mới
      setState(() {});
    } else {
      // Nếu chưa đăng nhập, gọi API không cần token (hoặc xử lý tùy logic app)
      setState(() {
        _homeData = ApiService().fetchHomeData(token: null);
      });
    }
  }

  // Hàm xử lý URL avatar
  String _getAvatarUrl(String path) {
    if (path.startsWith('http')) return path;

    // Nếu path bắt đầu bằng / (ví dụ /Images/...), ta lấy domain gốc để ghép vào
    if (path.startsWith('/')) {
      final uri = Uri.tryParse(imageBaseUrl);
      if (uri != null) {
        // uri.origin sẽ trả về scheme://host:port (VD: https://funaquasled90.conveyor.cloud)
        return "${uri.origin}$path";
      }
    }
    // Fallback: ghép trực tiếp với imageBaseUrl hiện tại
    return "$imageBaseUrl$path";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Màu nền đen chủ đạo
      extendBodyBehindAppBar: true, // Để ảnh banner tràn lên status bar
      appBar: _buildAppBar(),
      body: FutureBuilder<HomeDataResponse>(
        future: _homeData,
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
                "Không có dữ liệu",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!;

          // Xử lý logic Banner: Nếu API trả về banners rỗng, lấy tạm phim bộ đầu tiên làm banner
          BannerItem? featuredBanner;
          if (data.banners.isNotEmpty) {
            featuredBanner = data.banners.first;
          } else if (data.phimBo.isNotEmpty) {
            featuredBanner = BannerItem(
              id: data.phimBo.first.id,
              fileName: data.phimBo.first.img,
              tenPhim: data.phimBo.first.tenPhim,
            );
          }

          return NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse &&
                  _isBottomNavVisible) {
                // Người dùng vuốt lên (xem nội dung bên dưới) -> Ẩn menu
                setState(() => _isBottomNavVisible = false);
              } else if (notification.direction == ScrollDirection.forward &&
                  !_isBottomNavVisible) {
                // Người dùng vuốt xuống (quay lại đầu trang) -> Hiện menu
                setState(() => _isBottomNavVisible = true);
              }
              return true;
            },
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(overscroll: false),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Banner Chính (Featured Movie)
                    if (featuredBanner != null)
                      _buildFeaturedHeader(featuredBanner),

                    // 2. Các danh sách phim
                    _buildMovieSection(
                      "Đề xuất",
                      data.recommendations,
                      "xemtatcadexuat",
                      // Truyền null để hàm bên dưới tự xử lý hoặc mặc định lại
                      isSeries: null,
                    ),
                    _buildMovieSection(
                      "Phim Bộ ",
                      data.phimBo,
                      "xemtatcaphimbo",
                      isSeries: true,
                    ),
                    _buildMovieSection(
                      "Movie",
                      data.phimLe,
                      "xemtatcaphimle",
                      isSeries: false,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _isBottomNavVisible ? kBottomNavigationBarHeight : 0.0,
        child: SingleChildScrollView(child: _buildBottomNavBar()),
      ),
    );
  }

  // --- Widgets con ---

  // Header (AppBar) trong suốt
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 80, // Tăng chiều rộng vùng chứa logo (mặc định là 56)
      leading: Padding(
        padding: const EdgeInsets.all(
          4.0,
        ), // Giảm padding để logo hiển thị to hơn
        child: Image.asset(
          'assets/Img/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, color: Colors.red);
          },
        ),
      ),
      // THAY ĐỔI Ở ĐÂY: Logic hiển thị nút đăng nhập/đăng ký hoặc Avatar
      actions: [
        if (!_isLoggedIn) ...[
          // TRƯỜNG HỢP CHƯA ĐĂNG NHẬP
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(
                0xFFE50914,
              ), // Chữ màu đỏ thương hiệu
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            child: const Text("Đăng ký"),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914), // Màu đỏ đặc trưng
              foregroundColor: Colors.white,
              elevation: 5, // Thêm độ nổi
              shadowColor: Colors.red.withOpacity(0.5), // Bóng màu đỏ mờ
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // Bo góc mềm mại hơn
              ),
            ),
            child: const Text(
              "Đăng nhập",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
        ] else ...[
          // TRƯỜNG HỢP ĐÃ ĐĂNG NHẬP (Hiện Avatar)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) {
                  // Cập nhật lại thông tin (ví dụ avatar mới) khi quay lại từ trang Profile
                  _checkLoginStatus();
                });
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey,
                radius: 14,
                // Nếu có avatar thì load ảnh, nếu không thì null
                backgroundImage: _userAvatar != null
                    ? NetworkImage(_getAvatarUrl(_userAvatar!))
                    : null,
                // Nếu không có ảnh thì hiện icon mặc định
                child: _userAvatar == null
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Banner lớn đầu trang
  Widget _buildFeaturedHeader(BannerItem banner) {
    // Kiểm tra xem banner là video hay ảnh
    final bool isVideo =
        banner.mediaType == "video" ||
        (banner.fileName != null &&
            banner.fileName!.toLowerCase().endsWith('.mp4'));
    final String fullUrl = "$imageBaseUrl${banner.fileName}";

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Ảnh nền hoặc Video Player
        SizedBox(
          height: 500,
          width: double.infinity,
          child: isVideo
              ? _BannerVideoPlayer(url: fullUrl)
              : CachedNetworkImage(
                  imageUrl: fullUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) {
                    debugPrint("Lỗi tải ảnh banner ($url): $error");
                    return Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.error, color: Colors.red),
                    );
                  },
                ),
        ),
        // Gradient che mờ bên dưới để hiện text rõ hơn
        Container(
          height: 500,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black, Colors.transparent],
            ),
          ),
        ),
        // Nút bấm và thông tin
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                banner.tenPhim,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Thể loại (Hardcode ví dụ vì BannerItem API chưa trả về thể loại)
              const Text(
                "Hồi hộp • Kịch tính • Hành động",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildHeaderButton(Icons.add, "Danh sách"),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text(
                      "Phát",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                  ),
                  _buildHeaderButton(Icons.info_outline, "Thông tin"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderButton(IconData icon, String label) {
    // Bọc trong InkWell để có thể bấm vào và có hiệu ứng ripple
    return InkWell(
      onTap: () {
        debugPrint("Header button tapped: $label");
      },
      splashColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Section danh sách phim trượt ngang
  Widget _buildMovieSection(
    String title,
    List<MovieItem> movies,
    String apiEndpoint, {
    bool? isSeries, // Cho phép null để tự động xác định hoặc dùng mặc định khác
  }) {
    if (movies.isEmpty) return const SizedBox.shrink();

    // Tính toán kích thước co giãn dựa trên chiều rộng màn hình
    final double screenWidth = MediaQuery.of(context).size.width;
    // Hiển thị khoảng 3.5 poster trên màn hình
    final double itemWidth = screenWidth / 3.5;
    // Giữ tỷ lệ 2:3 cho poster (chiều cao = chiều rộng * 1.5)
    final double itemHeight = itemWidth * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllMoviesScreen(
                        title: title,
                        apiEndpoint: apiEndpoint,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Xem tất cả",
                  style: TextStyle(
                    color: Colors.white70, // Màu chữ nhạt hơn tiêu đề chút
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: itemHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];

              // LOGIC XÁC ĐỊNH LOẠI PHIM:
              // 1. Nếu isSeries (tham số hàm) có giá trị -> dùng nó (cho mục Phim Bộ/Phim Lẻ riêng biệt).
              // 2. Nếu null (mục Đề xuất) -> Lấy từ movie.isSeries. Nếu vẫn null -> mặc định false.
              bool finalIsSeries = isSeries ?? movie.isSeries ?? false;

              // Bọc trong GestureDetector để có thể bấm vào
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailScreen(
                        movieId: movie.id,
                        isSeries: finalIsSeries,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: itemWidth,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: "$imageBaseUrl${movie.img}",
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (context, url, error) {
                        debugPrint("Lỗi tải ảnh phim ($url): $error");
                        return const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        );
                      },
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

  // Bottom Navigation Bar
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF121212), // Màu xám đen
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentBottomNavIndex,
      onTap: (index) {
        // Trang chủ (index 0) thì không làm gì vì đã ở đó rồi
        if (index == 0) return;

        // Trang tìm kiếm (index 1)
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RankingScreen()),
          );
        } else if (index == 3) {
          // Trang tin tức (index 3)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewsScreen()),
          );
        } else if (index == 4) {
          // Trang Thêm (Menu)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MoreScreen()),
          );
        } else {
          // Các mục khác chưa có chức năng, có thể hiện SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Chức năng này sẽ sớm được cập nhật!"),
              duration: Duration(seconds: 1),
            ),
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

// Widget riêng để xử lý Video Player cho Banner
class _BannerVideoPlayer extends StatefulWidget {
  final String url;
  const _BannerVideoPlayer({required this.url});

  @override
  State<_BannerVideoPlayer> createState() => _BannerVideoPlayerState();
}

class _BannerVideoPlayerState extends State<_BannerVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
          _controller.setVolume(0.0);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return Container(color: Colors.black);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
