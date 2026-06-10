import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'home_map_controller.dart';

class HomeMapView extends GetView<HomeMapController> {
  const HomeMapView({super.key});

  // Fungsi pembantu untuk merapikan teks list dari Supabase (baik format String maupun Array)
  String _formatTypes(dynamic data) {
    if (data == null) return '-';
    if (data is List) return data.join(', ');
    return data
        .toString()
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '');
  }

  // ... (bagian atas tetap sama) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpotBan - Cari Bengkel'),
        centerTitle: true,
        elevation: 0,
        // ── FITUR BARU: Tombol Logout di Pojok Kanan Atas ──
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () {
              // Munculkan dialog konfirmasi sebelum logout
              Get.defaultDialog(
                title: "Konfirmasi Keluar",
                middleText: "Apakah Anda yakin ingin keluar dari akun?",
                textConfirm: "Ya, Keluar",
                textCancel: "Batal",
                confirmTextColor: Colors.white,
                buttonColor: Colors.red,
                cancelTextColor: Colors.black,
                onConfirm: () => controller.logout(),
              );
            },
          ),
        ],
      ),
      // ... (bagian stack peta dan sheet tetap sama) ...
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        LatLng centerMap =
            controller.userLocation.value ?? const LatLng(3.5641, 98.6565);

        return Stack(
          children: [
            // PETA UTAMA
            FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(initialCenter: centerMap, initialZoom: 14.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.spotban.app',
                ),
                PolylineLayer(
                  polylines: [
                    if (controller.routePoints.isNotEmpty)
                      Polyline(
                        points: controller.routePoints,
                        color: Colors.blueAccent,
                        strokeWidth: 5.0,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (controller.userLocation.value != null)
                      Marker(
                        point: controller.userLocation.value!,
                        width: 45,
                        height: 45,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ...controller.workshops.map((workshop) {
                      LatLng coord = controller.parseLocation(
                        workshop['location'],
                      );
                      bool isSelected =
                          controller.selectedWorkshop.value?['id'] ==
                          workshop['id'];
                      return Marker(
                        point: coord,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => controller.selectWorkshop(workshop),
                          child: Icon(
                            Icons.build_circle,
                            color: isSelected ? Colors.orange : Colors.red,
                            size: isSelected ? 45 : 35,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // PANEL GESER BAWAH
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize:
                  0.85, // Diperbesar agar muat foto dan detail panjang
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      controller.selectedWorkshop.value != null
                          ? _buildDetailWorkshopPanel()
                          : _buildListAllWorkshopsPanel(),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  // ── PANEL A: DETAIL DATA BENGKEL LENGKAP + FOTO ──────────────────────────
  // ── PANEL A: DETAIL DATA BENGKEL ──────────────────────────
  Widget _buildDetailWorkshopPanel() {
    final workshop = controller.selectedWorkshop.value!;

    // ── PERBAIKAN LOGIKA FOTO (Membaca Tabel Relasi) ──
    String imageUrl = "";

    // Cek apakah Supabase mengirimkan array workshop_photos dan isinya tidak kosong
    if (workshop['workshop_photos'] != null &&
        (workshop['workshop_photos'] as List).isNotEmpty) {
      List photos = workshop['workshop_photos'];

      // Cari foto utama (is_primary == true). Jika tidak ada, ambil foto pertama di list.
      var primaryPhoto = photos.firstWhere(
        (p) => p['is_primary'] == true,
        orElse: () => photos.first,
      );

      String? photoData = primaryPhoto['photo_url'];

      if (photoData != null && photoData.startsWith('http')) {
        imageUrl = photoData;
      } else if (photoData != null && photoData.isNotEmpty) {
        imageUrl =
            "https://gfqqtpmdwchjfteyjask.supabase.co/storage/v1/object/public/workshops/$photoData";
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                workshop['name'] ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.grey),
              onPressed: () => controller.clearSelection(),
            ),
          ],
        ),

        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                // ── FITUR BARU: Menampilkan Jarak di sebelah alamat ──
                "${controller.getDistanceString(workshop)} • ${workshop['address'] ?? ''}",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // TAMPILAN FOTO
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl.isEmpty
              ? Container(
                  width: double.infinity,
                  height: 160,
                  color: Colors.grey[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store, color: Colors.grey[400], size: 40),
                      const SizedBox(height: 4),
                      Text(
                        "Foto belum diunggah",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 160,
                      color: Colors.grey[100],
                      child: const Center(
                        child: Text(
                          "Gagal memuat foto",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),

        // Estimasi Harga Mulai
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Estimasi Biaya Mulai",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            Text(
              "Rp ${workshop['price_start'] ?? '0'}",
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // Deskripsi Lengkap
        const Text(
          "Deskripsi / Keterangan:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          workshop['description'] ??
              'Tidak ada deskripsi penjelasan mengenai bengkel ini.',
          style: const TextStyle(color: Colors.black87, height: 1.3),
        ),
        const SizedBox(height: 16),

        // Jenis Kendaraan yang Dilayani
        const Text(
          "Tipe Kendaraan:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: _formatTypes(workshop['vehicle_types']).split(',').map((
            type,
          ) {
            return Chip(
              backgroundColor: Colors.blue[50],
              label: Text(
                type.trim(),
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Jenis Layanan Tambal Ban / Servis
        const Text(
          "Jenis Layanan Tersedia:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _formatTypes(workshop['service_types']).split(',').map((
            service,
          ) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Text(
                service.trim(),
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── PANEL B: LIST ALL WORKSHOPS + RE-ORDER SORTING ───────────────────────
  Widget _buildListAllWorkshopsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Eksplorasi Bengkel Desa Lama",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),

        // Pilihan Fitur Sorting (Sudah Diperbaiki Logikanya)
        Row(
          children: [
            const Text(
              "Urutkan:",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              avatar: const Icon(Icons.location_on_outlined, size: 16),
              label: const Text("Terdekat"),
              selected: controller.sortBy.value == 'terdekat',
              selectedColor: Colors.blue[100],
              onSelected: (selected) {
                if (selected) controller.changeSortType('terdekat');
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.monetization_on_outlined, size: 16),
              label: const Text("Termurah"),
              selected: controller.sortBy.value == 'termurah',
              selectedColor: Colors.blue[100],
              onSelected: (selected) {
                if (selected) controller.changeSortType('termurah');
              },
            ),
          ],
        ),
        const Divider(height: 24),

        // List Item Bengkel
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.workshops.length,
          itemBuilder: (context, index) {
            final workshop = controller.workshops[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.blue),
                ),
                title: Text(
                  workshop['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    // ── FITUR BARU: Menampilkan Jarak di List Bengkel ──
                    "Jarak: ${controller.getDistanceString(workshop)} • Mulai Rp ${workshop['price_start']}\nLayanan: ${_formatTypes(workshop['vehicle_types'])}",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: () => controller.selectWorkshop(workshop),
              ),
            );
          },
        ),
      ],
    );
  }
}
