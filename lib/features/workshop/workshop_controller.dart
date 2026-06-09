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

  // ── Observable State ──────────────────────────────────────────────────────
  final isLoading = false.obs;
  final isLocating = false.obs;
  final selectedImages = <XFile>[].obs;
  final existingPhotoUrls = <String>[].obs;
  final selectedLocation = Rxn<LatLng>();

  // ── Tipe Kendaraan ────────────────────────────────────────────────────────
  final vehicleTypes = <String, bool>{'Motor': false, 'Mobil': false}.obs;

  // ── Jenis Layanan ─────────────────────────────────────────────────────────
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
    // Gunakan RPC agar server yang menangani update kolom latitude/longitude
    // (menghindari error "can only be updated to DEFAULT" dari generated column)
    await _supabase.rpc(
      'update_workshop',
      params: {
        'p_id': editingWorkshop!.id,
        'p_name': nameCtrl.text.trim(),
        'p_description': descCtrl.text.trim(),
        'p_address': addressCtrl.text.trim(),
        'p_price_start': int.tryParse(priceCtrl.text.trim()) ?? 0,
        'p_vehicle_types': _selectedKeys(vehicleTypes),
        'p_service_types': _selectedKeys(serviceTypes),
        'p_latitude': selectedLocation.value!.latitude,
        'p_longitude': selectedLocation.value!.longitude,
      },
    );
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
        'Gunakan tombol GPS atau ketuk peta untuk memilih lokasi.',
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
