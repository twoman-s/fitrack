import 'package:flutter/material.dart';

class ErrorHandler {
  static void showSnackBar(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      // Basic Dio error handling
      if (error.toString().contains('DioException')) {
        // Can be improved based on specific dio errors
        return 'Network error occurred. Please check your connection.';
      }
      return error.toString();
    }
    return 'An unexpected error occurred.';
  }
}
