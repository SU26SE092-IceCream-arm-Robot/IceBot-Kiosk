import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/core/network/dio_client.dart';
import 'package:icebot_kiosk/features/kiosk/data/models/runtime_menu_models.dart';

class MenuRepository {
  MenuRepository(this._client);

  final DioClient _client;

  Future<RuntimeMenuResult> getRuntimeMenu(String kioskId) async {
    final result = await _client.getResult<RuntimeMenuResult>(
      '/api/v1/kiosks/$kioskId/runtime-menu',
      fromJson: RuntimeMenuResult.fromJson,
    );

    final menu = result.data;
    if (menu == null) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả về menu kiosk.',
      );
    }

    return menu;
  }
}
