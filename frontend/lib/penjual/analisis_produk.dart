import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../api/api_base_url.dart';
import '../widgets/sidebar_penjual.dart';
import 'notifikasi_penjual.dart';

const _kPrimary = Color(0xFF803033);
const _kBg = Color(0xFFF5ECEA);
const _kGold = Color(0xFFFF8C00);

class AnalisisProduk extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  const AnalisisProduk({super.key, this.userName, this.userEmail});

  @override
  State<AnalisisProduk> createState() => _AnalisisProdukState();
}

class _AnalisisProdukState extends State<AnalisisProduk>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late TabController _tabController;
  int _selectedPeriod = 1;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;
  String? _token;
  List<Map<String, dynamic>> _fastMovingData = [];
  List<Map<String, dynamic>> _deadStockData = [];
  String? _error;

  final List<String> _periodLabels = ['Harian', 'Mingguan', 'Bulanan'];
  final List<String> _periodValues = ['harian', 'mingguan', 'bulanan'];
  int _belumDibaca = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTokenAndFetch();
  }

  Future<void> _loadTokenAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await _fetchData();
    await _fetchJumlahNotifikasi();
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
              .where((n) =>
                  n['sudah_dibaca'] == false ||
                  n['sudah_dibaca'] == 0 ||
                  n['sudah_dibaca'] == '0')
              .length;
          setState(() => _belumDibaca = unread);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    _error = null;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final period = _periodValues[_selectedPeriod];

      final resFast = await http.get(
        Uri.parse(
            '${ApiBaseUrl.laporanFastMovingSku}?periode=$period&tanggal=$dateStr&limit=15'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      final resDead = await http.get(
        Uri.parse(
            '${ApiBaseUrl.laporanDeadStock}?periode=$period&tanggal=$dateStr&limit=20'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      bool hasError = false;

      if (resFast.statusCode == 200) {
        final data = jsonDecode(resFast.body);
        if (data['success'] == true) {
          setState(() => _fastMovingData = List<Map<String, dynamic>>.from(data['data']));
        } else {
          hasError = true;
        }
      } else {
        hasError = true;
      }

      if (resDead.statusCode == 200) {
        final data = jsonDecode(resDead.body);
        if (data['success'] == true) {
          setState(() => _deadStockData = List<Map<String, dynamic>>.from(data['data']));
        } else {
          hasError = true;
        }
      } else {
        hasError = true;
      }

      setState(() => _isLoading = false);
      if (hasError) _error = 'Gagal memuat data';
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: ${e.toString()}';
      });
    }
  }

  String _rupiah(int v) => v >= 1000000
      ? 'Rp ${(v / 1000000) % 1 == 0 ? (v / 1000000).toInt() : (v / 1000000).toStringAsFixed(1)}jt'
      : 'Rp ${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _getStatusLabel(String status) {
    switch (status) {
      case 'kritis':
        return '⚠️ Kritis (≤3 hari)';
      case 'perlu_diperhatikan':
        return '🟡 Perlu Diperhatikan (≤7 hari)';
      case 'fast_moving':
        return '⚡ Fast Moving';
      default:
        return '✅ Aman';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'kritis':
        return Colors.red;
      case 'perlu_diperhatikan':
        return Colors.orange;
      case 'fast_moving':
        return _kPrimary;
      default:
        return Colors.green;
    }
  }

  void _changeDate(int dir) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(
        days: _selectedPeriod == 0
            ? dir
            : (_selectedPeriod == 1 ? dir * 7 : dir * 30),
      ));
      _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: SidebarWidget(
        userName: widget.userName ?? 'Admin',
        userEmail: widget.userEmail ?? '',
        selectedIndex: 8,
        onItemSelected: (index) => Navigator.pop(context),
      ),
      body: Stack(
        children: [
          Container(color: _kBg),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.28,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xFF803033), Color(0xFFD8A5A8), Color(0xFFF5ECEA)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      Badge(
                        label: Text(
                          '$_belumDibaca',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        backgroundColor: _kPrimary,
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
                            ).then((_) => _fetchJumlahNotifikasi());
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
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
                        'Analisis Produk',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fast Moving SKU & Dead Stock Detection',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    indicator: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '⚡ Fast Moving'),
                      Tab(text: '💀 Dead Stock'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 37,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _selectedPeriod,
                              icon: const Icon(Icons.arrow_drop_down, color: _kPrimary),
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              items: _periodLabels.asMap().entries.map((entry) {
                                return DropdownMenuItem<int>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPeriod = value!;
                                  _fetchData();
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildNavButton(Icons.chevron_left, () => _changeDate(-1)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2023),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  primaryColor: _kPrimary,
                                  colorScheme: const ColorScheme.light(
                                    primary: _kPrimary,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() => _selectedDate = picked);
                            _fetchData();
                          }
                        },
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildNavButton(Icons.chevron_right, () => _changeDate(1)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _kPrimary),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _kPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Coba Lagi',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildFastMovingList(),
                                _buildDeadStockList(),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _kPrimary, size: 18),
      ),
    );
  }

  Widget _buildFastMovingList() {
    if (_fastMovingData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.speed, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Tidak ada produk fast moving',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: _kPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _fastMovingData.length,
        itemBuilder: (context, index) {
          final item = _fastMovingData[index];
          final status = item['status'] ?? 'aman';
          final totalTerjual = item['total_terjual'] ?? 0;

          return GestureDetector(
            onTap: () => _showFastMovingDetail(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: status == 'kritis' ? Colors.red : Colors.grey.shade200,
                  width: status == 'kritis' ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildProductThumb(item['gambar']),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['nama_produk'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _rupiah(item['harga'] ?? 0),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _kPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoChip('📦 Stok', '${item['stok_saat_ini']} pcs'),
                      _buildInfoChip('📈 Rata/hari', '${item['rata_per_hari']}'),
                      _buildInfoChip('📊 Terjual', '$totalTerjual pcs'),
                    ],
                  ),
                  if ((item['rekomendasi_restock'] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, color: _kPrimary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Rekomendasi restock: +${item['rekomendasi_restock']} pcs',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeadStockList() {
    if (_deadStockData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Tidak ada dead stock',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: _kPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _deadStockData.length,
        itemBuilder: (context, index) {
          final item = _deadStockData[index];
          final hari = item['hari_tanpa_penjualan'] ?? 999;

          return GestureDetector(
            onTap: () => _showDeadStockDetail(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hari > 60 ? Colors.red : Colors.orange,
                  width: hari > 60 ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildProductThumb(item['gambar']),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['nama_produk'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kategori: ${item['kategori'] ?? '-'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hari > 60 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hari > 60 ? '🔴 $hari hari' : '🟡 $hari hari',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: hari > 60 ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildInfoChip('📦 Stok', '${item['stok_saat_ini']} pcs'),
                      _buildInfoChip('💰 Nilai', _rupiah(item['total_biaya'] ?? 0)),
                      _buildInfoChip('📅 Terakhir', item['terakhir_terjual'] ?? '-'),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: hari > 60 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hari > 60 ? Icons.warning : Icons.info_outline,
                            color: hari > 60 ? Colors.red : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['rekomendasi'] ?? 'Perhatikan tren penjualan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: hari > 60 ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFastMovingDetail(Map<String, dynamic> item) {
    final totalStok = item['stok_saat_ini'] ?? 0;
    final rataPerHari = item['rata_per_hari'] ?? 0;
    final totalTerjual = item['total_terjual'] ?? 0;
    final rekomendasiRestock = item['rekomendasi_restock'] ?? 0;
    final status = item['status'] ?? 'aman';
    final estimasiHabis = item['estimasi_habis'] ?? 999;
    final periodeLabel = item['periode_label'] ?? 'Periode';

    String statusDescription = '';
    String statusIcon = '';
    Color statusColor = Colors.green;
    switch (status) {
      case 'kritis':
        statusDescription = 'Stok diprediksi habis dalam ≤3 hari. Segera lakukan restock!';
        statusColor = Colors.red;
        break;
      case 'perlu_diperhatikan':
        statusDescription = 'Stok diprediksi habis dalam ≤7 hari. Persiapkan restock.';
        statusColor = Colors.orange;
        break;
      case 'fast_moving':
        statusDescription = 'Produk ini memiliki rata-rata penjualan ≥5 pcs/hari. Sangat laris!';
        statusColor = _kPrimary;
        break;
      default:
        statusDescription = 'Stok aman, tidak perlu tindakan segera.';
        statusColor = Colors.green;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  _buildProductThumb(item['gambar']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['nama_produk'] ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _kPrimary,
                          ),
                        ),
                        Text(
                          _rupiah(item['harga'] ?? 0),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: _kPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$statusIcon Status: ${_getStatusLabel(status)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                '📊 Ringkasan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Periode', periodeLabel),
              _buildDetailRow('Total Stok', '$totalStok pcs'),
              _buildDetailRow('Total Terjual', '$totalTerjual pcs'),
              _buildDetailRow('Rata-rata/hari', '$rataPerHari pcs'),
              _buildDetailRow('Estimasi Habis', '$estimasiHabis hari'),
              _buildDetailRow('Rekomendasi Restock', '+$rekomendasiRestock pcs'),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                '🧮 Cara Perhitungan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildCalculationRow(
                'Rata-rata/hari',
                'Total Terjual ($totalTerjual) ÷ Jumlah Hari',
                '= $rataPerHari pcs/hari',
              ),
              _buildCalculationRow(
                'Estimasi Habis',
                'Total Stok ($totalStok) ÷ Rata-rata/hari ($rataPerHari)',
                '= $estimasiHabis hari',
              ),
              _buildCalculationRow(
                'Rekomendasi Restock',
                '(Rata-rata/hari × 7) - Stok',
                '= +$rekomendasiRestock pcs',
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                '📌 Status: ${_getStatusLabel(status)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusDescription,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeadStockDetail(Map<String, dynamic> item) {
    final totalStok = item['stok_saat_ini'] ?? 0;
    final harga = item['harga'] ?? 0;
    final totalBiaya = totalStok * harga;
    final hariTanpaPenjualan = item['hari_tanpa_penjualan'] ?? 999;
    final rekomendasi = item['rekomendasi'] ?? 'Perhatikan tren penjualan';
    final terakhirTerjual = item['terakhir_terjual'] ?? 'Tidak pernah';

    String statusIcon = '🟢';
    String statusText = 'Masih Wajar';
    Color statusColor = Colors.green;
    String statusDescription = 'Produk masih terjual dalam periode wajar.';

    if (hariTanpaPenjualan > 60) {
      statusIcon = '🔴';
      statusText = 'Kritis (≥60 hari)';
      statusColor = Colors.red;
      statusDescription = 'Produk sudah >60 hari tidak terjual! Segera lakukan tindakan.';
    } else if (hariTanpaPenjualan > 30) {
      statusIcon = '🟡';
      statusText = 'Perlu Perhatian (≥30 hari)';
      statusColor = Colors.orange;
      statusDescription = 'Produk sudah 30-60 hari tidak terjual. Pertimbangkan promosi.';
    } else if (hariTanpaPenjualan > 14) {
      statusIcon = '🟠';
      statusText = 'Mulai Perhatikan (≥14 hari)';
      statusColor = const Color(0xFFFF8C00);
      statusDescription = 'Produk mulai tidak terjual. Evaluasi tren penjualan.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  _buildProductThumb(item['gambar']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['nama_produk'] ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _kPrimary,
                          ),
                        ),
                        Text(
                          'Kategori: ${item['kategori'] ?? '-'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$statusIcon $statusText',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                '📊 Ringkasan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Total Stok', '$totalStok pcs'),
              _buildDetailRow('Harga per Pcs', _rupiah(harga)),
              _buildDetailRow('Nilai Stok (jika terjual)', _rupiah(totalBiaya)),
              _buildDetailRow('Terakhir Terjual', terakhirTerjual),
              _buildDetailRow('Hari Tanpa Penjualan', '$hariTanpaPenjualan hari'),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                '🧮 Cara Perhitungan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildCalculationRow(
                'Hari Tanpa Penjualan',
                'Hari Ini - Terakhir Kali Produk Terjual',
                '= $hariTanpaPenjualan hari',
              ),
              _buildCalculationRow(
                'Nilai Stok',
                'Total Stok ($totalStok) × Harga ($harga)',
                '= ${_rupiah(totalBiaya)}',
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                '💡 Rekomendasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      hariTanpaPenjualan > 30 ? Icons.warning : Icons.info_outline,
                      color: statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rekomendasi,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String title, String formula, String result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formula,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            result,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildProductThumb(dynamic gambar) {
    final url = (gambar != null && gambar.toString().isNotEmpty)
        ? ApiBaseUrl.getImageUrl(gambar.toString())
        : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.isNotEmpty
          ? Image.network(
              url,
              width: 55,
              height: 55,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _thumbFallback(),
            )
          : _thumbFallback(),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 55,
      height: 55,
      color: _kPrimary.withOpacity(0.1),
      child: const Icon(Icons.checkroom, color: _kPrimary, size: 30),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
