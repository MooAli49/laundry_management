import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../orders/presentation/cubit/bluetooth_printer_cubit.dart';
import '../../../orders/presentation/cubit/bluetooth_printer_state.dart';
import '../../../orders/presentation/services/bluetooth_printer/bluetooth_printer_service.dart';
import '../../../orders/presentation/services/bluetooth_printer/printer_profile.dart';
import '../../../orders/presentation/services/bluetooth_printer/thermal_command_builder.dart';
import '../../../orders/presentation/services/bluetooth_printer/thermal_invoice_renderer.dart';

/// Settings section for configuring the Bluetooth thermal printer.
///
/// Displayed as a tab in the main settings screen.
/// Integrated into the existing [SettingsScreen] tab navigation at index 8.
class BluetoothPrinterSection extends StatelessWidget {
  const BluetoothPrinterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BluetoothPrinterCubit>.value(
      value: getIt<BluetoothPrinterCubit>(),
      child: const _BluetoothPrinterSectionContent(),
    );
  }
}

class _BluetoothPrinterSectionContent extends StatefulWidget {
  const _BluetoothPrinterSectionContent();

  @override
  State<_BluetoothPrinterSectionContent> createState() =>
      _BluetoothPrinterSectionContentState();
}

class _BluetoothPrinterSectionContentState
    extends State<_BluetoothPrinterSectionContent> {
  bool _isTestPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: BlocBuilder<BluetoothPrinterCubit, BluetoothPrinterState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                AppSpacing.gapLg,
                // Connected printer card
                if (state.isConnected && state.connectedProfile != null)
                  _buildConnectedCard(context, state)
                else if (state.savedProfile != null && !state.isConnected)
                  _buildSavedProfileCard(context, state),
                AppSpacing.gapLg,
                // Scanner
                _buildScannerCard(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الطابعة الحرارية',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'إعداد طابعة البلوتوث الحرارية لطباعة الفواتير مباشرةً',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Connected / saved printer cards
  // ---------------------------------------------------------------------------

  Widget _buildConnectedCard(
    BuildContext context,
    BluetoothPrinterState state,
  ) {
    final profile = state.connectedProfile!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
              ),
              AppSpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'الطابعة متصلة  ·  ${profile.paperWidth.label}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapHorizontalMd,
              AppButton(
                label: 'طباعة تجريبية',
                icon: Icons.print_outlined,
                isLoading: _isTestPrinting,
                onPressed: _isTestPrinting
                    ? null
                    : () => _handleTestPrint(profile),
              ),
              AppSpacing.gapHorizontalSm,
              AppButton(
                label: 'قطع الاتصال',
                variant: AppButtonVariant.outline,
                onPressed: () =>
                    context.read<BluetoothPrinterCubit>().disconnect(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleTestPrint(PrinterProfile profile) async {
    if (_isTestPrinting) return;
    setState(() => _isTestPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<BluetoothPrinterCubit>();

    try {
      final imageBytes = await ThermalInvoiceRenderer.renderTestReceiptToImage(
        context: context,
        profile: profile,
      );

      final command = await ThermalCommandBuilder.buildPrintCommand(
        imageBytes: imageBytes,
        profile: profile,
        blockHeight: 256,
      );

      if (!mounted) return;
      await cubit.write(command);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الفاتورة التجريبية إلى الطابعة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('فشلت الطباعة التجريبية: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestPrinting = false);
      }
    }
  }

  Widget _buildSavedProfileCard(
    BuildContext context,
    BluetoothPrinterState state,
  ) {
    final profile = state.savedProfile!;
    final isConnecting = state.isConnecting;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connectionStateColor(state.connectionState),
            ),
          ),
          AppSpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _connectionStateLabel(state.connectionState),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (state.connectionError != null)
                  Text(
                    state.connectionError!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapHorizontalMd,
          AppButton(
            label: 'اتصال',
            isLoading: isConnecting,
            onPressed: isConnecting ? null : () => _reconnect(context, profile),
          ),
          AppSpacing.gapHorizontalMd,
          AppButton(
            label: 'حذف',
            variant: AppButtonVariant.outline,
            onPressed: () =>
                context.read<BluetoothPrinterCubit>().forgetPrinter(),
          ),
        ],
      ),
    );
  }

  void _reconnect(BuildContext context, PrinterProfile profile) {
    final discovered = DiscoveredPrinter(
      name: profile.name,
      address: profile.address,
    );
    context.read<BluetoothPrinterCubit>().connect(
      discovered,
      paperWidth: profile.paperWidth,
      protocol: profile.protocol,
    );
  }

  // ---------------------------------------------------------------------------
  // Scanner card
  // ---------------------------------------------------------------------------

  Widget _buildScannerCard(BuildContext context, BluetoothPrinterState state) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'البحث عن طابعات',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppButton(
                label: state.isScanning ? 'إيقاف البحث' : 'بدء البحث',
                icon: state.isScanning ? null : Icons.search,
                isLoading: state.isScanning,
                onPressed: state.isScanning
                    ? () => context.read<BluetoothPrinterCubit>().stopScan()
                    : () => _startScan(),
              ),
            ],
          ),
          if (state.scanError != null) ...[
            AppSpacing.gapMd,
            _errorBanner(state.scanError!),
          ],
          if (!state.isScanning && state.discoveredPrinters.isEmpty) ...[
            AppSpacing.gapLg,
            Center(
              child: Text(
                'اضغط "بدء البحث" للعثور على الطابعات القريبة عبر البلوتوث',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.gapLg,
          ],
          if (state.discoveredPrinters.isNotEmpty) ...[
            AppSpacing.gapMd,
            ...state.discoveredPrinters.map(
              (p) => _printerListTile(context, p, state),
            ),
          ],
        ],
      ),
    );
  }

  void _startScan() {
    final cubit = context.read<BluetoothPrinterCubit>();
    cubit.requestPermissions().then((_) {
      if (mounted) {
        cubit.startScan();
      }
    });
  }

  Widget _printerListTile(
    BuildContext context,
    DiscoveredPrinter printer,
    BluetoothPrinterState state,
  ) {
    final isCurrentlyConnecting =
        state.isConnecting &&
        state.connectedProfile?.address == printer.address;

    return ListTile(
      leading: const Icon(Icons.print_outlined, color: AppColors.primary),
      title: Text(printer.name, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        printer.address,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
      ),
      trailing: isCurrentlyConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : AppButton(
              label: 'اتصال',
              onPressed: () => context.read<BluetoothPrinterCubit>().connect(
                printer,
                paperWidth: ThermalPaperWidth.w80,
                protocol: PrinterProtocol.auto,
              ),
            ),
      contentPadding: EdgeInsets.zero,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }

  Color _connectionStateColor(BluetoothPrinterConnectionState state) {
    switch (state) {
      case BluetoothPrinterConnectionState.connected:
        return AppColors.success;
      case BluetoothPrinterConnectionState.connecting:
        return AppColors.warning;
      case BluetoothPrinterConnectionState.connectionFailed:
      case BluetoothPrinterConnectionState.printFailed:
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _connectionStateLabel(BluetoothPrinterConnectionState state) {
    switch (state) {
      case BluetoothPrinterConnectionState.connected:
        return 'الطابعة متصلة';
      case BluetoothPrinterConnectionState.connecting:
        return 'جاري الاتصال بالطابعة...';
      case BluetoothPrinterConnectionState.scanning:
        return 'جاري البحث عن الطابعات...';
      case BluetoothPrinterConnectionState.connectionFailed:
        return 'فشل الاتصال بالطابعة';
      case BluetoothPrinterConnectionState.bluetoothOff:
        return 'البلوتوث مغلق';
      case BluetoothPrinterConnectionState.permissionDenied:
        return 'صلاحية البلوتوث مطلوبة';
      case BluetoothPrinterConnectionState.disconnected:
        return 'تم قطع الاتصال بالطابعة';
      case BluetoothPrinterConnectionState.printing:
        return 'جاري الطباعة...';
      case BluetoothPrinterConnectionState.printFailed:
        return 'فشلت عملية الطباعة';
      case BluetoothPrinterConnectionState.idle:
        return 'غير متصل';
    }
  }
}
