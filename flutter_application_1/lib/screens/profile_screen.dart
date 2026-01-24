import 'dart:ui'; // Cần cho ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/home_screen.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';

import 'watch_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ??
      "https://largegreyroof19.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService().getProfile();
      setState(() {
        _user = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // SỬA LỖI: Tắt loading dù có lỗi
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi tải hồ sơ: $e")));
      }
    }
  }

  // Chọn ảnh và Upload ngay
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (!mounted) return;
      // Hiện loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đang tải ảnh lên...")));

      try {
        final bytes = await image.readAsBytes();
        String newFileName = await ApiService().uploadAvatar(bytes, image.name);

        if (!mounted) return;
        setState(() {
          _user ??= {}; // Khởi tạo map nếu chưa có dữ liệu để tránh lỗi null
          _user!['avarta'] = newFileName; // Cập nhật UI ngay lập tức
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật ảnh thành công!")),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi upload: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Xử lý Đăng xuất
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Đăng xuất", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bạn có chắc chắn muốn đăng xuất?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Đăng xuất",
              style: TextStyle(
                color: Color(0xFFE50914),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService().logout();
      if (mounted) {
        // Chuyển về trang Login và xóa hết stack cũ
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Thông tin cá nhân"),
                        const SizedBox(height: 10),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.email_outlined,
                            "Email",
                            _user?['email'] ?? "",
                          ),
                          _buildDivider(),
                          _buildInfoRow(
                            Icons.phone_iphone,
                            "Số điện thoại",
                            _user?['sdt'] ?? "Chưa cập nhật",
                          ),
                          _buildDivider(),
                          _buildInfoRow(
                            Icons.cake_outlined,
                            "Ngày sinh",
                            _user?['dob'] ?? "Chưa cập nhật",
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Tài khoản & Dịch vụ"),
                        const SizedBox(height: 10),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.workspace_premium,
                            "Gói dịch vụ",
                            (_user?['isPremium'] == true)
                                ? "Premium (VIP)"
                                : "Miễn phí",
                            valueColor: (_user?['isPremium'] == true)
                                ? Colors.amber
                                : Colors.grey,
                          ),
                          _buildDivider(),
                          _buildActionRow(Icons.history, "Lịch sử xem", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const WatchHistoryScreen(),
                              ),
                            );
                          }),
                          _buildDivider(),
                          _buildActionRow(
                            Icons.edit_note,
                            "Chỉnh sửa thông tin",
                            () async {
                              // Chuyển sang trang Edit và đợi kết quả trả về
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditProfileScreen(userData: _user ?? {}),
                                ),
                              );
                              // Nếu có cập nhật (result == true), tải lại profile
                              if (result == true) _loadProfile();
                            },
                          ),
                          _buildDivider(),
                          _buildActionRow(
                            Icons.logout,
                            "Đăng xuất",
                            _handleLogout,
                          ),
                        ]),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Quay lại Home
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text("Quay lại Trang chủ"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Lớp 1: Ảnh nền mờ (Lấy chính avatar làm nền)
            Image(image: _getAvatarImage(), fit: BoxFit.cover),
            // Lớp 2: Blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withOpacity(0.6), // Làm tối bớt
              ),
            ),
            // Lớp 3: Gradient để chuyển tiếp mượt xuống body
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
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
            // Lớp 4: Nội dung chính (Avatar + Tên)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40), // Tránh status bar
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE50914),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundImage: _getAvatarImage(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFFE50914),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user?['fullName'] ?? "Xin chào",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Thành viên NotFlex",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getAvatarImage() {
    String? avatar = _user?['avarta'];
    if (avatar == null || avatar.isEmpty || avatar == "default_avatar.png") {
      return const NetworkImage("https://i.pravatar.cc/150?img=12");
    }

    // Nếu avatar đã là link full (http...)
    if (avatar.startsWith('http')) return NetworkImage(avatar);

    // Chuẩn hóa URL để tránh lỗi thiếu/thừa dấu /
    String cleanBase = imageBaseUrl.endsWith('/')
        ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
        : imageBaseUrl;
    String cleanPath = avatar.startsWith('/') ? avatar : "/$avatar";
    return NetworkImage("$cleanBase$cleanPath");
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.grey[400],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16), // Bo tròn hiệu ứng ripple
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE50914), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE50914),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[800], indent: 54);
  }
}
