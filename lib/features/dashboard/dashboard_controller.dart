import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Workshop {
  final String id;
  final String name;
  final String? description;
  final String address;
  final int? priceStart;
  final List<String>? vehicleTypes;
  final List<String>? serviceTypes;
  final double? latitude;
  final double? longitude;

  const Workshop({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    this.priceStart,
    this.vehicleTypes,
    this.serviceTypes,
    this.latitude,
    this.longitude,
  });

  factory Workshop.fromMap(Map<String, dynamic> map) => Workshop(
    id: map['id'] as String,
    name: map['name'] as String,
    address: map['address'] as String,
    description: map['description'] as String?,
    priceStart: map['price_start'] as int?,
    vehicleTypes: (map['vehicle_types'] as List?)
        ?.map((e) => e.toString())
        .toList(),
    serviceTypes: (map['service_types'] as List?)
        ?.map((e) => e.toString())
        .toList(),
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
  );
}

class DashboardController extends GetxController {
  final _supabase = Supabase.instance.client;

  final workshops = <Workshop>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWorkshops();
  }

  Future<void> fetchWorkshops() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final data = await _supabase
          .from('workshops')
          .select(
            'id, name, description, address, price_start, '
            'vehicle_types, service_types, latitude, longitude',
          )
          .eq('is_active', true)
          .order('name', ascending: true);

      workshops.value = (data as List).map((e) => Workshop.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      errorMessage.value = 'DB Error: ${e.message}';
    } catch (e) {
      errorMessage.value = 'Gagal memuat data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteWorkshop(String id) async {
    workshops.removeWhere((w) => w.id == id);

    try {
      await _supabase
          .from('workshops')
          .update({'is_active': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      Get.snackbar('Gagal', 'Tidak bisa menghapus: ${e.message}');
      fetchWorkshops(); // rollback
    } catch (e) {
      Get.snackbar('Error', '$e');
      fetchWorkshops();
    }
  }
}
