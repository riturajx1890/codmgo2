import 'package:codmgo2/styles/sizes.dart';
import 'package:flutter/material.dart';

class CSpacingStyle {
  static const EdgeInsetsGeometry paddingWithAppBarHeight = EdgeInsets.only(
    top: CSizes.appBarHeight,
    left: CSizes.defaultSpace,
    bottom: CSizes.defaultSpace,
    right: CSizes.defaultSpace,
  );
}