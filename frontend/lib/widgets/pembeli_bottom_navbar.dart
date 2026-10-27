import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pembeli/produk_pembeli.dart';
import '../pembeli/wishlist_screen.dart';
import '../pembeli/rekomendasi_produk.dart';

class PembeliBottomNavbar extends StatelessWidget {
  final int selectedIndex;

  const PembeliBottomNavbar({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.shopping_bag_outlined,
            label: 'Produk',
            index: 0,
            isSelected: selectedIndex == 0,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.favorite_outline,
            label: 'Favorit',
            index: 1,
            isSelected: selectedIndex == 1,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.stars_outlined,
            label: 'Rekomendasi',
            index: 2,
            isSelected: selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    const kPrimaryColor = Color(0xFF803033);

    void pindahHalaman(Widget halaman) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => halaman,
          transitionDuration: Duration.zero, // Tanpa animasi agar instan
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Memastikan area klik luas
      onTap: () {
        if (isSelected) return;

        switch (index) {
          case 0:
            pindahHalaman(const ProdukPembeli());
            break;
          case 1:
            pindahHalaman(const WishlistScreen());
            break;
          case 2:
            pindahHalaman(const RekomendasiProduk());
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
