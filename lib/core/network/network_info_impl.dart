// lib/core/network/network_info_impl.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'network_info.dart';

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    // La versión 5+ de connectivity_plus devuelve una Lista de resultados.
    final result = await connectivity.checkConnectivity();

    // La forma más robusta de verificar es asegurarse de que la lista de resultados
    // NO contenga 'none'. Si no lo contiene, significa que hay al menos una conexión activa.
    if (result.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }
}