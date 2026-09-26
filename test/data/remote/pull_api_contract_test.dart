import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/app_exception.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/remote/dto/pull_changes_response_dto.dart';

void main() {
  group('Pull API Contract & Parsing Tests', () {
    test('1. Deserializes PullChangesResponseDto correctly', () {
      final json = {
        'changes': [
          {
            'sequence': 101,
            'operation_id': 'op-1',
            'entity_type': 'customer',
            'entity_id': 'c-1',
            'operation_type': 'create',
            'payload': {'name': 'Ali', 'phone': '01000000001'},
            'server_version': 1,
            'created_at': '2026-09-17T15:30:00.000Z',
          },
          {
            'sequence': 102,
            'operation_id': 'op-2',
            'entity_type': 'payment',
            'entity_id': 'p-1',
            'operation_type': 'create',
            'payload': {'order_id': 'o-1', 'amount': 5000},
            'server_version': null,
            'created_at': '2026-09-17T15:31:00.000Z',
          },
        ],
        'has_more': true,
        'latest_sequence': 150,
      };

      final dto = PullChangesResponseDto.fromJson(json);

      expect(dto.changes.length, equals(2));
      expect(dto.hasMore, isTrue);
      expect(dto.latestSequence, equals(150));

      final first = dto.changes[0];
      expect(first.sequence, equals(101));
      expect(first.operationId, equals('op-1'));
      expect(first.entityType, equals('customer'));
      expect(first.entityId, equals('c-1'));
      expect(first.operationType, equals('create'));
      expect(first.payload['name'], equals('Ali'));
      expect(first.serverVersion, equals(1));
      expect(first.createdAt.toIso8601String(), contains('2026-09-17'));

      final second = dto.changes[1];
      expect(second.sequence, equals(102));
      expect(second.operationId, equals('op-2'));
      expect(second.serverVersion, isNull);
    });

    test('2. SyncRemoteApi issues GET /api/v1/sync/changes with after and limit', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.supabase.co'));
      RequestOptions? capturedOptions;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'changes': [],
                  'has_more': false,
                  'latest_sequence': 0,
                },
              ),
            );
          },
        ),
      );

      final api = SyncRemoteApi(dio);
      await api.getChanges(after: 42, limit: 50);

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.method, equals('GET'));
      expect(capturedOptions!.path, equals('/api/v1/sync/changes'));
      expect(capturedOptions!.queryParameters['after'], equals(42));
      expect(capturedOptions!.queryParameters['limit'], equals(50));
    });

    test('3. SyncRemoteDataSource maps 200 OK response into PullChangesResponseDto', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.supabase.co'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'changes': [
                    {
                      'sequence': 1,
                      'operation_id': 'op-c',
                      'entity_type': 'customer',
                      'entity_id': 'c-1',
                      'operation_type': 'create',
                      'payload': {'name': 'Ahmed'},
                      'server_version': 1,
                      'created_at': '2026-09-17T12:00:00.000Z',
                    },
                  ],
                  'has_more': false,
                  'latest_sequence': 1,
                },
              ),
            );
          },
        ),
      );

      final dataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));
      final result = await dataSource.getChanges(after: 0, limit: 100);

      expect(result.changes.length, equals(1));
      expect(result.changes.first.sequence, equals(1));
      expect(result.hasMore, isFalse);
      expect(result.latestSequence, equals(1));
    });

    test('4. SyncRemoteDataSource maps HTTP 410 to CursorTooOldException distinctly', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.supabase.co'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 410,
                  data: {
                    'error': 'CURSOR_TOO_OLD',
                    'message': 'Client cursor has expired; full resync required.',
                    'oldest_available_sequence': 500,
                  },
                ),
              ),
            );
          },
        ),
      );

      final dataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));

      expect(
        () => dataSource.getChanges(after: 10, limit: 100),
        throwsA(
          isA<CursorTooOldException>()
              .having((e) => e.oldestAvailableSequence, 'oldestAvailableSequence', equals(500))
              .having((e) => e.message, 'message', contains('Client cursor has expired')),
        ),
      );
    });

    test('5. SyncRemoteDataSource propagates generic network errors as DioException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.supabase.co'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
                message: 'Connection timed out',
              ),
            );
          },
        ),
      );

      final dataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));

      expect(
        () => dataSource.getChanges(after: 10),
        throwsA(isA<DioException>().having((e) => e.type, 'type', equals(DioExceptionType.connectionTimeout))),
      );
    });
  });
}
