/**
 * config.js — Dónde está el servidor (la API).
 *
 * - Normalmente el sitio lo entrega el mismo servidor que la API (php artisan serve en
 *   http://localhost:3000, o el servidor publicado en OCI): la API está en ese mismo origen.
 * - Solo si lo abres con una herramienta aparte (Live Server en el puerto 5500, por ejemplo, o
 *   el archivo directo), la API se busca en http://localhost:3000. Si tu servidor usa otro
 *   puerto, cámbialo aquí.
 */
const PUERTO_API = "3000";
const PUERTOS_HERRAMIENTAS = ["5500", "5501", "5502", "8000", "8080"]; // Live Server y similares

const abiertoAparte = window.location.protocol === "file:" || PUERTOS_HERRAMIENTAS.includes(window.location.port);

export const API_ORIGEN = abiertoAparte ? `http://localhost:${PUERTO_API}` : window.location.origin;
export const API_URL = `${API_ORIGEN}/api`;
