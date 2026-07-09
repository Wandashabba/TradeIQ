import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// A tiny valid 1x1 transparent PNG encoded as a data URL, used as a stand-in
/// image until real camera capture is wired up.
// TODO: replace with real camera capture (image_picker) — see follow-up ticket
const kPlaceholderPhotoDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

class PhotoUploadResult {
  const PhotoUploadResult({
    required this.id,
    required this.url,
  });
  final String id;
  final String url;

  factory PhotoUploadResult.fromJson(Map<String, dynamic> json) =>
      PhotoUploadResult(
        id: json['id'] as String,
        url: json['url'] as String,
      );
}

abstract class PhotosRepository {
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  });
}

class DioPhotosRepository implements PhotosRepository {
  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async {
    final response = await dio.post('/photos', data: {
      'visitId': visitId,
      'section': section,
      'dataUrl': dataUrl,
      'gpsTag': gpsTag,
      'timestamp': timestamp,
    });
    return PhotoUploadResult.fromJson(response.data as Map<String, dynamic>);
  }
}

final photosRepositoryProvider =
    Provider<PhotosRepository>((ref) => DioPhotosRepository());
