// lib/src/toolbar/vertical_divider_widget.dart

import 'package:flutter/material.dart';

class DividerVertical extends StatelessWidget {
  final double height;
  final double width;
  final double thickness;
  final Color color;

  const DividerVertical({
    super.key,
    this.height = 36.0,
    this.width = 0.5,
    this.thickness = 0.5,
    this.color = const Color(0xFFD1D5DB), // Colors.grey.shade300
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: VerticalDivider(
        width: width,
        thickness: thickness,
        color: color,
      ),
    );
  }
}
