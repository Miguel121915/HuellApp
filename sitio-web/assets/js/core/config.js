/**
 * config.js — Dónde está el servidor (la API).
 *
 * - Si abres el sitio desde el propio servidor (http://localhost:3000), la API es ese mismo origen.
 * - Si lo abres con otra herramienta (Live Server en el puerto 5500, por ejemplo), la API se busca en
 *   http://localhost:3000. Si tu servidor usa otro puerto, cámbialo aquí.
 */
const PUERTO_API = "3000";

export const API_ORIGEN = window.location.port === PUERTO_API ? window.location.origin : `http://localhost:${PUERTO_API}`;
export const API_URL = `${API_ORIGEN}/api`;
