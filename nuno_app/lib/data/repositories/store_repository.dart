import '../../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/store_models.dart';

/// /api/v1/store, /inventory, /balance, /rewards/daily
class StoreRepository {
  final ApiClient _api;

  StoreRepository(this._api);

  Future<List<StoreItem>> getStore() async {
    final data = J.list(await _api.get('/store'));
    final items = data.map((e) => StoreItem.fromJson(J.map(e))).toList();

    // Defensive: keep the first of any repeated itemId, so a duplicate in the
    // catalogue cannot produce two tiles that fight over the same purchase.
    final seen = <String>{};
    return items.where((i) => seen.add(i.itemId)).toList();
  }

  Future<Inventory> getInventory() async =>
      Inventory.fromJson(J.map(await _api.get('/inventory')));

  Future<int> getBalance() async {
    final data = J.map(await _api.get('/balance'));
    return J.int_(data['coins']);
  }

  Future<void> purchase(StoreItem item) =>
      _api.post('/store/purchase', body: item.toPurchasePayload());

  /// Makes an owned cosmetic the active one for its type.
  Future<void> equip(StoreItem item) => _api.post(
        '/store/equip',
        body: {'cosmeticId': item.itemId, 'cosmeticType': item.type.wire},
      );

  Future<void> claimDailyReward() => _api.post('/rewards/daily');
}
