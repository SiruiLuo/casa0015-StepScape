import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'location_picker.dart';
import 'package:latlong2/latlong.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  LatLng? _startPosition;
  LatLng? _endPosition;
  String? _startAddress;
  String? _endAddress;

  Future<void> _selectLocation(bool isStart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          title: isStart ? '选择起点' : '选择终点',
          initialPosition: isStart ? _startPosition : _endPosition,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (isStart) {
          _startPosition = result['position'] as LatLng;
          _startAddress = result['address'] as String;
        } else {
          _endPosition = result['position'] as LatLng;
          _endAddress = result['address'] as String;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.inputBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.route,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '规划路线',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: AppTheme.iconButtonDecoration.copyWith(
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.history),
                        color: AppTheme.primaryColor,
                        onPressed: () {
                          // 历史记录按钮点击事件
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        decoration: AppTheme.cardDecoration.copyWith(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.inputBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              title: Text(
                                '起点',
                                style: AppTheme.subtitleStyle.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              subtitle: Text(
                                _startAddress ?? '点击选择起点',
                                style: _startAddress != null
                                    ? AppTheme.bodyStyle
                                    : AppTheme.hintStyle,
                              ),
                              onTap: () => _selectLocation(true),
                            ),
                            const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.inputBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.flag,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              title: Text(
                                '终点',
                                style: AppTheme.subtitleStyle.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              subtitle: Text(
                                _endAddress ?? '点击选择终点',
                                style: _endAddress != null
                                    ? AppTheme.bodyStyle
                                    : AppTheme.hintStyle,
                              ),
                              onTap: () => _selectLocation(false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_startPosition != null && _endPosition != null)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: AppTheme.primaryButtonStyle,
                            onPressed: () {
                              // 开始导航
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: Text(
                                '开始导航',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 