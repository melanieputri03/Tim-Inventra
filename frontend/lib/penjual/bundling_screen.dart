import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_base_url.dart';

class BundlingScreen extends StatefulWidget {
  const BundlingScreen({super.key});

  @override
  State<BundlingScreen> createState() => _BundlingScreenState();
}

class _BundlingScreenState extends State<BundlingScreen> {
  List<dynamic> _rules = [];
  bool _isLoading = true;
  int _totalTransaksi = 0;

  // Parameter default
  double _minSupport = 0.1; // 10%
  double _minConfidence = 0.5; // 50%

  @override
  void initState() {
    super.initState();
    _fetchRekomendasi();
  }

  Future<void> _fetchRekomendasi() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiBaseUrl.bundlingRekomendasi}?min_support=$_minSupport&min_confidence=$_minConfidence',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _rules = data['data'] ?? [];
          _totalTransaksi = data['total_transaksi'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal memuat data bundling');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showPengaturanDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                Text(
                  'Pengaturan Parameter Apriori',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF803033),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sesuaikan sensitivitas rekomendasi bundling.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Slider Support
                Text(
                  'Min Support: ${(_minSupport * 100).toInt()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _minSupport,
                  min: 0.05,
                  max: 0.5,
                  divisions: 45,
                  activeColor: const Color(0xFF803033),
                  label: '${(_minSupport * 100).toInt()}%',
                  onChanged: (val) => setModalState(() => _minSupport = val),
                ),

                // Slider Confidence
                Text(
                  'Min Confidence: ${(_minConfidence * 100).toInt()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _minConfidence,
                  min: 0.1,
                  max: 0.9,
                  divisions: 80,
                  activeColor: const Color(0xFF803033),
                  label: '${(_minConfidence * 100).toInt()}%',
                  onChanged: (val) => setModalState(() => _minConfidence = val),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetchRekomendasi(); // Hitung ulang
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF803033),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Terapkan & Hitung',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECEA),
      appBar: AppBar(
        title: Text(
          'Rekomendasi Bundling',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF803033),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showPengaturanDialog,
            tooltip: 'Pengaturan Apriori',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF803033).withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Color(0xFF803033)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Analisis didasarkan pada $_totalTransaksi transaksi.\nApriori berjalan dengan Min Support: ${(_minSupport * 100).toInt()}% & Min Confidence: ${(_minConfidence * 100).toInt()}%.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF803033),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Rekomendasi
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF803033)),
                  )
                : _rules.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchRekomendasi,
                    color: const Color(0xFF803033),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rules.length,
                      itemBuilder: (context, index) {
                        return _buildRuleCard(_rules[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(dynamic rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rule (Jika Beli -> Maka Beli)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'JIKA BELI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rule['jika_beli'],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'MAKA BELI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rule['maka_beli'],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Metrik
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Support', '${rule['support']}%', Colors.orange),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _buildMetric(
                  'Confidence',
                  '${rule['confidence']}%',
                  const Color(0xFF803033),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Rekomendasi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak ada pola pembelian yang memenuhi parameter saat ini. Coba turunkan Min Support atau Min Confidence melalui ikon pengaturan di kanan atas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showPengaturanDialog,
              icon: const Icon(Icons.tune),
              label: const Text('Ubah Parameter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF803033),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
