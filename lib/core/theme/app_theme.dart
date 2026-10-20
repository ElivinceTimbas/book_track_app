import 'package:flutter/material.dart';

const ink = Color(0xFF2B3529);
const olive = Color(0xFF526348);
const paper = Color(0xFFF8F7F3);
const muted = Color(0xFF85877D);
const line = Color(0xFFE9E9E1);
const rust = Color(0xFFC47C54);
const softOlive = Color(0xFFEDF0E7);

ThemeData folioTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'DM Sans',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: olive,
    primary: olive,
    surface: Colors.white,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'DM Sans',
    bodyColor: ink,
    displayColor: ink,
  ),
  dividerColor: line,
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: olive,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: paper,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: olive),
    ),
  ),
);

TextStyle editorial(
  double size, {
  Color color = ink,
  FontWeight weight = FontWeight.w400,
  double height = 1.2,
}) => TextStyle(
  fontFamily: 'Lora',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: -0.7,
);
