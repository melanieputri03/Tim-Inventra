import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/sidebar_penjual.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'produk_screen.dart';
import 'laporan_penjualan.dart';
import '../api/api_base_url.dart';
import 'notifikasi_penjual.dart';

class BerandaScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final bool isLoggedIn;
  const BerandaScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.isLoggedIn = false,
  });
  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final int _selectedIndex = 0;

  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _weeklySales = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  bool _isLoading = true;
  String? _token;
  String? _errorMessage;
  int _belumDibaca = 0;

  // ==================== PALET WARNA BUTIK ====================
  static const Color _cMarunTua = Color(0xFF803033);
  static const Color _cMerahBata = Color(0xFFA0524D);
  static const Color _cCoklatMuda = Color(0xFFC48C7A);
  static const Color _cKrem = Color(0xFFE8D5CC);
  static const Color _cPutihGading = Color(0xFFF5ECEA);

  static const List<Color> _donutPalette = [
    _cMarunTua,
    _cMerahBata,
    _cCoklatMuda,
    _cKrem,
    _cPutihGading,
  ];

  static const Map<int, String> _kategoriNames = {
    1: 'Abaya',
    2: 'Gamis',
    3: 'Baju Kurung',
    4: 'Khimar',
    5: 'Bergo',
  };

  static const List<String> _namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _namaBulan = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetch();
  }

  // ==================== FETCH DATA ====================
  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await Future.wait([_fetchDashboardData(), _fetchLowStockProducts()]);
    await _fetchJumlahNotifikasi();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final resPenjualan = await http.get(
        Uri.parse(
          '${ApiBaseUrl.laporanPenjualan}?periode=mingguan&tanggal=$dateStr',
        ),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final resProduk = await http.get(
        Uri.parse(
          '${ApiBaseUrl.laporanProdukTerlaris}?periode=mingguan&tanggal=$dateStr',
        ),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (resPenjualan.statusCode == 200 && resProduk.statusCode == 200) {
        final dataPenjualan = jsonDecode(resPenjualan.body);
        final dataProduk = jsonDecode(resProduk.body);

        if (dataPenjualan['success'] == true && dataProduk['success'] == true) {
          final pData = dataPenjualan['data'];
          final labels = List<String>.from(pData['labels']);
          final values = List<int>.from(pData['values']);
          final counts = List<int>.from(pData['transaction_counts']);

          setState(() {
            _weeklySales = List.generate(
              labels.length,
              (i) => {
                'day': labels[i],
                'value': values[i] / 1000000,
                'count': counts[i],
              },
            );

            final prodList = dataProduk['data'] as List;
            _topProducts = prodList.map((item) {
              final map = item as Map<String, dynamic>;
              return {
                'nama_produk': map['nama_produk'] ?? '',
                'total_terjual': map['total_terjual'] ?? 0,
                'total_penjualan': map['total_penjualan'] ?? 0,
                'gambar': map['gambar'] ?? '',
                'harga': map['harga'] ?? 0,
                'kategori_id': map['kategori_id'] ?? 0,
                'rank': prodList.indexOf(item) + 1,
              };
            }).toList();

            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        setState(() => _isLoading = false);
        _errorMessage = 'Gagal memuat data dashboard';
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
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

  Future<void> _fetchLowStockProducts() async {
    try {
      final response = await http.get(
        Uri.parse(ApiBaseUrl.produk),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final allProducts = data['data'] as List;
          final lowStock =
              allProducts.where((p) {
                  final stok = p['stok'] ?? 0;
                  final minStok = p['min_stok'] ?? 10;
                  return stok <= minStok && stok > 0;
                }).toList()
                ..sort((a, b) => (a['stok'] ?? 0).compareTo(b['stok'] ?? 0));

          setState(() {
            _lowStockProducts = lowStock
                .map(
                  (item) => {
                    'produk_id': item['produk_id'],
                    'nama_produk': item['nama_produk'] ?? '',
                    'stok': item['stok'] ?? 0,
                    'min_stok': item['min_stok'] ?? 10,
                    'gambar': item['gambar'] ?? '',
                    'harga': item['harga'] ?? 0,
                  },
                )
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching low stock: $e');
    }
  }

  // ==================== HELPERS ====================
  String _rupiah(int v) => v >= 1000000
      ? 'Rp ${(v / 1000000) % 1 == 0 ? (v / 1000000).toInt() : (v / 1000000).toStringAsFixed(1)}jt'
      : 'Rp ${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String formatPrice(int price) => _rupiah(price);

  String _formatTanggalHariIni() {
    final now = DateTime.now();
    final hari = _namaHari[now.weekday - 1];
    final bulan = _namaBulan[now.month];
    return '$hari, ${now.day} $bulan ${now.year}';
  }

  int _totalPenjualanMingguan() => _weeklySales.fold<int>(0, (sum, item) {
    final value = (item['value'] ?? 0) as num;
    return sum + (value * 1000000).toInt();
  });

  int _getTotalTransaksiMingguan() {
    return _weeklySales.fold<int>(0, (sum, item) {
      return sum + ((item['count'] ?? 0) as int);
    });
  }

  int _getTotalProdukTerjual() {
    return _topProducts.fold<int>(0, (sum, p) {
      return sum + ((p['total_terjual'] ?? 0) as int);
    });
  }

  List<Map<String, dynamic>> _getKategoriData() {
    if (_topProducts.isEmpty) return [];

    final Map<int, int> totalsByKategori = {};

    for (final p in _topProducts) {
      final kategoriId = (p['kategori_id'] ?? 0) as int;
      final terjual = (p['total_terjual'] ?? 0) as int;

      if (kategoriId > 0 && _kategoriNames.containsKey(kategoriId)) {
        totalsByKategori[kategoriId] =
            (totalsByKategori[kategoriId] ?? 0) + terjual;
      }
    }

    if (totalsByKategori.isEmpty) {
      final kategoriIds = [1, 2, 3, 4, 5];
      for (int i = 0; i < _topProducts.length && i < kategoriIds.length; i++) {
        final p = _topProducts[i];
        final terjual = (p['total_terjual'] ?? 0) as int;
        if (terjual > 0) {
          final kategoriId = kategoriIds[i % kategoriIds.length];
          totalsByKategori[kategoriId] =
              (totalsByKategori[kategoriId] ?? 0) + terjual;
        }
      }
    }

    if (totalsByKategori.isEmpty) return [];

    final totalTerjual = totalsByKategori.values.fold(0, (sum, v) => sum + v);

    final entries = totalsByKategori.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.asMap().entries.map((mapEntry) {
      final index = mapEntry.key;
      final kategoriId = mapEntry.value.key;
      final count = mapEntry.value.value;
      final percent = totalTerjual > 0 ? (count / totalTerjual * 100) : 0;

      return {
        'kategori_id': kategoriId,
        'nama_kategori': _kategoriNames[kategoriId] ?? 'Kategori $kategoriId',
        'total_terjual': count,
        'persentase': percent,
        'color': _donutPalette[index % _donutPalette.length],
      };
    }).toList();
  }

  int _getTotalTerjualKategori() {
    int total = 0;
    for (final p in _topProducts) {
      total += (p['total_terjual'] ?? 0) as int;
    }
    return total;
  }

  // ==================== NAVIGASI ====================
  void _navigateToProduk() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ProdukScreen(userName: widget.userName, userEmail: widget.userEmail),
    ),
  );

  void _navigateToLaporan() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LaporanPenjualan(
        userName: widget.userName,
        userEmail: widget.userEmail,
      ),
    ),
  );

  void _navigateToProdukWithLowStock() => _navigateToProduk();

  void _onMenuItemSelected(int index) {
    Navigator.pop(context);
    if (index == 1) _navigateToProduk();
    if (index == 2) _navigateToLaporan();
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) return;
    if (index == 1) _navigateToProduk();
    if (index == 2) _navigateToLaporan();
  }

  // ==================== WIDGETS ====================
  Widget _buildProductImage(Map<String, dynamic> product, {double size = 55}) {
    final image = product['gambar'];
    if (image != null && image.toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          ApiBaseUrl.getImageUrl(image),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.checkroom, color: Colors.grey.shade400, size: 30),
        ),
      );
    }
    return Icon(Icons.checkroom, color: Colors.grey.shade400, size: 30);
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final rank = (product['rank'] ?? 0) as int;
    final rankColor = rank == 1
        ? _cMarunTua
        : rank == 2
        ? _cMerahBata
        : rank == 3
        ? _cCoklatMuda
        : _cKrem;

    return GestureDetector(
      onTap: _navigateToProduk,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cPutihGading, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: _cPutihGading,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildProductImage(product),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['nama_produk'] ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(product['harga'] ?? 0),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _cMarunTua,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 12,
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${product['total_terjual'] ?? 0} terjual minggu ini',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: rank <= 3 ? 1 : 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '#$rank',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : _cMarunTua,
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildBottomNavBar() => Container(
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

  // ==================== SUMMARY CARDS ====================
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required double cardWidth,
    String? subtitle,
    bool isAlert = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cPutihGading, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _cPutihGading,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _cMarunTua, size: 16),
                ),
                if (subtitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isAlert
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: isAlert
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final int lowStockCount = _lowStockProducts.length;
    final int totalProdukTerjual = _getTotalProdukTerjual();
    final int totalTransaksi = _getTotalTransaksiMingguan();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth >= 900;

    double cardWidth;
    if (isWeb) {
      final availableWidth = screenWidth - 64 - 36;
      cardWidth = availableWidth / 4;
      cardWidth = cardWidth.clamp(150.0, 350.0);
    } else {
      cardWidth = (screenWidth * 0.30).clamp(120.0, 160.0);
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: isWeb
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        children: [
          _buildSummaryCard(
            title: 'Stok Menipis',
            value: '$lowStockCount',
            icon: Icons.warning_amber_rounded,
            onTap: _navigateToProdukWithLowStock,
            subtitle: lowStockCount > 0 ? 'Restock!' : 'Aman',
            isAlert: lowStockCount > 0,
            cardWidth: cardWidth,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            title: 'Produk Terjual',
            value: '$totalProdukTerjual',
            icon: Icons.shopping_bag_outlined,
            onTap: _navigateToProduk,
            subtitle: 'Minggu ini',
            cardWidth: cardWidth,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            title: 'Total Transaksi',
            value: '$totalTransaksi',
            icon: Icons.receipt_long_outlined,
            onTap: _navigateToLaporan,
            subtitle: 'Minggu ini',
            cardWidth: cardWidth,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            title: 'Pendapatan',
            value: _rupiah(_totalPenjualanMingguan()),
            icon: Icons.payments_outlined,
            onTap: _navigateToLaporan,
            subtitle: 'Minggu ini',
            cardWidth: cardWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildChart() => SizedBox(
    height: 100,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  final idx = value.toInt();
                  if (idx >= 0 && idx < _weeklySales.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _weeklySales[idx]['day'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(4),
              tooltipMargin: 4,
              getTooltipColor: (_) => _cMarunTua,
              getTooltipItems: (spots) => spots.map((spot) {
                final idx = spot.x.toInt();
                final count = idx >= 0 && idx < _weeklySales.length
                    ? _weeklySales[idx]['count'] ?? 0
                    : 0;
                return LineTooltipItem(
                  '$count transaksi',
                  const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
            handleBuiltInTouches: true,
          ),
          minX: -0.3,
          maxX: (_weeklySales.length - 1) + 0.3,
          lineBarsData: [
            LineChartBarData(
              spots: _weeklySales
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value['value']))
                  .toList(),
              isCurved: true,
              gradient: const LinearGradient(colors: [_cMerahBata, _cMarunTua]),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: _cMarunTua,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _cMarunTua.withValues(alpha: 0.16),
                    _cMarunTua.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ==================== DONUT CHART ====================
  Widget _buildDonutChart() {
    final kategoriData = _getKategoriData();
    final totalTerjual = _getTotalTerjualKategori();

    if (kategoriData.isEmpty || totalTerjual == 0) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        child: Text(
          'Belum ada produk terjual minggu ini',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth >= 900;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: isWeb ? 1 : 2,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: kategoriData.map((item) {
                        final count = item['total_terjual'] as int;
                        final percent = totalTerjual > 0
                            ? count / totalTerjual
                            : 0.0;
                        return PieChartSectionData(
                          color: item['color'] as Color,
                          value: percent,
                          title: '',
                          radius: isWeb ? 50 : 40,
                          showTitle: false,
                          borderSide: (item['color'] as Color) == _cPutihGading
                              ? BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                )
                              : BorderSide.none,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: isWeb ? 32 : 25,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // handle touch
                        },
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalTerjual',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isWeb ? 20 : 16,
                          fontWeight: FontWeight.bold,
                          color: _cMarunTua,
                        ),
                      ),
                      Text(
                        'Total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isWeb ? 10 : 8,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: isWeb ? 16 : 10),
          Expanded(
            flex: isWeb ? 2 : 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: kategoriData.map((item) {
                final count = item['total_terjual'] as int;
                final percent = (item['persentase'] as num);
                final dotColor = item['color'] as Color;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: isWeb ? 3 : 1),
                  child: Row(
                    children: [
                      Container(
                        width: isWeb ? 14 : 11,
                        height: isWeb ? 14 : 11,
                        decoration: BoxDecoration(
                          color: dotColor,
                          borderRadius: BorderRadius.circular(3),
                          border: dotColor == _cPutihGading
                              ? Border.all(color: Colors.grey.shade300)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['nama_kategori'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isWeb ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count (${percent.toStringAsFixed(1)}%)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isWeb ? 13 : 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final isTablet = screenWidth >= 600;
    final isWeb = screenWidth >= 900;
    final horizontalPadding = screenWidth < 340
        ? 12.0
        : (isWeb ? 32.0 : (isTablet ? 24.0 : 16.0));

    final clampedTextScaler = mq.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedTextScaler),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _cPutihGading,
        drawer: SidebarWidget(
          userName: widget.userName,
          userEmail: widget.userEmail,
          selectedIndex: _selectedIndex,
          onItemSelected: _onMenuItemSelected,
        ),
        body: Stack(
          children: [
            Container(color: _cPutihGading),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.26,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      _cMarunTua,
                      _cMerahBata,
                      _cCoklatMuda,
                      _cPutihGading,
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF803033),
                      ),
                    )
                  : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                                icon: const Icon(
                                  Icons.menu_rounded,
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
                                backgroundColor: _cMarunTua,
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
                                      color: _cPutihGading,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.notifications_none_rounded,
                                      color: _cMarunTua,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // BRAND / NAMA BUTIK
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'DASHBOARD BUTIK',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // GREETING + TANGGAL
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${widget.userName} 👋',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isTablet ? 28 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTanggalHariIni(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // SUMMARY CARDS
                          _buildSummarySection(),
                          const SizedBox(height: 16),

                          // CARD PENJUALAN MINGGU INI
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _cPutihGading,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.show_chart_rounded,
                                          size: 14,
                                          color: _cMarunTua,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Pendapatan Mingguan',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '7 Hari',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _rupiah(_totalPenjualanMingguan()),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_weeklySales.isNotEmpty) _buildChart(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // CARD KATEGORI TERLARIS
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isWeb ? 16 : 12,
                              vertical: isWeb ? 2 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _cPutihGading,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.donut_large_rounded,
                                          size: isWeb ? 14 : 12,
                                          color: _cMarunTua,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Kategori Terlaris',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: isWeb ? 12 : 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${_getTotalTerjualKategori()} produk terjual',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: isWeb ? 11 : 10,
                                        fontWeight: FontWeight.w500,
                                        color: _cMarunTua,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildDonutChart(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // PRODUK TERLARIS
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _cPutihGading,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '🏆',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Produk Terlaris',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: _navigateToProduk,
                                      child: Row(
                                        children: [
                                          Text(
                                            'Lihat Semua',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _cMarunTua,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 9,
                                            color: _cMarunTua,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_topProducts.isNotEmpty)
                                  ..._topProducts
                                      .take(3)
                                      .map((p) => _buildProductItem(p))
                                else
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        'Belum ada data produk terlaris',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }
}