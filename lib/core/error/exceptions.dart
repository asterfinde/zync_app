// lib/core/error/exceptions.dart
// Estas son las excepciones que la capa de datos lanzará.

class ServerException implements Exception {
  final String? message;
  ServerException({this.message});
}

class CacheException implements Exception {}
