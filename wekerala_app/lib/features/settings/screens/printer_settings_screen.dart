import 'dart:async';
import 'dart:io';

import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/print_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  bool _connecting = false;
  bool _testPrinting = false;
  String? _savedAddress;
  StreamSubscription<List<BluetoothDevice>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  Future<void> _loadSavedAddress() async {
    final addr = await PrintService.getSavedPrinterAddress();
    if (mounted) setState(() => _savedAddress = addr);
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });
    _scanSub?.cancel();
    _scanSub = PrintService.scanDevices().listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    // Stop scanning after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _scanSub?.cancel();
        PrintService.stopScan();
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _connecting = true);
    try {
      final success = await PrintService.connect(device);
      if (!mounted) return;
      if (success) {
        await PrintService.savePrinterAddress(device.address ?? '');
        setState(() {
          _connectedDevice = device;
          _savedAddress = device.address;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.name ?? device.address ?? 'printer'}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection failed. Make sure the printer is on and in range.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testPrinting = true);
    try {
      await PrintService.printTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test page sent to printer'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testPrinting = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    PrintService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && !Platform.isAndroid) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Printer Settings'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.print_outlined, size: 56, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Printing on Windows',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bluetooth printers work on the Android phone app.\n\nOn Windows, connect your thermal printer via USB and use the Windows printer dialog (Ctrl + P) to print bills.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.smartphone, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'For Bluetooth printing, open the Oratas app on your Android phone.',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Printer Setup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            tooltip: 'Bluetooth',
            onPressed: null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Saved/paired printer card
          if (_savedAddress != null) ...[
            Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.print, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectedDevice?.name ?? 'Saved Printer',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _savedAddress!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_connectedDevice != null)
                      Chip(
                        label: const Text('Connected'),
                        backgroundColor: AppColors.success.withValues(alpha: 0.15),
                        labelStyle: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ),
            ),
            if (_connectedDevice != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _testPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.print_outlined, color: AppColors.primary),
                  label: Text(
                    _testPrinting ? 'Printing...' : 'Test Print',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _testPrinting ? null : _testPrint,
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Scan section header
          Row(
            children: [
              const Text(
                'Available Printers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_isScanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Make sure your Bluetooth printer is powered on and in pairing mode.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Scan button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Printers'),
              onPressed: _isScanning ? null : _startScan,
            ),
          ),
          const SizedBox(height: 16),

          // Device list
          if (_devices.isEmpty && !_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No printers found. Tap "Scan for Printers" to search.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._devices.map((device) {
              final isConnected = _connectedDevice?.address == device.address;
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(
                    Icons.print_outlined,
                    color: isConnected ? AppColors.success : AppColors.primary,
                  ),
                  title: Text(
                    device.name ?? 'Unknown Device',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isConnected ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    device.address ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: isConnected
                      ? const Chip(
                          label: Text('Connected'),
                          backgroundColor: Color(0xFFE8F5E9),
                          labelStyle: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide.none,
                        )
                      : _connecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: (_connecting || isConnected) ? null : () => _connectToDevice(device),
                ),
              );
            }),
        ],
      ),
    );
  }
}
