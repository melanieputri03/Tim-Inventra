import 'package:shared_preferences/shared_preferences.dart';

class WishlistService {
  static const String _key = 'wishlist_produk_pembeli';

  // 1. Ambil semua ID produk yang di-wishlist
  static Future<List<int>> getWishlistIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> stringList = prefs.getStringList(_key) ?? [];
    return stringList.map((e) => int.parse(e)).toList();
  }

  // 2. Cek apakah produk sudah ada di wishlist
  static Future<bool> isWishlisted(int produkId) async {
    final ids = await getWishlistIds();
    return ids.contains(produkId);
  }

  // 3. Tambah / Hapus (Toggle) dari Wishlist
  static Future<bool> toggleWishlist(int produkId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stringList = prefs.getStringList(_key) ?? [];
    List<int> ids = stringList.map((e) => int.parse(e)).toList();

    bool isAdded;
    if (ids.contains(produkId)) {
      ids.remove(produkId);
      isAdded = false;
    } else {
      ids.add(produkId);
      isAdded = true;
    }

    await prefs.setStringList(_key, ids.map((e) => e.toString()).toList());
    return isAdded;
  }
}
