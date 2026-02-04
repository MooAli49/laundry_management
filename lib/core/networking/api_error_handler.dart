import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:laundry_management/core/networking/api_error_factory.dart';
import 'package:laundry_management/core/networking/api_error_model.dart';
import 'package:laundry_management/core/networking/dio_exception_type_extension.dart';
import 'package:laundry_management/core/networking/local_status_codes.dart';

class ApiErrorHandler {
  static ApiErrorModel handle(dynamic e) {
    if (e is Exception) {
      if (e is DioException) {
        return e.when(
          connectionError: () => ApiErrorModel(
            message:
                "No internet connection. Please check your Wi-Fi or mobile data.",
            errors: const [],
            icon: Icons.wifi_off,
            statusCode: LocalStatusCodes.connectionError,
          ),
          connectionTimeout: () => ApiErrorModel(
            message:
                "The connection took too long. Try checking your internet or try again later.",
            icon: Icons.timer_off,
            statusCode: LocalStatusCodes.connectionTimeout,
            errors: const [],
          ),
          sendTimeout: () => ApiErrorModel(
            message: "Request timed out while sending data. Please try again.",
            icon: Icons.send,
            statusCode: LocalStatusCodes.sendTimeout,
            errors: const [],
          ),
          receiveTimeout: () => ApiErrorModel(
            message: "Server took too long to respond. Please try again later.",
            icon: Icons.downloading,
            statusCode: LocalStatusCodes.receiveTimeout,
            errors: const [],
          ),
          badCertificate: () => ApiErrorModel(
            message:
                "Security issue detected with the server. Connection not secure.",
            icon: Icons.security,
            statusCode: LocalStatusCodes.badCertificate,
            errors: const [],
          ),
          badResponse: () {
            final data = e.response?.data;

            if (data is Map<String, dynamic>) {
              return ApiErrorModel.fromJson(
                data,
                statusCode: e.response?.statusCode,
              );
            }

            if (data is List) {
              // backend returned a list of errors directly
              final parsedErrors = data.map((e) => e.toString()).toList();
              return ApiErrorModel(
                statusCode: e.response?.statusCode,
                message: parsedErrors.join('\n'),
                errors: parsedErrors,
                icon: Icons.error,
              );
            }

            return ApiErrorFactory.defaultError;
          },
          cancel: () => ApiErrorModel(
            message: "The request was cancelled. Please try again.",
            icon: Icons.cancel,
            statusCode: LocalStatusCodes.cancel,
            errors: const [],
          ),
          unknown: () => ApiErrorModel(
            message:
                "Something went wrong. Please check your connection and try again.",
            icon: Icons.error_outline,
            statusCode: LocalStatusCodes.unknown,
            errors: const [],
          ),
        );
      }
    }
    return ApiErrorFactory.defaultError;
  }
}
