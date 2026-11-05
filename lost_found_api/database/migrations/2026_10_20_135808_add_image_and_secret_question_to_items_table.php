<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add image_path, contact_phone, and PostGIS point field to items table.
     * Uses PostgreSQL PostGIS extension for efficient spatial queries.
     * 
     * Fields:
     * - image_path: nullable path to stored image in storage/app/public/items
     * - contact_phone: optional contact phone for the object report
     * - location: PostGIS point geometry for spatial indexing and queries (SRID 4326 = WGS84)
     */
    public function up(): void
    {
        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'pgsql') {
            try {
                DB::statement('CREATE EXTENSION IF NOT EXISTS postgis');
            } catch (\Throwable $e) {}
        }
        
        Schema::table('items', function (Blueprint $table) {
            if (!Schema::hasColumn('items', 'image_path')) {
                $table->string('image_path')->nullable();
            }
            if (!Schema::hasColumn('items', 'contact_phone')) {
                $table->string('contact_phone')->nullable();
            }
        });

        if ($driver === 'pgsql') {
            try {
                DB::statement('ALTER TABLE items ADD COLUMN IF NOT EXISTS location geography(POINT, 4326) NULLABLE');
                DB::statement('CREATE INDEX IF NOT EXISTS items_location_idx ON items USING GIST(location)');
            } catch (\Throwable $e) {}
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'pgsql') {
            try {
                DB::statement('DROP INDEX IF EXISTS items_location_idx');
                DB::statement('ALTER TABLE items DROP COLUMN IF EXISTS location');
            } catch (\Throwable $e) {}
        }

        Schema::table('items', function (Blueprint $table) {
            if (Schema::hasColumn('items', 'image_path')) {
                $table->dropColumn('image_path');
            }
            if (Schema::hasColumn('items', 'contact_phone')) {
                $table->dropColumn('contact_phone');
            }
        });
    }
};
