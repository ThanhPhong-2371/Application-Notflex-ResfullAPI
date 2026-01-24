import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'deposit_screen.dart'; // Để chuyển hướng nếu thiếu tiền
import 'login_screen.dart'; // Để chuyển hướng nếu chưa đăng nhập

class PremiumPlansScreen extends StatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  State<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends State<PremiumPlansScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _plans = [];
  bool _isLoading = true;
  String? _selectedPlanId; // Lưu ID gói đang chọn

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _apiService.fetchPremiumPlans();
      setState(() {
        _plans = plans;
        // Mặc định chọn gói phổ biến (monthly) hoặc gói đầu tiên
        if (_plans.isNotEmpty) {
          final popular = _plans.firstWhere(
            (p) => p['id'] == 'monthly',
            orElse: () => _plans.first,
          );
          _selectedPlanId = popular['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBuy(String planKey, double price) async {
    // 1. Kiểm tra đăng nhập
    final token = await _apiService.getToken();
    if (token == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    // Hiển thị loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );

    try {
      await _apiService.buyPremium(planKey);
      Navigator.pop(context); // Tắt loading

      // Thông báo thành công
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          content: const Text(
            "Đăng ký thành công!\nBạn đã là thành viên Premium.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Tắt dialog
                Navigator.pop(context); // Quay về trang trước
              },
              child: const Text(
                "Tuyệt vời",
                style: TextStyle(color: Color(0xFFE50914)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Tắt loading

      // Nếu lỗi là do thiếu tiền -> Gợi ý nạp tiền
      if (e.toString().contains("Số dư không đủ")) {
        _showDepositDialog();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  void _showDepositDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          "Số dư không đủ",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Ví của bạn không đủ tiền để mua gói này. Vui lòng nạp thêm.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DepositScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
            ),
            child: const Text(
              "Nạp Tiền Ngay",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Gói Premium",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final bool isPopular =
                    plan['id'] == 'monthly'; // Giả sử gói tháng là phổ biến
                final bool isSelected = plan['id'] == _selectedPlanId;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedPlanId = plan['id']);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF252525)
                          : const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: const Color(0xFFE50914), width: 2)
                          : Border.all(color: Colors.transparent, width: 2),
                      boxShadow: [
                        if (isSelected || isPopular)
                          BoxShadow(
                            color: const Color(0xFFE50914).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (isPopular)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE50914),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "PHỔ BIẾN NHẤT",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                plan['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatCurrency(plan['priceVND']),
                                style: const TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "${plan['durationDays']} ngày sử dụng",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const Divider(color: Colors.white24, height: 30),

                              _buildFeatureItem("Xem không quảng cáo"),
                              _buildFeatureItem("Chất lượng 4K Ultra HD"),
                              _buildFeatureItem(
                                "Đăng nhập ${plan['maxDevices']} thiết bị",
                              ),
                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _handleBuy(
                                    plan['id'],
                                    (plan['priceVND'] as num).toDouble(),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? const Color(0xFFE50914)
                                        : Colors.white,
                                    foregroundColor: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    "Chọn Gói Này",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
