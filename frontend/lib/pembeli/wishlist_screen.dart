import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../api/api_base_url.dart';
import '../services/wishlist_service.dart';
import '../widgets/pembeli_bottom_navbar.dart';
import '../widgets/pembeli_top_bar.dart'; // IMPORT TOP BAR

class _C {
  static const primary = Color(0xFF803033);
  static const bg = Color(0xFFFBF7F5);
  static const ink = Color(0xFF241617);
  static const muted = Color(0xFF8E7F80);
  static const line = Color(0xFFEBDFDC);
  static const rose = Color(0xFFF8DADA);
  static const heart = Color(0xFFE53935);
}

TextStyle _display(double size, {Color color = _C.ink, double ls = -0.5}) =>
    GoogleFonts.sora(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: ls,
    );

TextStyle _body(
  double size, {
  Color color = _C.ink,
  FontWeight w = FontWeight.w500,
}) => GoogleFonts.plusJakartaSans(fontSize: size, color: color, fontWeight: w);

String _formatRupiah(dynamic value) {
  final n = (double.tryParse(value.toString()) ?? 0).round();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

const _waKeys = [
  'no_whatsapp',
  'whatsapp',
  'no_wa',
  'wa',
  'no_hp',
  'nomor_hp',
  'no_telp',
  'telepon',
  'phone',
];

String? _pick(dynamic p, List<String> keys) {
  if (p is! Map) return null;

  String? read(Map m) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is Map) {
        final inner =
            v['nama_kategori'] ?? v['nama_toko'] ?? v['nama'] ?? v['name'];
        if (inner != null && inner.toString().trim().isNotEmpty) {
          return inner.toString().trim();
        }
        continue;
      }
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return null;
  }

  final direct = read(p);
  if (direct != null) return direct;
  for (final n in ['penjual', 'toko', 'user', 'seller']) {
    final sub = p[n];
    if (sub is Map) {
      final r = read(sub);
      if (r != null) return r;
    }
  }
  return null;
}

String? _normalizePhone(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('62')) return digits;
  if (digits.startsWith('0')) return '62${digits.substring(1)}';
  if (digits.startsWith('8')) return '62$digits';
  return digits;
}

void _showSnack(
  BuildContext context,
  String message, {
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: _C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: const Color(0xFFFFB4B6),
                onPressed: onAction ?? () {},
              ),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_rounded : Icons.check_circle_rounded,
              color: error ? const Color(0xFFFF8A80) : const Color(0xFF7BE0A8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: _body(13.5, color: Colors.white, w: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<dynamic> _produkFavorit = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final wishlistIds = await WishlistService.getWishlistIds();

      if (wishlistIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _produkFavorit = [];
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(Uri.parse(ApiBaseUrl.produkPublik));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> allProduk = data['data'];

        List<dynamic> filtered = allProduk
            .where((p) => wishlistIds.contains(p['produk_id']))
            .toList();

        if (!mounted) return;
        setState(() {
          _produkFavorit = filtered;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _hapus(dynamic produk) async {
    final id = produk['produk_id'];
    try {
      await WishlistService.toggleWishlist(id);
    } catch (_) {
      if (!mounted) return;
      _showSnack(context, 'Gagal menghapus dari favorit', error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _produkFavorit.remove(produk));
    _showSnack(
      context,
      'Dihapus dari favorit',
      actionLabel: 'Urungkan',
      onAction: () async {
        await WishlistService.toggleWishlist(id);
        _loadWishlist();
      },
    );
  }

  void _openDetail(dynamic produk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ProdukDetailSheet(produk: produk, onRemove: () => _hapus(produk)),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('Produk Favorit', style: _display(28)),
              ],
            ),
          ),
          if (!_isLoading && _produkFavorit.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _C.rose,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded, size: 16, color: _C.heart),
                  const SizedBox(width: 6),
                  Text(
                    '${_produkFavorit.length}',
                    style: _display(14, color: _C.primary, ls: 0),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonLabel,
    VoidCallback? onButton,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 72, 40, 0),
      child: Column(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: _C.rose,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(icon, size: 50, color: _C.primary),
          ),
          const SizedBox(height: 24),
          Text(title, style: _display(19)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: _body(13.5, color: _C.muted).copyWith(height: 1.5),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: onButton,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _C.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: _body(14, color: Colors.white, w: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  SliverGridDelegate get _gridDelegate =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      // NAVBAR DISINI
      bottomNavigationBar: const PembeliBottomNavbar(selectedIndex: 1),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // TAMBAHKAN TOP BAR DISINI
            const PembeliTopBar(),
            Expanded(
              child: RefreshIndicator(
                color: _C.primary,
                backgroundColor: Colors.white,
                onRefresh: _loadWishlist,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    const SliverToBoxAdapter(child: SizedBox(height: 22)),
                    if (_isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        sliver: SliverGrid(
                          gridDelegate: _gridDelegate,
                          delegate: SliverChildBuilderDelegate(
                            (_, __) => const _Pulse(child: _SkeletonCard()),
                            childCount: 4,
                          ),
                        ),
                      )
                    else if (_hasError)
                      SliverToBoxAdapter(
                        child: _buildMessageState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Gagal memuat favorit',
                          subtitle:
                              'Periksa koneksi internetmu lalu coba muat ulang.',
                          buttonLabel: 'Coba lagi',
                          onButton: _loadWishlist,
                        ),
                      )
                    else if (_produkFavorit.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildMessageState(
                          icon: Icons.favorite_border_rounded,
                          title: 'Belum ada favorit',
                          subtitle:
                              'Tekan ikon hati pada produk untuk menyimpannya di sini.',
                          buttonLabel: 'Jelajahi Produk',
                          onButton: () {
                            Navigator.pushReplacementNamed(context, '/produk');
                          },
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        sliver: SliverGrid(
                          gridDelegate: _gridDelegate,
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final produk = _produkFavorit[index];
                            return TweenAnimationBuilder<double>(
                              key: ValueKey(produk['produk_id']),
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds:
                                    350 + (index > 8 ? 8 : index) * 70,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, child) => Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - v) * 24),
                                  child: child,
                                ),
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openDetail(produk),
                                child: _ProdukCard(
                                  produk: produk,
                                  onRemove: () => _hapus(produk),
                                ),
                              ),
                            );
                          }, childCount: _produkFavorit.length),
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
  }
}

// ==========================================
// KOMPONEN PENDUKUNG (JANGAN DIHAPUS)
// ==========================================
class _ProdukCard extends StatelessWidget {
  final dynamic produk;
  final VoidCallback onRemove;

  const _ProdukCard({required this.produk, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14803033),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFFF3E7E4),
                  child: Image.network(
                    ApiBaseUrl.getImageUrl(produk['gambar']),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _C.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        size: 36,
                        color: _C.muted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: onRemove,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: _C.heart,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produk['nama_produk'] ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _body(13.5, w: FontWeight.w700).copyWith(height: 1.25),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRupiah(produk['harga']),
                  style: _display(14.5, color: _C.primary, ls: -0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFE3E0),
        borderRadius: BorderRadius.circular(26),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_ctrl),
      child: widget.child,
    );
  }
}

