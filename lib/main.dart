import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
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
  final TextEditingController _rawTextController =
      TextEditingController(text: 'PING');
  final TextEditingController _rawHexController =
      TextEditingController(text: '1B 40');

  final List<ble.ScanResult> _bleResults = <ble.ScanResult>[];
  StreamSubscription<List<ble.ScanResult>>? _bleScanSub;
  StreamSubscription<bool>? _bleScanStateSub;
  bool _isBleScanning = false;
  bool _appendCrlf = true;

  List<BluetoothDevice> _devices = <BluetoothDevice>[];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _bleScanSub = ble.FlutterBluePlus.scanResults.listen(_updateBleResults);
    _bleScanStateSub = ble.FlutterBluePlus.isScanning.listen((bool scanning) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBleScanning = scanning;
      });
    });
    _refreshBondedDevices();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _rawTextController.dispose();
    _rawHexController.dispose();
    _bleScanSub?.cancel();
    _bleScanStateSub?.cancel();
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

  Future<void> _sendRawText() async {
    if (!_isConnected) {
      _showSnackBar('Connect to a printer before sending data.');
      return;
    }

    String message = _rawTextController.text;
    if (message.trim().isEmpty) {
      _showSnackBar('Enter raw text to send.');
      return;
    }

    if (_appendCrlf) {
      message = _applyCrlf(message);
    }

    try {
      await _printer.write(message);
      _showSnackBar('Raw text sent.');
    } catch (error) {
      _showSnackBar('Raw text send failed: $error');
    }
  }

  Future<void> _sendRawBytes() async {
    if (!_isConnected) {
      _showSnackBar('Connect to a printer before sending data.');
      return;
    }

    final Uint8List? bytes = _parseHexBytes(_rawHexController.text);
    if (bytes == null || bytes.isEmpty) {
      _showSnackBar('Enter hex bytes, e.g. "1B 40".');
      return;
    }

    try {
      await _printer.writeBytes(bytes);
      _showSnackBar('Raw bytes sent (${bytes.length}).');
    } catch (error) {
      _showSnackBar('Raw bytes send failed: $error');
    }
  }

  Uint8List? _parseHexBytes(String input) {
    final String cleaned = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.isEmpty || cleaned.length.isOdd) {
      return null;
    }

    final List<int> bytes = <int>[];
    for (int i = 0; i < cleaned.length; i += 2) {
      final String hex = cleaned.substring(i, i + 2);
      bytes.add(int.parse(hex, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  String _applyCrlf(String input) {
    final String normalized = input.replaceAll('\r\n', '\n');
    final String withCrlf = normalized.replaceAll('\n', '\r\n');
    return withCrlf.endsWith('\r\n') ? withCrlf : '$withCrlf\r\n';
  }

  void _setPreset(String preset) {
    _rawTextController.text = preset;
  }

  Future<void> _startBleScan() async {
    final bool granted = await _ensureBluetoothPermissions();
    if (!granted) {
      return;
    }

    setState(() {
      _bleResults.clear();
    });

    try {
      await ble.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );
    } catch (error) {
      _showSnackBar('BLE scan failed: $error');
    }
  }

  Future<void> _stopBleScan() async {
    try {
      await ble.FlutterBluePlus.stopScan();
    } catch (error) {
      _showSnackBar('Stop scan failed: $error');
    }
  }

  void _updateBleResults(List<ble.ScanResult> results) {
    if (!mounted) {
      return;
    }

    setState(() {
      for (final ble.ScanResult result in results) {
        final int index = _bleResults.indexWhere(
          (ble.ScanResult item) => item.device.id == result.device.id,
        );
        if (index == -1) {
          _bleResults.add(result);
        } else {
          _bleResults[index] = result;
        }
      }
    });
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
            const SizedBox(height: 24),
            Text(
              'Raw protocol diagnostics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rawTextController,
              enabled: !_isBusy,
              decoration: const InputDecoration(
                labelText: 'Raw text (sent with write)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Append CRLF (\\r\\n) to raw text'),
              value: _appendCrlf,
              onChanged: _isBusy
                  ? null
                  : (bool value) {
                      setState(() {
                        _appendCrlf = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isBusy
                      ? null
                      : () => _setPreset(
                            'SIZE 40 mm,30 mm\n'
                            'GAP 2 mm,0\n'
                            'CLS\n'
                            'TEXT 10,10,"0",0,1,1,"TEST"\n'
                            'PRINT 1,1',
                          ),
                  child: const Text('TSPL preset'),
                ),
                OutlinedButton(
                  onPressed: _isBusy
                      ? null
                      : () => _setPreset(
                            '^XA^FO20,20^A0N,30,30^FDTEST^FS^XZ',
                          ),
                  child: const Text('ZPL preset'),
                ),
                OutlinedButton(
                  onPressed: _isBusy
                      ? null
                      : () => _setPreset(
                            '! 0 200 200 200 1\n'
                            'TEXT 4 0 30 40 TEST\n'
                            'FORM\n'
                            'PRINT',
                          ),
                  child: const Text('CPCL preset'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _sendRawText,
              icon: const Icon(Icons.send),
              label: const Text('Send raw text'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rawHexController,
              enabled: !_isBusy,
              decoration: const InputDecoration(
                labelText: 'Raw hex bytes (e.g. 1B 40)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _sendRawBytes,
              icon: const Icon(Icons.send),
              label: const Text('Send raw bytes'),
            ),
            const SizedBox(height: 24),
            Text(
              'BLE scan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy || _isBleScanning ? null : _startBleScan,
                    icon: const Icon(Icons.radar),
                    label: const Text('Start scan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBleScanning ? _stopBleScan : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop scan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_bleResults.isEmpty)
              Text(
                _isBleScanning
                    ? 'Scanning for BLE devices...'
                    : 'No BLE devices found yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ..._bleResults.map(
                (ble.ScanResult result) {
                  final String name = result.device.name.isNotEmpty
                      ? result.device.name
                      : 'Unknown';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(result.device.id.toString()),
                    trailing: Text('${result.rssi} dBm'),
                  );
                },
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
