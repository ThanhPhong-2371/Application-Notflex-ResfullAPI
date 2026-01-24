import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/home_model.dart';
import '../models/movie_detail_model.dart';
import '../models/comment_like_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Lấy API_URL từ file .env
  static String get baseUrl => dotenv.env['API_URL'] ?? "";

  // Bạn cần truyền token nếu API yêu cầu xác thực (User.FindFirstValue)
  Future<HomeDataResponse> fetchHomeData({String? token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/HomeAPI/Index?page=1'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return HomeDataResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load home data');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Lưu token vào máy
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        await prefs.setString('user_info', jsonEncode(data['userInfo']));
        return data; // Trả về data để xử lý UI
      } else {
        throw Exception(
          jsonDecode(response.body)['message'] ?? "Lỗi đăng nhập",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Đăng ký
  Future<bool> register(
    String email,
    String password,
    String fullName,
    String sdt,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Auth/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "fullName": fullName,
        "sdt": sdt,
        "dob": "2000-01-01", // Tạm thời hardcode hoặc thêm date picker
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? "Đăng ký thất bại");
    }
  }

  // Hàm lấy token đã lưu
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Hàm lấy thông tin user đã lưu
  Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString('user_info');
    if (userStr != null) return jsonDecode(userStr);
    return null;
  }

  // Đăng xuất
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_info');
  }

  // Lấy Profile từ API
  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/Profile/me'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Không thể tải thông tin cá nhân");
    }
  }

  // Upload Avatar
  Future<String> uploadAvatar(List<int> bytes, String fileName) async {
    final token = await getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Profile/upload-avatar'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);

      // Cập nhật lại cache user_info
      await _updateLocalAvatar(data['avatar']);
      return data['avatar'];
    } else {
      throw Exception("Upload thất bại");
    }
  }

  // Cập nhật thông tin cá nhân (FullName, SDT, Dob)
  Future<bool> updateProfile(String fullName, String sdt, String dob) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/Profile/update'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"fullName": fullName, "sdt": sdt, "dob": dob}),
    );

    if (response.statusCode == 200) {
      // Cập nhật cache local để đồng bộ tên hiển thị ở các màn hình khác
      await _updateLocalName(fullName);
      return true;
    } else {
      throw Exception("Cập nhật thất bại");
    }
  }

  // Hàm phụ: Update cache local để Home Screen tự cập nhật
  Future<void> _updateLocalAvatar(String newAvatar) async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_info');
    if (userStr != null) {
      var userMap = jsonDecode(userStr);
      userMap['avarta'] = newAvatar; // Cập nhật key avarta
      await prefs.setString('user_info', jsonEncode(userMap));
    }
  }

  // Hàm phụ: Update cache local tên người dùng
  Future<void> _updateLocalName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_info');
    if (userStr != null) {
      var userMap = jsonDecode(userStr);
      userMap['fullName'] = newName;
      await prefs.setString('user_info', jsonEncode(userMap));
    }
  }

  Future<PagedMovieResponse> fetchPagedMovies(String endpoint, int page) async {
    final token = await getToken();
    // Giả sử Controller là HomeAPI dựa trên code cũ
    final uri = Uri.parse('$baseUrl/HomeAPI/$endpoint?page=$page');

    final response = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return PagedMovieResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Lỗi tải danh sách phim: ${response.statusCode}");
    }
  }

  // Lấy chi tiết Phim Bộ
  Future<MovieDetailResponse> getPhimBoDetail(int id) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/DetailsAPIMovie/phimbo/$id'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return MovieDetailResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Lỗi tải chi tiết phim bộ ($id): ${response.statusCode}');
    }
  }

  // Lấy chi tiết Phim Lẻ
  Future<MovieDetailResponse> getPhimLeDetail(int id) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/DetailsAPIMovie/phimle/$id'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return MovieDetailResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Lỗi tải chi tiết phim lẻ ($id): ${response.statusCode}');
    }
  }

  // --- COMMENT API ---

  // Thêm bình luận
  Future<Comment> addComment({
    required String content,
    int? idPhimBo,
    int? idPhimLe,
    int? idTapPhim,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/CommentAPI/add'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "noiDung": content,
        "idPhimBo": idPhimBo,
        "idPhimLe": idPhimLe,
        "idTapPhim": idTapPhim,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Comment.fromJson(data['comment']);
    } else {
      throw Exception("Lỗi thêm bình luận: ${response.statusCode}");
    }
  }

  // Like/Unlike bình luận
  Future<CommentLikeModel> toggleLikeComment(int commentId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/CommentAPI/like/$commentId'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return CommentLikeModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Lỗi like bình luận");
    }
  }

  // Trả lời bình luận
  Future<Comment> replyComment({
    required String content,
    required int parentId,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/CommentAPI/reply'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({"noiDung": content, "parentId": parentId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Comment.fromJson(data['reply']);
    } else {
      throw Exception("Lỗi trả lời bình luận: ${response.statusCode}");
    }
  }

  // Xóa bình luận
  Future<bool> deleteComment(int commentId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/CommentAPI/delete/$commentId'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Lỗi xóa bình luận");
    }
  }

  // Hàm gọi API lấy dữ liệu video (chuyển từ logic _loadVideoData)
  Future<Map<String, dynamic>> fetchVideoData(
    int phimId,
    bool isSeries,
    int? tapSo,
  ) async {
    final token = await getToken();
    final endpoint = isSeries
        ? '/XemPhimAPI/phimbo/$phimId?tap=${tapSo ?? 1}'
        : '/XemPhimAPI/phimle/$phimId';

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Lỗi tải dữ liệu video: ${response.statusCode}");
    }
  }

  // Trong class ApiService
  Future<List<MovieItem>> searchMovies(String keyword) async {
    final token = await getToken();
    // Gọi API bạn vừa viết ở trên
    final response = await http.get(
      Uri.parse('$baseUrl/SearchAPI/search?keyword=$keyword&pageSize=20'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        final List<dynamic> list = body['data'];
        return list
            .map(
              (e) => MovieItem(
                id: e['id'],
                tenPhim: e['tenPhim'],
                img: e['img'], // Nhớ xử lý URL ảnh như màn hình WatchMovie
                isSeries: e['isSeries'],
              ),
            )
            .toList();
      }
    }
    return [];
  }

  // Lấy danh sách tin tức
  Future<List<dynamic>> fetchNews() async {
    final response = await http.get(Uri.parse('$baseUrl/NewsAPI'));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    }
    return [];
  }

  // Lấy chi tiết tin tức
  Future<Map<String, dynamic>> fetchNewsDetail(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/NewsAPI/$id'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load news');
  }

  // Lấy lịch sử
  Future<List<dynamic>> fetchHistory() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/HistoryAPI'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    }
    return [];
  }

  // Xóa lịch sử
  Future<void> deleteHistory(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/HistoryAPI/delete/$id'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode != 200) throw Exception("Lỗi xóa");
  }

  // Thêm vào lịch sử xem (Gọi khi nhấn nút Phát)
  Future<void> addToHistory({int? idPhimBo, int? idPhimLe, int? tap}) async {
    final token = await getToken();
    // Backend C# nhận tham số qua Query String hoặc FormUrlEncoded vì không dùng [FromBody] với DTO
    final uri = Uri.parse('$baseUrl/HistoryAPI/add').replace(
      queryParameters: {
        if (idPhimBo != null) 'idPhimBo': idPhimBo.toString(),
        if (idPhimLe != null) 'idPhimLe': idPhimLe.toString(),
        if (tap != null) 'tap': tap.toString(),
      },
    );

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    // Không throw exception để tránh chặn người dùng xem phim nếu API lỗi nhẹ
  }

  // --- THEO DÕI (MY LIST) API ---

  // Kiểm tra đã theo dõi chưa
  Future<bool> checkIsFollowing({int? idPhimBo, int? idPhimLe}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/TheoDoiAPI/check').replace(
      queryParameters: {
        if (idPhimBo != null) 'idPhimBo': idPhimBo.toString(),
        if (idPhimLe != null) 'idPhimLe': idPhimLe.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {if (token != null) "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['isFollowing'] ?? false;
    }
    return false;
  }

  // Thêm vào danh sách theo dõi
  Future<bool> addToWatchList({int? idPhimBo, int? idPhimLe}) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/TheoDoiAPI/add'),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({"IdPhimBo": idPhimBo, "IdPhimLe": idPhimLe}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception("Lỗi thêm vào danh sách");
    }
  }

  // Lấy danh sách theo dõi
  Future<List<dynamic>> fetchWatchList() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/TheoDoiAPI'),
      headers: {if (token != null) "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? [];
    }
    return [];
  }

  // Xóa khỏi danh sách theo dõi
  Future<void> removeFromWatchList(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/TheoDoiAPI/delete/$id'),
      headers: {if (token != null) "Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      throw Exception("Lỗi xóa khỏi danh sách");
    }
  }

  // Lấy thông tin ví
  Future<Map<String, dynamic>> fetchWallet() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/WalletAPI'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    return {'Balance': 0, 'LastUpdated': ''};
  }

  // Lấy lịch sử giao dịch
  Future<List<dynamic>> fetchTransactions() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/WalletAPI/history'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    return [];
  }

  // Xóa giao dịch
  Future<void> deleteTransaction(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/WalletAPI/history/$id'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode != 200) throw Exception("Lỗi xóa");
  }

  // Lấy danh sách gói Premium
  Future<List<dynamic>> fetchPremiumPlans() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/CheckoutAPI/plans'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    return [];
  }

  // Mua gói Premium
  Future<void> buyPremium(String planKey) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/CheckoutAPI/buy-premium'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"PlanKey": planKey}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? "Lỗi thanh toán");
    }
  }

  // Tạo yêu cầu nạp tiền (Trả về URL thanh toán)
  Future<String> createDeposit(double amount, String gateway) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/CheckoutAPI/deposit'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"Amount": amount, "Gateway": gateway}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['paymentUrl'];
    }
    throw Exception("Lỗi tạo đơn nạp tiền");
  }

  // Lấy danh sách Top Trending từ AI
  Future<List<dynamic>> fetchTopRanking(String type) async {
    // type: 'week' hoặc 'month'
    final response = await http.get(
      Uri.parse('$baseUrl/RatingAPI/top?type=$type&limit=9'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'];
    }
    return [];
  }
}
