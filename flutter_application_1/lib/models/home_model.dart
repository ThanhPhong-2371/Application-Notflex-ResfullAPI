class MovieItem {
  final int id;
  final String tenPhim;
  final String? img;
  final int? luotXem;
  final int? soBinhLuan;
  final bool? isSeries;

  MovieItem({
    required this.id,
    required this.tenPhim,
    this.img,
    this.luotXem,
    this.soBinhLuan,
    this.isSeries,
  });

  factory MovieItem.fromJson(Map<String, dynamic> json) {
    return MovieItem(
      id:
          json['id'] ??
          0, // Chú ý: C# trả về ID viết hoa hay thường tùy thuộc vào config JSON, thường là camelCase (id)
      tenPhim: json['tenPhim'] ?? "",
      img: json['img'],
      luotXem: json['luotXem'],
      soBinhLuan: json['soBinhLuan'],
      isSeries: json['isSeries'] ?? json['IsSeries'], // Hỗ trợ cả 2 kiểu viết hoa/thường từ Backend
    );
  }
}

class BannerItem {
  final int id;
  final String? fileName;
  final String? mediaType;
  final String tenPhim;

  BannerItem({
    required this.id,
    this.fileName,
    this.mediaType,
    required this.tenPhim,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'] ?? 0,
      fileName: json['fileName'],
      mediaType: json['mediaType'],
      tenPhim: json['tenPhim'] ?? "",
    );
  }
}

class HomeDataResponse {
  final List<BannerItem> banners;
  final List<MovieItem> recommendations;
  final List<MovieItem> phimBo;
  final List<MovieItem> phimLe;

  HomeDataResponse({
    required this.banners,
    required this.recommendations,
    required this.phimBo,
    required this.phimLe,
  });

  factory HomeDataResponse.fromJson(Map<String, dynamic> json) {
    return HomeDataResponse(
      banners:
          (json['banners'] as List?)
              ?.map((e) => BannerItem.fromJson(e))
              .toList() ??
          [],
      recommendations:
          (json['recommendations'] as List?)
              ?.map((e) => MovieItem.fromJson(e))
              .toList() ??
          [],
      phimBo:
          (json['phimBo'] as List?)
              ?.map((e) => MovieItem.fromJson(e))
              .toList() ??
          [],
      phimLe:
          (json['phimLe'] as List?)
              ?.map((e) => MovieItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

// Class mới để hứng dữ liệu phân trang từ API Xem Tất Cả
class PagedMovieResponse {
  final List<MovieItem> data;
  final int pageNumber;
  final int pageCount;
  final int totalItemCount;

  PagedMovieResponse({
    required this.data,
    required this.pageNumber,
    required this.pageCount,
    required this.totalItemCount,
  });

  factory PagedMovieResponse.fromJson(Map<String, dynamic> json) {
    return PagedMovieResponse(
      data:
          (json['data'] as List?)?.map((e) => MovieItem.fromJson(e)).toList() ??
          [],
      pageNumber: json['pagination']?['pageNumber'] ?? 1,
      pageCount: json['pagination']?['pageCount'] ?? 1,
      totalItemCount: json['pagination']?['totalItemCount'] ?? 0,
    );
  }
}
