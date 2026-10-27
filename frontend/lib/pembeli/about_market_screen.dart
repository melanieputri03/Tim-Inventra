import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../api/api_base_url.dart';

class AboutMarketScreen extends StatefulWidget {
  const AboutMarketScreen({super.key});

  @override
  State<AboutMarketScreen> createState() => _AboutMarketScreenState();
}

class _AboutMarketScreenState extends State<AboutMarketScreen> {
  Map<String, dynamic>? _toko;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfil();
  }

  Future<void> _fetchProfil() async {
    try {
      final response = await http.get(Uri.parse(ApiBaseUrl.tokoProfil));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _toko = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _chatWhatsApp() async {
    if (_toko == null) return;
    final url =
        'https://wa.me/${_toko!['no_telepon']}?text=Halo%20${_toko!['nama_toko']},%20saya%20ingin%20bertanya.';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECEA),
      appBar: AppBar(
        title: Text(
          'Tentang Toko',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF803033),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF803033)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(0xFF803033),
                    child: Icon(
                      Icons.storefront,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _toko?['nama_toko'] ?? 'Butik Syar\'i Ani',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF803033),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pemilik: ${_toko?['nama_pemilik'] ?? '-'}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Card Kontak & Alamat
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Toko',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.location_on,
                            color: Color(0xFF803033),
                          ),
                          title: Text(
                            'Alamat Toko',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Tanjung Piayu, Batam',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone, color: Colors.green),
                          title: Text(
                            'WhatsApp',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            _toko?['no_telepon'] ?? '-',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _chatWhatsApp,
                            icon: const Icon(Icons.chat),
                            label: Text(
                              'Hubungi via WhatsApp',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
