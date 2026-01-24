import 'home_model.dart'; // Để tái sử dụng MovieItem nếu cần

class MovieInfo {
  final int id;
  final String tenPhim;
  final String? img;
  final String? link;
  final int matchScore;
  final String nam;
  final String quocGia;
  final String noiDung;
  final String dienVien;
  final String theLoai;

  MovieInfo({
    required this.id,
    required this.tenPhim,
    this.img,
    this.link,
    required this.matchScore,
    required this.nam,
    required this.quocGia,
    required this.noiDung,
    required this.dienVien,
    required this.theLoai,
  });

  factory MovieInfo.fromJson(Map<String, dynamic> json) {
    return MovieInfo(
      id: json['id'] ?? 0,
      tenPhim: json['tenPhim'] ?? "Chưa cập nhật",
      img: json['img'],
      link: json['link'],
      matchScore: json['matchScore'] ?? 0,
      nam: json['nam']?.toString() ?? "2024",
      quocGia: json['quocGia'] ?? "VN",
      noiDung: json['noiDung'] ?? "Chưa có mô tả",
      dienVien: json['dienVien'] ?? "Đang cập nhật",
      theLoai: json['theLoai'] ?? "Khác",
    );
  }
}

class Episode {
  final int id; // Thêm ID
  final int soTap;
  final String linkPhim;

  Episode({this.id = 0, required this.soTap, required this.linkPhim});

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] ?? json['ID'] ?? 0,
      soTap: json['soTap'] ?? 0,
      linkPhim: json['linkPhim'] ?? "",
    );
  }
}

class CommentUser {
  final String fullName;
  final String? avarta;

  CommentUser({required this.fullName, this.avarta});

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      fullName: json['fullName'] ?? json['FullName'] ?? "Người dùng",
      avarta: json['avarta'] ?? json['Avarta'],
    );
  }
}

class Comment {
  final int id; // Thêm ID
  final int? parentId; // Thêm ParentID để biết là comment con
  final String noiDung;
  final String thoiGian;
  final bool isLiked;
  final int likeCount; // Thêm số like
  final String? userId; // Thêm userId để check quyền xóa
  final CommentUser? user;
  final List<Comment> replies; // Thêm danh sách trả lời

  Comment({
    required this.id,
    this.parentId,
    required this.noiDung,
    required this.thoiGian,
    required this.isLiked,
    this.likeCount = 0,
    this.userId,
    this.user,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    var listReplies = <Comment>[];
    // API C# AddComment không trả về replies, nên cần check null kỹ
    if (json['replies'] != null && json['replies'] is List) {
      listReplies = (json['replies'] as List)
          .map((e) => Comment.fromJson(e))
          .toList();
    }

    return Comment(
      id: json['id'] ?? json['ID'] ?? 0,
      parentId: json['parentId'] ?? json['ParentId'] ?? json['ParentID'],
      noiDung: json['noiDung'] ?? json['NoiDung'] ?? "",
      thoiGian: json['thoiGian'] ?? json['ThoiGian'] ?? "",
      isLiked: json['isLiked'] ?? json['IsLiked'] ?? false,
      likeCount: json['likeCount'] ?? json['LikeCount'] ?? 0,
      // Sửa logic lấy UserId: Ưu tiên lấy ở ngoài, nếu không có thì lấy trong object User
      userId:
          (json['userId'] ??
                  json['UserId'] ??
                  json['user']?['id'] ??
                  json['User']?['Id'])
              ?.toString(),
      user: (json['user'] != null || json['User'] != null)
          ? CommentUser.fromJson(json['user'] ?? json['User'])
          : null,
      replies: listReplies,
    );
  }
}

class MovieDetailResponse {
  final MovieInfo? movie;
  final List<Episode> episodes;
  final List<Comment> comments;
  final List<MovieItem> relatedMovies; // Tái sử dụng MovieItem từ home_model

  MovieDetailResponse({
    this.movie,
    required this.episodes,
    required this.comments,
    required this.relatedMovies,
  });

  factory MovieDetailResponse.fromJson(Map<String, dynamic> json) {
    // Xử lý logic key viết hoa/thường ở đây 1 lần duy nhất
    final movieData = json['phim'] ?? json['Phim'];
    final tapPhimsData = json['tapPhims'] ?? json['TapPhims'];
    final commentsData = json['comments'] ?? json['Comments'];
    final relatedData = json['related'] ?? json['Related'];

    List<MovieItem> relatedList = [];
    if (relatedData != null) {
      if (relatedData['phimBo'] != null) {
        relatedList.addAll(
          (relatedData['phimBo'] as List).map((e) => MovieItem.fromJson(e)),
        );
      }
      if (relatedData['phimLe'] != null) {
        relatedList.addAll(
          (relatedData['phimLe'] as List).map((e) => MovieItem.fromJson(e)),
        );
      }
    }

    return MovieDetailResponse(
      movie: movieData != null ? MovieInfo.fromJson(movieData) : null,
      episodes:
          (tapPhimsData as List?)?.map((e) => Episode.fromJson(e)).toList() ??
          [],
      comments:
          (commentsData as List?)?.map((e) => Comment.fromJson(e)).toList() ??
          [],
      relatedMovies: relatedList,
    );
  }
}
