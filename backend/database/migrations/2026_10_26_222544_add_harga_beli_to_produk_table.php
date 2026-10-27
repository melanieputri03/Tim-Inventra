<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
{
    Schema::table('produk', function (Blueprint $table) {
        // Menambahkan kolom harga_beli (HPP), ditaruh setelah kolom harga
        $table->bigInteger('harga_beli')->default(0)->after('harga');
    });
}

public function down(): void
{
    Schema::table('produk', function (Blueprint $table) {
        $table->dropColumn('harga_beli');
    });
}
};
