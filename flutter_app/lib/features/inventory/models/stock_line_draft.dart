import 'package:flutter/material.dart';

class StockLineDraft {
  StockLineDraft({required this.component, String quantity = '1'})
    : quantityController = TextEditingController(text: quantity);

  final Map<String, dynamic> component;
  final TextEditingController quantityController;
}
