# AWS Profile Manager (macOS)

Una app SwiftUI nativa para gestionar visualmente tus perfiles de AWS SSO
(IAM Identity Center): ver los perfiles, cambiar el `[default]`, y refrescar los
tokens lanzando el login en el browser.

> **No maneja credenciales.** Toda la autenticación se delega en el AWS CLI
> (`aws sso login`). La app solo lee/escribe `~/.aws/config` y lee la expiración
> de los tokens cacheados — nunca el token en sí.

## Requisitos

- macOS 14+
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  en `/usr/local/bin/aws` o `/opt/homebrew/bin/aws` (o exportá `AWS_CLI_PATH`).

## Correr en desarrollo

```bash
cd AWSProfileManager
swift run
```

## Tests

```bash
swift test
```

Los tests cubren la lógica pura del núcleo: parser del config, agrupación por
sesión, detección del default, reescritura segura del bloque `[default]`
(con backup) y clasificación de expiración de tokens.

## Arquitectura

Hexagonal + Screaming, en dos targets que imponen la frontera por compilación:

- **`AWSProfileKit`** — dominio + casos de uso + infraestructura. No linkea SwiftUI.
  - `Domain/` — `Profile`, `SSOSession`, `ProfileGroup`, `TokenStatus`, `AWSConfiguration`
  - `Ports/` — `ProfileRepository`, `SSOTokenReader`, `AWSCommandRunner`
  - `Application/` — `LoadProfileGroups`, `SetDefaultProfile`, `RefreshSSOSession`
  - `Infrastructure/` — parser INI, writer con backup atómico, lector de cache SSO, runner de proceso
- **`AWSProfileManager`** — el ejecutable: solo SwiftUI + composition root.

## Qué hace

- Lista los perfiles **agrupados por su `sso-session`** (un login refresca todo el grupo).
- Marca el default actual y permite cambiarlo (**reescribe `[default]` con backup** `config.bak.<timestamp>`).
- Muestra el estado del token por sesión (verde / ámbar / rojo) leído del cache.
- Botón **Login / Refresh** por sesión → `aws sso login --sso-session <name>` (abre el browser).

## Distribución

Esta app **no puede ir sandboxeada** (necesita leer `~/.aws` y ejecutar el CLI),
por lo que **no es apta para el Mac App Store**. Para distribuirla: empaquetar
como `.app`, firmar con **Developer ID** y **notarizar**.
