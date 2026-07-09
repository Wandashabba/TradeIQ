import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';

void main() {
  test('PhotoUploadResult.fromJson parses id and url', () {
    final result = PhotoUploadResult.fromJson(const {
      'id': 'photo-1',
      'url': 'https://cdn.example.com/photo-1.png',
    });

    expect(result.id, 'photo-1');
    expect(result.url, 'https://cdn.example.com/photo-1.png');
  });

  test('kPlaceholderPhotoDataUrl is a non-empty PNG data URL', () {
    expect(kPlaceholderPhotoDataUrl, isNotEmpty);
    expect(kPlaceholderPhotoDataUrl, startsWith('data:image/png;base64,'));
  });
}
