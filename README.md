# Escape Room Maker (Godot 4 + GDScript)

Juego 3D donde juegas un tutorial y luego **construyes tu propio escape room**.

## Cómo abrirlo
1. Instala **Godot 4.3 o superior** (versión estándar, no .NET).
2. En el Project Manager pulsa **Importar** y elige `project.godot`.
3. Abre el proyecto y pulsa **F5**.

## Menú principal
- **Tutorial**: sala de práctica ya hecha (nota → llave → cofre → puerta).
- **Crear una sala nueva**: abre el editor 3D.
- **Mis salas guardadas**: juega, edita o **borra** las salas que guardaste (el botón Borrar pide confirmar con un segundo clic; así liberas espacio).

## Controles al jugar
| Tecla | Acción |
|---|---|
| W A S D | Moverse |
| Shift | Correr |
| Espacio | Saltar |
| Ratón | Mirar |
| E | Interactuar |
| M | Volver al menú (o al editor si estás probando tu sala) |
| Esc | Soltar el ratón |

## Modo creador
| Acción | Cómo |
|---|---|
| Volar con la cámara | Mantén **clic derecho** + W A S D (Q baja, E sube, Shift más rápido) |
| Acercar / alejar | Rueda del ratón |
| Buscar un objeto | Escribe en el **buscador** del panel izquierdo (busca por nombre o categoría) |
| Categorías | El panel agrupa los objetos en Muebles, Decoración, Paredes y puertas, Llaves y objetos, Cofres y cajas y Puzzles; pulsa el título para plegar/desplegar |
| Colocar un objeto | Elígelo en el panel izquierdo y haz **clic izquierdo** en la sala |
| Objetos sobre muebles | Lámpara, llave y nota se apoyan en mesas, cajas y el librero |
| Seleccionar / mover | Herramienta «Seleccionar», clic en el objeto y arrastra |
| Girar | **R** |
| Borrar | **Supr** / **Retroceso** / **X** |
| Soltar herramienta | **Esc** |

### Puzzles
Selecciona un objeto para editar sus propiedades en el panel derecho:
- **Llave**: su color (Roja, Azul, Verde, Dorada).
- **Cofre**: con qué llave se abre y qué contiene (otra llave o nada).
- **Puerta de salida**: con qué llave se abre. Es fija en la pared norte.
- **Nota**: el texto de la pista.

El editor te avisa si la sala no se puede resolver (por ejemplo, una puerta que pide una llave que no existe).
Con **Probar sala** juegas tu escape room al instante (desde la sala 1) y con **M** vuelves al editor.

### Varias salas
Un escape room puede tener hasta **6 salas** conectadas en orden:
- En la barra de arriba, el selector cambia de sala, **+ Sala** agrega una nueva y **Quitar sala** borra la actual (hay que pulsarlo dos veces para confirmar).
- La puerta de cada sala lleva a la **siguiente**; la puerta de la última sala es la **salida final**.
- **Al cambiar de sala tu inventario se vacía.** Cada sala debe poder resolverse con lo que hay dentro de ella.
- Hay tres tipos de objeto de inventario: **Llave** (de color), **Tarjeta** (de color, objeto de 20 monedas) y **Código** (un número de 4 cifras que se escribe en un teclado). Los cofres y cuadros-cofre pueden contener cualquiera de ellos.
- Las puertas (de salida e interiores) tienen estilo de cerradura: **Llave, Tarjeta, Código o Ninguna**. Se elige en el panel de propiedades del creador.
- La validación comprueba que cada sala sea resoluble por separado.
- El editor comprueba todo el recorrido y te avisa si alguna puerta o cofre no se puede abrir.
- Las salas guardadas con la versión anterior se abren como un escape room de una sola sala.

## Monedas y tienda
Empiezas con **50 monedas**. Se ganan así (cada premio se cobra una sola vez por sala):
| Acción | Monedas |
|---|---|
| Terminar el tutorial | 25 |
| Guardar un proyecto con al menos 3 objetos y que se pueda resolver | 20 |
| Publicar una sala | 30 |
| Escapar de tu propia sala con «Probar sala» | 15 |
| Escapar de una sala de la comunidad | 10 |

En **Tienda** (menú principal) compras objetos y formas de sala. Lo comprado queda guardado.

### Objetos de la tienda
| Objeto | Precio | Qué hace |
|---|---|---|
| Planta | 10 | Decoración |
| Cuadro | 10 | Se cuelga de la pared (3 estilos) y puede llevar una pista escrita |
| Sofá | 20 | Decoración |
| Cuadro secreto | 25 | Igual que un cuadro, pero se abre y esconde una llave |
| Libro de acertijo | 30 | Hay que responder una pregunta para ganar una llave |
| Panel de interruptores | 35 | Hay que dejar 3 interruptores en la posición correcta |
| Caja fuerte | 40 | Se abre con un código de 4 dígitos |
| Reloj de pared | 15 | Marca la hora que elijas: pista para un código |
| Pared (2 m) / Pared (4 m) | 10 / 18 | Paredes interiores para dividir la sala (se giran con R) |
| Cofre misterioso | 30 | Cofre sin ninguna pista del color de la llave que necesita |
| Puerta con llave | 25 | Puerta que pones donde quieras (por ejemplo entre dos paredes) |
| Cofre con candado de código | 35 | Cofre que se abre con un código de 4 dígitos |
| Cuadro con cofre escondido | 45 | Se abre y detrás hay un cofre, con o sin llave |
| Panel de colores | 40 | Hay que pulsar 4 colores en el orden correcto |
| Cuadro con pasadizo secreto | 60 | Cuadro grande que se abre: es una salida secreta a la sala siguiente (o al final) |

