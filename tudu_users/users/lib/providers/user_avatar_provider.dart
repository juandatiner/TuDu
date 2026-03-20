import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the current user's avatar state and notifies listeners whenever
/// it changes (e.g. after a photo-change request is approved).
/// Lives at the top of the widget tree so any screen can react to updates
/// without polling the network again.
class UserAvatarProvider extends ChangeNotifier {
  String? _avatarImage; // base64 data-URI or null
  String _avatarColor = '#78BF32';
  String _avatarIcon = 'person';

  String? get avatarImage => _avatarImage;
  String get avatarColor => _avatarColor;
  String get avatarIcon => _avatarIcon;

  /// Called by home_screen when the socket delivers an approved photo.
  /// Updates in-memory state, saves to SharedPreferences, then notifies.
  Future<void> applyApprovedPhoto({
    required String userEmail,
    required String newAvatarImage,
  }) async {
    _avatarImage = newAvatarImage;
    notifyListeners();

    // Persist so profile/my_data also see the new image on next cold start
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyPrefix = 'profile_${userEmail}_';
      await prefs.setString('${keyPrefix}image', newAvatarImage);
    } catch (e) {
      debugPrint('UserAvatarProvider: failed to persist avatar: $e');
    }
  }

  /// Called by profile_screen / my_data_screen on first load so the
  /// provider stays in sync with whatever the network returned.
  void syncFromNetwork({
    required String? avatarImage,
    required String avatarColor,
    required String avatarIcon,
  }) {
    bool changed = avatarImage != _avatarImage ||
        avatarColor != _avatarColor ||
        avatarIcon != _avatarIcon;
    _avatarImage = avatarImage;
    _avatarColor = avatarColor;
    _avatarIcon = avatarIcon;
    if (changed) notifyListeners();
  }
}
