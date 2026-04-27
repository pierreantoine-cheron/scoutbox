import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../repositories/tent_repository.dart';

part 'tent_detail_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Tent> tentDetail(Ref ref, String tentId) async {
  return ref.read(tentRepositoryProvider).getTent(tentId);
}