Los objetos de pared (cuadros y panel) se colocan haciendo clic en la cara interior de una pared.
Los puzzles entregan una llave del color que elijas, que sirve para cofres y puertas.

### Formas de sala
Cuadrada (gratis), Rectangular (40), Pasillo (50), En L (60) y En cruz (80). Cada sala de un escape room puede tener
una forma distinta: se elige con «Forma» en la segunda fila de la barra superior del editor.

## Texturas y aspecto
El juego usa texturas **generadas por código** (madera, parquet, yeso, tela, alfombra, metal), así que no hay problemas de derechos de autor. Las paredes llevan zócalo de madera.
Si prefieres texturas fotográficas gratuitas (CC0, por ejemplo de Poly Haven o ambientCG), copia las imágenes en `assets/textures/` con los nombres indicados en `assets/textures/LEEME.txt` y el juego las usará automáticamente.

## Pasadizo secreto y paredes
- El **cuadro con pasadizo secreto** abre un hueco real en la pared. Se puede colgar en las paredes de la sala y también en las paredes de **2 m y 4 m** que pongas tú.
- Tipo **Salida**: al abrirlo avisa y pasa a la siguiente sala (o termina el escape room). Tipo **Abertura**: solo abre el hueco, sin avisar ni terminar; sirve para comunicar zonas que armes con paredes. En una pared exterior de la sala, la abertura da a un pequeño nicho oscuro.
- Las paredes colocadas y las puertas con llave ya llevan textura.

## Dónde se guardan las salas
Como archivos `.json` en `user://salas/`. En Godot: **Proyecto → Abrir carpeta de datos del usuario**. Para liberar espacio, borra salas desde el menú principal.

## Archivos
- `main.gd`: menú principal y cambio entre modos.
- `player.gd`: jugador en primera persona, inventario y HUD.
- `catalog.gd`: lista de objetos, su apariencia y su lógica de juego.
- `creator.gd`: editor 3D.
- `room_data.gd`: guardar, cargar y validar salas.
- `shell.gd`: formas de sala; genera suelo, paredes y hueco de la puerta.
- `economy.gd`: monedas, compras y premios (se guarda en `user://progreso.cfg`).
- `room_builder.gd`: construye la sala del tutorial.
- `interactable.gd`: base de los objetos que se usan con E.
- `online.gd` / `online_config.gd`: conexión con el servidor de salas (Supabase).
- `supabase_setup.sql`: crea la tabla y las reglas del servidor.
- `export_presets.cfg` y `.github/workflows/pages.yml`: exportar a web y publicar en GitHub Pages.

## Publicar el juego y compartir salas

GitHub Pages solo aloja el juego (archivos estáticos). Las salas que suben los jugadores se guardan en **Supabase** (gratis, sin escribir código de servidor).

### 1. Crear el servidor de salas
1. Crea un proyecto en supabase.com.
2. En **SQL Editor** pega todo `supabase_setup.sql` y pulsa **Run**. Si ya lo habías ejecutado antes, vuelve a ejecutarlo: es seguro y actualiza las reglas para escape rooms de varias salas.
3. En **Project Settings → API** copia la **Project URL** y la clave **anon / publishable**.
4. Pégalas en `online_config.gd`. Esa clave es pública por diseño: lo que protege los datos son las reglas del SQL (solo se puede leer y publicar, no editar ni borrar).

Con eso ya funcionan **Publicar** (en el editor) y **Salas de la comunidad** (en el menú), incluso desde el editor de Godot con F5.

### 2. Publicar el juego en GitHub Pages
1. Crea un repositorio en GitHub y sube todos los archivos (incluidos `.github` y `.gitignore`).
2. En **Settings → Pages**, elige **Source: GitHub Actions**.
3. Cada vez que subas cambios a `main`, GitHub exporta el juego a web y lo publica en `https://TU-USUARIO.github.io/TU-REPO/`.

### Notas
- Las salas guardadas «en tu equipo» se guardan en el navegador de cada persona.
- No hay cuentas de usuario: cualquiera puede publicar. Para borrar una sala, usa el **Table Editor** de Supabase.
- Si el despliegue falla por `export_presets.cfg`, en Godot ve a **Proyecto → Exportar → Añadir… → Web**, desactiva «Soporte de hilos», y sube el `export_presets.cfg` que genere.
- Los gráficos usan el renderizador «Compatibilidad» en web, así que algunos efectos (como SSAO) no se ven allí.

## Ideas para seguir
- Candado de código (teclado numérico) y palancas.
- Más muebles y decoración, y distintos tamaños de sala.
- Temporizador y puntuación.
- Cuentas de usuario, votos y moderación de salas.
