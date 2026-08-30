<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaksi;
use App\Models\DetailTransaksi;
use App\Models\Produk;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class LaporanController extends Controller
{
    // GET /api/laporan/penjualan
    public function getPenjualan(Request $request)
    {
        $user = $request->user();
        $periode = $request->get('periode', 'harian');
        $tanggal = $request->get('tanggal', now()->toDateString());

        $data = match ($periode) {
            'harian' => $this->getPenjualanHarian($user->penjual_id, $tanggal),
            'mingguan' => $this->getPenjualanMingguan($user->penjual_id, $tanggal),
            'bulanan' => $this->getPenjualanBulanan($user->penjual_id, $tanggal),
            default => $this->getPenjualanHarian($user->penjual_id, $tanggal),
        };

        return response()->json([
            'success' => true,
            'data' => $data
        ]);
    }

    // GET /api/laporan/penjualan/tahunan
    public function getPenjualanTahunan(Request $request)
    {
        $user = $request->user();
        $tahun = $request->get('tahun', now()->year);

        return response()->json([
            'success' => true,
            'data' => $this->getPenjualanTahunanData($user->penjual_id, $tahun)
        ]);
    }

    // GET /api/laporan/produk-terlaris
    public function getProdukTerlaris(Request $request)
    {
        $user = $request->user();
        $periode = $request->get('periode', 'harian');
        $tanggal = $request->get('tanggal', now()->toDateString());

        $query = DetailTransaksi::query()
            ->join('transaksi', 'detail_transaksi.transaksi_id', '=', 'transaksi.transaksi_id')
            ->join('produk', 'detail_transaksi.produk_id', '=', 'produk.produk_id')
            ->leftJoin('gambar_produk', function ($join) {
                $join->on('produk.produk_id', '=', 'gambar_produk.produk_id')
                    ->where('gambar_produk.urutan', 0);
            })
            ->where('transaksi.penjual_id', $user->penjual_id)
            ->where('transaksi.status', 'selesai');

        // Filter berdasarkan periode
        $date = Carbon::parse($tanggal);
        switch ($periode) {
            case 'harian':
                $query->whereDate('transaksi.tanggal_transaksi', $date);
                break;
            case 'mingguan':
                $startOfWeek = $date->copy()->startOfWeek(Carbon::MONDAY);
                $endOfWeek = $date->copy()->endOfWeek(Carbon::SUNDAY);
                $query->whereBetween('transaksi.tanggal_transaksi', [$startOfWeek, $endOfWeek]);
                break;
            case 'bulanan':
                $query->whereYear('transaksi.tanggal_transaksi', $date->year)
                      ->whereMonth('transaksi.tanggal_transaksi', $date->month);
                break;
        }

        $produkTerlaris = $query
            ->select(
                'produk.produk_id',
                'produk.nama_produk',
                'produk.harga',
                DB::raw('SUM(detail_transaksi.jumlah) as total_terjual'),
                DB::raw('SUM(detail_transaksi.jumlah * detail_transaksi.harga_saat_transaksi) as total_penjualan'),
                'gambar_produk.gambar as gambar'
            )
            ->groupBy('produk.produk_id', 'produk.nama_produk', 'produk.harga', 'gambar_produk.gambar')
            ->orderBy('total_terjual', 'desc')
            ->limit(3)
            ->get();

        // Konversi ke tipe data konsisten (int)
        $produkTerlaris = $produkTerlaris->map(function($item) {
            return [
                'produk_id' => (int) $item->produk_id,
                'nama_produk' => $item->nama_produk,
                'harga' => (int) $item->harga,
                'total_terjual' => (int) $item->total_terjual,
                'total_penjualan' => (int) $item->total_penjualan,
                'gambar' => $item->gambar,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $produkTerlaris
        ]);
    }

    // GET /api/laporan/produk-terlaris/tahunan
    public function getProdukTerlarisTahunan(Request $request)
    {
        $user = $request->user();
        $tahun = $request->get('tahun', now()->year);

        $query = DetailTransaksi::query()
            ->join('transaksi', 'detail_transaksi.transaksi_id', '=', 'transaksi.transaksi_id')
            ->join('produk', 'detail_transaksi.produk_id', '=', 'produk.produk_id')
            ->leftJoin('gambar_produk', function ($join) {
                $join->on('produk.produk_id', '=', 'gambar_produk.produk_id')
                    ->where('gambar_produk.urutan', 0);
            })
            ->where('transaksi.penjual_id', $user->penjual_id)
            ->where('transaksi.status', 'selesai')
            ->whereYear('transaksi.tanggal_transaksi', $tahun);

        $produkTerlaris = $query
            ->select(
                'produk.produk_id',
                'produk.nama_produk',
                'produk.harga',
                DB::raw('SUM(detail_transaksi.jumlah) as total_terjual'),
                DB::raw('SUM(detail_transaksi.jumlah * detail_transaksi.harga_saat_transaksi) as total_penjualan'),
                'gambar_produk.gambar as gambar'
            )
            ->groupBy('produk.produk_id', 'produk.nama_produk', 'produk.harga', 'gambar_produk.gambar')
            ->orderBy('total_terjual', 'desc')
            ->limit(3)
            ->get();

        $produkTerlaris = $produkTerlaris->map(function($item) {
            return [
                'produk_id' => (int) $item->produk_id,
                'nama_produk' => $item->nama_produk,
                'harga' => (int) $item->harga,
                'total_terjual' => (int) $item->total_terjual,
                'total_penjualan' => (int) $item->total_penjualan,
                'gambar' => $item->gambar,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $produkTerlaris
        ]);
    }

    // GET /api/laporan/dead-stock
    public function getDeadStock(Request $request)
    {
        $user = $request->user();
        $periode = $request->get('periode', 'bulanan');
        $tanggal = $request->get('tanggal', now()->toDateString());
        $limit = (int) $request->get('limit', 20);

        $date = Carbon::parse($tanggal);
        $startDate = $this->getStartDate($periode, $date);
        $endDate = $this->getEndDate($periode, $date);

        // 1. Ambil semua produk penjual
        $allProduk = Produk::where('penjual_id', $user->penjual_id)
            ->with('kategori', 'gambarProduk')
            ->get();

        // 2. Ambil ID produk yang terjual dalam periode
        $terjualIds = DetailTransaksi::query()
            ->join('transaksi', 'detail_transaksi.transaksi_id', '=', 'transaksi.transaksi_id')
            ->where('transaksi.penjual_id', $user->penjual_id)
            ->where('transaksi.status', 'selesai')
            ->whereBetween('transaksi.tanggal_transaksi', [$startDate, $endDate])
            ->distinct('produk_id')
            ->pluck('produk_id')
            ->toArray();

        // 3. Filter: produk yang TIDAK terjual
        $deadStock = $allProduk->filter(function ($produk) use ($terjualIds) {
            return !in_array($produk->produk_id, $terjualIds);
        });

        // 4. Format data
        $data = $deadStock->map(function ($produk) {
            $ukuranStok = $this->parseUkuranStok($produk->ukuran_stok);
            $totalStok = $this->getTotalStok($ukuranStok, $produk->stok);
            $daysSinceLastSale = $produk->updated_at
                ? (int) Carbon::parse($produk->updated_at)->diffInDays(now())
                : 999;

            // Rekomendasi berdasarkan durasi
            if ($daysSinceLastSale > 60) {
                $rekomendasi = '🔴 Diskon besar atau bundling dengan produk lain';
            } elseif ($daysSinceLastSale > 30) {
                $rekomendasi = '🟡 Promosi atau bundling dengan produk laris';
            } elseif ($daysSinceLastSale > 14) {
                $rekomendasi = '🟢 Perhatikan tren, mungkin perlu evaluasi';
            } else {
                $rekomendasi = '✅ Masih dalam periode wajar';
            }

            return [
                'produk_id' => (int) $produk->produk_id,
                'nama_produk' => $produk->nama_produk,
                'harga' => (int) $produk->harga,
                'stok_saat_ini' => $totalStok,
                'min_stok' => (int) ($produk->min_stok ?? 10),
                'ukuran_stok' => $ukuranStok,
                'gambar' => $produk->gambarProduk->isNotEmpty()
                    ? $produk->gambarProduk->first()->gambar
                    : '',
                'kategori' => $produk->kategori?->nama_kategori ?? '',
                'terakhir_terjual' => $produk->updated_at
                    ? $produk->updated_at->format('Y-m-d')
                    : 'Tidak pernah',
                'hari_tanpa_penjualan' => $daysSinceLastSale,
                'total_biaya' => $totalStok * $produk->harga,
                'rekomendasi' => $rekomendasi,
            ];
        })
        ->sortByDesc('hari_tanpa_penjualan')
        ->take($limit)
        ->values();

        return response()->json([
            'success' => true,
            'periode' => $periode,
            'start_date' => $startDate->format('Y-m-d'),
            'end_date' => $endDate->format('Y-m-d'),
            'data' => $data,
        ]);
    }

    // Helper: parse ukuran_stok JSON
    private function parseUkuranStok($ukuranStok)
    {
        if (is_string($ukuranStok)) {
            $ukuranStok = json_decode($ukuranStok, true);
        }
        return is_array($ukuranStok) ? $ukuranStok : [];
    }

    // Helper: hitung total stok dari ukuran_stok atau stok
    private function getTotalStok(array $ukuranStok, $stokGlobal)
    {
        if (!empty($ukuranStok)) {
            $total = 0;
            foreach ($ukuranStok as $uk) {
                $total += (int) ($uk['stock'] ?? 0);
            }
            return $total > 0 ? $total : (int) $stokGlobal;
        }
        return (int) $stokGlobal;
    }

    // Helper: get start date
    private function getStartDate($periode, Carbon $date)
    {
        switch ($periode) {
            case 'harian':
                return $date->copy()->startOfDay();
            case 'mingguan':
                return $date->copy()->startOfWeek(Carbon::MONDAY);
            case 'bulanan':
                return $date->copy()->startOfMonth();
            default:
                return $date->copy()->startOfMonth();
        }
    }

    // Helper: get end date
    private function getEndDate($periode, Carbon $date)
    {
        switch ($periode) {
            case 'harian':
                return $date->copy()->endOfDay();
            case 'mingguan':
                return $date->copy()->endOfWeek(Carbon::SUNDAY);
            case 'bulanan':
                return $date->copy()->endOfMonth();
            default:
                return $date->copy()->endOfMonth();
        }
    }

    private function getPeriodeLabel($periode, $days)
    {
        switch ($periode) {
            case 'harian':
                return 'Hari Ini';
            case 'mingguan':
                return 'Minggu Ini (7 hari)';
            case 'bulanan':
                return 'Bulan Ini (' . $days . ' hari)';
            default:
                return 'Periode';
        }
    }

    public function getFastMovingSku(Request $request)
    {
        $user = $request->user();
        $periode = $request->get('periode', 'bulanan');
        $tanggal = $request->get('tanggal', now()->toDateString());
        $limit = (int) $request->get('limit', 15); 
        $threshold = (int) $request->get('threshold', 2);
        
        $date = Carbon::parse($tanggal);
        $startDate = $this->getStartDate($periode, $date);
        $endDate = $this->getEndDate($periode, $date);
        $days = $startDate->diffInDays($endDate) + 1;

        $query = DetailTransaksi::query()
        ->join('transaksi', 'detail_transaksi.transaksi_id', '=', 'transaksi.transaksi_id')
        ->join('produk', 'detail_transaksi.produk_id', '=', 'produk.produk_id')
        ->leftJoin('gambar_produk', function ($join) {
            $join->on('produk.produk_id', '=', 'gambar_produk.produk_id')
                ->where('gambar_produk.urutan', 0);
            })
                ->where('transaksi.penjual_id', $user->penjual_id)
                ->where('transaksi.status', 'selesai')
                ->whereBetween('transaksi.tanggal_transaksi', [$startDate, $endDate]);
                
                $results = $query
                ->select(
                    'produk.produk_id',
                    'produk.nama_produk',
                    'produk.harga',
                    'produk.stok',
                    'produk.min_stok',
                    'produk.ukuran_stok',
                    'gambar_produk.gambar as gambar',
                    DB::raw('SUM(detail_transaksi.jumlah) as total_terjual'),
                    DB::raw('COUNT(DISTINCT transaksi.transaksi_id) as jumlah_transaksi'),
                    DB::raw('SUM(detail_transaksi.jumlah) / ' . $days . ' as rata_per_hari')
                )
                
                ->groupBy(
                    'produk.produk_id',
                    'produk.nama_produk',
                    'produk.harga',
                    'produk.stok',
                    'produk.min_stok',
                    'produk.ukuran_stok',
                    'gambar_produk.gambar'
                )
                
                ->having('rata_per_hari', '>=', $threshold)
                ->orderBy('rata_per_hari', 'desc')
                ->limit($limit)
                ->get();

    $data = $results->map(function ($item) use ($days, $periode) {
        $ukuranStok = $this->parseUkuranStok($item->ukuran_stok);
        $totalStok = $this->getTotalStok($ukuranStok, $item->stok);
        $rataPerHari = round($item->rata_per_hari, 2);
        $estimasiHabis = $rataPerHari > 0 ? round($totalStok / $rataPerHari) : 999;

        if ($estimasiHabis <= 3) {
            $status = 'kritis';
        } elseif ($estimasiHabis <= 7) {
            $status = 'perlu_diperhatikan';
        } elseif ($rataPerHari >= 5) {
            $status = 'fast_moving';
        } else {
            $status = 'aman';
        }

        return [
            'produk_id' => (int) $item->produk_id,
            'nama_produk' => $item->nama_produk,
            'harga' => (int) $item->harga,
            'stok_saat_ini' => $totalStok,
            'min_stok' => (int) ($item->min_stok ?? 10),
            'total_terjual' => (int) $item->total_terjual,
            'jumlah_transaksi' => (int) $item->jumlah_transaksi,
            'rata_per_hari' => $rataPerHari,
            'estimasi_habis' => $estimasiHabis,
            'status' => $status,
            'ukuran_stok' => $ukuranStok,
            'gambar' => $item->gambar,
            'rekomendasi_restock' => max(0, (int) round(($rataPerHari * 7) - $totalStok)),
            'periode_label' => $this->getPeriodeLabel($periode, $days),
        ];
    });

    return response()->json([
        'success' => true,
        'periode' => $periode,
        'start_date' => $startDate->format('Y-m-d'),
        'end_date' => $endDate->format('Y-m-d'),
        'days' => $days,
        'data' => $data,
    ]);
}

    private function getPenjualanHarian($penjualId, $tanggal)
    {
        $date = Carbon::parse($tanggal);
        
        $transaksi = Transaksi::where('penjual_id', $penjualId)
            ->where('status', 'selesai')
            ->whereDate('tanggal_transaksi', $date)
            ->get();

        $totalPenjualan = (int) $transaksi->sum('total');
        $jumlahTransaksi = $transaksi->count();

        $labels = [];
        $values = [];
        $transactionCounts = [];

        for ($i = 7; $i <= 23; $i++) {
            $labels[] = $i . ':00';
            $values[] = 0;
            $transactionCounts[] = 0;
        }

        foreach ($transaksi as $t) {
            $jam = Carbon::parse($t->tanggal_transaksi)->hour;
            if ($jam >= 7 && $jam <= 23) {
                $index = $jam - 7;
                $values[$index] += (int) $t->total;
                $transactionCounts[$index] += 1;
            }
        }

        $maxValue = max($values) > 0 ? max($values) : 1;
        $normalizedValues = array_map(function($v) use ($maxValue) {
            return (int) round(($v / $maxValue) * 100);
        }, $values);

        return [
            'periode' => 'harian',
            'tanggal' => $date->format('Y-m-d'),
            'total_penjualan' => $totalPenjualan,
            'jumlah_transaksi' => $jumlahTransaksi,
            'labels' => $labels,
            'values' => $values,
            'normalized_values' => $normalizedValues,
            'transaction_counts' => $transactionCounts,
        ];
    }

    private function getPenjualanMingguan($penjualId, $tanggal)
    {
        $date = Carbon::parse($tanggal);
        $startOfWeek = $date->copy()->startOfWeek(Carbon::MONDAY);
        $endOfWeek = $date->copy()->endOfWeek(Carbon::SUNDAY);

        $transaksi = Transaksi::where('penjual_id', $penjualId)
            ->where('status', 'selesai')
            ->whereBetween('tanggal_transaksi', [$startOfWeek, $endOfWeek])
            ->get();

        $totalPenjualan = (int) $transaksi->sum('total');
        $jumlahTransaksi = $transaksi->count();

        $hariIndonesia = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
        $labels = [];
        $values = [];
        $transactionCounts = [];

        for ($i = 0; $i < 7; $i++) {
            $hari = $startOfWeek->copy()->addDays($i);
            $labels[] = $hariIndonesia[$i];
            $values[$i] = 0;
            $transactionCounts[$i] = 0;
        }

        foreach ($transaksi as $t) {
            $tgl = Carbon::parse($t->tanggal_transaksi);
            $dayOfWeek = $tgl->dayOfWeekIso;
            $index = $dayOfWeek - 1;
            if ($index >= 0 && $index < 7) {
                $values[$index] += (int) $t->total;
                $transactionCounts[$index] += 1;
            }
        }

        $maxValue = max($values) > 0 ? max($values) : 1;
        $normalizedValues = array_map(function($v) use ($maxValue) {
            return (int) round(($v / $maxValue) * 100);
        }, $values);

        return [
            'periode' => 'mingguan',
            'start_date' => $startOfWeek->format('Y-m-d'),
            'end_date' => $endOfWeek->format('Y-m-d'),
            'total_penjualan' => $totalPenjualan,
            'jumlah_transaksi' => $jumlahTransaksi,
            'labels' => $labels,
            'values' => $values,
            'normalized_values' => $normalizedValues,
            'transaction_counts' => $transactionCounts,
        ];
    }

    private function getPenjualanBulanan($penjualId, $tanggal)
    {
        $date = Carbon::parse($tanggal);
        $year = $date->year;
        $month = $date->month;
        
        $labels = [];
        $values = [];
        $transactionCounts = [];

        $daysInMonth = $date->daysInMonth;
        
        for ($day = 1; $day <= $daysInMonth; $day++) {
            $labels[] = $day;
            $values[$day] = 0;
            $transactionCounts[$day] = 0;
        }

        $transaksi = Transaksi::where('penjual_id', $penjualId)
            ->where('status', 'selesai')
            ->whereYear('tanggal_transaksi', $year)
            ->whereMonth('tanggal_transaksi', $month)
            ->get();

        foreach ($transaksi as $t) {
            $day = (int) Carbon::parse($t->tanggal_transaksi)->format('d');
            if (isset($values[$day])) {
                $values[$day] += (int) $t->total;
                $transactionCounts[$day] += 1;
            }
        }

        $totalPenjualan = (int) $transaksi->sum('total');
        $jumlahTransaksi = $transaksi->count();

        $valuesArray = array_values($values);
        $transactionCountsArray = array_values($transactionCounts);
        $maxValue = max($valuesArray) > 0 ? max($valuesArray) : 1;
        $normalizedValues = array_map(function($v) use ($maxValue) {
            return (int) round(($v / $maxValue) * 100);
        }, $valuesArray);

        $bulanIndonesia = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

        return [
            'periode' => 'bulanan',
            'tahun' => $year,
            'bulan' => $bulanIndonesia[$month - 1] . ' ' . $year,
            'total_penjualan' => $totalPenjualan,
            'jumlah_transaksi' => $jumlahTransaksi,
            'labels' => $labels,
            'values' => $valuesArray,
            'normalized_values' => $normalizedValues,
            'transaction_counts' => $transactionCountsArray,
        ];
    }

    private function getPenjualanTahunanData($penjualId, $tahun)
    {
        $bulanIndonesia = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        $labels = [];
        $values = [];
        $transactionCounts = [];

        for ($month = 1; $month <= 12; $month++) {
            $labels[] = $bulanIndonesia[$month - 1];
            
            $total = Transaksi::where('penjual_id', $penjualId)
                ->where('status', 'selesai')
                ->whereYear('tanggal_transaksi', $tahun)
                ->whereMonth('tanggal_transaksi', $month)
                ->sum('total');
            
            $count = Transaksi::where('penjual_id', $penjualId)
                ->where('status', 'selesai')
                ->whereYear('tanggal_transaksi', $tahun)
                ->whereMonth('tanggal_transaksi', $month)
                ->count();

            $values[] = (int) $total;
            $transactionCounts[] = $count;
        }

        $totalPenjualan = array_sum($values);
        $jumlahTransaksi = array_sum($transactionCounts);

        $maxValue = max($values) > 0 ? max($values) : 1;
        $normalizedValues = array_map(function($v) use ($maxValue) {
            return (int) round(($v / $maxValue) * 100);
        }, $values);

        return [
            'periode' => 'tahunan',
            'tahun' => $tahun,
            'total_penjualan' => $totalPenjualan,
            'jumlah_transaksi' => $jumlahTransaksi,
            'labels' => $labels,
            'values' => $values,
            'normalized_values' => $normalizedValues,
            'transaction_counts' => $transactionCounts,
        ];
    }
}
