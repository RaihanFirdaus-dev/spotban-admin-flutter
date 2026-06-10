import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_map/home_map_controller.dart';
import '../dashboard/dashboard_controller.dart'; // Jika ada
import '../workshop/workshop_controller.dart';

class AuthController extends GetxController {
  final _supabase = Supabase.instance.client;

  final isLoading = false.obs;
  final errorMessage = ''.obs;

  Future<void> signIn(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.user != null) {
        final profileData = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .single();

        final String userRole = profileData['role'] ?? 'USER';

        // Diagnosa
        Get.snackbar(
          'Diagnosa Login',
          'Email: ${email.trim()}\nRole terbaca: $userRole',
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );

        // Routing berdasarkan role
        if (userRole == 'ADMIN') {
          Get.offAllNamed('/dashboard');
        } else {
          Get.offAllNamed('/home-map');
        }
      } else {
        errorMessage.value = 'Login gagal. Periksa kredensial Anda.';
      }
    } on AuthException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Terjadi kesalahan: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ... (Fungsi signUp tetap sama seperti kode Anda) ...
  Future<void> signUp(String fullName, String email, String password) async {
    // ... [Kode signUp Anda tidak perlu diubah, biarkan seperti aslinya] ...
  }

  Future<void> signOut() async {
    // 1. Bersihkan sesi otentikasi di server Supabase
    await _supabase.auth.signOut();

    // 2. HAPUS MEMORI HALAMAN SECARA SPESIFIK (JANGAN hapus AuthController)
    // Ini memastikan tidak ada state Admin/User yang terbawa ke sesi berikutnya
    Get.delete<DashboardController>(force: true);
    Get.delete<HomeMapController>(force: true);
    Get.delete<WorkshopController>(force: true);

    // 3. Kembali ke gerbang utama
    Get.offAllNamed('/login');
  }
}
