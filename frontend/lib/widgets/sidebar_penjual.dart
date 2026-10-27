// lib/widgets/sidebar_penjual.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../penjual/produk_screen.dart';
import '../penjual/riwayat_transaksi_screen.dart';
import '../penjual/beranda_screen.dart';
import '../penjual/manajemen_periode_screen.dart';
import '../penjual/laporan_penjualan.dart';
import '../penjual/notifikasi_penjual.dart';
import '../penjual/rekomendasi_stok.dart';
import '../penjual/profil_penjual.dart';
import '../penjual/analisis_produk.dart';
import '../penjual/paket_langganan.dart';
import '../penjual/kategori_screen.dart';
import '../penjual/bundling_screen.dart';
import '../penjual/profit_analytics_screen.dart';

class SidebarWidget extends StatefulWidget {
  final String userName;
  final String userEmail;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SidebarWidget({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  String _nama = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nama = prefs.getString('nama') ?? widget.userName;
        _email = prefs.getString('email') ?? widget.userEmail;
      });
    }
  }

  String get userName => _nama.isNotEmpty ? _nama : widget.userName;
  String get userEmail => _email.isNotEmpty ? _email : widget.userEmail;

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToProduk(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProdukScreen(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToProfitAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfitAnalyticsScreen()),
    );
  }

  void _navigateToKategori(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const KategoriScreen()),
    );
  }

  void _navigateToTransaksi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RiwayatTransaksiScreen(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToBeranda(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BerandaScreen(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToPeriode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManajemenPeriodeScreen(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToLaporan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LaporanPenjualan()),
    );
  }

  void _navigateToBundling(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BundlingScreen()),
    );
  }

  void _navigateToNotifikasi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotifikasiPenjual()),
    );
  }

  void _navigateToAnalisisProduk(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AnalisisProduk(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToRekomendasiStok(BuildContext context) async {
    final needRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RekomendasiStok()),
    );

    if (needRefresh == true) {
      _refreshProdukScreen(context);
    }
  }

  void _refreshProdukScreen(BuildContext context) {
    Navigator.pop(context);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProdukScreen(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToPaketLangganan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaketLangganan(userName: userName, userEmail: userEmail),
      ),
    );
  }

  void _navigateToProfil(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfilPenjual(userName: userName, userEmail: userEmail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF5ECEA),
      child: SafeArea(
        child: Column(
          children: [
            // Header Profile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF803033),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 45,
                        color: Color(0xFF803033),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Admin Butik Syar\'i Ani',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.home_outlined,
                    title: 'Beranda',
                    index: 0,
                    onTap: () => _navigateToBeranda(context),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Produk',
                    index: 1,
                    onTap: () => _navigateToProduk(context),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    title: 'Transaksi',
                    index: 2,
                    onTap: () => _navigateToTransaksi(context),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.assessment_outlined,
                    title: 'Laporan',
                    index: 3,
                    onTap: () => _navigateToLaporan(context),
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Manajemen Periode',
                    index: 4,
                    onTap: () => _navigateToPeriode(context),
                  ),

                  const Divider(
                    height: 24,
                    indent: 16,
                    endIndent: 16,
                  ), // pemisah

                  _buildMenuItem(
                    context: context,
                    icon: Icons.trending_up_outlined,
                    title: 'Rekomendasi Stok',
                    index: 5,
                    onTap: () => _navigateToRekomendasiStok(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.analytics_outlined,
                    title: 'Analisis Produk',
                    index: 6,
                    onTap: () => _navigateToAnalisisProduk(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.shopping_cart_checkout_outlined,
                    title: 'Rekomendasi Bundling',
                    index: 11,
                    onTap: () => _navigateToBundling(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifikasi',
                    index: 7,
                    onTap: () => _navigateToNotifikasi(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.stars_outlined,
                    title: 'Paket Langganan',
                    index: 8,
                    onTap: () => _navigateToPaketLangganan(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.monetization_on_outlined,
                    title: 'Profit Analytics',
                    index: 12,
                    onTap: () => _navigateToProfitAnalytics(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'Profil',
                    index: 9,
                    onTap: () => _navigateToProfil(context),
                  ),

                  _buildMenuItem(
                    context: context,
                    icon: Icons.category_outlined,
                    title: 'Kategori Produk',
                    index: 10,
                    onTap: () => _navigateToKategori(context),
                  ),

                  const SizedBox(height: 20),

                  _buildLogoutButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = widget.selectedIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF803033).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF803033)
                  : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF803033)
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _logout(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.logout, color: Color(0xFF803033), size: 22),
              const SizedBox(width: 16),
              Text(
                'Keluar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF803033),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
