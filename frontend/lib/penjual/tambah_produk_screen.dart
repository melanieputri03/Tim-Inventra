import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_base_url.dart';

class TambahProdukScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const TambahProdukScreen({super.key, required this.userName, required this.userEmail});

  @override
  State<TambahProdukScreen> createState() => _TambahProdukScreenState();
}

class _TambahProdukScreenState extends State<TambahProdukScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _namaProdukController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _minStokController = TextEditingController();
  final TextEditingController _stockPerSizeController = TextEditingController();
  // ⭐ TAMBAH CONTROLLER WARNA
  final TextEditingController _warnaController = TextEditingController();

  // Data Kategori API
  List<Map<String, dynamic>> _kategoriList = [];
  String? _selectedKategoriId;

  // Data Ukuran & Stok
  List<Map<String, dynamic>> _sizeStockList = [];
  final List<String> _ukuranList = ['S', 'M', 'L', 'XL', 'XXL', 'ALL SIZE'];
  String? _selectedUkuran;

  // Multi Gambar Produk (maksimal 5)
  List<File> _selectedImages = [];
  List<Uint8List> _selectedImagesBytes = [];
  List<String> _imageNames = [];
  bool _isImageSelected = false;

  // Gambar Size Chart
  File? _selectedSizeChart;
  Uint8List? _selectedSizeChartBytes;
  String? _sizeChartName;
  bool _isSizeChartSelected = false;

  // State
  bool _isLoading = false;
  String? _token;

  // ⭐ HELPER WARNA
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
    _loadToken();
    _fetchKategori();
  }

  // LOAD TOKEN
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  // FETCH KATEGORI API
  Future<void> _fetchKategori() async {
    try {
      final response = await http.get(
        Uri.parse(ApiBaseUrl.kategori),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _kategoriList = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error fetching kategori: $e');
    }
  }

  // ⭐ TAMBAH UKURAN & STOK (DENGAN WARNA)
  void _addSizeStock() {
    String size = _selectedUkuran ?? '';
    String warna = _warnaController.text.trim();
    String stockStr = _stockPerSizeController.text.trim();

    if (size.isEmpty) {
      _showSnackbar('Pilih ukuran terlebih dahulu!', Colors.orange);
      return;
    }
    if (warna.isEmpty) {
      _showSnackbar('Masukkan warna!', Colors.orange);
      return;
    }
    if (stockStr.isEmpty) {
      _showSnackbar('Masukkan jumlah stok!', Colors.orange);
      return;
    }

    int stock = int.tryParse(stockStr) ?? 0;
    if (stock <= 0) {
      _showSnackbar('Stok harus lebih dari 0!', Colors.orange);
      return;
    }

    // Cek kombinasi size+warna sudah ada
    bool exists = _sizeStockList.any((item) => 
      item['size'] == size && item['warna'] == warna
    );
    if (exists) {
      _showSnackbar('Ukuran "$size" warna "$warna" sudah ada!', Colors.red);
      return;
    }

    setState(() {
      // ⭐ SIMPAN DENGAN FORMAT BARU (size + warna + stock)
      _sizeStockList.add({
        'size': size,
        'warna': warna,
        'stock': stock,
      });
      _warnaController.clear();
      _stockPerSizeController.clear();
      _selectedUkuran = null;
    });
  }

  void _removeSizeStock(int index) {
    setState(() => _sizeStockList.removeAt(index));
  }

  void _updateStock(int index, int newStock) {
    if (newStock > 0) {
      setState(() => _sizeStockList[index]['stock'] = newStock);
    }
  }

  // UPLOAD MULTI GAMBAR
  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showSnackbar('Maksimal 5 gambar!', Colors.orange);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        int availableSlots = 5 - _selectedImages.length;
        int filesToAdd = result.files.length > availableSlots ? availableSlots : result.files.length;
        
        for (int i = 0; i < filesToAdd; i++) {
          final file = result.files[i];
          setState(() {
            _imageNames.add(file.name);
            if (kIsWeb) {
              _selectedImagesBytes.add(file.bytes!);
            } else {
              _selectedImages.add(File(file.path!));
            }
            _isImageSelected = true;
          });
        }
        _showSnackbar('$filesToAdd gambar berhasil ditambahkan', Colors.green);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedImagesBytes.removeAt(index);
      } else {
        _selectedImages.removeAt(index);
      }
      _imageNames.removeAt(index);
      if (_selectedImages.isEmpty && _selectedImagesBytes.isEmpty) {
        _isImageSelected = false;
      }
    });
    _showSnackbar('Gambar dihapus', Colors.orange);
  }

  // UPLOAD SIZE CHART
  Future<void> _pickSizeChart() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.single;
        setState(() {
          _sizeChartName = file.name;
          _isSizeChartSelected = true;
          if (kIsWeb) {
            _selectedSizeChartBytes = file.bytes;
            _selectedSizeChart = null;
          } else {
            _selectedSizeChart = File(file.path!);
            _selectedSizeChartBytes = null;
          }
        });
        _showSnackbar('Size Chart "${file.name}" berhasil dipilih', Colors.green);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    }
  }

  // SIMPAN PRODUK
  Future<void> _simpanProduk() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sizeStockList.isEmpty) {
      _showSnackbar('Tambahkan minimal 1 ukuran, warna, dan stok!', Colors.orange);
      return;
    }
    if (_selectedKategoriId == null) {
      _showSnackbar('Pilih kategori terlebih dahulu!', Colors.orange);
      return;
    }
    if (_selectedImages.isEmpty && _selectedImagesBytes.isEmpty) {
      _showSnackbar('Pilih minimal 1 gambar produk!', Colors.orange);
      return;
    }
    if (_token == null) {
      _showSnackbar('Token tidak ditemukan, silakan login ulang', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    var request = http.MultipartRequest('POST', Uri.parse(ApiBaseUrl.produk));
    request.headers['Authorization'] = 'Bearer $_token';
    request.headers['Accept'] = 'application/json';

    request.fields['nama_produk'] = _namaProdukController.text;
    request.fields['harga'] = _hargaController.text.replaceAll('.', '');
    request.fields['kategori_id'] = _selectedKategoriId!;
    request.fields['min_stok'] = _minStokController.text.isNotEmpty ? _minStokController.text : '10';
    request.fields['ukuran_stok'] = jsonEncode(_sizeStockList);
    request.fields['deskripsi'] = _deskripsiController.text;
    request.fields['stok'] = _sizeStockList.fold(0, (sum, item) => sum + (item['stock'] as int)).toString();

    // Upload multiple gambar produk
    if (kIsWeb) {
      for (int i = 0; i < _selectedImagesBytes.length; i++) {
        request.files.add(http.MultipartFile.fromBytes(
          'gambar[]',
          _selectedImagesBytes[i],
          filename: _imageNames[i],
        ));
      }
    } else {
      for (int i = 0; i < _selectedImages.length; i++) {
        request.files.add(await http.MultipartFile.fromPath(
          'gambar[]',
          _selectedImages[i].path,
        ));
      }
    }

    // Upload size chart
    if (_isSizeChartSelected) {
      if (kIsWeb && _selectedSizeChartBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('size_chart', _selectedSizeChartBytes!, filename: _sizeChartName));
      } else if (_selectedSizeChart != null) {
        request.files.add(await http.MultipartFile.fromPath('size_chart', _selectedSizeChart!.path));
      }
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        _showSnackbar('Produk berhasil disimpan!', Colors.green);
        Navigator.pop(context, true);
      } else {
        _showSnackbar(data['message'] ?? 'Gagal menyimpan produk', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // HELPER
  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  String formatPrice(String value) {
    if (value.isEmpty) return '';
    final number = int.tryParse(value.replaceAll('.', '')) ?? 0;
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  int getTotalStock() {
    return _sizeStockList.fold(0, (sum, item) => sum + (item['stock'] as int));
  }

  // WIDGET BUILD
  Widget _buildImagePreview(int index) {
    if (kIsWeb && index < _selectedImagesBytes.length) {
      return Image.memory(_selectedImagesBytes[index], width: 80, height: 80, fit: BoxFit.cover);
    } else if (index < _selectedImages.length) {
      return Image.file(_selectedImages[index], width: 80, height: 80, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSizeChartPreview() {
    if (!_isSizeChartSelected) {
      return _buildUploadPlaceholder();
    }
    if (kIsWeb && _selectedSizeChartBytes != null) {
      return Image.memory(_selectedSizeChartBytes!, width: double.infinity, height: 140, fit: BoxFit.cover);
    }
    if (_selectedSizeChart != null) {
      return Image.file(_selectedSizeChart!, width: double.infinity, height: 140, fit: BoxFit.cover);
    }
    return _buildUploadPlaceholder();
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF5ECEA), shape: BoxShape.circle),
          child: const Icon(Icons.cloud_upload_outlined, size: 32, color: Color(0xFF803033)),
        ),
        const SizedBox(height: 12),
        Text('Klik untuk pilih gambar', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('JPG/PNG, max 2MB', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF803033)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tambah Produk',
              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF803033)),
            ),
            const SizedBox(height: 2),
            Text(
              'Lengkap detail produk',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        toolbarHeight: 70,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF803033)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FOTO PRODUK (MULTI GAMBAR)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Foto Produk (Maksimal 5)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('${_selectedImages.length + _selectedImagesBytes.length}/5', 
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Grid preview gambar
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (_selectedImages.length + _selectedImagesBytes.length) + 1,
                        itemBuilder: (context, index) {
                          if (index == (_selectedImages.length + _selectedImagesBytes.length)) {
                            // Tombol tambah gambar
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD8A5A8), width: 2),
                                ),
                                child: const Icon(Icons.add_photo_alternate, size: 40, color: Color(0xFF803033)),
                              ),
                            );
                          }
                          // Preview gambar dipilih
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD8A5A8), width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildImagePreview(index),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                              if (index == 0)
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF803033),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Utama', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white)),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Gambar pertama akan menjadi gambar utama', 
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500)),

                    const SizedBox(height: 24),

                    // SIZE CHART (OPSIONAL)
                    Text('Size Chart (Opsional)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickSizeChart,
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD8A5A8), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildSizeChartPreview(),
                              if (_isSizeChartSelected) Container(color: Colors.black.withOpacity(0.4)),
                              if (_isSizeChartSelected)
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white, size: 32),
                                      const SizedBox(height: 8),
                                      Text(_sizeChartName ?? 'Size Chart terpilih', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Upload panduan ukuran untuk produk ini (opsional)', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500)),

                    const SizedBox(height: 24),

                    // NAMA PRODUK
                    Text('NAMA PRODUK', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TextFormField(
                        controller: _namaProdukController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Abaya Maroon Elegan',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Nama produk tidak boleh kosong' : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // HARGA
                    Text('HARGA', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TextFormField(
                        controller: _hargaController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        onChanged: (value) {
                          final formatted = formatPrice(value);
                          if (formatted != value) {
                            _hargaController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                          }
                        },
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          hintText: '387.000',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Harga tidak boleh kosong' : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // KATEGORI
                    Text('KATEGORI', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: _kategoriList.isEmpty
                              ? Text('   Memuat kategori...', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade500))
                              : Text('   Pilih Kategori', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade500)),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF803033)),
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black87),
                          value: _selectedKategoriId,
                          items: _kategoriList.map((k) {
                            return DropdownMenuItem<String>(
                              value: k['kategori_id'].toString(),
                              child: Text(k['nama_kategori']),
                            );
                          }).toList(),
                          onChanged: _kategoriList.isEmpty
                              ? null
                              : (String? value) {
                                  setState(() {
                                    _selectedKategoriId = value;
                                  });
                                },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // MIN STOK
                    Text('MIN. STOK', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TextFormField(
                        controller: _minStokController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '10',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Min. stok tidak boleh kosong' : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DESKRIPSI
                    Text('DESKRIPSI', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TextFormField(
                        controller: _deskripsiController,
                        maxLines: 4,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Deskripsi produk...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // UKURAN, WARNA & STOK
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5ECEA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8A5A8), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.label_outline, color: Color(0xFF803033), size: 20),
                              const SizedBox(width: 8),
                              Text('UKURAN, WARNA & STOK', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF803033))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Row: Ukuran dropdown + Stok input
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      hint: Text('Pilih Ukuran', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade500)),
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF803033)),
                                      value: _selectedUkuran,
                                      items: _ukuranList.map((ukuran) {
                                        return DropdownMenuItem<String>(
                                          value: ukuran,
                                          child: Text(ukuran, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(() => _selectedUkuran = value),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _stockPerSizeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Stok',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(color: const Color(0xFF803033), borderRadius: BorderRadius.circular(10)),
                                child: IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                  onPressed: _addSizeStock,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // ⭐ TAMBAH INPUT WARNA
                          Text(
                            'Warna',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _warnaController,
                              decoration: InputDecoration(
                                hintText: 'Contoh: Merah, Biru, Pink, Hitam',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.palette_outlined,
                                  color: Color(0xFF803033),
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // ⭐ DAFTAR VARIAN (DENGAN WARNA)
                          if (_sizeStockList.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            Text('Daftar Varian:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            ..._sizeStockList.asMap().entries.map((entry) {
                              int index = entry.key;
                              var item = entry.value;
                              String warna = item['warna'] ?? '';
                              Color warnaColor = _getWarnaColor(warna);
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFD8A5A8), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    // 🎨 Indikator warna
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: warnaColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Ukuran + Warna
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item['size']} | ${item['warna'] ?? '-'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // Stok
                                    Expanded(
                                      flex: 1,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: item['stock'].toString(),
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                              ),
                                              onChanged: (value) {
                                                int newStock = int.tryParse(value) ?? 0;
                                                if (newStock > 0) _updateStock(index, newStock);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      onPressed: () => _removeSizeStock(index),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_sizeStockList.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF803033).withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Stok:', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${getTotalStock()} pcs', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF803033))),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // BUTTON
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF803033), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Batal', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF803033))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _simpanProduk,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF803033),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text('Simpan Produk', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _hargaController.dispose();
    _deskripsiController.dispose();
    _minStokController.dispose();
    _stockPerSizeController.dispose();
    _warnaController.dispose();
    super.dispose();
  }
}