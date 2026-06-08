import 'package:get/get.dart';
import 'features/auth/login_view.dart';
import 'features/dashboard/dashboard_view.dart';
import 'features/workshop/workshop_controller.dart';
import 'features/workshop/workshop_form_view.dart';

abstract class Routes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const workshopForm = '/workshop-form';
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
  ];
}
