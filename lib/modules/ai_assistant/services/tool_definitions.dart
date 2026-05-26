import 'package:dart_openai/dart_openai.dart';

class ToolArg {
  final String name;
  final String type;
  final bool required;
  final String? hint;
  const ToolArg(this.name, this.type, {this.required = false, this.hint});
}

class ToolDefinition {
  final String name;
  final String description;
  final List<ToolArg> args;
  const ToolDefinition(this.name, this.description, {this.args = const []});

  static const List<ToolDefinition> all = [
    ToolDefinition('get_products', ''),
    ToolDefinition(
      'get_product',
      '',
      args: [ToolArg('id', 'int', required: true)],
    ),
    ToolDefinition(
      'create_product',
      '',
      args: [
        ToolArg('name', 'string', required: true),
        ToolArg('price', 'number', required: true),
        ToolArg('purchase_price', 'number'),
        ToolArg('quantity', 'int'),
        ToolArg('code', 'string'),
        ToolArg('description', 'string'),
      ],
    ),
    ToolDefinition('get_customers', ''),
    ToolDefinition(
      'get_customer',
      '',
      args: [ToolArg('id', 'int', required: true)],
    ),
    ToolDefinition(
      'create_customer',
      '',
      args: [
        ToolArg('name', 'string', required: true),
        ToolArg('email', 'string'),
        ToolArg('phone', 'string'),
        ToolArg('address', 'string'),
      ],
    ),
    ToolDefinition('get_sales', ''),
    ToolDefinition(
      'get_sales_by_customer',
      '',
      args: [ToolArg('customer_name', 'string', required: true)],
    ),
    ToolDefinition(
      'create_sale',
      '',
      args: [
        ToolArg('customer_name', 'string', required: true),
        ToolArg(
          'products',
          'array',
          required: true,
          hint: '[{"product_name","quantity"}]',
        ),
      ],
    ),
    ToolDefinition('get_purchases', ''),
    ToolDefinition(
      'create_purchase',
      '',
      args: [
        ToolArg(
          'products',
          'array',
          required: true,
          hint: '[{"product_name","quantity","unit_price?"}]',
        ),
      ],
    ),
    ToolDefinition('get_categories', ''),
    ToolDefinition(
      'create_category',
      '',
      args: [
        ToolArg('name', 'string', required: true),
        ToolArg('description', 'string'),
      ],
    ),
  ];

  OpenAIToolModel toOpenAIFormat() {
    final properties = <String, dynamic>{};
    final required = <String>[];
    for (final a in args) {
      final type = a.type == 'int'
          ? 'integer'
          : a.type == 'number'
              ? 'number'
              : a.type == 'array'
                  ? 'array'
                  : 'string';
      if (a.type == 'array') {
        properties[a.name] = {
          'type': 'array',
          'items': {'type': 'object'},
          'description': a.hint ?? '',
        };
      } else {
        properties[a.name] = {
          'type': type,
          'description': a.hint ?? '',
        };
      }
      if (a.required) required.add(a.name);
    }
    return OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: name,
        description: description,
        parametersSchema: {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      ),
    );
  }

  static List<OpenAIToolModel> toolsToOpenAI() =>
      all.map((t) => t.toOpenAIFormat()).toList();

  static String get systemPrompt {
    final buf = StringBuffer();
    buf.writeln(
      'Sistema de gestion de tienda. El usuario es el ADMINISTRADOR, no un cliente.',
    );
    buf.writeln(
      'Ejecuta las operaciones que te pide (crear, vender, comprar, consultar).',
    );
    buf.writeln(
      'No trates al usuario como cliente de la tienda. name es ÚNICO. Español.',
    );
    buf.writeln('Ejemplos:');
    buf.writeln('  Usuario: "crea el cliente Juan"');
    buf.writeln(
      '  → {"thought":"creando","tool":"create_customer","args":{"name":"Juan"}}',
    );
    buf.writeln('  Usuario: "vende 2 Leches y 1 Pan a Maria"');
    buf.writeln(
      '  → {"thought":"creando","tool":"create_sale","args":{"customer_name":"Maria","products":[{"product_name":"Leche","quantity":2},{"product_name":"Pan","quantity":1}]}}',
    );
    buf.writeln('  Cuando ya completaste TODO:');
    buf.writeln(
      '  → {"thought":"tareas completadas","answer":"Listo, ya cree los clientes"}',
    );
    buf.writeln('');
    buf.writeln(
      'IMPORTANTE: Cuando completes todas las tareas, responde con answer.',
    );
    buf.writeln('NO llames mas tools si ya no hay nada pendiente.');
    buf.writeln(
      'Puede existir compras que tengan precio 0.0 o no tengan precios, no repitas las compras ya COMPLETADAS',
    );
    buf.writeln('Tools:');
    for (final t in all) {
      final args = t.args
          .map((a) {
            final s = a.required ? a.name : '${a.name}?';
            return a.hint != null ? '$s  →  ${a.hint}' : s;
          })
          .join(',');
      buf.writeln('- ${t.name}($args)');
    }

    return buf.toString();
  }
}
