<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProfitController extends Controller
{
    public function getAnalytics(Request $request)
    {
        $user = $request->user();

        // 1. Ambil semua produk milik penjual ini
        $produk = DB::table('produk')
            ->where('penjual_id', $user->penjual_id)
            ->get();

        $hasilAnalisis = [];

        foreach ($produk as $p) {
            // 2. Hitung total terjual dari tabel detail_transaksi
            // (Gunakan status 'selesai' agar transaksi batal tidak dihitung)
            $totalTerjual = DB::table('detail_transaksi')
                ->join('transaksi', 'detail_transaksi.transaksi_id', '=', 'transaksi.transaksi_id')
                ->where('detail_transaksi.produk_id', $p->produk_id)
                ->where('transaksi.status', 'selesai')
                ->sum('detail_transaksi.jumlah');

            // 3. Hitung Margin Kontribusi & Total Profit
            $hargaJual = (float) $p->harga;
            $hargaBeli = (float) $p->harga_beli;
            
            $marginKontribusi = $hargaJual - $hargaBeli;
            $totalProfit = $marginKontribusi * $totalTerjual;

            // Masukkan ke array hasil (hanya yang pernah terjual atau punya margin)
            if ($totalTerjual > 0) {
                $hasilAnalisis[] = [
                    'produk_id' => $p->produk_id,
                    'nama_produk' => $p->nama_produk,
                    'harga_jual' => $hargaJual,
                    'harga_beli' => $hargaBeli,
                    'margin_kontribusi' => $marginKontribusi,
                    'total_terjual' => (int) $totalTerjual,
                    'total_profit' => $totalProfit,
                ];
            }
        }

        // 4. Urutkan berdasarkan Total Profit tertinggi ke terendah
        usort($hasilAnalisis, function($a, $b) {
            return $b['total_profit'] <=> $a['total_profit'];
        });

        return response()->json([
            'success' => true,
            'message' => 'Data profit analytics berhasil diambil',
            'data' => $hasilAnalisis
        ], 200);
    }
}