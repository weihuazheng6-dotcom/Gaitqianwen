import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/gait_data.dart';

enum DeviceRole { leftPressure, rightPressure, leftIMU, rightIMU }

class DeviceConnection {
  final BluetoothDevice device;
  final DeviceRole role;
  BluetoothCharacteristic? notifyChar;
  BluetoothCharacteristic? readChar;
  BluetoothCharacteristic? writeChar;
  StreamSubscription? notifySub;
  SensorData data;

  String get roleStr {
    switch (role) {
      case DeviceRole.leftPressure: return 'left_pressure';
      case DeviceRole.rightPressure: return 'right_pressure';
      case DeviceRole.leftIMU: return 'left_imu';
      case DeviceRole.rightIMU: return 'right_imu';
    }
  }

  DeviceConnection({required this.device, required this.role})
      : data = SensorData(deviceId: device.remoteId.str, role: '') {
    data.role = roleStr;
  }
}

class BleManager extends ChangeNotifier {
  final FlutterBluePlus _ble = FlutterBluePlus();
  List<BluetoothDevice> scannedDevices = [];
  bool isScanning = false;
  final Map<String, DeviceConnection> _connections = {};
  Map<String, BluetoothConnectionState> connectionStates = {};
  bool isRecording = false;
  List<RecordEntry> records = [];
  String currentLabel = '0';
  Timer? _recordTimer;
  final Map<String, StringBuffer> _pressureBuffers = {};
  final Map<String, List<int>> _imuBuffers = {};
  static const int imuFrameLength = 20;

  BleManager() {
    _ble.isScanning.listen((scanning) {
      isScanning = scanning;
      notifyListeners();
    });
  }

  SensorData? getLeftPressure() => _getByRole(DeviceRole.leftPressure);
  SensorData? getRightPressure() => _getByRole(DeviceRole.rightPressure);
  SensorData? getLeftIMU() => _getByRole(DeviceRole.leftIMU);
  SensorData? getRightIMU() => _getByRole(DeviceRole.rightIMU);

  SensorData? _getByRole(DeviceRole role) {
    try {
      return _connections.values.firstWhere((c) => c.role == role).data;
    } catch (_) {
      return null;
    }
  }

  bool isConnected(DeviceRole role) => _connections.values.any((c) => c.role == role);

