import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../domain/pozo.dart';

final pozosProvider = FutureProvider<List<PozoSummary>>((ref) async {
  return ref.watch(apiClientProvider).listPozos();
});

final pozoProvider = FutureProvider.family<PozoDetail, String>((ref, id) async {
  return ref.watch(apiClientProvider).getPozo(id);
});
