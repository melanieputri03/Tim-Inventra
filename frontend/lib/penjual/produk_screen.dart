import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sidebar_penjual.dart';
import 'beranda_screen.dart';
import 'tambah_produk_screen.dart';
import 'edit_produk_screen.dart';
import 'laporan_penjualan.dart';
import '../api/api_base_url.dart';
import 'notifikasi_penjual.dart';

class ProdukScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProdukScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final int _selectedIndex = 1;
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Semua';
  String _selectedStatus = 'Semua';
  final List<String> _categories = [
    'Semua',
    'Abaya',
    'Gamis',
    'Baju Kurung',
    'Khimar',
    'Bergo',
  ];
  final List<String> _statusOptions = ['Semua', 'Stok Rendah'];

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String? _token;
  int _belumDibaca = 0;

  String _safeString(dynamic value) => ApiBaseUrl.safeString(value);

  int _safeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  List _safeList(dynamic value) => ApiBaseUrl.safeList(value);

  // ⭐ HELPER WARNA UNTUK BADGE
  Color _getWarnaColor(String warna) {
    switch (warna.toLowerCase()) {
      case 'merah': return Colors.red;
      case 'biru': return Colors.blue;
      case 'hijau': return Colors.green;
      case 'kuning': return Colors.yellow;
      case 'putih': return Colors.white;
      case 'hitam': return Colors.black;
      case 'pink': return Colors.pink;
      case 'ungu': return Colors.purple;
      case 'cokelat': return Colors.brown;
      case 'abu':
      case 'abu-abu': return Colors.grey;
      case 'navy': return Colors.blue.shade900;
      case 'krem': return const Color(0xFFF5F5DC);
      case 'gold': return const Color(0xFFFFD700);
      default: return Colors.grey.shade400;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchProducts();
  }

  Future<void> _loadTokenAndFetchProducts() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await _fetchProducts();
    await _fetchJumlahNotifikasi();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(ApiBaseUrl.produk),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(data['data']);
            _filteredProducts = _products;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat data produk'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchJumlahNotifikasi() async {
    try {
      final response = await http.get(
        Uri.parse(ApiBaseUrl.notifikasi),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List listNotif = data['data'] ?? [];
          final unread = listNotif
              .where(
                (n) =>
                    n['sudah_dibaca'] == false ||
                    n['sudah_dibaca'] == 0 ||
                    n['sudah_dibaca'] == '0',
              )
              .length;

          setState(() {
            _belumDibaca = unread;
          });
        }
      }
    } catch (_) {}
  }

  // ==================== NAVIGASI ====================
  void _navigateToBeranda() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BerandaScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  void _navigateToLaporan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LaporanPenjualan(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  void _navigateToTambahProduk() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TambahProdukScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
      ),
    ).then((_) => _fetchProducts());
  }

  void _onMenuItemSelected(int index) {
    Navigator.pop(context);
    switch (index) {
      case 0:
        _navigateToBeranda();
        break;
      case 1:
        break;
      case 2:
        _navigateToLaporan();
        break;
      default:
        break;
    }
  }

  void _onBottomNavTapped(int index) {
    switch (index) {
      case 0:
        _navigateToBeranda();
        break;
      case 1:
        break;
      case 2:
        _navigateToLaporan();
        break;
      default:
        break;
    }
  }

  // ==================== FILTER ====================
  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _products.where((product) {
        final namaProduk = _safeString(product['nama_produk']).toLowerCase();
        final kategori = _safeString(product['kategori']).toLowerCase();

        final matchesSearch =
            query.isEmpty ||
            namaProduk.contains(query.toLowerCase()) ||
            kategori.contains(query.toLowerCase());

        final matchesCategory =
            _selectedCategory == 'Semua' ||
            kategori == _selectedCategory.toLowerCase();

        bool matchesStatus = true;
        if (_selectedStatus == 'Stok Rendah') {
          final totalStock = _getTotalStock(product);
          final minStock = _safeInt(product['min_stok'], defaultValue: 10);
          matchesStatus = totalStock <= minStock && totalStock > 0;
        }

        return matchesSearch && matchesCategory && matchesStatus;
      }).toList();
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts(_searchController.text);
    });
    Navigator.pop(context);
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Kategori',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF803033),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => _filterByCategory(category),
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: const Color(
                      0xFF803033,
                    ).withValues(alpha: 0.2),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: isSelected
                          ? const Color(0xFF803033)
                          : Colors.grey.shade700,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showStatusFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Status',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF803033),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: _statusOptions.map((status) {
                  final isSelected = _selectedStatus == status;
                  return FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatus = status;
                        _filterProducts(_searchController.text);
                      });
                      Navigator.pop(context);
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: const Color(
                      0xFF803033,
                    ).withValues(alpha: 0.2),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: isSelected
                          ? const Color(0xFF803033)
                          : Colors.grey.shade700,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ==================== HELPER ====================
  String formatPrice(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';
  }

  int _getTotalStock(Map<String, dynamic> product) {
    final ukuranStok = _safeList(product['ukuran_stok']);
    if (ukuranStok.isNotEmpty) {
      int total = 0;
      for (var item in ukuranStok) {
        total += _safeInt(item['stock']);
      }
      return total;
    }
    return _safeInt(product['stok']);
  }

  bool _isLowStock(Map<String, dynamic> product) {
    int totalStock = _getTotalStock(product);
    int minStock = _safeInt(product['min_stok'], defaultValue: 10);
    return totalStock <= minStock;
  }

  // ==================== EDIT & DELETE ====================
  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProdukScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
          produk: product,
        ),
      ),
    ).then((_) => _fetchProducts());
  }

  void _deleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5ECEA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF803033),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hapus Produk?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF803033),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin menghapus produk ${_safeString(product['nama_produk'])}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF803033),
                          side: const BorderSide(
                            color: Color(0xFFD8A5A8),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          try {
                            final response = await http.delete(
                              Uri.parse(
                                ApiBaseUrl.produkById(product['produk_id']),
                              ),
                              headers: {
                                'Authorization': 'Bearer $_token',
                                'Accept': 'application/json',
                              },
                            );
                            final resBody = response.body.isNotEmpty
                                ? json.decode(response.body)
                                : {};

                            setState(() => _isLoading = false);

                            if (response.statusCode == 200) {
                              await _fetchProducts();
                              _showResultDialog(
                                success: true,
                                message:
                                    '${_safeString(product['nama_produk'])} telah dihapus',
                              );
                            } else {
                              final pesanError =
                                  _safeString(resBody['message']).isNotEmpty
                                  ? _safeString(resBody['message'])
                                  : 'Gagal menghapus produk';
                              _showResultDialog(
                                success: false,
                                message: pesanError,
                              );
                            }
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showResultDialog(
                              success: false,
                              message: 'Error: ${e.toString()}',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF803033),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        child: Text(
                          'Ya, Hapus',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDialog({required bool success, required String message}) {
    final Color mainColor = success
        ? const Color(0xFF2E7D32)
        : const Color(0xFF803033);
    final Color bgIconColor = success
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFF5ECEA);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgIconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  color: mainColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                success ? 'Berhasil!' : 'Gagal',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WIDGETS ====================
  Widget _buildProductImage(Map<String, dynamic> product) {
    final String gambar = _safeString(product['gambar']);
    final String imageUrl = ApiBaseUrl.getImageUrl(gambar);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
      ),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 120,
                  width: double.infinity,
                  color: const Color(0xFFF5ECEA),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF803033),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: double.infinity,
                  color: const Color(0xFFF5ECEA),
                  child: Icon(
                    Icons.broken_image,
                    color: const Color(0xFF803033).withValues(alpha: 0.4),
                    size: 50,
                  ),
                );
              },
            )
          : Container(
              height: 120,
              width: double.infinity,
              color: const Color(0xFFF5ECEA),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: const Color(0xFF803033).withValues(alpha: 0.4),
                size: 50,
              ),
            ),
    );
  }

  // ⭐⭐⭐ BUILD PRODUCT CARD DENGAN VARIAN LENGKAP ⭐⭐⭐
  Widget _buildProductCard(Map<String, dynamic> product) {
    final bool isLowStock = _isLowStock(product);
    final int totalStock = _getTotalStock(product);
    final String namaProduk = _safeString(product['nama_produk']);
    final int harga = _safeInt(product['harga']);

    // ⭐ Ambil data varian dari ukuran_stok
    final List<dynamic> ukuranStok = _safeList(product['ukuran_stok']);

    // ⭐ Ambil daftar warna unik untuk badge
    List<String> warnaList = [];
    for (var item in ukuranStok) {
      String warna = item['warna'] ?? '';
      if (warna.isNotEmpty && !warnaList.contains(warna)) {
        warnaList.add(warna);
      }
    }

    // ⭐ Tampilkan maksimal 3 varian, sisanya "+N varian"
    List<Map<String, dynamic>> displayVarian = [];
    String? moreVarianText;
    if (ukuranStok.length > 3) {
      displayVarian = ukuranStok.take(3).map((e) => Map<String, dynamic>.from(e)).toList();
      moreVarianText = '+${ukuranStok.length - 3} varian';
    } else {
      displayVarian = ukuranStok.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8A5A8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProductImage(product),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nama Produk
                Text(
                  namaProduk,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Harga
                Text(
                  formatPrice(harga),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF803033),
                  ),
                ),
                const SizedBox(height: 3),

                // ⭐ BADGE WARNA (lingkaran kecil)
                if (warnaList.isNotEmpty) ...[
                  Row(
                    children: warnaList.map((warna) {
                      return Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: _getWarnaColor(warna),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                ],

                // ⭐ DAFTAR VARIAN (UKURAN + WARNA + STOK)
                if (displayVarian.isNotEmpty) ...[
                  ...displayVarian.map((item) {
                    String size = item['size'] ?? '';
                    String warna = item['warna'] ?? '';
                    int stock = _safeInt(item['stock']);
                    Color warnaColor = _getWarnaColor(warna);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          // Lingkaran warna kecil
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: warnaColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Ukuran + Stok
                          Text(
                            '$size : $stock',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                // ⭐ "+N varian" jika ada lebih dari 3
                if (moreVarianText != null) ...[
                  Text(
                    moreVarianText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF803033),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 4),

                // Stok + Status
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 10,
                      color: isLowStock ? Colors.orange : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Stok: $totalStock',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: isLowStock
                            ? Colors.orange
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Stok rendah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7,
                            color: const Color(0xFFFFB74D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // Tombol Edit & Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _editProduct(product),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5ECEA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF803033),
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteProduct(product),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5ECEA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final opacity = isSelected ? 1.0 : 0.5;

    return GestureDetector(
      onTap: () => _onBottomNavTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: isSelected
              ? Border.all(color: Colors.grey.shade200, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF803033).withValues(alpha: opacity),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF803033).withValues(alpha: opacity),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(icon: Icons.home_outlined, label: 'Beranda', index: 0),
          _buildNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Produk',
            index: 1,
          ),
          _buildNavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Laporan',
            index: 2,
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5ECEA),
      drawer: SidebarWidget(
        userName: widget.userName,
        userEmail: widget.userEmail,
        selectedIndex: _selectedIndex,
        onItemSelected: _onMenuItemSelected,
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5ECEA)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.28,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: const [
                    Color(0xFF803033),
                    Color(0xFFD8A5A8),
                    Color(0xFFF5ECEA),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      Badge(
                        label: Text(
                          '$_belumDibaca',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        backgroundColor: const Color(0xFF803033),
                        isLabelVisible: _belumDibaca > 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotifikasiPenjual(
                                  userName: widget.userName,
                                  userEmail: widget.userEmail,
                                ),
                              ),
                            ).then((_) {
                              _fetchJumlahNotifikasi();
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none,
                              color: Color(0xFF803033),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Produk',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_filteredProducts.length} produk dalam katalog',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF803033),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _filterProducts,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Cari produk...',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey.shade500,
                                    size: 22,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showFilterDialog,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF803033),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.filter_list,
                                color: const Color(0xFF803033),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showStatusFilterDialog,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF803033),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: _selectedStatus == 'Stok Rendah'
                                    ? const Color(0xFFFFB74D)
                                    : const Color(0xFF803033),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF803033),
                          ),
                        )
                      : _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada produk',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchProducts,
                          color: const Color(0xFF803033),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 2;
                              if (constraints.maxWidth > 800) {
                                crossAxisCount = 3;
                              }
                              if (constraints.maxWidth > 1100) {
                                crossAxisCount = 4;
                              }
                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.64, 
                                    ),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = _filteredProducts[index];
                                  return _buildProductCard(product);
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToTambahProduk,
        backgroundColor: const Color(0xFF803033),
        elevation: 0,
        mini: true,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}