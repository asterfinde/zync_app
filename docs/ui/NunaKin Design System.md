# **NunaKin · Design System (v2.0 Minimalist Refined)**

Una app de estado para tus círculos cercanos. Sin feed, sin likes, sin desconocidos.

NunaKin (anteriormente conocida como **Zync** en pantallas legacy) ayuda a las personas a compartir cómo están —Casa, Trabajo, Camino, S.O.S— con un círculo privado de gente que les importa, en un solo toque y sin tener que escribir un mensaje.

Este documento formaliza los tokens, componentes y reglas de interacción táctil y de formularios para la **versión 2.0 (Modern & Minimalist)**, optimizando el contraste, garantizando la accesibilidad de lectura y simplificando la sobrecarga visual.

## **Index de Archivos del Proyecto**

| Archivo | Propósito / Destino |
| :---- | :---- |
| design\_system.md | Especificación de tokens, análisis de pantallas, reglas de interacción táctil y patrón de inputs. |
| main.dart | Implementación completa en Flutter (Single File) para simuladores (DartPad, Zapp). |
| index.html | Prototipo interactivo en alta fidelidad con el rediseño v2 optimizado para gestos táctiles. |

## **1\. Análisis de Pantallas Legacy (UI Audit)**

A partir de las capturas de pantalla provistas de la versión anterior, se identificaron las siguientes áreas de oportunidad:

### **A. Pantalla de Iniciar Sesión (image\_8a8302.png)**

