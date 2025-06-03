import 'package:flutter/material.dart';
import 'package:codmgo2/theme/text_theme.dart';
import 'package:codmgo2/theme/appbar_theme.dart';
import 'package:codmgo2/theme/checkbox_theme.dart';
import 'elevated_button_theme.dart';


class AppTheme{
  AppTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'poppins',
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    textTheme: CTextTheme.lightTextTheme,
    appBarTheme: CAppBarTheme.lightAppBarTheme,
    checkboxTheme: CCheckBoxTheme.lightCheckboxTheme,
    elevatedButtonTheme: CElevatedButtonTheme.lightElevatedButtonTheme,
  );


  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'poppins',
    brightness: Brightness.dark,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.black,
    textTheme: CTextTheme.darkTextTheme,
    appBarTheme: CAppBarTheme.darkAppBarTheme,
    checkboxTheme: CCheckBoxTheme.darkCheckboxTheme,
    elevatedButtonTheme: CElevatedButtonTheme.darkElevatedButtonTheme,
  );

}