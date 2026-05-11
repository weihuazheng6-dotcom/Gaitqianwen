import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../services/ble_manager.dart';

class ScanScreen extends StatefulWidget {
  final DeviceRole? selectRole;
  const ScanScreen({super.key, this.selectRole});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    final ble = context.read<BleManager>();
    if (!ble.isScanning) {
      ble.startScan(timeoutSeconds: 12);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('扫描设备'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: Consumer<BleManager>(
        builder: (context, ble, _) => Column(
          children: [
            if (ble.isScanning) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: ble.scannedDevices.length,
                itemBuilder: (context, index) {
                  final device = ble.scannedDevices[index];
                  return ListTile(
                    title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown'),
                    subtitle: Text('MAC: ${device.remoteId.str}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (widget.selectRole != null) {
                        Navigator.pop(context, device);
                      } else {
                        _showRoleDialog(context, device);
                      }
                    },
                    onLongPress: () => _showRoleDialog(context, device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context, BluetoothDevice device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('选择角色 for ${device.platformName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DeviceRole.values.map((role) {
            return ListTile(
              title: Text(role.name),
              onTap: () async {
                Navigator.pop(ctx);
                final ble = context.read<BleManager>();
                try {
                  await ble.connectDevice(device, role);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('连接失败: $e')));
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
