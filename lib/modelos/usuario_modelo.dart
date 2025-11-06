/// Modelo base para representar la información principal del usuario.
class UsuarioModelo {
  const UsuarioModelo({
    required this.id,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.terminosAceptados,
    this.correoSecundario,
    this.documentoIdentidad,
    this.paisResidencia,
    this.monedaPreferida,
    this.fotoUrl,
    this.pinHash,
  });

  final String id;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final bool terminosAceptados;
  final String? correoSecundario;
  final String? documentoIdentidad;
  final String? paisResidencia;
  final String? monedaPreferida;
  final String? fotoUrl;
  final String? pinHash;

  UsuarioModelo copiarCon({
    String? nombreCompleto,
    String? telefono,
    bool? terminosAceptados,
    String? correoSecundario,
    String? documentoIdentidad,
    String? paisResidencia,
    String? monedaPreferida,
    String? fotoUrl,
    String? pinHash,
  }) {
    return UsuarioModelo(
      id: id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correo: correo,
      telefono: telefono ?? this.telefono,
      terminosAceptados: terminosAceptados ?? this.terminosAceptados,
      correoSecundario: correoSecundario ?? this.correoSecundario,
      documentoIdentidad: documentoIdentidad ?? this.documentoIdentidad,
      paisResidencia: paisResidencia ?? this.paisResidencia,
      monedaPreferida: monedaPreferida ?? this.monedaPreferida,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      pinHash: pinHash ?? this.pinHash,
    );
  }
}
