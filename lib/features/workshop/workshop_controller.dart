import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../dashboard/dashboard_controller.dart';

class WorkshopController extends GetxController {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  static const _bucket = 'workshop-photos';

  // ── Text Controllers ──────────────────────────────────────────────────────
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final locationSearchCtrl = TextEditingController();

  // ── Observable State ──────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isLocating = false.obs;
  final isSearchingLocation = false.obs;
  final selectedImages = <XFile>[].obs;
  final existingPhotoUrls = <String>[].obs;
  final selectedLocation = Rxn<LatLng>();
  final locationSearchResults = <NominatimResult>[].obs;

  // ── Tipe Kendaraan (Truk dihapus) ─────────────────────────────────────────
  final vehicleTypes = <String, bool>{'Motor': false, 'Mobil': false}.obs;

  // ── Jenis Layanan (relevan Motor & Mobil) ─────────────────────────────────
  final serviceTypes = <String, bool>{
    'Tambal Ban': false,
    'Ganti Ban': false,
    'Spooring & Balancing': false,
    'Ganti Oli Mesin': false,
    'Ganti Oli Transmisi': false,
    'Tune Up & Servis Rutin': false,
    'Servis Rem': false,
    'Servis Kelistrikan': false,
    'Servis AC (Mobil)': false,
    'Ganti Aki': false,
    'Cuci Motor': false,
    'Cuci Mobil': false,
    'Body Repair & Cat': false,
    'Onderstel & Kaki-kaki': false,
  }.obs;

