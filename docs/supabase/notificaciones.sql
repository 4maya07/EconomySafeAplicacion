-- Tabla de notificaciones inteligentes para EconomySafe
CREATE TABLE notificaciones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES usuarios(id),
    tipo VARCHAR(50) NOT NULL, -- ejemplo: alerta, recordatorio, sugerencia
    mensaje TEXT NOT NULL,
    datos JSONB, -- información adicional relevante
    leida BOOLEAN DEFAULT FALSE,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    fecha_leida TIMESTAMP
);

-- Índices recomendados
CREATE INDEX idx_notificaciones_user_id ON notificaciones(user_id);
CREATE INDEX idx_notificaciones_leida ON notificaciones(leida);