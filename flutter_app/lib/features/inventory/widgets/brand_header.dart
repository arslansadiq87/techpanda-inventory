import 'package:flutter/material.dart';

/// App brand logo widget with custom shadow and rounded corners.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({
    super.key,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220B7775),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/techpanda.png', fit: BoxFit.cover),
    );
  }
}

/// App brand title widget showing the logo, app name, and subtitle.
class BrandTitle extends StatelessWidget {
  final double logoSize;

  const BrandTitle({
    super.key,
    this.logoSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(size: logoSize),
          const SizedBox(width: 10),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tech Panda',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text('Inventory', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

