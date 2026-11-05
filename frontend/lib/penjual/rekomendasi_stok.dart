// lib/penjual/rekomendasi_stok.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sidebar_penjual.dart';
import 'manajemen_periode_screen.dart';
import '../api/api_base_url.dart';

const _kPrimary6 = Color(0xFF803033);
const _kBg6 = Color(0xFFF5ECEA);
const _kGold = Color(0xFFFF8C00);

class RekomendasiStok extends StatefulWidget {
  final String? highlightProduk;
  final String? userName;
  final String? userEmail;
  const RekomendasiStok({super.key, this.highlightProduk, this.userName, this.userEmail});

  @override
  State<RekomendasiStok> createState() => _RekomendasiStokState();
}

class _RekomendasiStokState extends State<RekomendasiStok> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  Future<void> _simpanLeadTime(int hari) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lead_time_stok', hari);
  }

  Future<void> _loadLeadTime() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _leadTime = prefs.getInt('lead_time_stok') ?? 0;
    });
  }

  int _periodeIdx = 1;
  final List<String> _periodeLabel = ['Harian\n(7 hari)', 'Mingguan\n(21 hari)', 'Bulanan\n(30 hari)'];
  final List<int> _hariCoverOptions = [7, 21, 30];
  int _leadTime = 0;

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _token;
  String? _selectedPeriodeId;
  Map<String, dynamic>? _selectedPeriodeData;

  String _selectedCategory = 'Semua';
  String _selectedStatus = 'Semua';
  final List<String> _categories = ['Semua', 'Abaya', 'Gamis', 'Baju Kurung', 'Khimar', 'Bergo'];
  final List<String> _statusList = ['Semua', 'Perlu Restock', 'Sedang Dipesan'];
  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() { super.initState(); _init(); }

  // LOAD DATA 
  Future<void> _init() async {
    await _loadToken();
    await _loadSelectedPeriode();
    await _loadLeadTime();

    if (!mounted) return;
    await _fetchRekomendasi();
  }

  Future<void> _loadToken() async => _token = (await SharedPreferences.getInstance()).getString('token');

  Future<void> _loadSelectedPeriode() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedPeriodeId = prefs.getString('selected_periode_id');
    if (_selectedPeriodeId != null && _selectedPeriodeId!.isNotEmpty) {
      await _fetchPeriodeDetail(_selectedPeriodeId!);
    } else {
      setState(() => _selectedPeriodeData = null);
    }
  }

  Future<void> _fetchPeriodeDetail(String periodeId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiBaseUrl.periodeById(int.parse(periodeId))),
        headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) setState(() => _selectedPeriodeData = data['data']);
      }
    } catch (e) { debugPrint('Error fetch periode detail: $e'); }
  }

  // FETCH REKOMENDASI
  Future<void> _fetchRekomendasi() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final int hariCover = _hariCoverOptions[_periodeIdx];
      String url =
          '${ApiBaseUrl.rekomendasiStok}'
          '?hari_cover=$hariCover'
          '&lead_time=$_leadTime';
      if (_selectedPeriodeId != null && _selectedPeriodeId!.isNotEmpty) {
        url += '&periode_id=$_selectedPeriodeId';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final allItems = List<Map<String, dynamic>>.from(data['data']);
          final filteredItems = allItems.where((item) {
            final status = item['status'] as String;
            final saran = item['saranTambah'] as int;
            return saran > 0 || status == 'sudah_dipesan';
          }).toList();
          setState(() { _items = filteredItems; _filteredItems = filteredItems; _isLoading = false; });
        } else {
          setState(() { _items = []; _filteredItems = []; _isLoading = false; });
        }
      } else {
        setState(() { _items = []; _filteredItems = []; _isLoading = false; });
      }
    } catch (e) {
      debugPrint('Error fetch rekomendasi: $e');
      setState(() { _items = []; _filteredItems = []; _isLoading = false; });
    }
  }

  // FILTER METHODS
  void _filterRekomendasi(String query) => setState(() {
    if (query.isEmpty && _selectedCategory == 'Semua' && _selectedStatus == 'Semua') {
      _filteredItems = List.from(_items);
      return;
    }
    _filteredItems = _items.where((item) {
      final nama = item['nama']?.toString().toLowerCase() ?? '';
      final kategori = item['kategori']?.toString().toLowerCase() ?? '';
      final status = item['status'] as String? ?? '';
      String statusLabel = '';
      if (status == 'perlu_restock' || status == 'perlu_diperhatikan') statusLabel = 'Perlu Restock';
      else if (status == 'sudah_dipesan') statusLabel = 'Sedang Dipesan';
      final matchSearch = query.isEmpty || nama.contains(query.toLowerCase()) || kategori.contains(query.toLowerCase());
      final matchCategory = _selectedCategory == 'Semua' || kategori.contains(_selectedCategory.toLowerCase());
      final matchStatus = _selectedStatus == 'Semua' || statusLabel == _selectedStatus;
      return matchSearch && matchCategory && matchStatus;
    }).toList();
  });

  void _showFilterDialog() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Filter Kategori', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary6)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 12, children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return FilterChip(
            label: Text(category), selected: isSelected,
            onSelected: (_) { setState(() { _selectedCategory = category; _filterRekomendasi(_searchController.text); }); Navigator.pop(context); },
            backgroundColor: Colors.grey.shade100,
            selectedColor: _kPrimary6.withOpacity(0.2),
            labelStyle: GoogleFonts.plusJakartaSans(color: isSelected ? _kPrimary6 : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          );
        }).toList()),
      ]),
    ),
  );

  void _showStatusFilterDialog() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Filter Status', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary6)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 12, children: _statusList.map((status) {
          final isSelected = _selectedStatus == status;
          Color chipColor = Colors.grey.shade100;
          if (status == 'Perlu Restock') chipColor = Colors.red.shade50;
          if (status == 'Sedang Dipesan') chipColor = Colors.orange.shade50;
          return FilterChip(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              if (status == 'Perlu Restok') const Text('🔴 ', style: TextStyle(fontSize: 14)),
              if (status == 'Sedang Dipesan') const Text('🟡 ', style: TextStyle(fontSize: 14)),
              Text(status),
            ]),
            selected: isSelected,
            onSelected: (_) { setState(() { _selectedStatus = status; _filterRekomendasi(_searchController.text); }); Navigator.pop(context); },
            backgroundColor: chipColor,
            selectedColor: isSelected ? (status == 'Perlu Restock' ? Colors.red.shade200 : status == 'Sedang Dipesan' ? Colors.orange.shade200 : Colors.grey.shade200) : chipColor,
            labelStyle: GoogleFonts.plusJakartaSans(color: isSelected ? Colors.black87 : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          );
        }).toList()),
      ]),
    ),
  );

  // PERIODE NAV
  void _navigateToManajemenPeriode() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => ManajemenPeriodeScreen(
      userName: widget.userName ?? 'Admin Butikk', userEmail: widget.userEmail ?? '')));
    await _loadSelectedPeriode();
    _fetchRekomendasi();
    setState(() {});
  }

  void _clearPeriode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_periode_id');
    setState(() { _selectedPeriodeId = null; _selectedPeriodeData = null; });
    _fetchRekomendasi();
    _snack('Periode dinonaktifkan');
  }

  String _formatTanggal(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      const days = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${date.day} ${days[date.month - 1]} ${date.year}';
    } catch (e) { return isoDate.split('T')[0]; }
  }

  // RESTOCK SHEET
  void _showRestockSheet(Map<String, dynamic> item) {
    final int produkId = item['id'] as int;
    final int stokSekarang = item['stok'] as int;
    final int sisaHari = item['sisa_hari'] as int? ?? 0;
    final double multiplier = (item['multiplier'] as num?)?.toDouble() ?? 1.0;
    final String periodeNama = item['periode_nama'] ?? 'Tidak ada periode';
    final int hariCover = item['hari_cover'] as int? ?? 30;
    final int totalTerjual = item['total_terjual'] as int? ?? 0;
    final double rataHari = (item['rataHari'] as num?)?.toDouble() ?? 0;
    final int rekomendasiTotal = item['rekomendasi_total'] as int? ?? 0;
    final int saranTambahTotal = item['saranTambah'] as int? ?? 0;

    List<Map<String, dynamic>> rekomendasiPerUkuran = [];
    final rawRekomendasi = item['rekomendasi_per_ukuran'];
    if (rawRekomendasi != null && rawRekomendasi is List) {
      rekomendasiPerUkuran = List<Map<String, dynamic>>.from(rawRekomendasi);
    }

    final int totalKebutuhan = rekomendasiPerUkuran.fold<int>(
      0,
      (total, uk) =>
          total + ((uk['kebutuhan'] as num?)?.toInt() ?? 0),
    );

    Map<String, TextEditingController> ukuranControllers = {};
    Map<String, int> ukuranJumlah = {};
    for (var uk in rekomendasiPerUkuran) {
      final size = uk['size'].toString();
      final defaultJumlah = (uk['saran_tambah'] as int?) ?? 0;
      ukuranJumlah[size] = defaultJumlah;
      ukuranControllers[size] = TextEditingController(text: defaultJumlah.toString());
    }

    int _hitungTotal(Map<String, int> map) => map.values.fold(0, (a, b) => a + b);
    Set<String> _expandedSizes = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final totalJumlah = _hitungTotal(ukuranJumlah);
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
              builder: (context, scrollController) => Column(children: [
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                Padding(padding: const EdgeInsets.all(20), child: Row(children: [
                  _buildProdukThumb(item, size: 52), const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['nama'] as String, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Stok saat ini (total): $stokSekarang pcs', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                  GestureDetector(onTap: () => Navigator.pop(ctx),
                    child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _kBg6, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.close, size: 18))),
                ])),
                Expanded(child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _kBg6, borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Dasar Perhitungan Sistem', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _kPrimary6)),
                        const SizedBox(height: 10),
                        _buildInfoRow('Periode', periodeNama),
                        _buildInfoRow('Multiplier', '$multiplier ×'),
                        _buildInfoRow('Data', '$hariCover hari terakhir'),
                        _buildInfoRow('Sisa hari periode', '$sisaHari hari'),
                        const Divider(height: 16),
                        _buildInfoRow('Total terjual $hariCover hr', '$totalTerjual pcs'),
                        _buildInfoRow('Rata² per hari', '${rataHari.toStringAsFixed(2)} pcs/hari'),
                        _buildInfoRow(
                          'Lead time',
                          '${(item['lead_time'] as num?)?.toInt() ?? 0} hari',
                        ),

                        _buildInfoRow(
                          'Kebutuhan total',
                          '$totalKebutuhan pcs',
                        ),
                        _buildInfoRow('Rekomendasi total', '$rekomendasiTotal pcs'),
                        const Divider(height: 16),
                        _buildInfoRow('Saran tambah total (default)', '+$saranTambahTotal pcs', highlight: true),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Text('Jumlah Tambah per Ukuran', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('(klik baris untuk detail perhitungan)', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rekomendasiPerUkuran.length,
                      itemBuilder: (context, index) {
                        final uk = rekomendasiPerUkuran[index];
                        final size = uk['size'].toString();
                        final saranTambah = (uk['saran_tambah'] as int?) ?? 0;
                        final stokSaatIni = (uk['stok_saat_ini'] as int?) ?? 0;
                        final terjual = (uk['terjual'] as int?) ?? 0;
                        final kebutuhan = (uk['kebutuhan'] as int?) ?? 0;
                        final rekomendasiSize = (uk['rekomendasi'] as int?) ?? 0;
                        final rataHariSize = (uk['rata_hari'] as num?)?.toDouble() ?? 0;
                        final stokSedangDipesan =
                            (uk['stok_sedang_dipesan'] as num?)?.toInt() ?? 0;

                        final leadTime =
                            (item['lead_time'] as num?)?.toInt() ?? _leadTime;
                        final isExpanded = _expandedSizes.contains(size);
                        return Container(margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kPrimary6.withOpacity(0.15))),
                          child: Column(children: [
                            GestureDetector(onTap: () => setSheet(() { if (isExpanded) { _expandedSizes.remove(size); } else { _expandedSizes.add(size); } }),
                              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(children: [
                                  Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 20, color: _kPrimary6),
                                  const SizedBox(width: 8),
                                  Container(width: 50, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _kPrimary6.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(size, textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: _kPrimary6))),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('Saran: +$saranTambah pcs',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: saranTambah > 0 ? Colors.orange.shade700 : Colors.grey.shade500))),
                                  _buildQtyButton(icon: Icons.remove, onTap: () => setSheet(() {
                                    int current = ukuranJumlah[size] ?? 0;
                                    if (current > 0) { ukuranJumlah[size] = current - 1; ukuranControllers[size]!.text = (current - 1).toString(); }
                                  })),
                                  Container(width: 50, margin: const EdgeInsets.symmetric(horizontal: 8),
                                    child: TextField(
                                      controller: ukuranControllers[size],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        filled: true, fillColor: _kBg6,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                      onChanged: (val) {
                                        final parsed = int.tryParse(val);
                                        if (parsed != null && parsed >= 0) setSheet(() => ukuranJumlah[size] = parsed);
                                        else if (val.isEmpty) setSheet(() => ukuranJumlah[size] = 0);
                                      },
                                    ),
                                  ),
                                  _buildQtyButton(icon: Icons.add, onTap: () => setSheet(() {
                                    int current = ukuranJumlah[size] ?? 0;
                                    ukuranJumlah[size] = current + 1;
                                    ukuranControllers[size]!.text = (current + 1).toString();
                                  })),
                                ]),
                              ),
                            ),
                            if (isExpanded) Container(padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
                              decoration: BoxDecoration(color: _kBg6, borderRadius: BorderRadius.circular(10)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('DETAIL PERHITUNGAN UKURAN $size',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary6)),
                                const SizedBox(height: 8),
                                Text('Data terjual $hariCover hari: $terjual pcs',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
                                Text('Rata-rata per hari: $terjual ÷ $hariCover = ${rataHariSize.toStringAsFixed(2)} pcs',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
                                const SizedBox(height: 8),
                                Text('Hari cover: $hariCover hari',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
                                Text(
                                  'Kebutuhan = ${rataHariSize.toStringAsFixed(2)} '
                                  '× ($hariCover + $leadTime) = $kebutuhan pcs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Multiplier: $multiplier ×',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
                                Text('Rekomendasi = $kebutuhan × $multiplier = $rekomendasiSize pcs',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
                                const SizedBox(height: 8),
                                Text('Stok saat ini: $stokSaatIni pcs',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600)),
                                const Divider(height: 8),
                                Text(
                                  'Stok sedang dipesan: $stokSedangDipesan pcs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Saran tambah = max(0, $rekomendasiSize - '
                                  '$stokSaatIni - $stokSedangDipesan) '
                                  '= +$saranTambah pcs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary6,
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: _kPrimary6.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kPrimary6.withOpacity(0.2))),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Total semua ukuran:', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary6)),
                          Text('$totalJumlah pcs', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: _kPrimary6)),
                        ]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Stok setelah restock:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600)),
                          Text('$stokSekarang + $totalJumlah = ${stokSekarang + totalJumlah} pcs',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _kPrimary6)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          for (var uk in rekomendasiPerUkuran) {
                            final size = uk['size'].toString();
                            final defaultJumlah = (uk['saran_tambah'] as int?) ?? 0;
                            ukuranJumlah[size] = defaultJumlah;
                            ukuranControllers[size]!.text = defaultJumlah.toString();
                          }
                        }),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _kPrimary6.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Atur Ulang', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary6)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: () async {
                          if (totalJumlah == 0) { _snack('Jumlah tidak boleh 0'); return; }
                          Navigator.pop(ctx);
                          Map<String, int> finalPerUkuran = {};
                          for (var uk in rekomendasiPerUkuran) {
                            final size = uk['size'].toString();
                            final jumlah = ukuranJumlah[size] ?? 0;
                            if (jumlah > 0) finalPerUkuran[size] = jumlah;
                          }
                          try {
                            final response = await http.post(
                              Uri.parse(ApiBaseUrl.restock),
                              headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
                              body: json.encode({'produk_id': produkId, 'jumlah': totalJumlah, 'jumlah_per_ukuran': finalPerUkuran}),
                            );
                              if (!mounted) return;

                              if (response.statusCode == 200) {
                                final data = json.decode(response.body);

                                if (data['success'] == true) {
                                  _snack(
                                    'Restock ${item['nama']} ($totalJumlah pcs) berhasil dicatat',
                                  );
                                  await _fetchRekomendasi();
                                } else {
                                  _snack(data['message'] ?? 'Gagal mencatat restok');
                                }
                              } else {
                                _snack('Gagal mencatat restok (${response.statusCode})');
                              }
                          } catch (e) { _snack('Error: ${e.toString()}'); }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: Text('Pesan Restok', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      )),
                    ]),
                    const SizedBox(height: 24),
                  ]),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _kBg6, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: _kPrimary6, size: 18)),
  );

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11,
        color: highlight ? _kPrimary6 : Colors.grey.shade600, fontWeight: highlight ? FontWeight.w700 : FontWeight.normal)),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11,
        color: highlight ? _kPrimary6 : Colors.black87, fontWeight: highlight ? FontWeight.w800 : FontWeight.w500)),
    ]),
  );

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: color ?? Colors.grey.shade500)),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: color ?? Colors.black87)),
    ]),
  );

  // KONFIRMASI TIBA 
  void _showKonfirmasiTibaSheet(Map<String, dynamic> item) {
    final int produkId = item['id'] as int;
    final int jumlahDipesan = (item['jumlah_dipesan'] as num?)?.toInt() ?? 0;
    final int stokSekarang = item['stok'] as int;

    Map<String, int>? perUkuran;
    if (item['jumlah_per_ukuran'] != null) {
      final raw = item['jumlah_per_ukuran'];
      if (raw is List) {
        perUkuran = {};
        for (var entry in raw) { if (entry is Map) { final size = entry['size'].toString(); final jumlah = (entry['jumlah'] as num).toInt(); perUkuran[size] = jumlah; } }
      } else if (raw is Map) {
        perUkuran = Map<String, int>.from(raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _buildProdukThumb(item, size: 48), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['nama'] as String, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Stok saat ini: $stokSekarang pcs', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            _BadgeChip(label: item['badge'] as String),
          ]),
          const SizedBox(height: 16),
          Text('Konfirmasi Barang Tiba', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Pastikan barang sudah benar-benar tiba sebelum konfirmasi. Stok akan langsung bertambah.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500, height: 1.4)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _kBg6, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _buildInfoRow('Stok sebelumnya', '$stokSekarang pcs'),
              if (perUkuran != null && perUkuran.isNotEmpty) ...[
                const Divider(height: 14),
                Text('Rincian per ukuran:', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...perUkuran.entries.map((e) => _buildInfoRow('  Ukuran ${e.key}', '+${e.value} pcs')),
                const Divider(height: 14),
              ],
              _buildInfoRow('Total barang tiba', '+$jumlahDipesan pcs'),
              const Divider(height: 12),
              _buildInfoRow('Stok setelah konfirmasi', '${stokSekarang + jumlahDipesan} pcs', highlight: true),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final response = await http.post(
                    Uri.parse(ApiBaseUrl.konfirmasiTiba),
                    headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
                    body: json.encode({'produk_id': produkId, 'jumlah': jumlahDipesan}),
                  );
                  print('📡 Konfirmasi Tiba Response: ${response.statusCode}');
                  print('📡 Response body: ${response.body}');
                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                   if (data['success'] == true) {
                      if (!mounted) return;

                      _snack(
                        'Stok ${item['nama']} bertambah $jumlahDipesan pcs!',
                      );

                      await _fetchRekomendasi();
                    } else { _snack(data['message'] ?? 'Gagal mengupdate stok'); setState(() => _isLoading = false); }
                  } else { _snack('Gagal mengupdate stok (${response.statusCode})'); setState(() => _isLoading = false); }
                } catch (e) { print('Error konfirmasi tiba: $e'); _snack('Error: ${e.toString()}'); setState(() => _isLoading = false); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary6, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text('Konfirmasi Tiba', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.warning_amber_outlined, size: 13, color: _kGold),
            const SizedBox(width: 4),
            Expanded(child: Text('Tindakan ini akan langsung menambah stok di database dan tidak bisa dibatalkan.',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500, height: 1.4))),
          ]),
        ]),
      ),
    );
  }

  // UTILITY WIDGETS
  Widget _buildProdukThumb(Map<String, dynamic> item, {double size = 48}) {
    final g = item['gambar'];
    final url = (g != null && g.toString().isNotEmpty) ? ApiBaseUrl.getImageUrl(g.toString()) : '';
    return ClipRRect(borderRadius: BorderRadius.circular(10),
      child: url.isNotEmpty ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbFallback(size)) : _thumbFallback(size));
  }

  Widget _thumbFallback(double size) => Container(width: size, height: size, color: _kPrimary6.withOpacity(0.1),
    child: const Icon(Icons.checkroom, color: _kPrimary6, size: 22));

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kPrimary6, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  Widget _buildCalcRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11,
        color: highlight ? _kPrimary6 : Colors.grey.shade600, fontWeight: highlight ? FontWeight.w700 : FontWeight.normal)),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11,
        color: highlight ? _kPrimary6 : Colors.black87, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _buildStatusBtn(Map<String, dynamic> item, String status) {
    switch (status) {
      case 'sudah_dipesan':
        return GestureDetector(onTap: () => _showKonfirmasiTibaSheet(item),
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFFFF3DC), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGold.withOpacity(0.4))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🟡', style: TextStyle(fontSize: 14)), const SizedBox(width: 6),
              Column(children: [
                Text('Sudah Dipesan (barang belum tiba)',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFCC7000), fontWeight: FontWeight.w700, fontSize: 12)),
                Text('Tap untuk konfirmasi tiba →',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFCC7000), fontSize: 10)),
              ]),
            ]),
          ),
        );
      case 'telah_tiba':
        return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFEAF6EA), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF629D3E).withOpacity(0.4))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('✅', style: TextStyle(fontSize: 14)), const SizedBox(width: 6),
            Text('Telah Tiba', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF629D3E), fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        );
      default:
        return SizedBox(width: double.infinity,
          child: ElevatedButton(onPressed: () => _showRestockSheet(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary6, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🔴', style: TextStyle(fontSize: 14)), const SizedBox(width: 6),
              Text('Restok Sekarang', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    }
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    final int hariCover = _hariCoverOptions[_periodeIdx];
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg6,
      drawer: SidebarWidget(
        userName: widget.userName ?? 'Admin Butikk',
        userEmail: widget.userEmail ?? '',
        selectedIndex: 5,
        onItemSelected: (index) => Navigator.pop(context),
      ),
      body: Stack(children: [
        Container(color: _kBg6),
        Positioned(
          top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.28,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft, end: Alignment.topRight,
                colors: [Color(0xFF803033), Color(0xFFD8A5A8), Color(0xFFF5ECEA)],
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
          ),
        ),
        SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                IconButton(onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu, color: Colors.white, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const Spacer(),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rekomendasi Stok', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Rekomendasi pengadaan stok', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kPrimary6))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      child: Column(children: [
                        GestureDetector(
                          onTap: _navigateToManajemenPeriode,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _selectedPeriodeData != null ? _kPrimary6 : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
                            ),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectedPeriodeData != null ? Colors.white.withOpacity(0.2) : _kPrimary6.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.calendar_month, color: _selectedPeriodeData != null ? Colors.white : _kPrimary6, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Periode Aktif',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10,
                                    color: _selectedPeriodeData != null ? Colors.white70 : Colors.grey.shade500)),
                                Text(_selectedPeriodeData != null ? (_selectedPeriodeData!['nama_periode'] ?? 'Periode Khusus') : 'Tidak Aktif',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14,
                                    color: _selectedPeriodeData != null ? Colors.white : Colors.black87)),
                                if (_selectedPeriodeData != null)
                                  Text(
                                    '${_formatTanggal(_selectedPeriodeData!['tanggal_mulai'])} → ${_formatTanggal(_selectedPeriodeData!['tanggal_selesai'])} | Rekomendasi disesuaikan',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70),
                                  )
                                else
                                  Text('Klik untuk mengatur periode',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade400)),
                              ])),
                              Icon(Icons.chevron_right, color: _selectedPeriodeData != null ? Colors.white : Colors.grey),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: List.generate(_periodeLabel.length, (i) {
                              final sel = _periodeIdx == i;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () { setState(() => _periodeIdx = i); _fetchRekomendasi(); },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel ? _kPrimary6 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(_periodeLabel[i], textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600,
                                        color: sel ? Colors.white : Colors.grey.shade500, height: 1.4)),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // INPUT LEAD TIME
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                color: _kPrimary6,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Waktu Tunggu Pemasok',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Perkiraan hari sampai barang tiba',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  if (_leadTime > 0) {
                                    setState(() => _leadTime--);
                                    await _simpanLeadTime(_leadTime);
                                    await _fetchRekomendasi();
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                                color: _kPrimary6,
                              ),
                              Text(
                                '$_leadTime hari',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  if (_leadTime < 365) {
                                    setState(() => _leadTime++);
                                    await _simpanLeadTime(_leadTime);
                                    await _fetchRekomendasi();
                                  }
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                color: _kPrimary6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _filterRekomendasi,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Cari produk...',
                                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400),
                                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _showFilterDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedCategory != 'Semua' ? _kPrimary6.withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: _selectedCategory != 'Semua' ? Border.all(color: _kPrimary6, width: 1.5) : null,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Row(children: [
                                  Icon(Icons.filter_list, color: _selectedCategory != 'Semua' ? _kPrimary6 : Colors.grey.shade600, size: 18),
                                  const SizedBox(width: 4),
                                  Text(_selectedCategory != 'Semua' ? _selectedCategory : 'Filter',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: _selectedCategory != 'Semua' ? _kPrimary6 : Colors.grey.shade600)),
                                  if (_selectedCategory != 'Semua') ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(onTap: () => setState(() { _selectedCategory = 'Semua'; _filterRekomendasi(_searchController.text); }),
                                      child: Icon(Icons.close, size: 14, color: _kPrimary6)),
                                  ],
                                ]),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _showStatusFilterDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedStatus != 'Semua' ? _kPrimary6.withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: _selectedStatus != 'Semua' ? Border.all(color: _kPrimary6, width: 1.5) : null,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Row(children: [
                                  Icon(Icons.filter_alt_outlined, color: _selectedStatus != 'Semua' ? _kPrimary6 : Colors.grey.shade600, size: 18),
                                  const SizedBox(width: 4),
                                  Text(_selectedStatus != 'Semua' ? _selectedStatus : 'Status',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: _selectedStatus != 'Semua' ? _kPrimary6 : Colors.grey.shade600)),
                                  if (_selectedStatus != 'Semua') ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(onTap: () => setState(() { _selectedStatus = 'Semua'; _filterRekomendasi(_searchController.text); }),
                                      child: Icon(Icons.close, size: 14, color: _kPrimary6)),
                                  ],
                                ]),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        if (_filteredItems.isEmpty)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Column(children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('Tidak ada produk yang perlu direstok', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade500)),
                            ])),
                          )
                        else
                          ..._filteredItems.map((item) {
                            final status = item['status'] as String;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Expanded(
                                      child: Row(children: [
                                        _buildProdukThumb(item, size: 48), const SizedBox(width: 10),
                                        Expanded(child: Text(item['nama'] as String,
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                                          overflow: TextOverflow.ellipsis)),
                                      ]),
                                    ),
                                    _BadgeChip(label: item['badge'] as String),
                                  ]),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: _InfoChip(label: 'Stok', value: '${item['stok']}')),
                                    const SizedBox(width: 8),
                                    Expanded(child: _InfoChip(label: 'Rata²', value: '${item['rataHari']}/hari')),
                                    const SizedBox(width: 8),
                                    Expanded(child: _InfoChip(label: 'Saran', value: '+${item['saranTambah']} pcs')),
                                  ]),
                                  const SizedBox(height: 12),
                                  _buildStatusBtn(item, status),
                                ]),
                              ),
                            );
                          }),
                      ]),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// MINI WIDGETS 
class _BadgeChip extends StatelessWidget {
  final String label;
  const _BadgeChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kPrimary6.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.local_offer_outlined, size: 11, color: _kPrimary6),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kPrimary6, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500)),
      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
    ],
  );
}