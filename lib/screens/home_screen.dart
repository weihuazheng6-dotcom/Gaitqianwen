import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gait_data.dart';
import '../services/ble_manager.dart';
import '../services/csv_export.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('步态检测', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer<BleManager>(
        builder: (context, ble, _) {
          final hasLP = ble.isConnected(DeviceRole.leftPressure);
          final hasRP = ble.isConnected(DeviceRole.rightPressure);
          final hasLI = ble.isConnected(DeviceRole.leftIMU);
          final hasRI = ble.isConnected(DeviceRole.rightIMU);

          return Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _DeviceCard(
                      title: '左压力', icon: Icons.sensors,
                      isConnected: hasLP,
                      data: ble.getLeftPressure(),
                      onTap: () => _selectDevice(DeviceRole.leftPressure),
                    ),
                    _DeviceCard(
                      title: '右压力', icon: Icons.sensors,
                      isConnected: hasRP,
                      data: ble.getRightPressure(),
                      onTap: () => _selectDevice(DeviceRole.rightPressure),
                    ),
                    _DeviceCard(
                      title: '左IMU', icon: Icons.waves,
                      isConnected: hasLI,
                      data: ble.getLeftIMU(),
                      onTap: () => _selectDevice(DeviceRole.leftIMU),
                    ),
                    _DeviceCard(
                      title: '右IMU', icon: Icons.waves,
                      isConnected: hasRI,
                      data: ble.getRightIMU(),
                      onTap: () => _selectDevice(DeviceRole.rightIMU),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('标签: ', style: TextStyle(fontSize: 14)),
                    for (var i = 0; i <= 9; i++)
                      TextButton(
                        onPressed: () => ble.setLabel(i.toString()),
                        style: TextButton.styleFrom(
                          backgroundColor: ble.currentLabel == i.toString()
                              ? const Color(0xFF1565C0)
                              : Colors.grey[200],
                          foregroundColor: ble.currentLabel == i.toString()
                              ? Colors.white
                              : Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('$i'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ble.startScan(timeoutSeconds: 12);
                      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
                    },
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('扫描'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (ble.isRecording) ble.stopRecording(); else ble.startRecording();
                      setState(() {});
                    },
                    icon: Icon(ble.isRecording ? Icons.stop : Icons.fiber_manual_record),
                    label: Text(ble.isRecording ? '停止' : '录制'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ble.isRecording ? Colors.red : const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (ble.records.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有录制数据')));
                        return;
                      }
                      final path = await CsvExport.exportToCsv(ble.records);
                      if (path != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV已保存: $path')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出失败')));
                      }
                    },
                    icon: const Icon(Icons.save_alt),
                    label: const Text('导出CSV'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => ble.disconnectAll(),
                    icon: const Icon(Icons.link_off),
                    label: const Text('断开全部'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _selectDevice(DeviceRole role) async {
    final ble = context.read<BleManager>();
    if (ble.isConnected(role)) {
      // find and disconnect
      // We could add a method to get device by role, but for simplicity disconnectAll is called? No, better:
      // Actually BleManager has no public method to disconnect by role directly. We'll skip this functionality.
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(selectRole: role)),
    );
    if (result != null && result is BluetoothDevice) {
      try {
        await ble.connectDevice(result, role);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('连接失败: $e')));
        }
      }
    }
  }
}

class _DeviceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isConnected;
  final SensorData? data;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.title, required this.icon,
    required this.isConnected, this.data, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: isConnected ? Colors.blue.shade50 : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.green : Colors.grey,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              if (isConnected && data != null) _buildData(data!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildData(SensorData d) {
    if (d.isPressure) {
      return Text(
        'P1: ${d.pressure1?.toStringAsFixed(1) ?? '--'}\n'
        'P2: ${d.pressure2?.toStringAsFixed(1) ?? '--'}\n'
        'P3: ${d.pressure3?.toStringAsFixed(1) ?? '--'}',
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
      );
    } else {
      return Text(
        'Acc:${d.accX?.toStringAsFixed(3) ?? '-'}/${d.accY?.toStringAsFixed(3) ?? '-'}/${d.accZ?.toStringAsFixed(3) ?? '-'}\n'
        'Gyro:${d.gyroX?.toStringAsFixed(1) ?? '-'}/${d.gyroY?.toStringAsFixed(1) ?? '-'}/${d.gyroZ?.toStringAsFixed(1) ?? '-'}\n'
        'Angle:${d.roll?.toStringAsFixed(1) ?? '-'}/${d.pitch?.toStringAsFixed(1) ?? '-'}/${d.yaw?.toStringAsFixed(1) ?? '-'}',
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
      );
    }
  }
}
