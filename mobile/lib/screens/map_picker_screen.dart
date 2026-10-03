import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muzayen/data/account_store.dart';
import 'package:muzayen/data/auth_api.dart';
import 'package:muzayen/theme/settings_tone.dart';
import 'package:muzayen/theme/system_bars.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.title = 'تحديد العنوان',
    this.confirmLabel = 'استخدام هذا العنوان',
    this.initial,
  });

  final String title;
  final String confirmLabel;
  final LatLng? initial;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _cairo = LatLng(30.0444, 31.2357);

  final _controller = Completer<GoogleMapController>();
  late LatLng _target = widget.initial ?? _cairo;
  MapAddress? _picked;
  bool _loading = false;
  String? _error;
  int _request = 0;

  Future<void> _lookup(LatLng target) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picked = await MapGeocoder.resolve(
        target.latitude,
        target.longitude,
      );
      if (!mounted || request != _request) return;
      setState(() => _picked = picked);
    } on AuthException catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _error = 'تعذر قراءة العنوان من الخريطة.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      final controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tone = SettingsTone.of(AccountStore.instance.darkMode);
    final label = _picked?.address;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: tone.background,
        appBar: AppBar(
          backgroundColor: tone.background,
          foregroundColor: tone.text,
          elevation: 0,
          systemOverlayStyle: SystemBars.overlay(
            lightStatus: !tone.dark,
            lightNavigation: !tone.dark,
            statusColor: tone.background,
            navigationColor: tone.background,
          ),
          title: Text(widget.title),
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initial ?? _cairo,
                zoom: 14,
              ),
              onMapCreated: _controller.complete,
              onCameraMove: (position) => _target = position.target,
              onCameraIdle: () => _lookup(_target),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFFD9B25B),
                  size: 44,
                ),
              ),
            ),
            PositionedDirectional(
              top: 16,
              end: 16,
              child: FloatingActionButton.small(
                heroTag: 'map-locate',
                backgroundColor: tone.panel,
                foregroundColor: tone.accent,
                onPressed: _locate,
                child: const Icon(Icons.my_location),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tone.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tone.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        label ?? (_error ?? 'حرّك الخريطة لاختيار العنوان.'),
                        key: const Key('map-address'),
                        style: TextStyle(
                          color: _error != null && label == null
                              ? const Color(0xFFE56B6B)
                              : tone.text,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('map-confirm'),
                        onPressed: label == null || _loading
                            ? null
                            : () => Navigator.of(context).pop(_picked),
                        style: FilledButton.styleFrom(
                          backgroundColor: tone.accent,
                          foregroundColor: tone.ink,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _loading
                              ? 'جارٍ قراءة العنوان…'
                              : widget.confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
