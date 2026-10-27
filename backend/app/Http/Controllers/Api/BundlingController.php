<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BundlingController extends Controller
{
    public function getRekomendasi(Request $request)
    {
        // 1. Ambil parameter (default: support 10%, confidence 50%)
        $minSupport = $request->query('min_support', 0.1); 
        $minConfidence = $request->query('min_confidence', 0.5);

        // 2. Ambil semua transaksi beserta produk yang dibeli
        $transaksi = DB::table('detail_transaksi')
            ->join('transaksi', 'detail_transaksi.transaksi_id', '=', 'transaksi.transaksi_id')
            ->join('produk', 'detail_transaksi.produk_id', '=', 'produk.produk_id')
            ->select('detail_transaksi.transaksi_id', 'produk.nama_produk')
            ->where('transaksi.status', 'selesai') // Hanya hitung transaksi sukses
            ->get();

        $totalTransaksi = $transaksi->unique('transaksi_id')->count();

        if ($totalTransaksi == 0) {
            return response()->json(['success' => true, 'data' => [], 'message' => 'Belum ada data transaksi']);
        }

        // 3. Bentuk format array: [transaksi_id => [Produk A, Produk B, ...]]
        $itemset = [];
        foreach ($transaksi as $t) {
            $itemset[$t->transaksi_id][] = $t->nama_produk;
        }

        // Hilangkan duplikat produk dalam 1 transaksi (jika ada)
        foreach ($itemset as $id => $items) {
            $itemset[$id] = array_unique($items);
        }

        // 4. Hitung Kemunculan per Produk (1-Itemset)
        $supportCount = [];
        foreach ($itemset as $items) {
            foreach ($items as $item) {
                if (!isset($supportCount[$item])) $supportCount[$item] = 0;
                $supportCount[$item]++;
            }
        }

        // 5. Bentuk pasangan (2-Itemset) dan hitung Support-nya
        $pairCount = [];
        foreach ($itemset as $items) {
            $items = array_values($items);
            $n = count($items);
            for ($i = 0; $i < $n; $i++) {
                for ($j = $i + 1; $j < $n; $j++) {
                    $pair = [$items[$i], $items[$j]];
                    sort($pair); // Urutkan agar (A,B) sama dengan (B,A)
                    $pairKey = implode(' + ', $pair);
                    
                    if (!isset($pairCount[$pairKey])) {
                        $pairCount[$pairKey] = 0;
                    }
                    $pairCount[$pairKey]++;
                }
            }
        }

        // 6. Hitung Support & Confidence, lalu filter berdasarkan parameter
        $rules = [];
        foreach ($pairCount as $pairKey => $count) {
            $support = $count / $totalTransaksi;

            // Filter Min Support
            if ($support >= $minSupport) {
                $produk = explode(' + ', $pairKey);
                $prodA = $produk[0];
                $prodB = $produk[1];

                // Arah 1: Jika beli A, maka beli B
                $confidenceAtoB = $count / $supportCount[$prodA];
                if ($confidenceAtoB >= $minConfidence) {
                    $rules[] = [
                        'jika_beli' => $prodA,
                        'maka_beli' => $prodB,
                        'support' => round($support * 100, 1),
                        'confidence' => round($confidenceAtoB * 100, 1),
                    ];
                }

                // Arah 2: Jika beli B, maka beli A
                $confidenceBtoA = $count / $supportCount[$prodB];
                if ($confidenceBtoA >= $minConfidence) {
                    $rules[] = [
                        'jika_beli' => $prodB,
                        'maka_beli' => $prodA,
                        'support' => round($support * 100, 1),
                        'confidence' => round($confidenceBtoA * 100, 1),
                    ];
                }
            }
        }

        // Urutkan berdasarkan Confidence tertinggi
        usort($rules, function($a, $b) {
            return $b['confidence'] <=> $a['confidence'];
        });

        return response()->json([
            'success' => true,
            'total_transaksi' => $totalTransaksi,
            'parameter' => [
                'min_support' => $minSupport * 100 . '%',
                'min_confidence' => $minConfidence * 100 . '%',
            ],
            'data' => $rules
        ]);
    }
}