import 'package:get/get.dart';
import 'features/auth/login_view.dart';
import 'features/dashboard/dashboard_view.dart';
import 'features/workshop/workshop_controller.dart';
import 'features/workshop/workshop_form_view.dart';
import 'features/auth/register_view.dart';

// --- Import baru untuk fitur Peta User ---
import 'features/home_map/home_map_view.dart';
import 'features/home_map/home_map_controller.dart';

abstract class Routes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const workshopForm = '/workshop-form';
  static const register = '/register';

  // --- Route baru untuk Peta User ---
  static const homeMap = '/home-map';
}

/// Binding khusus form workshop.
/// Setiap kali route ini dibuka, controller SELALU dihapus dulu lalu dibuat
/// ulang — ini mencegah bug stale state (misal: data edit bengkel lama
/// masih terbawa saat tambah bengkel baru).
class WorkshopBinding extends Bindings {
  @override
  void dependencies() {
    // force: true → hapus instance lama walau masih ada
    Get.delete<WorkshopController>(force: true);
    Get.put(WorkshopController());
  }
}

class AppPages {
  static final pages = [
    GetPage(name: Routes.login, page: () => LoginView()),
    GetPage(name: Routes.dashboard, page: () => DashboardView()),
    GetPage(
      name: Routes.workshopForm,
      page: () => WorkshopFormView(),
      binding: WorkshopBinding(), // ← fix stale controller
    ),

    GetPage(name: Routes.register, page: () => RegisterView()),

    // --- Halaman baru untuk fitur User (Peta) ---
    GetPage(
      name: Routes.homeMap,
      page: () => const HomeMapView(),
      binding: BindingsBuilder(() {
        // Kita cukup menggunakan BindingsBuilder bawaan GetX karena
        // HomeMapController biasanya aman dipertahankan (tidak perlu dihapus paksa
        // seperti form input) agar peta tidak loading ulang terus-menerus.
        Get.put(HomeMapController());
      }),
    ),
  ];
}
