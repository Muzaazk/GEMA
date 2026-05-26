import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/assets.dart';

class GemaAppBarTitle extends StatelessWidget {
  const GemaAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppAssets.logoPutih,
          height: 65,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        Text(
          'Dashboard',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
