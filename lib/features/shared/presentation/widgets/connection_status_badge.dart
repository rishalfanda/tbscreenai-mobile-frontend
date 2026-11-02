import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/core/connectivity/connectivity_service.dart';
import 'package:myapp/core/localization/app_language.dart';

class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({super.key, this.service});
  final ConnectivityService? service;
  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge> {
  bool? _online;
  StreamSubscription<bool>? _subscription;
  @override
  void initState() {
    super.initState();
    final service = widget.service ?? ConnectivityService();
    unawaited(_start(service));
  }

  Future<void> _start(ConnectivityService service) async {
    final value = await service.checkNow();
    if (!mounted) return;
    setState(() => _online = value);
    _subscription = service.onStatusChange.listen((value) {
      if (mounted) setState(() => _online = value);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _online == null
        ? context.trRead('Memeriksa koneksi', 'Checking connection')
        : _online!
        ? 'Online'
        : 'Offline';
    final color = _online == true
        ? const Color(0xFF15803D)
        : const Color(0xFF64748B);
    final icon = Icon(
      _online == true ? Icons.wifi : Icons.wifi_off,
      color: color,
      size: 18,
    );
    return Tooltip(
      message: label,
      child: MediaQuery.sizeOf(context).width < 480
          ? icon
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            ),
    );
  }
}
