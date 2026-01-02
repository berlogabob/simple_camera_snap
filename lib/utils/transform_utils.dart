import 'package:flutter/material.dart';

Offset transformLandmark({
  required double x,
  required double y,
  required int sensorOrientation,
  required int transformMode,
  required Size screenSize,
}) {
  double tx = x;
  double ty = y;

  if (sensorOrientation == 270) {
    final temp = tx;
    tx = ty;
    ty = temp;
  } else if (sensorOrientation == 90) {
    tx = 1.0 - ty;
    ty = tx;
  }

  switch (transformMode) {
    case 1:
      final temp = tx;
      tx = ty;
      ty = 1.0 - temp;
      break;
    case 2:
      final temp = tx;
      tx = 1.0 - ty;
      ty = temp;
      break;
    case 3:
      tx = 1.0 - tx;
      ty = 1.0 - ty;
      break;
  }

  return Offset(tx * screenSize.width, ty * screenSize.height);
}