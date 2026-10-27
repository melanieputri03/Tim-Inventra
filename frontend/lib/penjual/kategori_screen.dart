import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// PENYESUAIAN PATH IMPORT:
// Karena file ini ada di dalam folder 'penjual', mundur satu folder (../)
// untuk mengakses folder 'api'
import '../api/api_base_url.dart';

// ==========================================
// 0. DESIGN TOKENS
// ==========================================
class _C {
  static const primary = Color(0xFF803033);
  static const primaryDeep = Color(0xFF55191C);
  static const bg = Color(0xFFFBF7F5);
  static const ink = Color(0xFF241617);
  static const muted = Color(0xFF8E7F80);
  static const line = Color(0xFFEBDFDC);
  static const danger = Color(0xFFE53935);
}

class _Pal {
  final Color bg;
  final Color accent;
  const _Pal(this.bg, this.accent);
}

// Palet pastel yang berputar per item supaya grid terasa hidup
const _palettes = <_Pal>[
  _Pal(Color(0xFFF8DADA), Color(0xFF803033)), // rose
  _Pal(Color(0xFFFFE2CA), Color(0xFFB45A1E)), // peach
  _Pal(Color(0xFFD7EFE1), Color(0xFF2B7A58)), // mint
  _Pal(Color(0xFFDBEAFA), Color(0xFF2D6CB3)), // sky
  _Pal(Color(0xFFE7DFF7), Color(0xFF6A4FB0)), // lavender
  _Pal(Color(0xFFFFF0BF), Color(0xFF9A7300)), // butter
];

TextStyle _display(double size, {Color color = _C.ink, double? ls}) =>
    GoogleFonts.sora(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: ls ?? -0.5,
    );

TextStyle _body(
  double size, {
  Color color = _C.ink,
  FontWeight w = FontWeight.w500,
}) => GoogleFonts.plusJakartaSans(fontSize: size, color: color, fontWeight: w);

void _showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: _C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

// ==========================================
// 1. MODEL KATEGORI
// ==========================================
class Kategori {
  final int kategoriId;
  final String namaKategori;

  Kategori({required this.kategoriId, required this.namaKategori});

  factory Kategori.fromJson(Map<String, dynamic> json) {
    return Kategori(
      kategoriId: json['kategori_id'],
      namaKategori: json['nama_kategori'],
    );
  }
}

// ==========================================
// 2. SERVICE API (KONEKSI KE LARAVEL)
// ==========================================
class KategoriService {
  // Ambil token untuk otentikasi (sesuai sistem SIBU)
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Kategori>> getAllKategori() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(ApiBaseUrl.kategori),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<dynamic> list = data['data'];
      return list.map((e) => Kategori.fromJson(e)).toList();
    } else {
      throw Exception('Gagal memuat kategori (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> tambahKategori(String nama) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(ApiBaseUrl.kategori),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nama_kategori': nama}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> editKategori(int id, String nama) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('${ApiBaseUrl.kategori}/$id'), // URL by ID
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nama_kategori': nama}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> hapusKategori(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${ApiBaseUrl.kategori}/$id'), // URL by ID
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }
}

// ==========================================
// 3. HALAMAN KATEGORI
// ==========================================
class KategoriScreen extends StatefulWidget {
  const KategoriScreen({super.key});

