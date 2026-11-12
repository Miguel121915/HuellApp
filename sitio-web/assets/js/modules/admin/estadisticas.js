/**
 * estadisticas.js — Estadísticas de uso para el administrador (HU-20).
 * Cifras principales, actividad semanal (una mini gráfica por medida, misma escala dentro de cada una)
 * y barras horizontales por estado. Todo con HTML y CSS, sin librerías; cada valor también está en la tabla.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { get } from "../../core/api.js";
import { crearElemento } from "../../core/utils.js";

const sesion = requerirRol("admin");

const NOMBRES = {
  usuario: "Usuarios", refugio: "Refugios", admin: "Administradores",
  pendiente: "Pendientes", aprobado: "Aprobados", rechazado: "Rechazados", suspendido: "Suspendidos",
  disponible: "Disponibles", "en proceso": "En proceso", adoptado: "Adoptadas",
  "en revision": "En revisión", aprobada: "Aprobadas", rechazada: "No aprobadas",
  perdida: "Perdidas", encontrada: "Encontradas", perro: "Perros", gato: "Gatos",
};
const nombre = (clave) => NOMBRES[clave] || clave;
const numero = (n) => Number(n || 0).toLocaleString("es-MX");
const suma = (obj = {}) => Object.values(obj).reduce((a, b) => a + b, 0);
const fechaCorta = (iso) => new Date(`${iso}T00:00:00Z`).toLocaleDateString("es-MX", { day: "numeric", month: "short", timeZone: "UTC" });

if (sesion) {
  montarNavbar({ sesion, activa: "estadisticas" });
  document.getElementById("boton-actualizar").addEventListener("click", cargar);
  cargar();
}

async function cargar() {
  const estado = document.getElementById("estado");
  estado.textContent = "Cargando estadísticas…";
  let d;
  try {
    d = await get("/admin/estadisticas");
  } catch (error) {
    estado.textContent = error.message;
    return;
  }
  estado.textContent = `Actualizado: ${new Date(d.generado).toLocaleString("es-MX")}`;
  pintarCifras(d);
  pintarActividad(d);
  barras(document.getElementById("grafica-adopciones"), d.adopciones, ["pendiente", "en revision", "aprobada", "rechazada"],
    d.tasaAprobacion != null ? `De las solicitudes ya resueltas, se aprobó el ${d.tasaAprobacion} %.` : "Aún no hay solicitudes resueltas.");
  barras(document.getElementById("grafica-mascotas"), d.mascotas, ["disponible", "en proceso", "adoptado"],
    `${numero(d.mascotasPorEspecie.perro)} perros y ${numero(d.mascotasPorEspecie.gato)} gatos registrados.`);
  barras(document.getElementById("grafica-refugios"), d.refugios, ["aprobado", "pendiente", "rechazado", "suspendido"]);
  barras(document.getElementById("grafica-top"), Object.fromEntries(d.topRefugios.map((r) => [r.nombre, r.adopciones])),
    d.topRefugios.map((r) => r.nombre), d.topRefugios.length ? "Adopciones aprobadas por refugio." : "Todavía no hay adopciones aprobadas.");
  pintarTabla(d);
}

/** Cifras grandes: el número es lo importante, no hace falta una gráfica. */
function pintarCifras(d) {
  const cifras = [
    [suma(d.usuarios), "Cuentas", `${numero(d.usuarios.usuario)} usuarios · ${numero(d.usuarios.refugio)} refugios`],
    [d.refugios.aprobado || 0, "Refugios verificados", `${numero(d.refugios.pendiente)} por revisar`],
    [d.mascotas.disponible || 0, "Mascotas en adopción", `${numero(d.mascotas.adoptado)} ya adoptadas`],
    [suma(d.adopciones), "Solicitudes de adopción", d.tasaAprobacion != null ? `${d.tasaAprobacion} % aprobadas` : "sin resolver aún"],
    [suma(d.reportes), "Reportes de mascotas", `${numero(d.reportes.perdida)} perdidas · ${numero(d.reportes.encontrada)} encontradas`],
    [d.coincidencias.total, "Coincidencias", `${numero(d.coincidencias.porIa)} comparadas con IA`],
    [d.comunidad.publicaciones, "Publicaciones en el foro", `${numero(d.comunidad.comentarios)} comentarios`],
    [d.comunidad.mensajes, "Mensajes a refugios", `${numero(d.comunidad.favoritos)} favoritos guardados`],
  ];
  document.getElementById("cifras").replaceChildren(...cifras.map(([valor, etiqueta, detalle]) =>
    crearElemento("article", { clase: "cifra tarjeta" }, [
      crearElemento("span", { clase: "cifra__numero", texto: numero(valor) }),
      crearElemento("span", { clase: "cifra__etiqueta", texto: etiqueta }),
      crearElemento("span", { clase: "cifra__detalle", texto: detalle }),
    ])));
}

