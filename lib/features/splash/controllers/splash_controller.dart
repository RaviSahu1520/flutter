import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/debug_logger.dart';

class SplashController extends GetxController with GetTickerProviderStateMixin {
  final currentStep = 0.obs;

  late AnimationController fadeController;
  late AnimationController slideController;
  late AnimationController scaleController;
  late AnimationController rotationController;

  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> rotationAnimation;

  late PageController pageController;

  int autoAdvanceSeconds = 4;

  // --- FIX: Add a Timer and a disposed flag for robust lifecycle management ---
  Timer? _timer;
  bool _isDisposed = false;
  bool _hasNavigated = false;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _startAutoAdvance();
  }

  void _initializeAnimations() {
    fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    slideController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    scaleController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    rotationController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: fadeController, curve: Curves.easeInOut));
    slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: slideController, curve: Curves.elasticOut));
    scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: scaleController, curve: Curves.bounceOut));
    rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: rotationController, curve: Curves.linear));

    pageController = PageController();
    _startStepAnimations();
  }

  void _startStepAnimations() {
    if (_isDisposed) return;
    fadeController.forward();
    slideController.forward();
    scaleController.forward();
    rotationController.repeat();
  }

  void _startAutoAdvance() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer(Duration(seconds: autoAdvanceSeconds), () {
      if (!_isDisposed) {
        nextStep();
      }
    });
  }

  void nextStep() {
    if (currentStep.value < 3) {
      currentStep.value++;
      _animateToStep(currentStep.value);
      _resetAndStartAnimations();
      _startAutoAdvance();
    } else {
      _checkAuthenticationAndNavigate();
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      _animateToStep(currentStep.value);
      _resetAndStartAnimations();
    }
  }

  void _animateToStep(int step) {
    if (pageController.hasClients) {
      pageController.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _resetAndStartAnimations() {
    if (_isDisposed) return;
    fadeController.reset();
    slideController.reset();
    scaleController.reset();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isDisposed) {
        _startStepAnimations();
      }
    });
  }

  void skipToHome() {
    _checkAuthenticationAndNavigate();
  }

  void _checkAuthenticationAndNavigate() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    try {
      if (!Get.isRegistered<AuthController>()) {
        Get.offAllNamed(AppRoutes.onboarding);
        return;
      }

      final authController = Get.find<AuthController>();
      await Future.delayed(const Duration(milliseconds: 500));

      if (authController.isAuthenticated) {
        final currentUser = authController.currentUser.value;
        if (currentUser != null && _isProfileComplete(currentUser)) {
          Get.offAllNamed(AppRoutes.dashboard);
        } else {
          Get.offAllNamed(AppRoutes.profileCompletion);
        }
      } else {
        Get.offAllNamed(AppRoutes.onboarding);
      }
    } catch (e, stackTrace) {
      DebugLogger.error('Error during splash navigation', e, stackTrace);
      Get.offAllNamed(AppRoutes.onboarding);
    }
  }

  bool _isProfileComplete(dynamic user) {
    if (user == null) return false;
    try {
      return user.name?.isNotEmpty == true && user.email?.isNotEmpty == true;
    } catch (e) {
      return false;
    }
  }

  @override
  void onClose() {
    // --- FIX: Set flag and cancel timer before disposing controllers ---
    _isDisposed = true;
    _timer?.cancel();
    fadeController.dispose();
    slideController.dispose();
    scaleController.dispose();
    rotationController.dispose();
    pageController.dispose();
    super.onClose();
  }
} 