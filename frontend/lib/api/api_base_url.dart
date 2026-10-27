import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io' show Platform;

class ApiConfig {
  static String get baseUrl {
    // Web
    if (kIsWeb) {
      return "http://localhost:8000";
    }
    // Android emulator
    // if (Platform.isAndroid) {
    //   return "http://10.0.2.2:8000";
    // }

    // Android physical device
    return "http://192.168.1.114:8000";
  }
}

class ApiBaseUrl {
  static String get baseUrl => '${ApiConfig.baseUrl}/api';

  // Auth
  static String get login => '$baseUrl/login';
  static String get logout => '$baseUrl/logout';

  // Produk
  static String get me => '$baseUrl/me';
  static String get produk => '$baseUrl/produk';
  static String produkById(int id) => '$baseUrl/produk/$id';

  // Produk publik untuk pembeli (tanpa auth)
  static String get produkPublik => '$baseUrl/produk-publik';
  static String produkPublikById(int id) => '$baseUrl/produk-publik/$id';

  // Rekomendasi
  static String get rekomendasi => '$baseUrl/rekomendasi';

  // Kategori
  static String get kategori => '$baseUrl/kategori';
  static String kategoriById(int id) => '$baseUrl/kategori/$id';

  // Notifikasi
  static String get notifikasi => '$baseUrl/notifikasi';
  static String notifikasiById(String id) => '$baseUrl/notifikasi/$id/baca';
  static String get notifikasiBacaSemua => '$baseUrl/notifikasi/baca-semua';
  static String get notifikasiHapusSemua => '$baseUrl/notifikasi/hapus-semua';
  static String get fcmToken => '$baseUrl/fcm-token';

  // Laporan
  static String get laporanPenjualan => '$baseUrl/laporan/penjualan';
  static String get laporanProdukTerlaris => '$baseUrl/laporan/produk-terlaris';
  static String get laporanPenjualanTahunan =>
      '$baseUrl/laporan/penjualan/tahunan';
  static String get laporanProdukTerlarisTahunan =>
      '$baseUrl/laporan/produk-terlaris/tahunan';

  // Transaksi
  static String get transaksi => '$baseUrl/transaksi';
  static String transaksiById(int id) => '$baseUrl/transaksi/$id';
  static String get riwayatTransaksi => '$baseUrl/riwayat-transaksi';

  // Periode
  static String get periode => '$baseUrl/periode';
  static String periodeById(int id) => '$baseUrl/periode/$id';

  // Rekomendasi Stok
  static String get rekomendasiStok => '$baseUrl/rekomendasi-stok';
  static String get restock => '$baseUrl/rekomendasi-stok/restock';
  static String get konfirmasiTiba =>
      '$baseUrl/rekomendasi-stok/konfirmasi-tiba';

  // Fast Moving SKU dan Dead Stock
  static String get laporanFastMovingSku => '$baseUrl/laporan/fast-moving-sku';
  static String get laporanDeadStock => '$baseUrl/laporan/dead-stock';

  static String get bundlingRekomendasi => '$baseUrl/bundling-rekomendasi';
  static String get profitAnalytics => '$baseUrl/profit-analytics';
  static String get tokoProfil => '$baseUrl/toko-profil';

  // Gambar produk
  static String getImageUrl(dynamic path) {
    if (path == null) return '';
    if (path is String && path.isNotEmpty) {
      String fileName = path.split('/').last;
      return '${ApiConfig.baseUrl}/gambar/$fileName';
    }
    return '';
  }

  // Gambar size chart
  static String getSizeChartUrl(dynamic path) {
    if (path == null) return '';
    if (path is String && path.isNotEmpty) {
      String fileName = path.split('/').last;
      return '${ApiConfig.baseUrl}/size-chart/$fileName';
    }
    return '';
  }

  static String safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  static int safeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static List safeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (e) {
        return [];
      }
    }
    return [];
  }
}
