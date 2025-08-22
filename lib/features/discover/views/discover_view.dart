import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/discover_controller.dart';
import '../../../core/controllers/filter_service.dart';
import '../../../core/controllers/location_controller.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../../widgets/common/loading_states.dart';
import '../../../../widgets/common/error_states.dart';
import '../widgets/property_swipe_card.dart';

class DiscoverView extends GetView<DiscoverController> {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final filterService = Get.find<FilterService>();
    // Access the global LocationController
    final locationController = Get.find<LocationController>();

    return Obx(() => Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBackground,
        elevation: 0,
        leading: _buildLocationDisplay(locationController),
        title: Text(
          '360ghar',
          style: TextStyle(
            color: AppColors.appBarText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Filters button
          Obx(() => IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.tune,
                  color: AppColors.iconColor,
                ),
                if (filterService.activeFiltersCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${filterService.activeFiltersCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => Get.toNamed('/filters'),
          )),
        ],
      ),
      body: Obx(() {
        // Show different states based on controller state
        switch (controller.state.value) {
          case DiscoverState.loading:
            return _buildLoadingState();
            
          case DiscoverState.error:
            return _buildErrorState();
            
          case DiscoverState.empty:
            return _buildEmptyState();
            
          case DiscoverState.loaded:
          case DiscoverState.prefetching:
            return _buildSwipeInterface(context);
            
          default:
            return _buildLoadingState();
        }
      }),
    ));
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Show loading progress if available
        Obx(() {
          if (controller.isPrefetching.value) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading more properties...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        }),
        
        // Main loading
        Expanded(
          child: LoadingStates.swipeCardSkeleton(),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Obx(() {
      final errorMessage = controller.error.value;
      if (errorMessage == null) return const SizedBox();

      // Check if this is a backend server not running error
      if (errorMessage.contains('Backend server is not running') ||
          errorMessage.contains('backend server is not running') ||
          errorMessage.contains('request not found') ||
          errorMessage.contains('404')) {
        return ErrorStates.backendServerNotRunning(
          onRetry: controller.retryLoading,
          onUseMockData: () {
            // Force refresh to trigger mock data fallback
            controller.refreshDeck();
          },
        );
      }

      // Try to map the error for better user experience
      try {
        final exception = ErrorMapper.mapApiError(Exception(errorMessage));
        return ErrorStates.genericError(
          error: exception,
          onRetry: controller.retryLoading,
        );
      } catch (e) {
        return ErrorStates.networkError(
          onRetry: controller.retryLoading,
          customMessage: errorMessage,
        );
      }
    });
  }

  Widget _buildEmptyState() {
    return ErrorStates.swipeDeckEmpty(
      onRefresh: controller.refreshDeck,
      onChangeFilters: () => Get.toNamed('/filters'),
    );
  }

  Widget _buildSwipeInterface(BuildContext context) {
    return Stack(
      children: [
        // Main swipe cards
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() => PropertySwipeStack(
              properties: controller.visibleCards, // Use reactive visible cards based on currentIndex
              onSwipeLeft: controller.swipeLeft,
              onSwipeRight: controller.swipeRight,
              onSwipeUp: (property) => controller.viewPropertyDetails(property),
              showSwipeInstructions: controller.totalSwipesInSession.value < 3,
            )),
          ),
        ),
        
        
      ],
    );
  }

  // --- NEW WIDGET: For displaying the current location in the AppBar ---
  Widget _buildLocationDisplay(LocationController locationController) {
    return GestureDetector(
      onTap: () {
        Get.snackbar(
          'Refreshing Location',
          'Getting your current location...',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primaryYellow.withOpacity(0.9),
          colorText: Colors.white,
        );
        locationController.getCurrentLocation(forceRefresh: true);
      },
      child: Obx(() {
        String locationText;
        IconData icon;

        if (locationController.isLoading.value) {
          locationText = 'Getting location...';
          icon = Icons.location_searching;
        } else if (locationController.currentCity.value.isNotEmpty) {
          locationText = locationController.currentCity.value;
          icon = Icons.location_on;
        } else if (locationController.locationError.value.isNotEmpty) {
          locationText = 'Location Error';
          icon = Icons.location_off;
        } else {
          locationText = 'Unknown Location';
          icon = Icons.location_off_outlined;
        }

        return Container(
          padding: const EdgeInsets.only(left: 8, right: 8), // Add space from corners
          constraints: const BoxConstraints(maxWidth: 120), // Limit width to show full names
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.primaryYellow,
                size: 16,
              ),
              const SizedBox(width: 6), // Better spacing
              Expanded( // Use Expanded instead of Flexible for better text display
                child: Text(
                  locationText,
                  style: TextStyle(
                    color: AppColors.appBarText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1, // Single line
                  overflow: TextOverflow.ellipsis, // Only ellipsis if absolutely necessary
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

}