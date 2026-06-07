import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadPropertyImage(File file, String propertyId, int index) async {
    try {
      final ref = _storage.ref().child('properties/$propertyId/image_$index.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadProfileImage(File file, String userId) async {
    try {
      final ref = _storage.ref().child('users/$userId/profile.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> deletePropertyImages(String propertyId) async {
    try {
      final listResult = await _storage.ref().child('properties/$propertyId').listAll();
      for (var item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
