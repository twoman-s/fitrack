import 'package:dio/dio.dart';
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
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        // Pick the first field message or the 'detail' field
        final detail = data['detail'] ?? data.values.first;
        if (detail is List && detail.isNotEmpty) return detail.first.toString();
        return detail.toString();
      }
      if (error.response?.statusCode == 409) {
        return 'You already have an active goal. Complete it first.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Network error. Please check your connection.';
      }
    }
    if (error is Exception) {
      return error.toString();
    }
    return 'An unexpected error occurred.';
  }

  /// Returns true when the server rejected the request because KYC is not done.
  static bool isKycRequired(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] == 'KYC_REQUIRED') return true;
    }
    return false;
  }
}
