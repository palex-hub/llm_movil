import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ToolService {
  final String specUrl;
  Map<String, dynamic>? _spec;
  List<Map<String, dynamic>>? _tools;

  ToolService({required this.specUrl});

  List<Map<String, dynamic>>? get tools => _tools;

  Future<List<Map<String, dynamic>>> fetchTools() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(specUrl));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      _spec = jsonDecode(body) as Map<String, dynamic>;
      _tools = _parseTools(_spec!);
      return _tools!;
    } finally {
      client.close();
    }
  }

  List<Map<String, dynamic>> _parseTools(Map<String, dynamic> spec) {
    final paths = spec['paths'] as Map<String, dynamic>? ?? {};
    final schemas = _resolveAllSchemas(spec);
    final tools = <Map<String, dynamic>>[];

    for (final entry in paths.entries) {
      final path = entry.key;
      final methods = entry.value as Map<String, dynamic>;

      if (path == '/' || path == '/health') continue;

      for (final methodEntry in methods.entries) {
        final method = methodEntry.key;
        final operation = methodEntry.value as Map<String, dynamic>;

        if (method != 'get' && method != 'post') continue;

        final operationId = operation['operationId'] as String? ?? '';
        final parts = operationId.split('_');
        if (parts.length < 2) continue;
        final name = '${parts[0]}_${parts[1]}';

        final properties = <String, Map<String, dynamic>>{};
        final required = <String>[];

        if (method == 'get') {
          final params = operation['parameters'] as List<dynamic>? ?? [];
          for (final p in params) {
            final param = p as Map<String, dynamic>;
            final compact = _compactSchema(param['schema'] as Map<String, dynamic>? ?? {});
            if (compact.isNotEmpty) {
              properties[param['name'] as String] = compact;
              if (param['required'] == true) required.add(param['name'] as String);
            }
          }
        } else if (method == 'post') {
          final requestBody = operation['requestBody'] as Map<String, dynamic>?;
          final content = requestBody?['content'] as Map<String, dynamic>?;
          final jsonContent = content?['application/json'] as Map<String, dynamic>?;
          var schema = jsonContent?['schema'] as Map<String, dynamic>? ?? {};
          schema = _resolveRef(schema, schemas);
          final props = schema['properties'] as Map<String, dynamic>? ?? {};
          final reqList = schema['required'] as List<dynamic>? ?? [];
          for (final propEntry in props.entries) {
            final compact = _compactSchema(propEntry.value as Map<String, dynamic>, schemas);
            if (compact.isNotEmpty) properties[propEntry.key] = compact;
          }
          for (final r in reqList) {
            required.add(r as String);
          }
        }

        if (properties.isEmpty) continue;

        tools.add({
          'type': 'function',
          'function': {
            'name': name,
            'parameters': {
              'type': 'object',
              'properties': properties,
              if (required.isNotEmpty) 'required': required,
            },
          },
        });
      }
    }

    return tools;
  }

  Map<String, dynamic> _resolveAllSchemas(Map<String, dynamic> spec) {
    return spec['components']?['schemas'] as Map<String, dynamic>? ?? {};
  }

  Map<String, dynamic> _compactSchema(Map<String, dynamic> schema, [Map<String, dynamic>? schemas]) {
    if (schema.containsKey(r'$ref')) {
      if (schemas != null) return _compactSchema(_resolveRef(schema, schemas), schemas);
      return {};
    }

    final type = schema['type'] as String?;
    if (type == null) {
      final anyOf = schema['anyOf'] as List<dynamic>?;
      if (anyOf != null) {
        for (final item in anyOf) {
          final itemMap = item as Map<String, dynamic>;
          if (itemMap['type'] != 'null') return _compactSchema(itemMap, schemas);
        }
      }
      return {};
    }

    final result = <String, dynamic>{'type': type};

    if (type == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) {
        final resolved = items.containsKey(r'$ref') && schemas != null
            ? _resolveRef(items, schemas)
            : items;
        final itemProps = resolved['properties'] as Map<String, dynamic>?;
        if (itemProps != null) {
          final nested = <String, Map<String, dynamic>>{};
          for (final e in itemProps.entries) {
            final c = _compactSchema(e.value as Map<String, dynamic>, schemas);
            if (c.isNotEmpty) nested[e.key] = c;
          }
          if (nested.isNotEmpty) {
            result['items'] = {'type': 'object', 'properties': nested};
          }
        } else {
          final c = _compactSchema(resolved, schemas);
          if (c.isNotEmpty) result['items'] = c;
        }
      }
    }

    return result;
  }

  Map<String, dynamic> _resolveRef(Map<String, dynamic> schema, Map<String, dynamic> schemas) {
    final ref = schema[r'$ref'] as String?;
    if (ref == null) return schema;
    final parts = ref.split('/');
    Map<String, dynamic> current = schemas;
    for (final part in parts.skip(3)) {
      if (current.containsKey(part) && current[part] is Map<String, dynamic>) {
        current = current[part] as Map<String, dynamic>;
      } else {
        return schema;
      }
    }
    return current;
  }

  String toolsToText() {
    if (_tools == null) return '';
    final buf = StringBuffer();
    for (final tool in _tools!) {
      final func = tool['function'] as Map<String, dynamic>;
      final name = func['name'] as String;
      final params = func['parameters'] as Map<String, dynamic>;
      final props = params['properties'] as Map<String, dynamic>? ?? {};
      final required = params['required'] as List<dynamic>? ?? [];

      final paramStrs = props.entries.map((e) {
        final isReq = required.contains(e.key);
        final typeStr = _typeHint(e.value as Map<String, dynamic>);
        return isReq ? '${e.key}: $typeStr' : '${e.key}?: $typeStr';
      }).join(', ');

      buf.writeln('- $name($paramStrs)');
    }
    return buf.toString();
  }

  String _typeHint(Map<String, dynamic> schema) {
    final type = schema['type'] as String? ?? '';
    if (type == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      final props = items?['properties'] as Map<String, dynamic>?;
      if (props != null) {
        final inner = props.entries
            .map((e) => '${e.key}: ${_typeHint(e.value as Map<String, dynamic>)}')
            .join(', ');
        return '[$inner]';
      }
      return 'lista';
    }
    if (type == 'integer' || type == 'number') return 'número';
    if (type == 'string') return 'texto';
    if (type == 'boolean') return 'sí/no';
    return type;
  }

  String buildSystemPrompt(String? userSystem) {
    final buf = StringBuffer();
    if (userSystem != null && userSystem.isNotEmpty) {
      buf.writeln(userSystem);
      buf.writeln('');
    } else {
      buf.writeln('Eres un asistente útil. Responde siempre en español. Usa las herramientas disponibles según lo que necesite el usuario.');
      buf.writeln('');
    }

    final toolsText = toolsToText();
    if (toolsText.isNotEmpty) {
      buf.writeln('Tienes las siguientes herramientas disponibles:');
      buf.writeln(toolsText);
      buf.writeln('- finalizar(mensaje: texto)');
      buf.writeln('');
      buf.writeln(
        'IMPORTANTE: Cuando necesites usar una herramienta, responde ÚNICAMENTE con este JSON.',
      );
      buf.writeln('');
      final example = _buildExampleFromFirstTool();
      if (example.isNotEmpty) {
        buf.writeln('EJEMPLO CORRECTO (solo datos del usuario):');
        buf.writeln(example);
        final wrongExample = example.replaceAllMapped(
          RegExp(r':\s*"ejemplo"'),
          (_) => ': "VALOR_INVENTADO"',
        );
        buf.writeln('EJEMPLO INCORRECTO (NO inventes datos):');
        buf.writeln(wrongExample);
        buf.writeln('');
      }
      buf.writeln(
        'REGLAS ESTRICTAS:\n'
        '- Incluye ÚNICAMENTE los campos que el usuario te dio.\n'
        '- NO inventes, adivines ni generes valores.\n'
        '- Si un campo falta, la API responderá error, informa al usuario.\n'
        '- NO repitas la misma herramienta con los mismos argumentos. Si ya falló, usa finalizar.\n'
        '- Si la herramienta se ejecutó con éxito, NO la llames de nuevo. Responde al usuario con el resultado.\n'
        '- Si el error persiste, usa finalizar.',
      );
    }

    return buf.toString();
  }

  String _buildExampleFromFirstTool() {
    if (_tools == null || _tools!.isEmpty) return '';
    final tool = _tools!.first;
    final func = tool['function'] as Map<String, dynamic>;
    final name = func['name'] as String;
    final params = func['parameters'] as Map<String, dynamic>? ?? {};
    final props = params['properties'] as Map<String, dynamic>? ?? {};
    final required = (params['required'] as List<dynamic>?)?.cast<String>() ?? [];

    final entries = required.isNotEmpty
        ? props.entries.where((e) => required.contains(e.key))
        : props.entries;

    final args = entries.map((e) {
      final type = (e.value as Map<String, dynamic>)['type'];
      final val = type == 'string' ? '"ejemplo"' : (type == 'integer' || type == 'number' ? '0' : 'true');
      return '"${e.key}": $val';
    }).join(', ');
    return '{"herramienta":"$name","argumentos":{$args}}';
  }

  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    if (_spec == null) return 'Error: Tools no cargadas';

    final paths = _spec!['paths'] as Map<String, dynamic>? ?? {};
    for (final entry in paths.entries) {
      final path = entry.key;
      final methods = entry.value as Map<String, dynamic>;
      for (final methodEntry in methods.entries) {
        final method = methodEntry.key;
        final operation = methodEntry.value as Map<String, dynamic>;
        final operationId = operation['operationId'] as String? ?? '';
        final parts = operationId.split('_');
        if (parts.length < 2) continue;
        if ('${parts[0]}_${parts[1]}' == name) {
          return await _executeHttp(method, path, args, operation);
        }
      }
    }
    return 'Error: Herramienta "$name" no encontrada';
  }

  Future<String> _executeHttp(
    String method,
    String path,
    Map<String, dynamic> args,
    Map<String, dynamic> operation,
  ) async {
    final uri = Uri.parse(specUrl);
    final basePath = uri.path.replaceAll('/openapi.json', '');
    final baseUrl = '${uri.scheme}://${uri.host}$basePath';
    var resolvedPath = path;

    for (final e in args.entries) {
      resolvedPath = resolvedPath.replaceAll('{${e.key}}', '${e.value}');
    }

    final client = HttpClient();
    try {
      if (method == 'get') {
        final queryParams = <String, String>{};
        final params = operation['parameters'] as List<dynamic>? ?? [];
        for (final p in params) {
          final param = p as Map<String, dynamic>;
          if (param['in'] == 'query' && args.containsKey(param['name'])) {
            queryParams[param['name'] as String] = '${args[param['name']]}';
          }
        }
        final requestUri =
            Uri.parse('$baseUrl$resolvedPath').replace(queryParameters: queryParams);
        final request = await client.getUrl(requestUri);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        debugPrint('[HTTP $method $requestUri → ${response.statusCode}] $body');
        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final parsed = jsonDecode(body);
            return const JsonEncoder.withIndent('  ').convert(parsed);
          } catch (_) {
            return body;
          }
        }
        return 'Error ${response.statusCode}: $body';
      } else if (method == 'post') {
        final params = operation['parameters'] as List<dynamic>? ?? [];
        final pathParams = params
            .where((p) => (p as Map<String, dynamic>)['in'] == 'path')
            .map((p) => (p as Map<String, dynamic>)['name'] as String)
            .toSet();
        final bodyArgs = Map<String, dynamic>.from(args)..removeWhere((k, v) => pathParams.contains(k));

        final request = await client.postUrl(Uri.parse('$baseUrl$resolvedPath'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(bodyArgs));
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        debugPrint('[HTTP $method $baseUrl$resolvedPath → ${response.statusCode}] body=$body');
        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final parsed = jsonDecode(body);
            return const JsonEncoder.withIndent('  ').convert(parsed);
          } catch (_) {
            return body;
          }
        }
        return 'Error ${response.statusCode}: $body';
      }
      return 'Error: Método $method no soportado';
    } catch (e) {
      return 'Error: $e';
    } finally {
      client.close();
    }
  }

  static List<Map<String, dynamic>> parseToolCalls(String text) {
    final regex = RegExp(
      r'\{\s*"herramienta":\s*"([^"]+)"\s*,\s*"argumentos":\s*(\{(?:[^{}]|(?:\{[^{}]*\}))*\})\s*\}',
    );
    return regex.allMatches(text).map((m) {
      final name = m.group(1)!;
      final args = jsonDecode(m.group(2)!) as Map<String, dynamic>;
      return {'name': name, 'arguments': args};
    }).toList();
  }
}
