import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../models/provider_item.dart';

class ProviderApi {
  static String? _workingBaseUrl;

  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];
    return ApiConfig.candidateUrls;
  }
