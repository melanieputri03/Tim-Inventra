<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Api\ProdukController;
use App\Http\Controllers\Api\TransaksiController;
use App\Http\Controllers\Api\PeriodeController;
use App\Http\Controllers\Api\RekomendasiStokController;
use App\Http\Controllers\Api\LaporanController;
use App\Http\Controllers\Api\NotifikasiController;
use App\Http\Controllers\Api\KategoriController;
use App\Http\Controllers\Api\BundlingController;
use App\Http\Controllers\Api\ProfitController;
use App\Models\Penjual;

// Endpoint About Market (Tanpa Auth / Publik)
Route::get('/toko-profil', function () {
    // Mengambil toko pertama (karena diasumsikan 1 aplikasi untuk 1 butik)
    $toko = Penjual::select('nama_toko', 'no_telepon', 'nama')->first();
    
    if (!$toko) {
        return response()->json([
            'success' => false,
            'message' => 'Data toko belum tersedia.'
        ], 404);
    }

    // Bersihkan format nomor HP (jika ada spasi atau strip)
    $noTelepon = preg_replace('/[^0-9]/', '', $toko->no_telepon);
    // Ubah awalan 0 menjadi 62 (format WhatsApp)
    if (substr($noTelepon, 0, 1) === '0') {
        $noTelepon = '62' . substr($noTelepon, 1);
    }

    return response()->json([
        'success' => true, 
        'data' => [
            'nama_toko' => $toko->nama_toko ?? 'Butik Syar\'i Ani',
            'nama_pemilik' => $toko->nama ?? 'Admin',
            'no_telepon' => $noTelepon
        ]
    ]);
});

// Auth
Route::post('/login', [LoginController::class, 'login']);

// Kategori (Public)
Route::get('/kategori', [ProdukController::class, 'getKategori']);

// Produk publik untuk pembeli (tidak perlu login)
Route::get('/produk-publik', [ProdukController::class, 'indexPembeli']);
Route::get('/produk-publik/{id}', [ProdukController::class, 'showPembeli']);
Route::get('/rekomendasi', [ProdukController::class, 'rekomendasi']);

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [LoginController::class, 'logout']);
    Route::get('/me', [LoginController::class, 'me']);
    Route::put('/me', [LoginController::class, 'updateProfil']);
    
    // CRUD Produk
    Route::apiResource('produk', ProdukController::class);
    
    // Transaksi
    Route::apiResource('transaksi', TransaksiController::class);
    Route::get('riwayat-transaksi', [TransaksiController::class, 'index']);

    // Periode
    Route::apiResource('periode', PeriodeController::class);

    // Rekomendasi Stok
    Route::get('/rekomendasi-stok', [RekomendasiStokController::class, 'index']);
    Route::post('/rekomendasi-stok/restock', [RekomendasiStokController::class, 'restock']);
    Route::post('/rekomendasi-stok/konfirmasi-tiba', [RekomendasiStokController::class, 'konfirmasiTiba']);

    // Notifikasi
    Route::get('/notifikasi', [NotifikasiController::class, 'index']);
    Route::put('/notifikasi/{id}/baca', [NotifikasiController::class, 'tandaiBaca']);
    Route::put('/notifikasi/baca-semua', [NotifikasiController::class, 'tandaiSemuaBaca']);
    Route::delete('/notifikasi/hapus-semua', [NotifikasiController::class, 'hapusSemuaNotifikasi']);
    Route::post('/fcm-token', [NotifikasiController::class, 'saveFcmToken']);

    // Laporan
    Route::prefix('laporan')->group(function () {
        Route::get('/penjualan', [LaporanController::class, 'getPenjualan']);
        Route::get('/produk-terlaris', [LaporanController::class, 'getProdukTerlaris']);
        Route::get('/penjualan/tahunan', [LaporanController::class, 'getPenjualanTahunan']);
        Route::get('/produk-terlaris/tahunan', [LaporanController::class, 'getProdukTerlarisTahunan']);
        Route::get('/fast-moving-sku', [LaporanController::class, 'getFastMovingSku']);
        Route::get('/dead-stock', [LaporanController::class, 'getDeadStock']);
    });

    Route::get('/kategori', [KategoriController::class, 'index']);
        Route::post('/kategori', [KategoriController::class, 'store']);
        Route::put('/kategori/{id}', [KategoriController::class, 'update']);
        Route::delete('/kategori/{id}', [KategoriController::class, 'destroy']);

    Route::middleware('auth:sanctum')->group(function () {
    Route::get('/profit-analytics', [ProfitController::class, 'getAnalytics']);
    Route::get('/bundling-rekomendasi', [BundlingController::class, 'getRekomendasi']);
});
});
