import 'package:flutter/material.dart';

class ApiErrorModel {
  final int? statusCode;
  final String? message;
  final List<String> errors;
  final IconData? icon;

  ApiErrorModel({
    required this.statusCode,
    required this.message,
    required this.errors,
    required this.icon,
  });

  /// Factory constructor to build from JSON
  factory ApiErrorModel.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    final List<String> parsedErrors =
        (json['errors'] as List?)?.map((e) => e.toString()).toList() ?? [];

    // fallback message: prefer "message", fallback to joined errors
    final String? resolvedMessage =
        (json['message'] as String?) ??
        (parsedErrors.isNotEmpty ? parsedErrors.join('\n') : null);

    return ApiErrorModel(
      statusCode: statusCode,
      message: resolvedMessage,
      errors: parsedErrors,
      icon: Icons.error,
    );
  }
}