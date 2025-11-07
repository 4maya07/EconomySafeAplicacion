"""Inicializa y comparte el cliente de Supabase para los servicios del backend."""

import os
from functools import lru_cache

from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()


class SupabaseConfigError(RuntimeError):
    """Señala una configuración inválida o ausente para Supabase."""


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY")

    if not url or not key:
        raise SupabaseConfigError(
            "SUPABASE_URL o SUPABASE_SERVICE_KEY no están configuradas en el entorno.",
        )

    return create_client(url, key)
