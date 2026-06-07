import 'dart:io';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// STORAGE SERVICE — Supabase Storage
///
/// Handles image uploads for properties and user profiles.
/// ═══════════════════════════════════════════════════════════════
class StorageService {
  static final _storage = SupabaseService.client.storage;
  static const String _propertiesBucket = 'properties';
  static const String _avatarsBucket = 'avatars';

  Future<String?> uploadPropertyImage(File file, String propertyId, int index) async {
    try {
      final path = '$propertyId/image_$index.jpg';
      await _storage.from(_propertiesBucket).upload(path, file);
      return _storage.from(_propertiesBucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadProfileImage(File file, String userId) async {
    try {
      final path = '$userId/profile.jpg';
      await _storage.from(_avatarsBucket).upload(path, file);
      return _storage.from(_avatarsBucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<void> deletePropertyImages(String propertyId) async {
    try {
      final files = await _storage.from(_propertiesBucket).list(path: propertyId);
      for (final file in files) {
        await _storage.from(_propertiesBucket).remove(['$propertyId/${file.name}']);
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
