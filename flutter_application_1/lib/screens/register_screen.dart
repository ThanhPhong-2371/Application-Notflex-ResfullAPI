import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Các controller để lấy dữ liệu từ TextFields
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;

  void _handleRegister() async {
    // 1. Validate cơ bản ở Client
    if (_fullNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passController.text.isEmpty) {
      _showSnackBar("Vui lòng điền đầy đủ thông tin", isError: true);
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      _showSnackBar("Mật khẩu nhập lại không khớp", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Gọi API đăng ký
      final success = await ApiService().register(
        _emailController.text.trim(),
        _passController.text,
        _fullNameController.text.trim(),
        _phoneController.text.trim(),
      );

      if (success && mounted) {
        _showSnackBar("Đăng ký thành công! Vui lòng đăng nhập.");

        // Chuyển sang màn hình đăng nhập
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        // Cắt chuỗi "Exception: " cho đẹp nếu có
        String errorMsg = e.toString().replaceAll("Exception: ", "");
        _showSnackBar(errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Màu nền tối
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/Img/logo.png',
                height: 60,
                errorBuilder: (context, error, stackTrace) => const Text(
                  "NOTFLEX",
                  style: TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "Đăng Ký Tài Khoản",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Form nhập liệu
              _buildTextField(
                "Họ và Tên",
                _fullNameController,
                icon: Icons.person,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                "Số điện thoại",
                _phoneController,
                icon: Icons.phone,
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                "Email",
                _emailController,
                icon: Icons.email,
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                "Mật khẩu",
                _passController,
                icon: Icons.lock,
                isPassword: true,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                "Nhập lại mật khẩu",
                _confirmPassController,
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              const SizedBox(height: 40),

              // Nút Đăng Ký
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Đăng Ký",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Nút chuyển sang Đăng Nhập
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Đã có tài khoản? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Đăng nhập ngay",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget TextField dùng chung để code gọn hơn
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE50914), width: 2),
        ),
      ),
    );
  }
}
