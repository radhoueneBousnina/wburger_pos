import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_models.dart';
import '../models/stock_models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_constants.dart';
import '../../core/services/monitoring_service.dart';
import '../../core/services/receipt_printer_service.dart';
import 'package:dio/dio.dart';

part 'app_providers/auth_providers.dart';
part 'app_providers/session_providers.dart';
part 'app_providers/catalog_providers.dart';
part 'app_providers/cart_providers.dart';
part 'app_providers/order_providers.dart';
part 'app_providers/stock_providers.dart';
part 'app_providers/purchase_providers.dart';
part 'app_providers/warmup_providers.dart';
part 'app_providers/drawer_monitor_providers.dart';
part 'app_providers/test_mode_providers.dart';

// ============================================================
// AUTH PROVIDER
// ============================================================
