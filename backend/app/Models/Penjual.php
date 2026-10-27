<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens; 

class Penjual extends Authenticatable
{
    use HasFactory, HasApiTokens; 

    protected $table = 'penjual';
    protected $primaryKey = 'penjual_id';
    
    protected $fillable = [
        'nama',
        'email',
        'kata_sandi',
        'no_telepon',
        'nama_toko',
        'fcm_token',
    ];

    protected $hidden = [
        'kata_sandi',
    ];

    public function getAuthPassword()
    {
        return $this->kata_sandi;
    }

    public function notifikasi()
    {
        return $this->hasMany(Notifikasi::class, 'penjual_id', 'penjual_id');
    }

    public function produk()
    {
        return $this->hasMany(Produk::class, 'penjual_id', 'penjual_id');
    }
}