import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';

class VehiclePreference {
  const VehiclePreference({
    required this.vehicleType,
    required this.vehicleName,
    required this.transmissionType,
    required this.transmissionName,
    required this.fareMultiplier,
  });

  final String vehicleType;
  final String vehicleName;
  final String transmissionType;
  final String transmissionName;
  final double fareMultiplier;

  Map<String, dynamic> toMap() => {
        'vehicleType': vehicleType,
        'vehicleName': vehicleName,
        'transmissionType': transmissionType,
        'transmissionName': transmissionName,
        'fareMultiplier': fareMultiplier,
      };
}

class _VehicleType {
  const _VehicleType({
    required this.id,
    required this.name,
    required this.icon,
    required this.multiplier,
  });

  final String id;
  final String name;
  final IconData icon;
  final double multiplier;
}

class _TransmissionType {
  const _TransmissionType({
    required this.id,
    required this.name,
    required this.multiplier,
  });

  final String id;
  final String name;
  final double multiplier;
}

const _vehicleTypes = [
  _VehicleType(id: 'hatchback', name: 'Hatchback', icon: Icons.directions_car_outlined, multiplier: 1.0),
  _VehicleType(id: 'sedan', name: 'Sedan', icon: Icons.directions_car, multiplier: 1.0),
  _VehicleType(id: 'suv', name: 'SUV', icon: Icons.directions_car_filled, multiplier: 1.0),
];

const _transmissionTypes = [
  _TransmissionType(id: 'manual', name: 'Manual', multiplier: 1.0),
  _TransmissionType(id: 'automatic', name: 'Automatic', multiplier: 1.0),
];

typedef VehicleSelectionCallback = void Function(VehiclePreference selection);

class VehicleSelector extends StatefulWidget {
  const VehicleSelector({super.key, required this.onSelectionChange});

  final VehicleSelectionCallback onSelectionChange;

  @override
  State<VehicleSelector> createState() => _VehicleSelectorState();
}

class _VehicleSelectorState extends State<VehicleSelector> {
  String _selectedVehicle = 'hatchback';
  String _selectedTransmission = 'manual';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSelection(_selectedVehicle, _selectedTransmission);
    });
  }

  void _updateSelection(String vehicleId, String transmissionId) {
    final vehicle = _vehicleTypes.firstWhere((v) => v.id == vehicleId);
    final transmission =
        _transmissionTypes.firstWhere((t) => t.id == transmissionId);

    widget.onSelectionChange(
      VehiclePreference(
        vehicleType: vehicleId,
        vehicleName: vehicle.name,
        transmissionType: transmissionId,
        transmissionName: transmission.name,
        fareMultiplier: vehicle.multiplier * transmission.multiplier,
      ),
    );
  }

  String _multiplierLabel(double multiplier) {
    if (multiplier == 1.0) return 'Base';
    return '+${((multiplier - 1) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 425;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Vehicle Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: _vehicleTypes.map((vehicle) {
              final selected = _selectedVehicle == vehicle.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Material(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {
                        setState(() => _selectedVehicle = vehicle.id);
                        _updateSelection(vehicle.id, _selectedTransmission);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.sm,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              vehicle.icon,
                              size: 24,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              vehicle.name,
                              style: TextStyle(
                                fontSize: compact ? 13 : 14,
                                fontWeight:
                                    selected ? FontWeight.bold : FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _multiplierLabel(vehicle.multiplier),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Select Transmission',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: _transmissionTypes.map((transmission) {
              final selected = _selectedTransmission == transmission.id;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: transmission.id == 'manual' ? AppSpacing.md / 2 : 0,
                    left: transmission.id == 'automatic' ? AppSpacing.md / 2 : 0,
                  ),
                  child: Material(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {
                        setState(() => _selectedTransmission = transmission.id);
                        _updateSelection(_selectedVehicle, transmission.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              transmission.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    selected ? FontWeight.bold : FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _multiplierLabel(transmission.multiplier),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