  Future<void> startScan({int timeoutSeconds = 12}) async {
    try {
      scannedDevices.clear();
      notifyListeners();
      await _ble.startScan(timeout: Duration(seconds: timeoutSeconds));
      _ble.scanResults.listen((results) {
        for (var r in results) {
          if (!scannedDevices.any((d) => d.remoteId == r.device.remoteId)) {
            scannedDevices.add(r.device);
          }
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Scan error: $e');
    }
  }

  Future<void> stopScan() async {
    try { await _ble.stopScan(); } catch (e) { debugPrint('Stop scan error: $e'); }
  }

  Future<void> connectDevice(BluetoothDevice device, DeviceRole role) async {
    try {
      if (_connections.containsKey(device.remoteId.str)) {
        await disconnectDevice(device.remoteId.str);
      }
      for (var entry in _connections.entries) {
        if (entry.value.role == role) {
          await disconnectDevice(entry.key);
          break;
        }
      }
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      device.connectionState.listen((cs) {
        connectionStates[device.remoteId.str] = cs;
        notifyListeners();
        if (cs == BluetoothConnectionState.disconnected) {
          _removeConnection(device.remoteId.str);
        }
      });
      final services = await device.discoverServices();
      DeviceConnection dc = DeviceConnection(device: device, role: role);
      _pressureBuffers[device.remoteId.str] = StringBuffer();
      _imuBuffers[device.remoteId.str] = [];
      bool isPressure = role == DeviceRole.leftPressure || role == DeviceRole.rightPressure;

      for (var service in services) {
        if (isPressure && service.uuid.toString() == '0000ffe0-0000-1000-8000-00805f9a34fb') {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == '0000ffe1-0000-1000-8000-00805f9a34fb') {
              dc.notifyChar = char;
            }
          }
        } else if (!isPressure && service.uuid.toString() == '0000ffe5-0000-1000-8000-00805f9a34fb') {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == '0000ffe4-0000-1000-8000-00805f9a34fb') {
              dc.readChar = char;
            } else if (char.uuid.toString() == '0000ffe9-0000-1000-8000-00805f9a34fb') {
              dc.writeChar = char;
            }
          }
        }
      }

      if (isPressure && dc.notifyChar != null) {
        await dc.notifyChar!.setNotifyValue(true);
        dc.notifySub = dc.notifyChar!.onValueReceived.listen((value) {
          _handlePressureData(dc, value);
        });
      } else if (!isPressure && dc.readChar != null) {
        _startIMUPolling(dc);
      }

      _connections[device.remoteId.str] = dc;
      connectionStates[device.remoteId.str] = BluetoothConnectionState.connected;
      notifyListeners();
      debugPrint('${DateTime.now().toIso8601String()} - ${device.remoteId.str} connected as ${dc.roleStr}');
    } catch (e) {
      connectionStates[device.remoteId.str] = BluetoothConnectionState.disconnected;
      notifyListeners();
      rethrow;
    }
  }

  void _startIMUPolling(DeviceConnection dc) {
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_connections.containsKey(dc.device.remoteId.str)) {
        timer.cancel();
        return;
      }
      try {
        if (dc.readChar != null) {
          final value = await dc.readChar!.read();
          _handleIMUData(dc, value);
        }
      } catch (e) {
        debugPrint('IMU read error: $e');
      }
    });
  }

  void _handlePressureData(DeviceConnection dc, List<int> bytes) {
    try {
      String str = utf8.decode(bytes, allowMalformed: true);
      final buffer = _pressureBuffers[dc.device.remoteId.str] ?? StringBuffer();
      buffer.write(str);
      String bufStr = buffer.toString();
      while (true) {
        int start = bufStr.indexOf('\$');
        if (start < 0) break;
        int end = bufStr.indexOf(';', start);
        if (end < 0) break;
        String frame = bufStr.substring(start + 1, end);
        bufStr = bufStr.substring(end + 1);
        buffer.clear();
        buffer.write(bufStr);
        var parts = frame.split(',');
        if (parts.length >= 3) {
          dc.data.pressure1 = double.tryParse(parts[0].trim());
          dc.data.pressure2 = double.tryParse(parts[1].trim());
          dc.data.pressure3 = double.tryParse(parts[2].trim());
          dc.data.lastUpdated = DateTime.now();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Pressure parse error: $e');
    }
  }

  void _handleIMUData(DeviceConnection dc, List<int> bytes) {
    try {
      List<int> buffer = _imuBuffers[dc.device.remoteId.str] ?? [];
      buffer.addAll(bytes);
      while (buffer.length >= imuFrameLength) {
        int headIdx = buffer.indexOf(0x55);
        if (headIdx < 0 || headIdx > buffer.length - 2) break;
        if (buffer[headIdx + 1] != 0x61) {
          buffer.removeAt(headIdx);
          continue;
        }
        if (buffer.length - headIdx < imuFrameLength) break;
        List<int> frame = buffer.sublist(headIdx, headIdx + imuFrameLength);
        buffer = buffer.sublist(headIdx + imuFrameLength);
        _parseIMUFrame(dc, frame);
      }
      _imuBuffers[dc.device.remoteId.str] = buffer;
    } catch (e) {
      debugPrint('IMU handle error: $e');
    }
  }

  void _parseIMUFrame(DeviceConnection dc, List<int> frame) {
    ByteData bd = ByteData.sublistView(Uint8List.fromList(frame));
    int offset = 2;
    int accXraw = bd.getInt16(offset, Endian.little); offset += 2;
    int accYraw = bd.getInt16(offset, Endian.little); offset += 2;
    int accZraw = bd.getInt16(offset, Endian.little); offset += 2;
    int gyroXraw = bd.getInt16(offset, Endian.little); offset += 2;
    int gyroYraw = bd.getInt16(offset, Endian.little); offset += 2;
    int gyroZraw = bd.getInt16(offset, Endian.little); offset += 2;
    int rollRaw = bd.getInt16(offset, Endian.little); offset += 2;
    int pitchRaw = bd.getInt16(offset, Endian.little); offset += 2;
    int yawRaw = bd.getInt16(offset, Endian.little); offset += 2;

    dc.data.accX = (accXraw / 32768.0) * 16.0;
    dc.data.accY = (accYraw / 32768.0) * 16.0;
    dc.data.accZ = (accZraw / 32768.0) * 16.0;
    dc.data.gyroX = (gyroXraw / 32768.0) * 2000.0;
    dc.data.gyroY = (gyroYraw / 32768.0) * 2000.0;
    dc.data.gyroZ = (gyroZraw / 32768.0) * 2000.0;
    dc.data.roll = (rollRaw / 32768.0) * 180.0;
    dc.data.pitch = (pitchRaw / 32768.0) * 180.0;
    dc.data.yaw = (yawRaw / 32768.0) * 180.0;
    dc.data.lastUpdated = DateTime.now();
    notifyListeners();
  }

  Future<void> disconnectDevice(String deviceId) async {
    try {
      if (_connections.containsKey(deviceId)) {
        final dc = _connections[deviceId]!;
        dc.notifySub?.cancel();
        await dc.device.disconnect();
        _removeConnection(deviceId);
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  void _removeConnection(String deviceId) {
    _connections.remove(deviceId);
    connectionStates.remove(deviceId);
    _pressureBuffers.remove(deviceId);
    _imuBuffers.remove(deviceId);
    notifyListeners();
  }

  Future<void> disconnectAll() async {
    for (var id in _connections.keys.toList()) {
      await disconnectDevice(id);
    }
    records.clear();
    isRecording = false;
    currentLabel = '0';
    _recordTimer?.cancel();
    notifyListeners();
  }

  void startRecording() {
    if (isRecording) return;
    isRecording = true;
    records.clear();
    _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _sampleRecord());
    notifyListeners();
  }

  void stopRecording() {
    isRecording = false;
    _recordTimer?.cancel();
    _recordTimer = null;
    notifyListeners();
  }

  void _sampleRecord() {
    if (!isRecording) return;
    final lp = getLeftPressure();
    final rp = getRightPressure();
    final li = getLeftIMU();
    final ri = getRightIMU();
    if (lp == null || rp == null || li == null || ri == null) return;

    records.add(RecordEntry(
      timestamp: DateTime.now(),
      label: currentLabel,
      p1R: rp.pressure1, p2R: rp.pressure2, p3R: rp.pressure3,
      accXR: ri.accX, accYR: ri.accY, accZR: ri.accZ,
      gyroXR: ri.gyroX, gyroYR: ri.gyroY, gyroZR: ri.gyroZ,
      rollR: ri.roll, pitchR: ri.pitch, yawR: ri.yaw,
      p1L: lp.pressure1, p2L: lp.pressure2, p3L: lp.pressure3,
      accXL: li.accX, accYL: li.accY, accZL: li.accZ,
      gyroXL: li.gyroX, gyroYL: li.gyroY, gyroZL: li.gyroZ,
      rollL: li.roll, pitchL: li.pitch, yawL: li.yaw,
    ));
    notifyListeners();
  }

  void setLabel(String label) {
    currentLabel = label;
    notifyListeners();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    disconnectAll();
    super.dispose();
  }
}