class _ProdukDetailSheet extends StatelessWidget {
  final dynamic produk;
  final VoidCallback onRemove;

  const _ProdukDetailSheet({required this.produk, required this.onRemove});

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final nama = produk['nama_produk'] ?? 'produk ini';
    final pesan =
        'Halo, saya tertarik dengan produk *$nama* (${_formatRupiah(produk['harga'])}) '
        'yang saya lihat di SIBU. Apakah masih tersedia?';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(pesan)}',
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _showSnack(context, 'Tidak bisa membuka WhatsApp', error: true);
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Tidak bisa membuka WhatsApp', error: true);
      }
    }
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: _body(12, color: fg, w: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _normalizePhone(_pick(produk, _waKeys));
    final deskripsi = _pick(produk, ['deskripsi', 'keterangan', 'description']);
    final stokRaw = _pick(produk, ['stok', 'stock']);
    final kategori = _pick(produk, ['nama_kategori', 'kategori']);
    final toko = _pick(produk, [
      'nama_toko',
      'toko',
      'nama_penjual',
      'penjual',
    ]);
    final stokHabis = stokRaw != null && (int.tryParse(stokRaw) ?? 1) <= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.12,
                        child: Container(
                          color: const Color(0xFFF3E7E4),
                          width: double.infinity,
                          child: Image.network(
                            ApiBaseUrl.getImageUrl(produk['gambar']),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _C.primary,
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                size: 48,
                                color: _C.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(200),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 24,
                        left: 20,
                        child: _circleButton(
                          Icons.close_rounded,
                          _C.ink,
                          () => Navigator.pop(context),
                        ),
                      ),
                      Positioned(
                        top: 24,
                        right: 20,
                        child: _circleButton(
                          Icons.favorite_rounded,
                          _C.heart,
                          () {
                            Navigator.pop(context);
                            onRemove();
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (kategori != null)
                              _chip(
                                Icons.sell_rounded,
                                kategori,
                                _C.rose,
                                _C.primary,
                              ),
                            if (stokRaw != null)
                              stokHabis
                                  ? _chip(
                                      Icons.block_rounded,
                                      'Stok habis',
                                      const Color(0xFFFFE1E0),
                                      _C.heart,
                                    )
                                  : _chip(
                                      Icons.inventory_2_rounded,
                                      'Stok: $stokRaw',
                                      const Color(0xFFD7EFE1),
                                      const Color(0xFF2B7A58),
                                    ),
                          ],
                        ),
                        if (kategori != null || stokRaw != null)
                          const SizedBox(height: 14),
                        Text(
                          produk['nama_produk'] ?? '-',
                          style: _display(22).copyWith(height: 1.25),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatRupiah(produk['harga']),
                          style: _display(26, color: _C.primary, ls: -0.8),
                        ),
                        const SizedBox(height: 22),
                        const Divider(color: _C.line, height: 1),
                        const SizedBox(height: 20),
                        Text(
                          'Deskripsi',
                          style: _body(14.5, w: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          deskripsi ?? 'Belum ada deskripsi untuk produk ini.',
                          style: _body(
                            14,
                            color: _C.muted,
                          ).copyWith(height: 1.65),
                        ),
                        if (toko != null) ...[
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _C.line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _C.rose,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: _C.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dijual oleh',
                                        style: _body(11.5, color: _C.muted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        toko,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _body(14.5, w: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _C.line)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: phone == null
                            ? null
                            : () => _openWhatsApp(context, phone),
                        icon: const Icon(Icons.chat_rounded, size: 21),
                        label: Text(
                          'Hubungi via WhatsApp',
                          style: _body(
                            15,
                            color: Colors.white,
                            w: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF25D366),
                          disabledBackgroundColor: const Color(0xFFD9CFCD),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    if (phone == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Nomor WhatsApp penjual belum tersedia',
                        style: _body(12, color: _C.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
