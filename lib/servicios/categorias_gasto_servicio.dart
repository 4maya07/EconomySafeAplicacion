import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/supabase/supabase_servicio.dart';
import '../modelos/categoria_gasto_modelo.dart';

/// Maneja la persistencia remota de las categorías de gasto en Supabase.
class CategoriasGastoServicio {
  CategoriasGastoServicio({SupabaseClient? cliente})
    : _cliente = cliente ?? SupabaseServicio.obtenerCliente();

  final SupabaseClient _cliente;

  static const String _tablaCategorias = 'categorias_gasto';

  Future<List<CategoriaGastoModelo>> obtenerCategorias(String usuarioId) async {
    final List<dynamic> datos = await _cliente
        .from(_tablaCategorias)
        .select()
        .eq('usuario_id', usuarioId)
        .order('created_at', ascending: false);

    return datos
        .map(
          (dynamic item) =>
              CategoriaGastoModelo.desdeMapa(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<CategoriaGastoModelo> crearCategoria(
    CategoriaGastoModelo categoria,
  ) async {
    final Map<String, dynamic> respuesta = await _cliente
        .from(_tablaCategorias)
        .insert(categoria.aMapaPersistencia(incluirUsuario: true))
        .select()
        .single();

    return CategoriaGastoModelo.desdeMapa(respuesta);
  }

  Future<CategoriaGastoModelo> actualizarCategoria(
    CategoriaGastoModelo categoria,
  ) async {
    if (categoria.id == null) {
      throw ArgumentError('La categoría debe tener un id para actualizarse.');
    }

    final Map<String, dynamic> respuesta = await _cliente
        .from(_tablaCategorias)
        .update(categoria.aMapaPersistencia())
        .eq('id', categoria.id!)
        .select()
        .single();

    return CategoriaGastoModelo.desdeMapa(respuesta);
  }

  Future<void> eliminarCategoria(String categoriaId) async {
    await _cliente.from(_tablaCategorias).delete().eq('id', categoriaId);
  }
}
