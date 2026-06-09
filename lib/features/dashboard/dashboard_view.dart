import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../auth/auth_controller.dart';
import 'dashboard_controller.dart';

class DashboardView extends StatelessWidget {
  DashboardView({super.key});

  final DashboardController _ctrl = Get.put(DashboardController());
  final AuthController _authCtrl = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('SpotBan Admin'),
        actions: [
          // Jumlah bengkel aktif sebagai badge info
          Obx(
            () => _ctrl.workshops.isNotEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_ctrl.workshops.length} bengkel',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _ctrl.fetchWorkshops,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),

      // FAB tambah bengkel baru
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Bengkel'),
      ),

      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_ctrl.errorMessage.value.isNotEmpty) {
          return _ErrorState(
            message: _ctrl.errorMessage.value,
            onRetry: _ctrl.fetchWorkshops,
          );
        }

        if (_ctrl.workshops.isEmpty) {
          return _EmptyState(onAdd: () => _navigateToForm(context));
        }

        return RefreshIndicator(
          onRefresh: _ctrl.fetchWorkshops,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _ctrl.workshops.length,
            itemBuilder: (_, i) {
              return _WorkshopCard(
                workshop: _ctrl.workshops[i],
                onEdit: () =>
                    _navigateToForm(context, workshop: _ctrl.workshops[i]),
                onDelete: () => _confirmDelete(
                  context,
                  _ctrl.workshops[i].id,
                  _ctrl.workshops[i].name,
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // Navigasi ke form — tunggu result; jika true → refresh list
  Future<void> _navigateToForm(
    BuildContext context, {
    Workshop? workshop,
  }) async {
    final result = await Get.toNamed(
      '/workshop-form',
      arguments: workshop, // null = mode Tambah, non-null = mode Edit
    );
    if (result == true) {
      _ctrl.fetchWorkshops();
    }
  }

  void _confirmDelete(BuildContext ctx, String id, String name) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 36,
        ),
        title: const Text('Nonaktifkan Bengkel?'),
        content: Text(
          '"$name" akan disembunyikan dari aplikasi.\nData tidak akan dihapus permanen.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Get.back();
              _ctrl.deleteWorkshop(id);
            },
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Sesi Anda akan diakhiri.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Get.back();
              _authCtrl.signOut();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

// ── WorkshopCard ────────────────────────────────────────────────────────────

class _WorkshopCard extends StatelessWidget {
  final Workshop workshop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkshopCard({
    required this.workshop,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final w = workshop;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris atas: nama + tombol aksi
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ikon bengkel
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.car_repair,
                    color: cs.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              w.address,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tombol edit & hapus dalam PopupMenu agar tidak sesak
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.block_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Nonaktifkan',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Divider
            if ((w.vehicleTypes?.isNotEmpty == true) ||
                (w.serviceTypes?.isNotEmpty == true) ||
                w.priceStart != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 10),
            ],

            // Harga
            if (w.priceStart != null) ...[
              Row(
                children: [
                  Icon(Icons.payments_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Mulai Rp ${_formatPrice(w.priceStart!)}',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Chip tipe kendaraan
            if (w.vehicleTypes?.isNotEmpty == true)
              _ChipRow(
                icon: Icons.directions_car_outlined,
                items: w.vehicleTypes!,
                color: cs.secondaryContainer,
                textColor: cs.onSecondaryContainer,
              ),

            // Chip jenis layanan
            if (w.serviceTypes?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _ChipRow(
                icon: Icons.build_outlined,
                items: w.serviceTypes!,
                color: cs.tertiaryContainer,
                textColor: cs.onTertiaryContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _ChipRow extends StatelessWidget {
  final IconData icon;
  final List<String> items;
  final Color color;
  final Color textColor;

  const _ChipRow({
    required this.icon,
    required this.items,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: textColor),
                const SizedBox(width: 4),
                Text(
                  item,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Empty & Error States ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.car_repair, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Belum ada bengkel',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan tombol di bawah untuk menambahkan bengkel pertama.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.outlineVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Bengkel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
