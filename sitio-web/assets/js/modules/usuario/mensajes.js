/**
 * mensajes.js — HU-13: mensajes que el usuario les escribió a los refugios y sus respuestas.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { pedirCuenta } from "../../components/aviso-cuenta.js";
import { obtenerMisMensajes } from "../../core/servicios.js";
import { crearElemento, formatearFecha, mostrarAlerta, resolverImagen } from "../../core/utils.js";

const ESTADOS = {
  nuevo: { texto: "Enviado", clase: "pendiente" },
  leido: { texto: "Leído por el refugio", clase: "pendiente" },
  respondido: { texto: "Respondido", clase: "aprobado" },
};

const sesion = requerirRol("usuario") // el visitante va al login: solo puede ver las mascotas en adopción;
const lista = document.getElementById("lista-mensajes");
const vacio = document.getElementById("sin-mensajes");

if (sesion) {
  montarNavbar({ sesion, activa: "mensajes" });
  if (sesion.rol === "invitado") mostrarParaVisitante();
  else cargar();
}

function mostrarParaVisitante() {
  const boton = crearElemento("button", { clase: "boton boton--primario", texto: "Iniciar sesión para ver mis mensajes", atributos: { type: "button" } });
  boton.addEventListener("click", () => pedirCuenta("escribirles a los refugios"));
  lista.replaceWith(crearElemento("section", { clase: "vacio tarjeta tarjeta--blanca" }, [
    crearElemento("p", { texto: "Con una cuenta puedes escribirle a un refugio para preguntar por una mascota o por su proceso de adopción." }),
    boton,
  ]));
}

async function cargar() {
  let mensajes;
  try {
    mensajes = await obtenerMisMensajes();
  } catch (error) {
    mostrarAlerta(document.getElementById("alerta"), "error", error.message);
    return;
  }
  vacio.hidden = mensajes.length > 0;
  lista.replaceChildren(...mensajes.map((m) => {
    const estado = ESTADOS[m.estado] || ESTADOS.nuevo;
    return crearElemento("li", { clase: "mensaje tarjeta tarjeta--blanca" }, [
      crearElemento("div", { clase: "mensaje__cabecera" }, [
        ...(m.mascotaFoto ? [crearElemento("img", { clase: "mensaje__foto", atributos: { src: resolverImagen(m.mascotaFoto), alt: "", width: 48, height: 48, loading: "lazy" } })] : []),
        crearElemento("div", { clase: "mensaje__titulo" }, [
          crearElemento("a", { clase: "enlace", texto: m.refugioNombre, atributos: { href: `refugios.html?id=${encodeURIComponent(m.refugioId)}` } }),
          crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${m.mascotaNombre ? `Sobre ${m.mascotaNombre} · ` : ""}${formatearFecha(m.fecha)}` }),
        ]),
        crearElemento("span", { clase: `insignia insignia--${estado.clase}`, texto: estado.texto }),
      ]),
      crearElemento("p", { clase: "mensaje__texto", texto: m.mensaje }),
      ...(m.respuesta ? [crearElemento("div", { clase: "mensaje__respuesta" }, [
        crearElemento("strong", { texto: `Respuesta de ${m.refugioNombre}` }),
        crearElemento("p", { texto: m.respuesta }),
        ...(m.respondido ? [crearElemento("span", { clase: "texto-suave texto-pequeno", texto: formatearFecha(m.respondido) })] : []),
      ])] : []),
    ]);
  }));
}
