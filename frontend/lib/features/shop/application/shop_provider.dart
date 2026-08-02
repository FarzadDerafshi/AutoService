import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/shop_profile_model.dart';
import '../data/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.watch(apiClientProvider));
});

class ShopProfileController extends AsyncNotifier<ShopProfile> {
  @override
  Future<ShopProfile> build() {
    return ref.read(shopRepositoryProvider).getProfile();
  }

  Future<void> updateProfile(Map<String, dynamic> input) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(shopRepositoryProvider).updateProfile(input));
  }

  Future<void> uploadLogo(Uint8List bytes, String filename) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(shopRepositoryProvider).uploadLogo(bytes, filename));
  }

  Future<void> deleteLogo() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(shopRepositoryProvider).deleteLogo());
  }
}

final shopProfileProvider = AsyncNotifierProvider<ShopProfileController, ShopProfile>(
  ShopProfileController.new,
);
