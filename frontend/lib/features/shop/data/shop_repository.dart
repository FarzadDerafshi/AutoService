import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'shop_profile_model.dart';

class ShopRepository {
  ShopRepository(this._client);
  final ApiClient _client;

  Future<ShopProfile> getProfile() async {
    final response = await _client.dio.get('/shop');
    return ShopProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ShopProfile> updateProfile(Map<String, dynamic> input) async {
    final response = await _client.dio.patch('/shop', data: input);
    return ShopProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ShopProfile> uploadLogo(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'logo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _client.dio.post('/shop/logo', data: formData);
    return ShopProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ShopProfile> deleteLogo() async {
    final response = await _client.dio.delete('/shop/logo');
    return ShopProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
