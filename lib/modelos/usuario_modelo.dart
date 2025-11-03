/// Modelo base para representar la información principal del usuario.
class UsuarioModelo {
  const UsuarioModelo({
    required this.id,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.terminosAceptados,
    this.pinHash,
  });

  final String id;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final bool terminosAceptados;
  final String? pinHash;

  UsuarioModelo copiarCon({
    String? nombreCompleto,
    String? telefono,
    bool? terminosAceptados,
    String? pinHash,
  }) {
    return UsuarioModelo(
      id: id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo,
      telefono: telefono ?? this.telefono,
      terminosAceptados: terminosAceptados ?? this.terminosAceptados,
      pinHash: pinHash ?? this.pinHash,
    );
  }
}
