import 'dart:io';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// STORAGE SERVICE — Supabase Storage
///
/// Handles image uploads for properties and user profiles.
/// Requires buckets: 'properties' (public) and 'avatars' (public)
/// ═══════════════════════════════════════════════════════════════
class StorageService {
  static final _storage = SupabaseService.client.storage;
  static const String _propertiesBucket = 'properties';
  static const String _avatarsBucket = 'avatars';

  /// Upload a property image to the 'properties' bucket.
  /// Returns the public URL on success, throws on failure.
  Future<String> uploadPropertyImage(File file, String propertyId, int index) async {
    final path = '$propertyId/image_$index.jpg';
    try {
      await _storage.from(_propertiesBucket).upload(path, file);
      final url = _storage.from(_propertiesBucket).getPublicUrl(path);
      // Supabase sometimes returns a URL with trailing '?' — clean it up
      return url.split('?').first;
    } catch (e) {
      print('StorageService.uploadPropertyImage ERROR: $e (bucket=$_propertiesBucket, path=$path)');
      rethrow;
    }
  }

  /// Upload a profile image to the 'avatars' bucket.
  /// Returns the public URL on success, throws on failure.
  Future<String> uploadProfileImage(File file, String userId) async {
    final path = '$userId/profile.jpg';
    try {
      await _storage.from(_avatarsBucket).upload(path, file);
      final url = _storage.from(_avatarsBucket).getPublicUrl(path);
      return url.split('?').first;
    } catch (e) {
      print('StorageService.uploadProfileImage ERROR: $e (bucket=$_avatarsBucket, path=$path)');
      rethrow;
    }
  }

  /// Delete all images for a given property.
  Future<void> deletePropertyImages(String propertyId) async {
    try {
      final files = await _storage.from(_propertiesBucket).list(path: propertyId);
      for (final file in files) {
        await _storage.from(_propertiesBucket).remove(['$propertyId/${file.name}']);
      }
    } catch (e) {
      print('StorageService.deletePropertyImages ERROR: $e');
      // Non-fatal — property may have no images
    }
  }
}
