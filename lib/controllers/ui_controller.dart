// lib/controllers/ui_controller.dart
import 'package:get/get.dart';

class UiController extends GetxController {
  // Titolo predefinito, può essere sovrascritto da schermate specifiche
  var currentScreenName = 'Caricamento...'.obs;

  void setCurrentScreenName(String name) {
    currentScreenName.value = name;
  }
}
