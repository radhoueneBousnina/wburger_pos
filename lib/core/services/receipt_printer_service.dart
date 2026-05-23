import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models/order_models.dart';
import 'monitoring_service.dart';
import 'receipt_printer_backend_stub.dart'
    if (dart.library.io) 'receipt_printer_backend_io.dart'
    if (dart.library.html) 'receipt_printer_backend_web.dart';

part 'receipt_printer/printer_models.dart';
part 'receipt_printer/receipt_printer_core.dart';
part 'receipt_printer/receipt_ticket_builder.dart';
part 'receipt_printer/esc_pos_ticket_builder.dart';
part 'receipt_printer/plain_text_ticket_builders.dart';
part 'receipt_printer/receipt_formatters.dart';

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
