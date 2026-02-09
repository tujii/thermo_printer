import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const ThermoPrinterApp());
}

class ThermoPrinterApp extends StatelessWidget {
  const ThermoPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermo Printer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const PrinterHomePage(),
    );
  }
}

class PrinterHomePage extends StatefulWidget {
  const PrinterHomePage({super.key});

  @override
  State<PrinterHomePage> createState() => _PrinterHomePageState();
}

class _PrinterHomePageState extends State<PrinterHomePage> {
  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  final TextEditingController _messageController =
      TextEditingController(text: 'Hello from Flutter');

  List<BluetoothDevice> _devices = <BluetoothDevice>[];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshBondedDevices();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refreshBondedDevices() async {
    setState(() {
      _isBusy = true;
    });

    try {
      final bool granted = await _ensureBluetoothPermissions();
      if (!granted) {
        return;
      }
      final List<BluetoothDevice> devices =
          await _printer.getBondedDevices();
      setState(() {
        _devices = devices;
        if (_devices.isNotEmpty) {
          _selectedDevice ??= _devices.first;
        }
      });
    } catch (error) {
      _showSnackBar('Failed to load paired devices: $error');
    } finally {
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _connect() async {
    final BluetoothDevice? device = _selectedDevice;
    if (device == null) {
      _showSnackBar('Select a paired printer first.');
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final bool granted = await _ensureBluetoothPermissions();
      if (!granted) {
        return;
      }
      await _printer.connect(device);
      final bool connected = await _printer.isConnected ?? false;
      setState(() {
        _isConnected = connected;
      });
      if (!connected) {
        _showSnackBar('Could not connect to ${device.name ?? device.address}.');
      }
    } catch (error) {
      _showSnackBar('Connection failed: $error');
    } finally {
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isBusy = true;
    });

    try {
      await _printer.disconnect();
      setState(() {
        _isConnected = false;
      });
    } catch (error) {
      _showSnackBar('Disconnect failed: $error');
    } finally {
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _printSample() async {
    if (!_isConnected) {
      _showSnackBar('Connect to a printer before printing.');
      return;
    }

    final String message = _messageController.text.trim();

    try {
      _printer.printCustom('THERMO PRINTER', 3, 1);
      _printer.printNewLine();
      if (message.isNotEmpty) {
        _printer.printCustom(message, 1, 0);
      }
      _printer.printNewLine();
      _printer.printCustom('Status: OK', 1, 0);
      _printer.printCustom('------------------------------', 1, 1);
      _printer.printCustom('Thank you!', 2, 1);
      _printer.printNewLine();
      _printer.paperCut();
    } catch (error) {
      _showSnackBar('Print failed: $error');
    }
  }

  Future<bool> _ensureBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final List<Permission> permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    if (await Permission.locationWhenInUse.isDenied) {
      permissions.add(Permission.locationWhenInUse);
    }

    final Map<Permission, PermissionStatus> statuses =
        await permissions.request();
    final bool allGranted = statuses.values.every(
      (PermissionStatus status) => status.isGranted,
    );

    if (!allGranted) {
      _showSnackBar('Bluetooth permissions are required.');
    }

    return allGranted;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Printer Demo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected' : 'Not connected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isBusy ? null : _refreshBondedDevices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Paired printers',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BluetoothDevice>(
                  isExpanded: true,
                  value: _selectedDevice,
                  items: _devices
                      .map(
                        (BluetoothDevice device) => DropdownMenuItem(
                          value: device,
                          child: Text(device.name ?? device.address ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: _isBusy
                      ? null
                      : (BluetoothDevice? device) {
                          setState(() {
                            _selectedDevice = device;
                          });
                        },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy || _isConnected ? null : _connect,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy || !_isConnected ? null : _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _messageController,
              enabled: !_isBusy,
              decoration: const InputDecoration(
                labelText: 'Print message',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _printSample,
              icon: const Icon(Icons.print),
              label: const Text('Print test ticket'),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: Pair the printer in Android Bluetooth settings first.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