* **Elementos**: Título centrado "Bienvenido", indicador de compilación (v10:50:30), inputs con iconos de candado y arroba. Botón con gradiente Mint y resplandor.  
* **Problema de Accesibilidad**: El texto placeholder en color Mint brillante (\#1CE8A1) sobre fondo oscuro tiene muy baja legibilidad y compite visualmente con el texto que el usuario ingresa.

### **B. Pantalla de Registro (image\_8a82de.jpg)**

* **Elementos**: Campo activo "Nickname" con un borde Mint completo y la etiqueta flotando de manera tosca cortando la línea del borde.  
* **Problema Estético**: El borde de 2px es demasiado intrusivo y el texto del placeholder se corta de forma rústica.

### **C. Pantalla de Círculo Vacío (image\_8a82a8.jpg)**

* **Problema Estético**: Las tarjetas gigantes de color Mint sólido resultan visualmente ruidosas. En la v2 se cambian por contenedores oscuros translúcidos con acentos sutiles.

### **D. Selector de Estados y S.O.S (image\_8a8267.jpg)**

* **Problema Estético**: Los bordes grises individuales alrededor de cada una de las 16 celdas de estado saturan la vista. El botón S.O.S plano no denota la sofisticación de una app de alta fidelidad.

## **2\. Patrón de Interacción: Floating Labels Dinámicos (Formularios v2.0)**

Este patrón es una de las soluciones de usabilidad y diseño móvil más sofisticadas para el manejo de formularios. Resuelve el problema de mantener el contexto de entrada de datos en pantallas compactas sin sacrificar el minimalismo estético.

### **Racional de UX (Por qué lo usamos)**

1. **Evita la sobrecarga cognitiva:** Cuando el campo está vacío, la interfaz se mantiene limpia, pacífica y de aspecto minimalista, mostrando únicamente el icono y el texto placeholder en gris apagado. Esto disminuye la ansiedad visual del usuario al enfrentarse a un formulario nuevo.  
2. **Previene la desorientación:** Una vez que el usuario comienza a escribir, el placeholder original desaparece. Para evitar que el usuario olvide qué dato está ingresando (problema común en formularios móviles tradicionales), la etiqueta se eleva automáticamente de manera fluida, transformándose en un indicador permanente en mayúsculas pequeñas de color Mint (\#1CE8A1).

### **Especificación de Estados Técnicos para Diseñadores y Desarrolladores**

```txt
   +-------------------------------------------------------------+
   |   [ resting / vacío ]                                       |
   |   (a) Icono Gris  [ placeholder en gris neutro ]            |
   +-------------------------------------------------------------+
                                 |
                                 |  Al hacer Tap o escribir 
                                 v  
   +-------------------------------------------------------------+  
   |   [ active / con contenido / enfocado ]                     |  
   |   (a) Icono Mint  LABEL EN MAYÚSCULAS MINT (9px)            |  
   |                   [ Texto ingresado por el usuario ]        |  
   +-------------------------------------------------------------+
   
```

#### **Estado 1: Vacío / Inactivo (Resting State)**

* **Visualización:** El input se integra al fondo oscuro. Se muestra únicamente un icono gris sutil a la izquierda y el texto descriptivo (placeholder) en tipografía regular de color gris neutro apagado (TEXT\_MUTED con opacidad ![][image1]).  
* **Fondo del campo:** rgba(255, 255, 255, 0.04).  
* **Borde:** rgba(255, 255, 255, 0.08).

#### **Estado 2: Activo / Enfocado (Focused State)**

* **Visualización:** Al hacer tap sobre el campo, el contenedor completo se ilumina de forma difuminada (resplandor radial o borde de marca sutil a menor opacidad).  
* **Transición:** El icono cambia a color Mint de marca (\#1CE8A1). El placeholder desaparece y la etiqueta del campo (Label) se desplaza de manera vertical hacia arriba con una animación de escala fluida (duración ![][image2]), reduciendo su tamaño a 9px con espaciado de letras expandido (letter-spacing: 1.2) y adquiriendo el color Mint de marca.

#### **Estado 3: Con Contenido / Sin Foco (Filled State)**

* **Visualización:** Si el usuario pasa a otro campo pero deja texto escrito, el foco visual (el resplandor Mint y la iluminación del icono) desaparece para dar paso al nuevo campo activo. Sin embargo, **la etiqueta Mint en la parte superior se mantiene fija**, y el texto ingresado se muestra debajo en color blanco puro con peso bold (15px), asegurando que no se pierda la referencia contextual del campo.

## **3\. Reglas de Interacción Táctil (Mobile UX Paradigm)**

* **Sin Hover de Puntero:** Se prohíbe el uso de estados de hover persistentes basados en mouse dentro del canvas móvil para evitar comportamientos pegajosos ("sticky hovers") en dispositivos touch reales.  
* **Pressed Feedback Instantáneo (Active):** Al hacer tap, el botón o tarjeta debe reaccionar reduciendo sutilmente su escala a 0.97 o 0.98 de forma instantánea (duración ![][image3]) para emular la elasticidad física de un objeto real.  
* **Selected State Sólido:** El estado "seleccionado" (como la celda activa del estado actual) debe distinguirse mediante un borde de marca de 1.5px en color Mint \#1CE8A1.  
* **Unificación de Botones Secundarios (según image\_8925c7.png):** Los botones secundarios o de configuración (tales como "Cerrar sesión" y "Ajustes") abandonan cualquier color destructivo (rojo) o gris plano. Ahora se unifican bajo la guía de un contenedor premium con fondo translúcido verde/negro profundo (rgba(28, 232, 161, 0.1)), borde de marca Mint sutil al 20%-30% de opacidad y texto/icono Mint sólido, logrando un balance estético de alta gama.

## **4\. Tokens Visuales v2.0 (Especificaciones de Código)**

### **Colores (Color Tokens)**

* BG\_CANVAS: \#000000 (Negro absoluto, sin gradientes generales).  
* COLOR\_BRAND: \#1CE8A1 (Mint característico \- usado para CTAs activos, acentos seleccionados).  
* COLOR\_BRAND\_DEEP: \#0F6B4C (Mint oscuro \- usado para estados hovered, fondos de botones secundarios).  
* COLOR\_SOS: \#E53E3E a \#C53030 (Gradiente de alerta premium para S.O.S).  
* SURFACE\_CARD: rgba(255, 255, 255, 0.04) (Para contenedores, inputs y tarjetas).  
* SURFACE\_BORDER: rgba(255, 255, 255, 0.08) (Bordes sutiles de 1px para delimitar superficies).  
* TEXT\_PRIMARY: \#FFFFFF (Blanco puro para títulos y lecturas principales).  
* TEXT\_MUTED: rgba(255, 255, 255, 0.4) (Gris suave para placeholders).

### **Radios de Esquinas (Radii)**

* Inputs y Botones Pequeños: 14px  
* Tarjetas e Items de Lista: 18px  
* Modales y Bottom Sheets: 28px  
* Chips y Pills de Estado: 999px

## **5\. Copywriting & Microcopy v2.0**

* Se mantienen estrictamente las reglas en español de tono neutro y segunda persona singular ("tú").  
* Se unifican todos los botones de confirmación rápida bajo el término "**OK**" (abandonando el uso de "Aceptar" o "Confirmar").

## **6\. Especificaciones de Pantallas (v2.0)**

### **6.1 Header Compartido (NoCircleView + InCircleView)**

| Elemento | Especificación |
| :---- | :---- |
| Logo | `ZyncLogoPainter` 20×20, color Mint |
| Nombre app | "NunaKin", 26px bold, Mint, `letterSpacing: -0.5` |
| Separación logo–nombre | 6px |
| Ícono persona | Círculo 36×36, fondo `surface2` (#1C1C1E), borde 1.5px `fgHint` (40%), ícono `person_outline` 18px `fgSub` (60%) |
| Separación ícono–botón | 6px |

### **6.2 NoCircleView — Pantalla Sin Círculo**

**Ícono central:**

| Propiedad | Valor |
| :---- | :---- |
| Tamaño | 64×64px |
| Fondo | `surface2` (#1C1C1E) opaco |
| Radio | `NkRadius.forCard` (18px) |
| Borde | `NkColors.line` (rgba 10% white) |
| Ícono | `group_off_outlined`, 28px, Mint |

**Textos:**

| Texto | Tamaño | Peso | Letter-spacing | Color |
| :---- | :---- | :---- | :---- | :---- |
| "Aún no estás en un círculo" | 22px | bold (700) | 0 | `onDark` (blanco) |
| "¿Qué te gustaría hacer hoy?" | 16px | regular (400) | 0 | `fgMuted` (80% white) |

**Tarjetas de acción:**

| Propiedad | Crear Círculo | Unirse a un Círculo |
| :---- | :---- | :---- |
| Fondo tarjeta | `Color(0x18FFFFFF)` (9.4% white) | `Color(0x18FFFFFF)` (9.4% white) |
| Borde tarjeta | `surfaceBorder` (8% white) | `surfaceBorder` (8% white) |
| Radio tarjeta | 18px | 18px |
| Ícono | `Icons.add`, Mint | `Icons.near_me`, Mint |
| Fondo ícono | `mintSoft(0.1)` (10% Mint) | `surfaceCard` (4% white) |
| Radio ícono | 14px | 14px |
| Tamaño ícono contenedor | 48×48px | 48×48px |
| Título | "Crear Círculo" — blanco bold 16px | "Unirse a un Círculo" — **blanco** bold 16px |
| Descripción | "Inicia un nuevo círculo e invita a / otros" — `fgHint` 12px, 2 líneas | "Ingresa con un código de / invitación privado" — `fgHint` 12px, 2 líneas |

**Ícono de cuenta (footer):**

| Propiedad | Valor |
| :---- | :---- |
| Posición | Footer fijo, izquierda — centrado verticalmente entre última tarjeta y borde inferior |
| Tamaño | 52×52px (proporcional al ícono central 64×64) |
| Forma | Círculo |
| Fondo | `surface2` (#1C1C1E) |
| Borde | 1.5px `fgHint` (40% white) |
| Ícono | `person_outline`, 24px, `fgSub` (60% white) |
| Padding footer | left/right 20px, top 20px, bottom 46px (ícono centrado entre última tarjeta y borde inferior, desplazado ½ su altura hacia arriba) |

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADsAAAAZCAYAAACPQVaOAAADdElEQVR4Xu2Xz2tTQRDHkzQqiFqtCDVN30titBoUlaJUWrGC2msF8VSrqAdvQkWLlOIPqKhgRZEqCv4CQdGCqFSlioIg9VBP/gHePPhH1M/k7drN5D1je2it5AvD7n5nZt/O7uxsEotVUcWsolAozG9oaFiueYVEKpVaqMk5hUwm0+553lvf9weQdVpvEMemC/1JrZhx5PP5FWCR5gXCp9PpDQRVr3W5XG4NAXxA1yJj+u+RI/C1jk0tgZ6CfyrfmfSeHSRZSH9YGrLIC+hGkD5kENnm6hn3IK+tL0GfEw6/+7SjRp4hY42Njdtd3xkHi1jJwh7TftfBymkhnS4np4Nc54QWyBjfWyL2LtI/IGLtzcnfmc6JJpubm+dpUiGOJDQZgSQL60W63dMxiMP1cxpbHK4YHPwnNiEjY/pDEowNFvoQ0mHt0Q1O+URxuov8RCaQ0VhEQLKD6I9qPgzY7WRhZ+Uu6mCbmpoWwz1Et9b1IdgzsgbaNhnLt6Q42ZNjPOD6+EFBqrHjimARaZxOMGlOFiaphTyAy2rbTFAZ92k+DPgPydwSpA7Wcn8ItpiqnFqK8QjjLoYJ2TzapOgkhaecvkxwUHMCJvP40A1/8sTHfFVAoiCpZe9dWLASJNx4pWAjUPLM8J0l9M8jn5FH2rgEfHCp5lxIac9ms1tjZkcrQXabxdy047BgeWpWY/NlOsGiK/imKMmG0r/CPKdRJeUJQ79M+5QAg1YcLtLeQ/ZrvYV504r3KQKy68dZwF5LhAX7t2msIW8yuqu2KOHfgv04h7HRmMj3dzsupZBKZ1JAfqH0McELnPfEQoqULC5qIQITxEvkHXZvRKSP/JAW/ycsdFVUgfKDdJyAb3d5C28yfYtFCbtjEqw7D+Oe3w4ashP2fhnEJeCMKlJyN+CumZSOQkLSSIK2IinLPKPSInWx4DrUSCb5qgZ4wdNTdpctfPWmmkwosYfrtf0yoGzVnIU5qcNekN5iV3baFRA3D/9HAs27CrkS8Lfdn5GMv/GdXa6dQbEoSeuSBNmJz1ff+c0snGszI2BxbX5QxV3RKTeMDMF1SEqagMo2FL7gOUXPwrz7w555DpmjXp47bfevQH43bzbB7tBKgakpl9Fv0joBNWA9+lfoLxH0c62fa4ibn4slKawgz07dnP8/W0UVVVTx3+MXiqPiZmT2s68AAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAE4AAAAZCAYAAACfIRhSAAADmElEQVR4Xu1X30tUQRS+q0u/f9eysbp3d3VrQ+tBoiiQ6qEwCiEo6iGDgoiohBAMQkwxigiSqAhRgozwJerFh+whlHypB30I3yTwvT/Cvq89s56m9e7dvWVC94PDzJxz5tyZb+bMzHWcECFChAgRCNlsdoPrupttfV1d3cba2trVlroqkUhsQxmx9A5896TT6e2oRm3bskYmk0lh4OcwsTW2rRhICghrTaVSn1FesO3UwTaL8iXi3kb9OWQG7VswVxs/If4+bF2Qfsgk5KAKtexQhQHvxSBfo2x0iuyCxRCLxdY5+f496D+/GHGQxySKxGFh4rYP9AfQfw7lKaXbBN0bELpS+y4LYBKHODjIM+ycrG33Cx/E/aZXiKBvN4lLJpP7jJI7Hv0GQGBa+f5bcBXdfHp1Y7AJ214ughCXy+XWo+8ryBQ42qVtjAtp1jqemSiqWG9oaFhB0XbaJBOKgjZski2oRmX3lz5L5Tw6i0GOQzpte6XwQxzPTuAGyDmuL4uampqt0L/3IO5nTNg7+A36IlYO5V3YxlDOQa4zJsrzEmsW8gIbJGZisQ7dIKQf/e6g/AgZ5fcXvlgEQtoYiStyywVCKeJ4tjmysvX19Un4TkA3zN1DstCeongRRzB95TtnlA8vn3nIE3MeMr3RnoRtgH1M2kP30JFxSKy+ksQRHCgCtKPDOGJfsu2Vwos4G2oS31EewyLuQPmlDOJ+8TPEQXfR6MwuNsQxnUkavwkZgWQcPylqIx6Pr0XQNpIoZ0YglEMcUI1JPqA/pMNvqhJexGk/mzjqMM+dbj61+V0Kn09HnTJeEQWgY6sE6wpySXgRxwlgor36Xaj8ezwuB962fdAdMYogxBFyXDWn8mc8d+lXzHu3sZeLKJlHoFEe4LbRD0oQxwF+woq7bKtUpf6qs7ADmUaFB696jhRIqpQ4+K9C+5q78GcTkTnP6hQPAgZsRMBOrytdQ26zR0LETdsO/RAWZL9qnyRJrvpzkEtiGPpB4ycTmzFt4wfdNKTJ6FC/LMRdceTc4psUugnICG9TtVhD/EOhj1xSvKELY1symNW2xVVvL54t0L2D9Kfzv1zfYG+3/whg4034FkULdyLq0/BrM3ZXdrUS7iimndZx8VpsnezUp7D1os8H1O+l8ul62qnkjFtCRDHIJsgJeXwuhqgQd/hPXFoKEaar1KPmAazsIf4GIjw0/Yjf8y1EiBAhQoT47/ADHdgybS8VygUAAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEQAAAAZCAYAAACIA4ibAAADiUlEQVR4Xu2Wy0tUURzH7+jQ+2UhgzPO3PFRpr2ICBKlRVhBIQRBhFAUSBBiy0BEtNqUBJGISYGRixYFIS16kFAURBK2CHdu3Lnwj6jPd+acPF1ndGYCc3G/8OOe83uc+zvfe36/cz0vRIgQIdYuyhKJxK5kMrlf46DRQbS6uvpAZWXllqBhrSOaSqVafd8/ETQEgU8j8gr/0XQ63cP4I+MWTBHHLYKuDdsXpJfxBM/HSJXjs7ZQW1u7nUS7SbJL46A9D7TRmwFdOcTclWis04DPU9Ydb2ho2GqdOE1H0c0thq0R1NTU+CQ/QHKTJN4etC+HeDy+ibhBhlFXzzr96EdYd4PduCXI+jBP68S4JP1vlEHGQZJ6yfO4F9hUgSgnfkEExGKxzVLodLHXZ+guaa4nPr/k4waq56B/S0/Z7erd/iLCvaVkVyzTg8rq6uqS5oSX847qoEMuqD+0mToe9v6u9aLBGrPaMPINYk/xvA0hD23S5rTkJUQnyI6tn5/tS+OM32l91rsKcRsZdxjdDLrXbHyPWS7To6TDdh4ZZD6FPHLfuQT19fXrcXrvF9cnloVOBoncYs05bQiZ1wY882VXIgR9q9URtxfdV3S1ju6KWXdI+QdipzTXGnp/KtvMM9DJEzF2nhdimsALOE/ysoGgvViwzhuks6mpaZ05IUpeBKjZlpdAyBNTKhmkFksuU4KC+g66cWRac133xP70s6f1DHtMeMtf/zkRVe9ggTFets8roXSIqyC+z3PqnMTuoVtQgkq0WEKYj65EiOzys4SACOMOZF6+ElM+jTamYIgMAof9xeZaMIg9ScyhgLqMZK6bpM45G8pJiEiwun8gJANyiaEbQb4bYiZde1Hga8ZZoI8XtausgvZcUJLUdWVQb47+tAjh2exnb6IHKivroxpHN4XPDjeuFELUmJlfs3YQxdap9zq60mH6TDsJXgzaXJifrgn3eoOgbfpKxPZ4ppT87HGexbfNuCnhPnw+2zgQYX4M/Rjv32mVxNwwhGjDmfX0EdA9R34YHzVVkX7ZiWtB98HOVw3aPDKD3NHG9dWRbnsjGIiALm1ApPC8j3xifERG99q1gq1fp8LVGb1OhqtT3FnIfMFzCOlFRlLZ67nZyWHVoIZWZRq0OvyfrxuEapzET+N32CvtRzAnVIq2HEUuZFR4JdwyIUBEDBYqbnMLESJEiBAh8uI3kpkRVjdgONoAAAAASUVORK5CYII=>