/** Una mini gráfica de columnas por medida (cada una con su propia escala y su título: sin leyenda). */
function pintarActividad(d) {
  const medidas = [["usuarios", "Cuentas nuevas"], ["reportes", "Reportes"], ["solicitudes", "Solicitudes de adopción"], ["publicaciones", "Publicaciones del foro"]];
  document.getElementById("actividad").replaceChildren(...medidas.map(([clave, titulo]) => {
    const valores = d.actividad[clave];
    const max = Math.max(1, ...valores);
    const total = valores.reduce((a, b) => a + b, 0);
    return crearElemento("figure", { clase: "mini-grafica tarjeta tarjeta--blanca" }, [
      crearElemento("figcaption", {}, [
        crearElemento("strong", { texto: titulo }),
        crearElemento("span", { clase: "texto-pequeno texto-suave", texto: `${numero(total)} en 8 semanas · esta semana: ${numero(valores.at(-1))}` }),
      ]),
      crearElemento("div", { clase: "columnas", atributos: { role: "img", "aria-label": `${titulo} por semana: ${valores.map((v, i) => `${fechaCorta(d.semanas[i])} ${v}`).join(", ")}` } },
        valores.map((v, i) => crearElemento("div", {
          clase: `columna${i === valores.length - 1 ? " columna--actual" : ""}`,
          atributos: { title: `Semana del ${fechaCorta(d.semanas[i])}: ${numero(v)}`, style: `--alto: ${Math.round((v / max) * 100)}%` },
        }, crearElemento("span", { clase: "columna__barra" })))),
      crearElemento("div", { clase: "columnas__eje texto-pequeno texto-suave" }, [
        crearElemento("span", { texto: fechaCorta(d.semanas[0]) }),
        crearElemento("span", { texto: "esta semana" }),
      ]),
    ]);
  }));
}

/** Barras horizontales: una sola tinta (la cantidad la dice el largo y la etiqueta, no el color). */
function barras(contenedor, datos, orden, nota = "") {
  const filas = orden.map((clave) => [clave, datos[clave] || 0]);
  const max = Math.max(1, ...filas.map(([, v]) => v));
  contenedor.replaceChildren(...[
    crearElemento("ul", { clase: "barras" }, filas.map(([clave, valor]) => crearElemento("li", {
      clase: "barra", atributos: { title: `${nombre(clave)}: ${numero(valor)}` },
    }, [
      crearElemento("span", { clase: "barra__etiqueta", texto: nombre(clave) }),
      crearElemento("span", { clase: "barra__pista" }, crearElemento("span", { clase: "barra__relleno", atributos: { style: `--ancho: ${valor === 0 ? 0 : Math.max(2, Math.round((valor / max) * 100))}%` } })),
      crearElemento("span", { clase: "barra__valor", texto: numero(valor) }),
    ]))),
    nota ? crearElemento("p", { clase: "texto-pequeno texto-suave", texto: nota }) : null,
  ].filter(Boolean)); // replaceChildren escribiría «null» como texto
}

/** Vista de tabla con todos los valores (accesible y para copiar al reporte). */
function pintarTabla(d) {
  const filas = [
    ...Object.entries(d.usuarios).map(([k, v]) => ["Cuentas", nombre(k), v]),
    ...Object.entries(d.refugios).map(([k, v]) => ["Refugios", nombre(k), v]),
    ...Object.entries(d.mascotas).map(([k, v]) => ["Mascotas", nombre(k), v]),
    ...Object.entries(d.adopciones).map(([k, v]) => ["Solicitudes de adopción", nombre(k), v]),
    ...Object.entries(d.reportes).map(([k, v]) => ["Reportes", nombre(k), v]),
    ["Coincidencias", "Total", d.coincidencias.total], ["Coincidencias", "Comparadas con IA", d.coincidencias.porIa],
    ["Comunidad", "Publicaciones", d.comunidad.publicaciones], ["Comunidad", "Comentarios", d.comunidad.comentarios],
    ["Comunidad", "Mensajes a refugios", d.comunidad.mensajes], ["Comunidad", "Favoritos", d.comunidad.favoritos],
    ...d.semanas.flatMap((s, i) => [["Semana del " + fechaCorta(s), "Cuentas / reportes / solicitudes / publicaciones",
      `${d.actividad.usuarios[i]} / ${d.actividad.reportes[i]} / ${d.actividad.solicitudes[i]} / ${d.actividad.publicaciones[i]}`]]),
  ];
  document.getElementById("tabla-datos").replaceChildren(crearElemento("table", { clase: "tabla" }, [
    crearElemento("thead", {}, crearElemento("tr", {}, ["Grupo", "Dato", "Valor"].map((t) => crearElemento("th", { texto: t, atributos: { scope: "col" } })))),
    crearElemento("tbody", {}, filas.map(([g, n, v]) => crearElemento("tr", {}, [
      crearElemento("td", { texto: g }), crearElemento("td", { texto: n }), crearElemento("td", { texto: typeof v === "number" ? numero(v) : v }),
    ]))),
  ]));
}