  final _removedPhotoUrls = <String>[];
  Workshop? editingWorkshop;
  bool get isEditMode => editingWorkshop != null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is Workshop) {
      editingWorkshop = Get.arguments as Workshop;
      _applyEditData();
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    addressCtrl.dispose();
    priceCtrl.dispose();
    locationSearchCtrl.dispose();
    super.onClose();
  }

  void _applyEditData() {
    final w = editingWorkshop!;
    nameCtrl.text = w.name;
    descCtrl.text = w.description ?? '';
    addressCtrl.text = w.address;
    priceCtrl.text = (w.priceStart ?? 0).toString();
    if (w.latitude != null && w.longitude != null) {
      selectedLocation.value = LatLng(w.latitude!, w.longitude!);
    }
    for (final t in (w.vehicleTypes ?? <String>[])) {
      if (vehicleTypes.containsKey(t)) vehicleTypes[t] = true;
    }
    for (final s in (w.serviceTypes ?? <String>[])) {
      if (serviceTypes.containsKey(s)) serviceTypes[s] = true;
    }
    _fetchExistingPhotos(w.id);
  }

  Future<void> _fetchExistingPhotos(String workshopId) async {
    try {
      final rows = await _supabase
          .from('workshop_photos')
          .select('photo_url')
          .eq('workshop_id', workshopId)
          .order('is_primary', ascending: false);
      existingPhotoUrls.value = (rows as List)
          .map((r) => r['photo_url'] as String)
          .toList();
    } catch (_) {}
  }

  // ── GPS: Ambil Lokasi Pengguna Sekarang ───────────────────────────────────
  Future<void> useCurrentLocation() async {
    isLocating.value = true;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Izin Lokasi Ditolak',
          'Aktifkan izin lokasi di pengaturan perangkat.',
          icon: const Icon(Icons.location_off, color: Colors.white),
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      selectedLocation.value = LatLng(pos.latitude, pos.longitude);
      locationSearchResults.clear();
      locationSearchCtrl.clear();
      Get.snackbar(
        'Lokasi Ditemukan',
        '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
        icon: const Icon(Icons.my_location, color: Colors.white),
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('Gagal Mendapat Lokasi', '$e');
    } finally {
      isLocating.value = false;
    }
  }

  // ── Nominatim Geocoding (OpenStreetMap, gratis tanpa API key) ─────────────
  Future<void> searchLocation(String query) async {
    if (query.trim().length < 3) {
      locationSearchResults.clear();
      return;
    }
    isSearchingLocation.value = true;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&addressdetails=1&limit=7&accept-language=id',
      );
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set(
        'User-Agent',
        'SpotBanAdmin/1.0 (spotban@example.com)',
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final List<dynamic> data = jsonDecode(body) as List<dynamic>;
      locationSearchResults.value = data
          .map((item) => NominatimResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      locationSearchResults.clear();
    } finally {
      isSearchingLocation.value = false;
    }
  }

  void selectSearchResult(NominatimResult result) {
    selectedLocation.value = LatLng(result.lat, result.lon);
    locationSearchCtrl.text = result.shortName;
    locationSearchResults.clear();
  }

  // ── Image Picker ──────────────────────────────────────────────────────────
  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 75);
    if (picked.isNotEmpty) selectedImages.addAll(picked);
  }

  void removeNewImage(int index) => selectedImages.removeAt(index);
  void removeExistingPhoto(String url) {
    existingPhotoUrls.remove(url);
    _removedPhotoUrls.add(url);
  }

  // ── Storage ───────────────────────────────────────────────────────────────
  Future<String> _uploadImage(XFile xFile, String workshopId) async {
    final file = File(xFile.path);
    final ext = xFile.path.split('.').last;
    final storagePath = '$workshopId/${const Uuid().v4()}.$ext';
    await _supabase.storage
        .from(_bucket)
        .upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
    return _supabase.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<void> _commitRemovedPhotos() async {
    for (final url in _removedPhotoUrls) {
      try {
        await _supabase.from('workshop_photos').delete().eq('photo_url', url);
        final uri = Uri.parse(url);
        final segs = uri.pathSegments;
        final idx = segs.indexOf(_bucket);
        if (idx != -1 && idx < segs.length - 1) {
          await _supabase.storage.from(_bucket).remove([
            segs.sublist(idx + 1).join('/'),
          ]);
        }
      } catch (_) {}
    }
    _removedPhotoUrls.clear();
  }

  Future<String> _insertWorkshopRpc() async {
    final result = await _supabase.rpc(
      'insert_workshop',
      params: {
        'p_name': nameCtrl.text.trim(),
        'p_description': descCtrl.text.trim(),
        'p_address': addressCtrl.text.trim(),
        'p_price_start': int.tryParse(priceCtrl.text.trim()) ?? 0,
        'p_vehicle_types': _selectedKeys(vehicleTypes),
        'p_service_types': _selectedKeys(serviceTypes),
        'p_longitude': selectedLocation.value!.longitude,
        'p_latitude': selectedLocation.value!.latitude,
        'p_created_by': _supabase.auth.currentUser!.id,
      },
    );
    return result as String;
  }

  Future<void> _updateWorkshopDirect() async {
    await _supabase
        .from('workshops')
        .update({
          'name': nameCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'address': addressCtrl.text.trim(),
          'price_start': int.tryParse(priceCtrl.text.trim()) ?? 0,
          'vehicle_types': _selectedKeys(vehicleTypes),
          'service_types': _selectedKeys(serviceTypes),
          'latitude': selectedLocation.value!.latitude,
          'longitude': selectedLocation.value!.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', editingWorkshop!.id);
  }

  Future<void> _insertPhotoRecords(String workshopId, List<String> urls) async {
    final existing = existingPhotoUrls.length;
    await _supabase
        .from('workshop_photos')
        .insert(
          urls
              .asMap()
              .entries
              .map(
                (e) => {
                  'workshop_id': workshopId,
                  'photo_url': e.value,
                  'is_primary': existing == 0 && e.key == 0,
                },
              )
              .toList(),
        );
  }

  Future<void> submitWorkshop() async {
    if (selectedLocation.value == null) {
      Get.snackbar(
        'Lokasi Belum Dipilih',
        'Gunakan tombol GPS atau cari nama jalan di atas peta.',
        icon: const Icon(Icons.location_off, color: Colors.white),
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
      );
      return;
    }
    isLoading.value = true;
    try {
      String workshopId;
      if (isEditMode) {
        workshopId = editingWorkshop!.id;
        await Future.wait([_updateWorkshopDirect(), _commitRemovedPhotos()]);
      } else {
        workshopId = await _insertWorkshopRpc();
      }
      if (selectedImages.isNotEmpty) {
        final urls = await Future.wait(
          selectedImages.map((img) => _uploadImage(img, workshopId)),
        );
        await _insertPhotoRecords(workshopId, urls);
      }
      Get.snackbar(
        'Berhasil! 🎉',
        isEditMode
            ? 'Data "${nameCtrl.text}" berhasil diperbarui'
            : '"${nameCtrl.text}" berhasil ditambahkan',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      Get.back(result: true);
    } on PostgrestException catch (e) {
      Get.snackbar('Database Error', e.message);
    } on StorageException catch (e) {
      Get.snackbar('Upload Gagal', e.message);
    } catch (e) {
      Get.snackbar('Error', '$e');
    } finally {
      isLoading.value = false;
    }
  }

  void toggleVehicle(String key) =>
      vehicleTypes[key] = !(vehicleTypes[key] ?? false);
  void toggleService(String key) =>
      serviceTypes[key] = !(serviceTypes[key] ?? false);
  List<String> _selectedKeys(Map<String, bool> map) =>
      map.entries.where((e) => e.value).map((e) => e.key).toList();
}

// ── Model Hasil Nominatim ─────────────────────────────────────────────────────
class NominatimResult {
  final String displayName;
  final String shortName;
  final double lat;
  final double lon;

  const NominatimResult({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });

  factory NominatimResult.fromJson(Map<String, dynamic> json) {
    final name = json['display_name'] as String? ?? '';
    final short = name.split(',').first.trim();
    return NominatimResult(
      displayName: name,
      shortName: short,
      lat: double.tryParse(json['lat'] as String? ?? '0') ?? 0,
      lon: double.tryParse(json['lon'] as String? ?? '0') ?? 0,
    );
  }
}
