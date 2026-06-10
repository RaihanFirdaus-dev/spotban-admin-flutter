import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class HomeMapController extends GetxController {
  final supabase = Supabase.instance.client;
  final mapController = MapController();
  final httpClient = GetConnect();

  var isLoading = true.obs;
  var userLocation = Rxn<LatLng>();
  var workshops = <Map<String, dynamic>>[].obs;

  var selectedWorkshop = Rxn<Map<String, dynamic>>();
  var routePoints = <LatLng>[].obs;
  var sortBy = 'terdekat'.obs; // 'terdekat' atau 'termurah'

  @override
  void onInit() {
    super.onInit();
    initializeApp();
  }

  Future<void> initializeApp() async {
    await getUserLocation();
    await fetchWorkshops();
    isLoading.value = false;
  }

  Future<void> getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    userLocation.value = LatLng(position.latitude, position.longitude);
  }

  Future<void> fetchWorkshops() async {
    try {
      // ── FITUR BARU: Mengambil data bengkel BESERTA relasi fotonya ──
      // Tanda * mengambil semua kolom workshop.
      // workshop_photos(photo_url, is_primary) mengambil kolom dari tabel sebelah.
      final response = await supabase
          .from('workshops')
          .select('*, workshop_photos(photo_url, is_primary)')
          .eq('is_active', true);

      workshops.assignAll(List<Map<String, dynamic>>.from(response));
      sortWorkshops();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data bengkel: $e');
    }
  }

  Future<void> fetchRealRoute(LatLng destination) async {
    if (userLocation.value == null) return;
    final start = userLocation.value!;

    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await httpClient.get(url);
      if (response.statusCode == 200 && response.body != null) {
        final routes = response.body['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          List<LatLng> points = coordinates.map((coord) {
            double lon = (coord[0] as num).toDouble();
            double lat = (coord[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          routePoints.assignAll(points);
        }
      } else {
        routePoints.assignAll([start, destination]);
      }
    } catch (e) {
      routePoints.assignAll([start, destination]);
    }
  }

  void selectWorkshop(Map<String, dynamic> workshop) async {
    selectedWorkshop.value = workshop;
    LatLng workshopCoord = parseLocation(workshop['location']);
    mapController.move(workshopCoord, 15.5);
    await fetchRealRoute(workshopCoord);
  }

  void clearSelection() {
    selectedWorkshop.value = null;
    routePoints.clear();
    if (userLocation.value != null) {
      mapController.move(userLocation.value!, 14.0);
    }
  }

  // ── FIX FITUR SORTING ───────────────────────────────────────────────────
  void changeSortType(String type) {
    sortBy.value = type;
    sortWorkshops();
  }

  void sortWorkshops() {
    if (sortBy.value == 'termurah') {
      workshops.sort((a, b) {
        final priceA = (a['price_start'] ?? 0) as num;
        final priceB = (b['price_start'] ?? 0) as num;
        return priceA.compareTo(priceB);
      });
    } else if (sortBy.value == 'terdekat' && userLocation.value != null) {
      workshops.sort((a, b) {
        LatLng locA = parseLocation(a['location']);
        LatLng locB = parseLocation(b['location']);

        double distA = Geolocator.distanceBetween(
          userLocation.value!.latitude,
          userLocation.value!.longitude,
          locA.latitude,
          locA.longitude,
        );
        double distB = Geolocator.distanceBetween(
          userLocation.value!.latitude,
          userLocation.value!.longitude,
          locB.latitude,
          locB.longitude,
        );

        return distA.compareTo(distB);
      });
    }
    workshops
        .refresh(); // Memaksa GetX merombak susunan list di UI secara realtime
  }

  LatLng parseLocation(dynamic locationData) {
    if (locationData == null) return const LatLng(3.5641, 98.6565);
    try {
      if (locationData is Map<String, dynamic>) {
        final coords = locationData['coordinates'];
        if (coords != null && coords.length >= 2) {
          return LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
        }
      }
      if (locationData is String) {
        String cleanString = locationData
            .replaceAll('POINT(', '')
            .replaceAll(')', '')
            .trim();
        List<String> coords = cleanString.split(' ');
        if (coords.length >= 2) {
          return LatLng(double.parse(coords[1]), double.parse(coords[0]));
        }
      }
    } catch (e) {
      print('Error parsing location: $e');
    }
    return const LatLng(3.5641, 98.6565);
  }

  // ── FUNGSI BARU 1: Menghitung Jarak untuk ditampilkan di UI ──
  String getDistanceString(Map<String, dynamic> workshop) {
    if (userLocation.value == null) return '';

    LatLng workshopLoc = parseLocation(workshop['location']);
    double distanceInMeters = Geolocator.distanceBetween(
      userLocation.value!.latitude,
      userLocation.value!.longitude,
      workshopLoc.latitude,
      workshopLoc.longitude,
    );

    // Jika jarak di bawah 1000 meter, tampilkan dalam meter (m)
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    }
    // Jika di atas 1000 meter, tampilkan dalam kilometer (km)
    else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  // ── FUNGSI BARU 2: Logout ──
  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
      Get.offAllNamed('/login'); // Kembali ke halaman login
    } catch (e) {
      Get.snackbar('Error', 'Gagal melakukan logout: $e');
    }
  }
}