  @override
  State<KategoriScreen> createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen> {
  final KategoriService _service = KategoriService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Kategori> _listKategori = [];
  bool _isLoading = true;
  String _query = '';

  List<Kategori> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _listKategori;
    return _listKategori
        .where((e) => e.namaKategori.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await _service.getAllKategori();
      if (!mounted) return;
      setState(() {
        _listKategori = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  // ---------- SHEETS & DIALOGS ----------
  void _openForm({Kategori? kategori}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KategoriFormSheet(kategori: kategori, onSaved: _loadData),
    );
  }

  void _openActions(Kategori item, _Pal pal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pal.bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.sell_rounded, color: pal.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaKategori,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _display(17),
                      ),
                      Text(
                        'Pilih tindakan',
                        style: _body(12.5, color: _C.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ActionTile(
              icon: Icons.edit_rounded,
              label: 'Edit nama kategori',
              color: const Color(0xFF2D6CB3),
              bg: const Color(0xFFDBEAFA),
              onTap: () {
                Navigator.pop(sheetContext);
                _openForm(kategori: item);
              },
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.delete_rounded,
              label: 'Hapus kategori',
              color: _C.danger,
              bg: const Color(0xFFFFE1E0),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Kategori kategori) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE1E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _C.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text('Hapus kategori?', style: _display(19)),
            const SizedBox(height: 8),
            Text(
              '"${kategori.namaKategori}" akan dihapus permanen dan tidak bisa dikembalikan.',
              textAlign: TextAlign.center,
              style: _body(13.5, color: _C.muted).copyWith(height: 1.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: _C.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Batal', style: _body(14, w: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      final res = await _service.hapusKategori(
                        kategori.kategoriId,
                      );
                      if (!mounted) return;
                      if (res['success'] == true) {
                        _loadData();
                        _showSnack(context, 'Kategori berhasil dihapus');
                      } else {
                        _showSnack(
                          context,
                          res['message'] ?? 'Gagal menghapus kategori',
                          error: true,
                        );
                      }
                    } catch (_) {
                      if (!mounted) return;
                      _showSnack(
                        context,
                        'Terjadi kesalahan koneksi',
                        error: true,
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: _C.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Hapus',
                    style: _body(14, color: Colors.white, w: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- SECTIONS ----------
  Widget _buildHeader() {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          if (canPop) ...[
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.line),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: _C.ink,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIBU  ·  PENJUAL',
                  style: _body(
                    10.5,
                    color: _C.primary,
                    w: FontWeight.w800,
                  ).copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: 2),
                Text('Kategori', style: _display(30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [_C.primary, _C.primaryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40803033),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -40,
              child: _Blob(size: 150, alpha: 22),
            ),
            Positioned(
              right: 50,
              bottom: -60,
              child: _Blob(size: 120, alpha: 16),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(36),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Total kategori',
                          style: _body(
                            12,
                            color: Colors.white,
                            w: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: _listKategori.length.toDouble(),
                        ),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          v.round().toString(),
                          style: _display(
                            56,
                            color: Colors.white,
                            ls: -2,
                          ).copyWith(height: 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'kategori aktif',
                          style: _body(
                            14,
                            color: Colors.white70,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Rapikan produk tokomu dengan kategori yang jelas.',
                    style: _body(
                      12.5,
                      color: Colors.white70,
                    ).copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: _C.line),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: _body(14.5),
          cursorColor: _C.primary,
          decoration: InputDecoration(
            hintText: 'Cari kategori…',
            hintStyle: _body(14.5, color: _C.muted),
            prefixIcon: const Icon(Icons.search_rounded, color: _C.muted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: _C.muted,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final searching = _query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 56, 40, 0),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: _palettes[0].bg,
              borderRadius: BorderRadius.circular(34),
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.sell_outlined,
              size: 48,
              color: _C.primary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            searching ? 'Tidak ditemukan' : 'Belum ada kategori',
            style: _display(19),
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'Coba gunakan kata kunci yang lain.'
                : 'Mulai dengan membuat kategori pertamamu lewat tombol tambah.',
            textAlign: TextAlign.center,
            style: _body(13.5, color: _C.muted).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  SliverGridDelegate get _gridDelegate =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.02,
      );

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _C.primary,
          backgroundColor: Colors.white,
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildSearch()),
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
                  sliver: SliverGrid(
                    gridDelegate: _gridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const _Pulse(child: _SkeletonCard()),
                      childCount: 6,
                    ),
                  ),
                )
              else if (list.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
                  sliver: SliverGrid(
                    gridDelegate: _gridDelegate,
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = list[index];
                      final pal =
                          _palettes[_listKategori.indexOf(item) %
                              _palettes.length];
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(item.kategoriId),
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds: 350 + (index > 8 ? 8 : index) * 70,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, (1 - v) * 24),
                            child: child,
                          ),
                        ),
                        child: _KategoriCard(
                          item: item,
                          pal: pal,
                          onTap: () => _openForm(kategori: item),
                          onMore: () => _openActions(item, pal),
                        ),
                      );
                    }, childCount: list.length),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _C.primary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}

// ==========================================
// 4. KOMPONEN KECIL
// ==========================================
class _Blob extends StatelessWidget {
  final double size;
  final int alpha;
  const _Blob({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(alpha),
      ),
    );
  }
}

class _KategoriCard extends StatelessWidget {
  final Kategori item;
  final _Pal pal;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _KategoriCard({
    required this.item,
    required this.pal,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final letter = item.namaKategori.isNotEmpty
        ? item.namaKategori[0].toUpperCase()
        : '?';

    return Material(
      color: pal.bg,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: Stack(
          children: [
            // Huruf besar transparan sebagai dekorasi
            Positioned(
              right: -6,
              bottom: -26,
              child: Text(
                letter,
                style: GoogleFonts.sora(
                  fontSize: 120,
                  fontWeight: FontWeight.w800,
                  color: pal.accent.withAlpha(30),
                  height: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.sell_rounded,
                          color: pal.accent,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onMore,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(140),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: pal.accent,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    item.namaKategori,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _display(
                      16,
                    ).copyWith(height: 1.2, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Kategori produk',
                    style: _body(11.5, color: pal.accent, w: FontWeight.w700),
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

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFE3E0),
        borderRadius: BorderRadius.circular(28),
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

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: _C.line,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: _body(14.5, w: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.muted),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. BOTTOM SHEET FORM (TAMBAH / EDIT)
// ==========================================
class KategoriFormSheet extends StatefulWidget {
  final Kategori? kategori;
  final VoidCallback onSaved;

  const KategoriFormSheet({super.key, this.kategori, required this.onSaved});

  @override
  State<KategoriFormSheet> createState() => _KategoriFormSheetState();
}

class _KategoriFormSheetState extends State<KategoriFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final KategoriService _service = KategoriService();
  bool _isLoading = false;

  bool get _isEdit => widget.kategori != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _controller.text = widget.kategori!.namaKategori;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final nama = _controller.text.trim();
      final res = _isEdit
          ? await _service.editKategori(widget.kategori!.kategoriId, nama)
          : await _service.tambahKategori(nama);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        final messenger = ScaffoldMessenger.of(context);
        final msg = _isEdit
            ? 'Kategori berhasil diperbarui'
            : 'Kategori berhasil ditambahkan';
        Navigator.pop(context);
        widget.onSaved();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              elevation: 0,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              backgroundColor: _C.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF7BE0A8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    msg,
                    style: _body(13.5, color: Colors.white, w: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
      } else {
        _showSnack(context, res['message'] ?? 'Gagal menyimpan', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(context, 'Terjadi kesalahan koneksi', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, {double w = 1.2}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: c, width: w),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _SheetShell(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _palettes[0].bg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      color: _C.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit kategori' : 'Kategori baru',
                          style: _display(21),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEdit
                              ? 'Ubah nama kategori produkmu'
                              : 'Beri nama kategori untuk produkmu',
                          style: _body(12.5, color: _C.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text('Nama kategori', style: _body(13, w: FontWeight.w700)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _controller,
                autofocus: true,
                cursorColor: _C.primary,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: _body(15, w: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Contoh: Makanan Ringan',
                  hintStyle: _body(14.5, color: _C.muted),
                  filled: true,
                  fillColor: _C.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: border(Colors.transparent),
                  enabledBorder: border(_C.line),
                  focusedBorder: border(_C.primary, w: 1.8),
                  errorBorder: border(_C.danger),
                  focusedErrorBorder: border(_C.danger, w: 1.8),
                  errorStyle: _body(12, color: _C.danger),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Nama kategori wajib diisi'
                    : null,
                onFieldSubmitted: (_) => _isLoading ? null : _simpan(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _C.primary,
                    disabledBackgroundColor: _C.primary.withAlpha(150),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Simpan perubahan' : 'Tambah kategori',
                          style: _body(
                            15,
                            color: Colors.white,
                            w: FontWeight.w800,
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
}
