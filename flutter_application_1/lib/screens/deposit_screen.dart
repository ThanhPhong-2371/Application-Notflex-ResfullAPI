import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Cần thêm package này để mở URL
import '../services/api_service.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final ApiService _apiService = ApiService();
  String _selectedGateway = "Momo"; // Mặc định chọn Momo
  bool _isLoading = false;

  final List<int> _quickAmounts = [20000, 50000, 100000, 200000, 500000];

  Future<void> _handleDeposit() async {
    double? amount = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Số tiền nạp tối thiểu là 10.000đ")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Gọi API lấy URL thanh toán
      final url = await _apiService.createDeposit(amount, _selectedGateway);

      // 2. Mở trình duyệt để thanh toán
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Không thể mở liên kết thanh toán");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Nạp Tiền",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nhập số tiền cần nạp",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // Input tiền
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                suffixText: "VNĐ",
                suffixStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Các mức tiền nhanh
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickAmounts.map((amount) {
                return ActionChip(
                  label: Text(
                    "${amount ~/ 1000}k",
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF2B2B2B),
                  onPressed: () {
                    _amountController.text = amount.toString();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),
            const Text(
              "Chọn phương thức thanh toán",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // Chọn cổng thanh toán
            _buildGatewayOption(
              "Momo",
              "assets/images/momo_logo.png",
            ), // Cần thêm ảnh vào assets
            const SizedBox(height: 10),
            _buildGatewayOption("VNPay", "assets/images/vnpay_logo.png"),

            const SizedBox(height: 40),

            // Nút xác nhận
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "TIẾP TỤC",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayOption(String gatewayName, String imagePath) {
    final bool isSelected = _selectedGateway == gatewayName;
    return GestureDetector(
      onTap: () => setState(() => _selectedGateway = gatewayName),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE50914).withOpacity(0.1)
              : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Thay icon bằng ảnh logo nếu có
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  gatewayName[0],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              gatewayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFE50914)),
          ],
        ),
      ),
    );
  }
}
