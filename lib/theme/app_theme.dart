import 'package:flutter/material.dart';

class AppTheme {
  // 颜色
  static const Color primaryColor = Color(0xFF6B8CEF);
  static const Color secondaryColor = Color(0xFF2D3142);
  static const Color backgroundColor1 = Color(0xFFE0EAFC);
  static const Color backgroundColor2 = Color(0xFFCFDEF3);
  static const Color cardColor = Colors.white;
  static const Color inputBackgroundColor = Color(0xFFF5F7FA);
  static const Color textColor = Color(0xFF2D3142);
  static const Color subtitleColor = Color(0xFF9CA3AF);

  // 渐变
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      backgroundColor1,
      backgroundColor2,
    ],
  );

  // 圆角
  static const double cardRadius = 24.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 16.0;

  // 阴影
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // 文字样式
  static const TextStyle titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textColor,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: textColor,
  );

  static TextStyle hintStyle = TextStyle(
    fontSize: 14,
    color: Colors.grey[400],
  );

  // 卡片装饰
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(cardRadius),
    boxShadow: cardShadow,
  );

  // 输入框装饰
  static BoxDecoration inputDecoration = BoxDecoration(
    color: inputBackgroundColor,
    borderRadius: BorderRadius.circular(inputRadius),
  );

  // 按钮样式
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  );

  // 图标按钮装饰
  static BoxDecoration iconButtonDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(buttonRadius),
    boxShadow: cardShadow,
  );
} 