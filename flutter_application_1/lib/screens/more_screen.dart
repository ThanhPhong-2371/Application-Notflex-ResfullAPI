import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'watch_history_screen.dart';
import 'watch_list_screen.dart';
import 'wallet_screen.dart';
import 'login_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  double _balance = 0;
  String _userName = "Tài khoản của bạn";
  String? _avatarUrl;
  bool _isLoggedIn = false;
  final String imageBaseUrl =
      dotenv.env['IMAGE_URL'] ?? "https://funaquasled90.conveyor.cloud/images/";

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final userInfo = await ApiService().getUserInfo();
      if (mounted) {
        setState(() {
          if (userInfo != null) {
            _isLoggedIn = true;
            _userName = userInfo['fullName'] ?? "Tài khoản của bạn";
            _avatarUrl = userInfo['avarta'];
          } else {
            _isLoggedIn = false;
            _userName = "Tài khoản của bạn";
            _avatarUrl = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải profile: $e");
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

  Future<void> _fetchBalance() async {
    try {
      final data = await ApiService().fetchWallet();
      if (mounted) {
        setState(() {
          _balance = (data['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải ví: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Menu",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          // 1. Shortcut đến Profile
          GestureDetector(
            onTap: () async {
              if (_isLoggedIn) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
              _fetchUserProfile(); // Cập nhật lại avatar/tên khi quay về
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 24,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_getFormattedImageUrl(_avatarUrl))
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Chạm để xem chi tiết",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Ví & Nạp tiền (Mới thêm)
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
              _fetchBalance(); // Cập nhật lại số dư khi quay về từ màn hình Ví
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF252525)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.amber,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Số dư ví",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: 'đ',
                        ).format(_balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                        _fetchBalance();
                      },
                      icon: const Icon(Icons.add_card, size: 18),
                      label: const Text("Nạp tiền ngay"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // 3. Danh sách chức năng
          _buildSectionTitle("Thư viện"),
          _buildMenuItem(context, Icons.check, "Danh sách của tôi", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WatchListScreen()),
            );
          }),
          _buildMenuItem(context, Icons.history, "Lịch sử xem", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WatchHistoryScreen(),
              ),
            );
          }),

          const SizedBox(height: 20),
          _buildSectionTitle("Ứng dụng"),
          _buildMenuItem(context, Icons.settings, "Cài đặt", () {}),
          _buildMenuItem(context, Icons.notifications, "Thông báo", () {}),
          _buildMenuItem(
            context,
            Icons.help_outline,
            "Trợ giúp & Hỗ trợ",
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey,
        size: 14,
      ),
    );
  }
}
