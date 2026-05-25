import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CompanyLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final IconData fallbackIcon;

  const CompanyLogo({
    super.key,
    this.logoUrl,
    this.size = 48,
    this.fallbackIcon = Icons.business,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                fallbackIcon,
                color: AppColors.primary,
                size: size * 0.55,
              ),
            )
          : Icon(
              fallbackIcon,
              color: AppColors.primary,
              size: size * 0.55,
            ),
    );
  }
}
