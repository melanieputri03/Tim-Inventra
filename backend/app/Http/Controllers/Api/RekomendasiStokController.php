<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Produk;
use App\Models\DetailTransaksi;
use App\Models\Periode;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class RekomendasiStokController extends Controller
{
    public function index(Request $request)
    {
        $validated = $request->validate([
            'periode_id' => 'nullable|integer',
            'hari_cover' => 'nullable|integer|in:7,21,30',
            'lead_time' => 'nullable|integer|min:0|max:365',
        ]);

        $user = $request->user();
        $hariCover = (int) ($validated['hari_cover'] ?? 30);
        $leadTime = (int) ($validated['lead_time'] ?? 0);
        $periodeId = $validated['periode_id'] ?? null;

        $periode = $periodeId ? Periode::findOrFail($periodeId) : null;
        // Jika tabel periode memiliki penjual_id, batasi pencarian di atas berdasarkan pemilik.
        $multiplier = $periode ? (float) ($periode->multiplier ?? 1.0) : 1.0;
        $sisaHari = $periode ? $this->hitungSisaHari($periode->tanggal_selesai) : 0;
        $totalHari = $this->hitungTotalHari($periode, $hariCover);

        $produk = Produk::where('penjual_id', $user->penjual_id)
            ->with('gambarProduk', 'kategori')
            ->get();

        $rekomendasi = [];

        foreach ($produk as $item) {
            $totalTerjual = $this->hitungTotalTerjual($item->produk_id, $periode, $hariCover);
            $rataHari = $totalHari > 0 ? round($totalTerjual / $totalHari, 2, PHP_ROUND_HALF_UP) : 0;

            $ukuranStok = $this->normalisasiArray($item->ukuran_stok);
            $stokDalamPesanan = $item->sedang_restock
                ? $this->normalisasiJumlahPerUkuran($item->jumlah_per_ukuran)
                : [];

            $rekomendasiPerUkuran = [];
            $totalRekomendasi = 0;
            $totalSaranTambah = 0;

            if (!empty($ukuranStok)) {
                foreach ($ukuranStok as $uk) {
                    $size = (string) ($uk['size'] ?? '');
                    if ($size === '') {
                        continue;
                    }

                    $stokUkuran = (int) ($uk['stock'] ?? 0);
                    $terjualUkuran = $this->hitungTerjualPerUkuran(
                        $item->produk_id, $size, $periode, $hariCover
                    );
                    $rataUkuran = $totalHari > 0
                        ? round($terjualUkuran / $totalHari, 2, PHP_ROUND_HALF_UP)
                        : 0;

                    // Cover days + lead time (default 0 hari): kebijakan target stok yang diusulkan.
                    $kebutuhan = (int) round(
                        $rataUkuran * ($hariCover + $leadTime), 0, PHP_ROUND_HALF_UP
                    );
                    $rekomendasiUkuran = (int) round(
                        $kebutuhan * $multiplier, 0, PHP_ROUND_HALF_UP
                    );
                    $stokSedangDipesan = (int) ($stokDalamPesanan[$size] ?? 0);
                    $saranTambah = max(
                        0, $rekomendasiUkuran - $stokUkuran - $stokSedangDipesan
                    );

                    $rekomendasiPerUkuran[] = [
                        'size' => $size,
                        'stok_saat_ini' => $stokUkuran,
                        'stok_sedang_dipesan' => $stokSedangDipesan,
                        'terjual' => $terjualUkuran,
                        'rata_hari' => $rataUkuran,
                        'kebutuhan' => $kebutuhan,
                        'rekomendasi' => $rekomendasiUkuran,
                        'saran_tambah' => $saranTambah,
                    ];

                    $totalRekomendasi += $rekomendasiUkuran;
                    $totalSaranTambah += $saranTambah;
                }
            } else {
                $kebutuhan = (int) round(
                    $rataHari * ($hariCover + $leadTime), 0, PHP_ROUND_HALF_UP
                );
                $totalRekomendasi = (int) round(
                    $kebutuhan * $multiplier, 0, PHP_ROUND_HALF_UP
                );
                $stokSedangDipesan = $item->sedang_restock
                    ? (int) ($item->jumlah_dipesan ?? 0)
                    : 0;
                $totalSaranTambah = max(
                    0, $totalRekomendasi - (int) $item->stok - $stokSedangDipesan
                );
            }

            if ($item->sedang_restock) {
                $status = 'sudah_dipesan';
            } elseif ($totalSaranTambah > 0) {
                $status = 'perlu_restock';
            } elseif ((int) $item->stok <= (int) $item->min_stok) {
                $status = 'perlu_diperhatikan';
            } else {
                $status = 'cukup';
            }

            $rekomendasi[] = [
                'id' => $item->produk_id,
                'nama' => $item->nama_produk,
                'kategori' => $item->kategori?->nama_kategori ?? '',
                'badge' => $periode ? ($periode->nama_periode ?? 'Periode Khusus') : 'Normal',
                'stok' => $item->stok,
                'ukuran_stok' => $ukuranStok,
                'rataHari' => $rataHari,
                'saranTambah' => $totalSaranTambah,
                'rekomendasi_total' => $totalRekomendasi,
                'status' => $status,
                'gambar' => $item->gambarProduk->isNotEmpty()
                    ? $item->gambarProduk->first()->gambar : null,
                'jumlah_dipesan' => $item->jumlah_dipesan,
                'jumlah_per_ukuran' => $item->jumlah_per_ukuran,
                'periode_nama' => $periode?->nama_periode,
                'multiplier' => $multiplier,
                'sisa_hari' => $sisaHari,
                'hari_cover' => $hariCover,
                'lead_time' => $leadTime,
                'total_terjual' => $totalTerjual,
                'rekomendasi_per_ukuran' => $rekomendasiPerUkuran,
            ];
        }

        usort($rekomendasi, function ($a, $b) {
            $prioritas = [
                'perlu_restock' => 0,
                'sudah_dipesan' => 1,
                'perlu_diperhatikan' => 2,
                'cukup' => 3,
            ];
            $pa = $prioritas[$a['status']] ?? 5;
            $pb = $prioritas[$b['status']] ?? 5;
            return $pa !== $pb ? $pa - $pb : $b['saranTambah'] - $a['saranTambah'];
        });

        return response()->json([
            'success' => true,
            'data' => $rekomendasi,
            'periode' => $periode ? [
                'id' => $periode->periode_id,
                'nama' => $periode->nama_periode,
                'multiplier' => $multiplier,
                'sisa_hari' => $sisaHari,
            ] : null,
            'hari_cover' => $hariCover,
            'lead_time' => $leadTime,
        ]);
    }

    private function normalisasiArray($value): array
    {
        if (is_string($value)) {
            $value = json_decode($value, true);
        }
        return is_array($value) ? $value : [];
    }

    /** Mendukung {"M": 2} dan [{"size": "M", "jumlah": 2}]. */
    private function normalisasiJumlahPerUkuran($value): array
    {
        $raw = $this->normalisasiArray($value);
        $hasil = [];
        foreach ($raw as $key => $entry) {
            if (is_array($entry)) {
                if (!isset($entry['size'], $entry['jumlah'])) {
                    continue;
                }
                $size = (string) $entry['size'];
                $jumlah = (int) $entry['jumlah'];
            } else {
                $size = (string) $key;
                $jumlah = (int) $entry;
            }
            $hasil[$size] = ($hasil[$size] ?? 0) + $jumlah;
        }
        return $hasil;
    }

    private function hitungSisaHari($tanggalSelesai): int
    {
        $now = Carbon::today();
        $end = Carbon::parse($tanggalSelesai)->startOfDay();
        return $now->greaterThan($end) ? 0 : (int) $now->diffInDays($end);
    }

    private function hitungTotalHari($periode, int $hariCover): int
    {
        if ($periode) {
            return (int) Carbon::parse($periode->tanggal_mulai)->startOfDay()
                ->diffInDays(Carbon::parse($periode->tanggal_selesai)->startOfDay()) + 1;
        }
        return $hariCover;
    }

    /** Rentang periode: [awal tanggal mulai, awal hari setelah tanggal selesai). */
    private function batasiTanggal($query, $periode, int $hariCover): void
    {
        if ($periode) {
            $awal = Carbon::parse($periode->tanggal_mulai)->startOfDay();
            $akhirEksklusif = Carbon::parse($periode->tanggal_selesai)->addDay()->startOfDay();
            $query->where('created_at', '>=', $awal)
                ->where('created_at', '<', $akhirEksklusif);
        } else {
            $query->where('created_at', '>=', now()->subDays($hariCover));
        }
        // Bila ada status transaksi, tambahkan filter transaksi selesai di sini.
    }

    private function hitungTotalTerjual($produkId, $periode, int $hariCover): int
    {
        $query = DetailTransaksi::where('produk_id', $produkId);
        $this->batasiTanggal($query, $periode, $hariCover);
        return (int) $query->sum('jumlah');
    }

    private function hitungTerjualPerUkuran($produkId, string $size, $periode, int $hariCover): int
    {
        $query = DetailTransaksi::where('produk_id', $produkId)
            ->where('ukuran', $size);
        $this->batasiTanggal($query, $periode, $hariCover);
        return (int) $query->sum('jumlah');
    }

    // POST /rekomendasi-stok/restock
    public function restock(Request $request)
    {
        $validated = $request->validate([
            'produk_id' => 'required|exists:produk,produk_id',
            'jumlah' => 'required|integer|min:1',
            'jumlah_per_ukuran' => 'nullable|array',
        ]);

        DB::transaction(function () use ($request, $validated) {
            $produk = Produk::where('penjual_id', $request->user()->penjual_id)
                ->where('produk_id', $validated['produk_id'])
                ->lockForUpdate()
                ->firstOrFail();

            if ($produk->sedang_restock) {
                throw ValidationException::withMessages([
                    'produk_id' => 'Produk ini masih memiliki pesanan restock yang belum diterima.',
                ]);
            }

            $ukuranStok = $this->normalisasiArray($produk->ukuran_stok);
            $perUkuran = $this->normalisasiJumlahPerUkuran($validated['jumlah_per_ukuran'] ?? null);

            if (!empty($ukuranStok)) {
                $ukuranValid = array_map(fn ($uk) => (string) ($uk['size'] ?? ''), $ukuranStok);
                if (empty($perUkuran) || array_diff(array_keys($perUkuran), $ukuranValid)) {
                    throw ValidationException::withMessages([
                        'jumlah_per_ukuran' => 'Masukkan jumlah pesanan untuk ukuran yang terdaftar.',
                    ]);
                }
                if (min($perUkuran) < 0 || array_sum($perUkuran) !== (int) $validated['jumlah']) {
                    throw ValidationException::withMessages([
                        'jumlah_per_ukuran' => 'Total pesanan per ukuran harus sama dengan jumlah pesanan.',
                    ]);
                }
            } else {
                $perUkuran = [];
            }

            $produk->sedang_restock = true;
            $produk->jumlah_dipesan = (int) $validated['jumlah'];
            $produk->jumlah_per_ukuran = !empty($perUkuran) ? $perUkuran : null;
            $produk->save();
        });

        return response()->json([
            'success' => true,
            'message' => 'Restock berhasil dicatat',
        ]);
    }

    // POST /rekomendasi-stok/konfirmasi-tiba
    public function konfirmasiTiba(Request $request)
    {
        $validated = $request->validate([
            'produk_id' => 'required|exists:produk,produk_id',
            // Dipertahankan untuk kompatibilitas request Flutter yang sudah ada.
            'jumlah' => 'required|integer|min:1',
        ]);

        $hasil = DB::transaction(function () use ($request, $validated) {
            $produk = Produk::where('penjual_id', $request->user()->penjual_id)
                ->where('produk_id', $validated['produk_id'])
                ->lockForUpdate()
                ->firstOrFail();

            if (!$produk->sedang_restock) {
                throw ValidationException::withMessages([
                    'produk_id' => 'Tidak ada pesanan restock aktif untuk dikonfirmasi.',
                ]);
            }

            $jumlahTambah = (int) ($produk->jumlah_dipesan ?? 0);
            if ($jumlahTambah < 1) {
                throw ValidationException::withMessages([
                    'jumlah_dipesan' => 'Jumlah restock tersimpan tidak valid.',
                ]);
            }

            $perUkuran = $this->normalisasiJumlahPerUkuran($produk->jumlah_per_ukuran);
            $ukuranStok = $this->normalisasiArray($produk->ukuran_stok);

            if (!empty($ukuranStok)) {
                // Hindari menambah seluruh pesanan ke ukuran pertama secara keliru.
                if (empty($perUkuran) || array_sum($perUkuran) !== $jumlahTambah) {
                    throw ValidationException::withMessages([
                        'jumlah_per_ukuran' => 'Data pesanan per ukuran tidak lengkap. Periksa pesanan lama sebelum konfirmasi.',
                    ]);
                }

                $ukuranValid = array_map(fn ($uk) => (string) ($uk['size'] ?? ''), $ukuranStok);
                if (array_diff(array_keys($perUkuran), $ukuranValid)) {
                    throw ValidationException::withMessages([
                        'jumlah_per_ukuran' => 'Ada ukuran dalam pesanan yang tidak lagi terdaftar.',
                    ]);
                }

                foreach ($ukuranStok as &$uk) {
                    $size = (string) ($uk['size'] ?? '');
                    $uk['stock'] = (int) ($uk['stock'] ?? 0) + (int) ($perUkuran[$size] ?? 0);
                }
                unset($uk);

                $produk->ukuran_stok = $ukuranStok;
                $produk->stok = array_sum(array_map(
                    fn ($uk) => (int) ($uk['stock'] ?? 0), $ukuranStok
                ));
            } else {
                $produk->stok = (int) $produk->stok + $jumlahTambah;
            }

            $produk->sedang_restock = false;
            $produk->jumlah_dipesan = null;
            $produk->jumlah_per_ukuran = null;
            $produk->save();

            return [
                'stok_baru' => $produk->stok,
                'ukuran_stok' => $produk->ukuran_stok,
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Stok berhasil diperbarui',
            ...$hasil,
        ]);
    }
}
