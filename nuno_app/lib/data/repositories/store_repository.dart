import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/store_models.dart';

/// /api/v1/store, /inventory, /balance, /rewards/daily
class StoreRepository {
  final ApiClient _api;

  StoreRepository(this._api);

  Future<List<StoreItem>> getStore() async {
    final data = J.list(await _api.get('/store'));
    final items = data.map((e) => StoreItem.fromJson(J.map(e))).toList();

    // The backend seed list contains duplicate itemIds; keep the first of each.
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

  Future<void> claimDailyReward() => _api.post('/rewards/daily');
}
