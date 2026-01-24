class CommentLikeModel {
  final bool success;
  final bool isLiked;
  final int likeCount;

  CommentLikeModel({
    required this.success,
    required this.isLiked,
    required this.likeCount,
  });

  factory CommentLikeModel.fromJson(Map<String, dynamic> json) {
    return CommentLikeModel(
      success: json['success'] ?? false,
      isLiked: json['isLiked'] ?? false,
      likeCount: json['likeCount'] ?? 0,
    );
  }
}
