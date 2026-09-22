import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../data/service/ble_heart_rate_service.dart';
import '../../data/service/open_wearables_service.dart';
import '../../viewmodel/activity_viewmodel.dart';

class DeviceManagerSheet extends StatefulWidget {
  const DeviceManagerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DeviceManagerSheet(),
    );
  }

  @override
  State<DeviceManagerSheet> createState() => _DeviceManagerSheetState();
}

class _DeviceManagerSheetState extends State<DeviceManagerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BleHeartRateService _bleService = BleHeartRateService();
  final OpenWearablesService _owService = OpenWearablesService();

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _bleService.scanResultsStream.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    _bleService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isScanning = (status == BleDeviceState.scanning);
          if (status != BleDeviceState.connecting) {
            _connectingDeviceId = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startBleScan() async {
    setState(() {
      _scanResults = [];
      _isScanning = true;
    });
    await _bleService.startScan(timeout: const Duration(seconds: 12));
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectingDeviceId = device.remoteId.str;
    });
    final activityVm = Provider.of<ActivityViewModel>(context, listen: false);
    final success = await activityVm.connectBleDevice(device);
    if (mounted) {
      setState(() {
        _connectingDeviceId = null;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Connected to ${device.platformName.isNotEmpty ? device.platformName : "Smartwatch"}!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Could not connect. Ensure the watch is nearby and Bluetooth is on.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityVm = context.watch<ActivityViewModel>();
    final isBleConnected = _bleService.currentState == BleDeviceState.connected;
    final connectedName = _bleService.connectedDeviceName;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.watch_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect Wearables',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navyAnchor,
                        ),
                      ),
                      Text(
                        'Direct Bluetooth & Cloud Sync',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.navyAnchor,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Bluetooth Watches'),
                Tab(text: 'Health Connect & Cloud'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBluetoothTab(context, isBleConnected, connectedName, activityVm),
                _buildCloudWearablesTab(context),
              ],
            ),
          ),

          // Clinical FHIR Footnote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.activeGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Streaming to https://fhir.drgodly.com/api/v1/vitals/ · HL7 FHIR R4',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab(
    BuildContext context,
    bool isConnected,
    String? connectedName,
    ActivityViewModel activityVm,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Smartwatch compatibility notice
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.navyAnchor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Using boAt, Fire-Boltt, or Noise? These watches sync via their companion app (boAt Crest) to Android Health Connect. Switch to the "Health Connect & Cloud" tab above!',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textPrimary, height: 1.35),
                ),
              ),
            ],
          ),
        ),

        // Connected device status card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConnected ? AppColors.activeGreen : AppColors.borderSubtle,
              width: isConnected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFF0F3924) : AppColors.navyAnchor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Active Watch Connected' : 'Direct Bluetooth LE Engine',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isConnected ? AppColors.activeGreen : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isConnected ? 'STREAMING' : 'READY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isConnected ? Colors.white : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isConnected) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.activeGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connectedName ?? 'Smartwatch',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'GATT 0x180D / 0x2A37 Continuous',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<int>(
                            stream: _bleService.heartRateStream,
                            initialData: _bleService.latestHeartRate,
                            builder: (ctx, snapshot) {
                              final bpm = snapshot.data ?? 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    bpm > 0 ? '$bpm' : '--',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  Text(
                                    'BPM',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 18),
                          label: Text(
                            'Disconnect Watch',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.redAccent),
                          ),
                          onPressed: () => activityVm.disconnectBleDevice(),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Pair your boAt, Fire-Boltt, Noise, or Bluetooth smartwatch directly. No companion app or Google Fit required.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.bluetooth_searching_rounded, size: 20),
                          label: Text(
                            _isScanning ? 'Scanning for Nearby Watches...' : 'Scan for Nearby Watches',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          onPressed: _isScanning ? null : _startBleScan,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Discovered devices list
        if (_scanResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Text(
                  'DISCOVERED DEVICES',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_scanResults.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._scanResults.map((result) {
            final device = result.device;
            final name = device.platformName.isNotEmpty ? device.platformName : 'Bluetooth Device';
            final isConnecting = _connectingDeviceId == device.remoteId.str;
            final isCurrentDevice = _bleService.connectedDevice?.remoteId.str == device.remoteId.str;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.watch_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'RSSI: ${result.rssi} dBm · ${device.remoteId.str.substring(0, 8)}...',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentDevice)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.activeGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Connected',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.activeGreen,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyAnchor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: isConnecting ? null : () => _connectToDevice(device),
                      child: isConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Connect',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCloudWearablesTab(BuildContext context) {
    final connections = _owService.connections;
    final activityVm = context.watch<ActivityViewModel>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ==========================================
        // SECTION 1: PART A (ON-DEVICE HEALTH CONNECT BRIDGE)
        // ==========================================
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.activeGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PART A · ACTIVE DEMO',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.activeGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'On-Device Watch Bridge',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navyAnchor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Hero Card: Android Health Connect
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activityVm.isOpenWearablesSynced ? AppColors.activeGreen : AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34A853).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF34A853), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Android Health Connect',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navyAnchor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (activityVm.isOpenWearablesSynced)
                              const Icon(Icons.check_circle_rounded, color: AppColors.activeGreen, size: 16),
                          ],
                        ),
                        Text(
                          'boAt · Fire-Boltt · Noise · Samsung · Zepp',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Collects Resting HR, HRV, Steps, and Sleep from your watch companion app (e.g., boAt Crest) via Android Health Connect with zero external server required.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Client-side SDK · No Docker',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyAnchor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: Text(
                      activityVm.isOpenWearablesSynced ? 'Sync Again' : 'Sync Now',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      final vm = Provider.of<ActivityViewModel>(context, listen: false);
                      await _owService.connectProvider(WearableProviderType.healthConnect);
                      final success = await vm.syncOpenWearablesVitals('Android Health Connect');
                      if (context.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.activeGreen,
                              content: Text(
                                'Live watch data synced! Resting HR: ${vm.dashboardHr.toInt()} bpm from ${_owService.lastSyncSource} pushed to FHIR server.',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFB45309),
                              duration: const Duration(seconds: 6),
                              content: Text(
                                'No watch records in Health Connect yet (0 records found). Ensure your watch is paired with boAt Crest and synced to Health Connect, then tap Sync again!',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ==========================================
        // SECTION 2: PART B (CLOUD SERVER INTEGRATION)
        // ==========================================
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PART B · FUTURE ROADMAP',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB45309),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Cloud Wearables Server',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navyAnchor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Info Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_outlined, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Requires Open-Wearables server/Docker container for OAuth 2.0 webhooks and token management (Garmin, WHOOP, Oura).',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Cloud Providers list (excluding healthConnect which is in Part A)
        ...[
          WearableProviderType.garmin,
          WearableProviderType.whoop,
          WearableProviderType.oura,
          WearableProviderType.fitbit,
        ].map((type) {
          final info = connections[type];
          final isConnected = info?.isConnected == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected ? AppColors.activeGreen : AppColors.borderSubtle,
                width: isConnected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _getProviderColor(type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getProviderIcon(type), color: _getProviderColor(type), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        type.category,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.activeGreen),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await _owService.disconnectProvider(type);
                      setState(() {});
                    },
                    child: Text(
                      'Linked',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.activeGreen,
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final vm = Provider.of<ActivityViewModel>(context, listen: false);
                      await _owService.connectProvider(type);
                      await vm.syncOpenWearablesVitals(type.displayName);
                      if (context.mounted) {
                        setState(() {});
                      }
                    },
                    child: Text(
                      'Link',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  IconData _getProviderIcon(WearableProviderType type) {
    switch (type) {
      case WearableProviderType.garmin:
        return Icons.navigation_rounded;
      case WearableProviderType.whoop:
        return Icons.fitness_center_rounded;
      case WearableProviderType.oura:
        return Icons.bedtime_rounded;
      case WearableProviderType.fitbit:
        return Icons.directions_run_rounded;
      case WearableProviderType.healthConnect:
        return Icons.health_and_safety_rounded;
      case WearableProviderType.appleHealth:
        return Icons.favorite_rounded;
    }
  }

  Color _getProviderColor(WearableProviderType type) {
    switch (type) {
      case WearableProviderType.garmin:
        return const Color(0xFF007CC3);
      case WearableProviderType.whoop:
        return const Color(0xFFE51A4B);
      case WearableProviderType.oura:
        return const Color(0xFF708090);
      case WearableProviderType.fitbit:
        return const Color(0xFF00B0B9);
      case WearableProviderType.healthConnect:
        return const Color(0xFF34A853);
      case WearableProviderType.appleHealth:
        return const Color(0xFFFF2D55);
    }
  }
}
