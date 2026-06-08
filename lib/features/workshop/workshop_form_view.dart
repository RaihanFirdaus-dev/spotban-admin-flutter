import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'workshop_controller.dart';

class WorkshopFormView extends StatefulWidget {
  const WorkshopFormView({super.key});

  @override
  State<WorkshopFormView> createState() => _WorkshopFormViewState();
}

class _WorkshopFormViewState extends State<WorkshopFormView> {
  final WorkshopController _ctrl = Get.find<WorkshopController>();
  final _formKey       = GlobalKey<FormState>();
  final _mapController = MapController();

  // Debounce agar Nominatim tidak dipanggil tiap ketikan
  Timer? _searchDebounce;

  static const _defaultCenter = LatLng(-6.2088, 106.8456);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Obx(() => Text(
              _ctrl.isEditMode ? 'Edit Bengkel' : 'Tambah Bengkel')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _confirmBack(context),
        ),
      ),
      bottomNavigationBar: _SubmitBar(ctrl: _ctrl, formKey: _formKey),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [

            // ── Informasi Dasar ─────────────────────────────────────────────
            _SectionCard(
              title: 'Informasi Dasar',
              icon: Icons.storefront_outlined,
              children: [
                _StyledField(
                  controller: _ctrl.nameCtrl,
                  label: 'Nama Bengkel',
                  hint: 'Contoh: Bengkel Maju Jaya',
                  icon: Icons.badge_outlined,
                  capitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _ctrl.descCtrl,
                  label: 'Deskripsi',
                  hint: 'Ceritakan keunggulan bengkel ini...',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                  capitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _ctrl.addressCtrl,
                  label: 'Alamat Lengkap',
                  hint: 'Jl. Contoh No. 10, Kota',
                  icon: Icons.place_outlined,
                  maxLines: 2,
                  capitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                _StyledField(
                  controller: _ctrl.priceCtrl,
                  label: 'Harga Mulai (Rp)',
                  hint: '25000',
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    if (int.tryParse(v.trim()) == null) return 'Masukkan angka saja';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Tipe Kendaraan ──────────────────────────────────────────────
            _SectionCard(
              title: 'Tipe Kendaraan',
              icon: Icons.two_wheeler_rounded,
              children: [
                Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _ctrl.vehicleTypes.keys.map((type) {
                    return _Chip(
                      label: type,
                      icon: type == 'Motor'
                          ? Icons.two_wheeler_rounded
                          : Icons.directions_car_rounded,
                      selected: _ctrl.vehicleTypes[type]!,
                      onTap: () => _ctrl.toggleVehicle(type),
                    );
                  }).toList(),
                )),
              ],
            ),
            const SizedBox(height: 14),

            // ── Jenis Layanan ───────────────────────────────────────────────
            _SectionCard(
              title: 'Jenis Layanan',
              icon: Icons.build_outlined,
              children: [
                Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _ctrl.serviceTypes.keys.map((type) {
                    return _Chip(
                      label: type,
                      selected: _ctrl.serviceTypes[type]!,
                      onTap: () => _ctrl.toggleService(type),
                    );
                  }).toList(),
                )),
              ],
            ),
            const SizedBox(height: 14),

            // ── Foto Bengkel ────────────────────────────────────────────────
            _SectionCard(
              title: 'Foto Bengkel',
              icon: Icons.photo_library_outlined,
              trailing: Obx(() {
                final total = _ctrl.existingPhotoUrls.length +
                    _ctrl.selectedImages.length;
                return total > 0
                    ? _CountBadge('$total foto')
                    : const SizedBox.shrink();
              }),
              children: [
                Obx(() {
                  if (_ctrl.existingPhotoUrls.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _PhotoGroup(
                    title: 'Foto tersimpan',
                    count: _ctrl.existingPhotoUrls.length,
                    itemBuilder: (i) => _PhotoThumb(
                      child: Image.network(
                        _ctrl.existingPhotoUrls[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, size: 32),
                      ),
                      onRemove: () =>
                          _ctrl.removeExistingPhoto(_ctrl.existingPhotoUrls[i]),
                    ),
                  );
                }),
                Obx(() {
                  if (_ctrl.selectedImages.isEmpty) return const SizedBox.shrink();
                  return _PhotoGroup(
                    title: 'Foto baru',
                    count: _ctrl.selectedImages.length,
                    itemBuilder: (i) => _PhotoThumb(
                      child: Image.file(
                        File(_ctrl.selectedImages[i].path),
                        fit: BoxFit.cover,
                      ),
                      onRemove: () => _ctrl.removeNewImage(i),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _ctrl.pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Pilih dari Galeri'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Lokasi Bengkel ──────────────────────────────────────────────
            _SectionCard(
              title: 'Lokasi Bengkel',
              icon: Icons.map_outlined,
              children: [

                // Status koordinat terpilih
                Obx(() {
                  final loc = _ctrl.selectedLocation.value;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: loc != null
                          ? cs.primaryContainer.withOpacity(0.4)
                          : cs.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: loc != null
                            ? cs.primary.withOpacity(0.4)
                            : cs.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        loc != null
                            ? Icons.check_circle_rounded
                            : Icons.touch_app_rounded,
                        size: 16,
                        color: loc != null ? cs.primary : cs.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc != null
                              ? 'Lat ${loc.latitude.toStringAsFixed(6)}, '
                                  'Lng ${loc.longitude.toStringAsFixed(6)}'
                              : 'Belum ada lokasi — gunakan GPS atau cari nama jalan',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: loc != null
                                ? cs.onPrimaryContainer
                                : cs.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 10),

                // Tombol GPS + Search field
                Row(children: [
                  Obx(() => _ctrl.isLocating.value
                      ? SizedBox(
                          width: 48,
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: cs.primary),
                          ),
                        )
                      : Tooltip(
                          message: 'Pakai lokasi GPS saya',
                          child: FilledButton.tonalIcon(
                            onPressed: _ctrl.useCurrentLocation,
                            icon: const Icon(Icons.my_location_rounded, size: 18),
                            label: const Text('GPS'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        )),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl.locationSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari nama jalan atau tempat...',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: Obx(() =>
                            _ctrl.isSearchingLocation.value
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : const SizedBox.shrink()),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: cs.outline.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: cs.outline.withOpacity(0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                      ),
                      onChanged: (q) {
                        // Debounce 600 ms supaya tidak spam Nominatim API
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 600),
                          () => _ctrl.searchLocation(q),
                        );
                      },
                    ),
                  ),
                ]),

                // Dropdown hasil search
                Obx(() {
                  if (_ctrl.locationSearchResults.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outline.withOpacity(0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _ctrl.locationSearchResults
                          .asMap()
                          .entries
                          .map((entry) {
                        final i      = entry.key;
                        final result = entry.value;
                        final isLast =
                            i == _ctrl.locationSearchResults.length - 1;
                        return Column(children: [
                          InkWell(
                            onTap: () {
                              _ctrl.selectSearchResult(result);
                              // Animasikan kamera peta ke titik yang dipilih
                              _mapController.move(
                                LatLng(result.lat, result.lon),
                                16,
                              );
                            },
                            borderRadius: BorderRadius.vertical(
                              top: i == 0
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                              bottom: isLast
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 16, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      result.displayName,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Divider(
                                height: 1,
                                color: cs.outline.withOpacity(0.12)),
                        ]);
                      }).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 10),

                // Flutter Map
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 280,
                    child: Obx(() {
                      final loc    = _ctrl.selectedLocation.value;
                      final center = loc ?? _defaultCenter;
                      return FlutterMap(
                        key: ValueKey('${_ctrl.isEditMode}_${loc != null}'),
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: loc != null ? 15.5 : 12,
                          // Ketuk peta untuk memindahkan pin
                          onTap: (_, latLng) {
                            _ctrl.selectedLocation.value = latLng;
                            _ctrl.locationSearchResults.clear();
                            _ctrl.locationSearchCtrl.clear();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.spotban.admin',
                          ),
                          if (loc != null)
                            MarkerLayer(markers: [
                              Marker(
                                point: loc,
                                width: 44,
                                height: 52,
                                alignment: Alignment.topCenter,
                                child: Icon(
                                  Icons.location_pin,
                                  color: cs.primary,
                                  size: 44,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Ketuk peta untuk memindahkan pin lokasi',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBack(BuildContext ctx) {
    if (!_ctrl.isEditMode) { Get.back(); return; }
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Tinggalkan halaman?'),
        content: const Text('Perubahan yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('Tetap di sini')),
          FilledButton(
            onPressed: () { Get.back(); Get.back(); },
            child: const Text('Tinggalkan'),
          ),
        ],
      ),
    );
  }
}

// ── Submit Bar ────────────────────────────────────────────────────────────────
class _SubmitBar extends StatelessWidget {
  final WorkshopController ctrl;
  final GlobalKey<FormState> formKey;
  const _SubmitBar({required this.ctrl, required this.formKey});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          border:
              Border(top: BorderSide(color: cs.outline.withOpacity(0.12))),
        ),
        child: Obx(() => ctrl.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      ctrl.submitWorkshop();
                    }
                  },
                  icon: Icon(ctrl.isEditMode
                      ? Icons.save_rounded
                      : Icons.add_circle_rounded),
                  label: Text(
                    ctrl.isEditMode ? 'Simpan Perubahan' : 'Tambah Bengkel',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              )),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Styled Text Field ─────────────────────────────────────────────────────────
class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final String? Function(String?)? validator;
  const _StyledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Chip Kendaraan / Layanan ──────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant),
            const SizedBox(width: 5),
          ],
          if (selected) ...[
            Icon(Icons.check_rounded, size: 13, color: cs.onPrimary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Photo Group & Thumb ───────────────────────────────────────────────────────
class _PhotoGroup extends StatelessWidget {
  final String title;
  final int count;
  final Widget Function(int) itemBuilder;
  const _PhotoGroup(
      {required this.title,
      required this.count,
      required this.itemBuilder});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 6),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => itemBuilder(i),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
}

class _PhotoThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 90, height: 90, child: child),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(11)),
              child:
                  const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ]);
}

class _CountBadge extends StatelessWidget {
  final String label;
  const _CountBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700)),
    );
  }
}
