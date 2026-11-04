# Laboratorio Ubuntu Server: Administración y Seguridad

## 1. Descripción del proyecto

Laboratorio práctico de administración de sistemas Linux y seguridad de redes, construido mediante virtualización KVM/QEMU sobre Zorin OS.

El objetivo es desplegar un servidor Ubuntu aislado, aplicar medidas básicas de hardening, restringir el acceso administrativo y desarrollar un script de auditoría que permita evaluar su configuración de seguridad.

El proyecto está orientado al aprendizaje práctico de administración Linux, seguridad de sistemas, redes y automatización.

## 2. Arquitectura del laboratorio

### Sistema anfitrión
- Sistema operativo: Zorin OS 18.1.
- Base: Ubuntu 24.04.
- Hipervisor: KVM/QEMU.
- Gestión de máquinas virtuales: libvirt y virt-manager.

### Máquina virtual
- Nombre: ubuntu-server-lab.
- Sistema operativo: Ubuntu Server 26.04.1 LTS.
- Kernel: 7.0.0-30-generic.
- Arquitectura: x86-64.
- Firmware virtual: QEMU.

## 3. Diseño de red

Se ha creado una red virtual independiente denominada `lab-aislado`.

| Parámetro | Configuración |
|---|---|
| Red virtual | lab-aislado |
| Bridge | virbr-lab |
| Dirección del anfitrión | 192.168.50.1/24 |
| Dirección de la VM | 192.168.50.10/24 |
| Interfaz de la VM | enp1s0 |
| DHCP | Deshabilitado |
| NAT / Forward | No configurado |
| Inicio automático | Deshabilitado |

La máquina virtual utiliza una dirección IPv4 estática y no dispone de una ruta predeterminada.

### Validación del aislamiento

Se realizaron pruebas de conectividad desde Ubuntu Server:

- Comunicación con el anfitrión: correcta.
- Comunicación IPv4 con Internet: no disponible.
- Comunicación IPv6 con Internet: no disponible.
- Ruta IPv4 predeterminada: inexistente.
- Ruta IPv6 predeterminada: inexistente.
- Dirección IPv6 global: no configurada en la interfaz.

La configuración permite administrar la VM desde el anfitrión sin proporcionarle conectividad externa mediante la configuración actual de la red virtual.

## 4. Seguridad del sistema

### 4.1 Cortafuegos UFW

Se ha configurado UFW con las siguientes políticas:

- Tráfico entrante: denegado por defecto.
- Tráfico saliente: permitido.
- Tráfico enrutado: deshabilitado.
- Registro: activado en nivel bajo.

Regla de acceso administrativo:

| Puerto | Protocolo | Origen | Acción |
|---|---|---|---|
| 22 | TCP | 192.168.50.1 | ALLOW |

El acceso SSH queda limitado a las conexiones procedentes del anfitrión.

### 4.2 Endurecimiento SSH

Se ha configurado OpenSSH para utilizar autenticación mediante clave pública.

Configuración efectiva verificada:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

Medidas implementadas:

- Autenticación mediante clave Ed25519.
- Deshabilitación de autenticación por contraseña.
- Deshabilitación de autenticación interactiva por teclado.
- Prohibición del acceso directo de root.
- Recarga y validación de la configuración SSH.

La conexión desde el anfitrión mediante clave pública se ha probado satisfactoriamente.

## 5. Auditoría automatizada

Se ha desarrollado un script de auditoría en Bash para recopilar información del sistema y detectar configuraciones que requieren revisión.

### Versiones desarrolladas

- V1: auditoría inicial del sistema.
- V2: generación automática de informes.
- V3: incorporación de comprobaciones adicionales y clasificación de resultados.
- V4: ampliación de las comprobaciones de seguridad y configuración SSH efectiva.

### Funcionalidades de V4

- Identificación del sistema y kernel.
- Comprobación de memoria y swap.
- Análisis del espacio en disco.
- Inspección de interfaces y rutas de red.
- Estado y configuración de UFW.
- Identificación de puertos en escucha.
- Revisión de parámetros efectivos de SSH.
- Detección de cuentas con UID 0.
- Comprobación de servicios fallidos.
- Verificación de actualizaciones automáticas.
- Clasificación de resultados en CRITICAL, WARNING e INFO.
- Generación automática de informes de auditoría.

### Último resultado registrado

Auditoría V4 ejecutada el 04/11/2026.

| Categoría | Resultado |
|---|---:|
| CRITICAL | 0 |
| WARNING | 2 |
| INFO | 10 |

Los dos avisos corresponden a la escucha de SSH en TCP/22 y a la escucha en todas las interfaces IPv4.

Se consideran avisos que requieren interpretación contextual, no vulnerabilidades confirmadas. UFW restringe el acceso entrante al anfitrión.

## 6. Resultados de seguridad

Controles implementados y verificados:

- Red virtual independiente.
- Ausencia de ruta predeterminada en IPv4 e IPv6.
- Ausencia de conectividad externa en las pruebas realizadas.
- Comunicación administrativa entre anfitrión y VM.
- Cortafuegos activo con política restrictiva.
- Acceso SSH mediante clave pública.
- Autenticación SSH por contraseña deshabilitada.
- Acceso directo de root por SSH prohibido.
- Ausencia de servicios fallidos en la última comprobación.
- Actualizaciones automáticas activas.

## 7. Tecnologías y herramientas

- Zorin OS.
- Ubuntu Server.
- KVM/QEMU.
- libvirt.
- virt-manager.
- OpenSSH.
- UFW.
- Bash.
- systemd.
- iproute2.
- ss.
- unattended-upgrades.

## 8. Posibles mejoras futuras

- Incorporar registros históricos y comparación entre auditorías.
- Mejorar la clasificación de riesgos y reducir falsos positivos.
- Añadir comprobaciones de integridad y permisos.
- Automatizar la ejecución periódica de auditorías.
- Incorporar monitorización de recursos y servicios.
- Documentar pruebas adicionales de seguridad de red.

## 9. Estado del proyecto

**Fase completada:** despliegue del servidor, configuración de red aislada, endurecimiento SSH, configuración del cortafuegos y auditoría automatizada V4.

**Fase actual:** documentación técnica y preparación de evidencias para portfolio profesional.

---

Proyecto de aprendizaje práctico de administración de sistemas Linux y ciberseguridad.
