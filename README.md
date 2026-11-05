# Ubuntu Server Security Lab

Laboratorio práctico de administración Linux, hardening de sistemas y seguridad de redes mediante virtualización KVM/QEMU.

El proyecto consiste en desplegar un servidor Ubuntu, configurar una red virtual independiente, aplicar medidas de seguridad y desarrollar scripts Bash para automatizar auditorías del sistema.

## 1. Objetivos

- Administrar un servidor Ubuntu desde terminal.
- Diseñar una red virtual con acceso restringido.
- Aplicar medidas de hardening en SSH.
- Configurar y verificar un cortafuegos UFW.
- Analizar servicios, puertos y rutas de red.
- Automatizar comprobaciones de seguridad mediante Bash.
- Generar informes técnicos reproducibles.

## 2. Arquitectura

### Sistema anfitrión
- Zorin OS 18.1.
- Base Ubuntu 24.04.
- KVM/QEMU.
- libvirt y virt-manager.

### Máquina virtual
- Nombre: `ubuntu-server-lab`.
- Sistema operativo: Ubuntu Server 26.04.1 LTS.
- Kernel: 7.0.0-30-generic.
- Arquitectura: x86-64.
- Adaptador de red: VirtIO.

## 3. Diseño de red

Se ha creado una red virtual denominada `lab-aislado`.

| Parámetro | Configuración |
|---|---|
| Red virtual | lab-aislado |
| Bridge | virbr-lab |
| IP del anfitrión | 192.168.50.1/24 |
| IP de la VM | 192.168.50.10/24 |
| Interfaz | enp1s0 |
| DHCP | Deshabilitado |
| NAT / Forward | No configurado |
| Gateway IPv4 | No configurado |
| Ruta predeterminada IPv6 | No configurada |

La máquina virtual utiliza una dirección IPv4 estática. No tiene configurada una ruta predeterminada IPv4 ni IPv6.

La interfaz se ha declarado opcional en Netplan para evitar que `systemd-networkd-wait-online` espere una conectividad externa que no forma parte del diseño del laboratorio.

**Nota de seguridad:** la ausencia de rutas predeterminadas y la configuración de la red virtual reducen la conectividad disponible, pero no constituyen por sí solas una auditoría completa de aislamiento del anfitrión y del hipervisor.

## 4. Medidas de seguridad

### 4.1 UFW

Configuración aplicada:

- Cortafuegos activo.
- Política de entrada: deny.
- Política de salida: allow.
- Tráfico enrutado: deshabilitado.
- Registro de actividad: low.

Regla de acceso SSH:

| Puerto | Protocolo | Origen | Acción |
|---|---|---|---|
| 22 | TCP | 192.168.50.1 | ALLOW |

El acceso administrativo está limitado mediante una regla de entrada desde el anfitrión.

### 4.2 Hardening SSH

Configuración efectiva comprobada:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

Medidas implementadas:

- Autenticación mediante clave pública Ed25519.
- Deshabilitación de autenticación por contraseña.
- Deshabilitación de autenticación interactiva.
- Prohibición del acceso SSH directo de root.
- Validación de la configuración mediante `sshd -t`.
- Comprobación de parámetros efectivos mediante `sshd -T`.

El acceso SSH desde el anfitrión se ha probado satisfactoriamente.

## 5. Auditoría automatizada

Se ha desarrollado una colección progresiva de scripts Bash para revisar la configuración del servidor.

### Evolución

| Versión | Mejoras |
|---|---|
| V1 | Auditoría inicial del sistema |
| V2 | Generación automática de informes |
| V3 | Ampliación de comprobaciones y clasificación |
| V4 | Revisión de configuración SSH y seguridad |
| V5 | Mejoras en diagnóstico, gestión de errores y comprobaciones de red |

### Funcionalidades de V5

- Identificación del sistema, kernel y arquitectura.
- Comprobación de memoria y swap.
- Análisis del espacio en disco.
- Inspección de interfaces y rutas IPv4.
- Inspección de direcciones y rutas IPv6.
- Comprobación del estado y las políticas de UFW.
- Identificación de puertos TCP y UDP en escucha.
- Verificación de la configuración efectiva de SSH.
- Detección de cuentas con UID 0.
- Comprobación de servicios fallidos.
- Verificación de actualizaciones automáticas.
- Clasificación de resultados en CRITICAL, WARNING, INFO y ERROR.
- Generación de informes con fecha y hora.
- Protección de los permisos de los informes.

### Ejecución

En Ubuntu Server:

```bash
sudo -v
~/auditoria-seguridad-v5.sh
```

Los informes se guardan en:

```text
~/auditorias/
```

El script es una herramienta de diagnóstico de solo lectura: recopila información y no aplica cambios en la configuración del servidor.

## 6. Resultados de V5

Última auditoría registrada: **5 de noviembre de 2026**.

| Categoría | Resultado |
|---|---:|
| CRITICAL | 0 |
| WARNING | 2 |
| INFO | 19 |
| ERROR | 0 |

### Estado de los controles

- UFW activo con política entrante restrictiva.
- SSH endurecido y autenticación por clave pública.
- Sin cuentas adicionales con UID 0.
- Sin servicios fallidos.
- Actualizaciones automáticas configuradas.
- Sin ruta predeterminada IPv4.
- Sin ruta predeterminada IPv6.
- Sin direcciones IPv6 globales en la interfaz.

Los dos WARNING corresponden a sockets SSH escuchando en direcciones wildcard IPv4 e IPv6. La escucha en todas las interfaces no demuestra por sí sola que el servicio sea accesible desde cualquier origen: debe interpretarse junto con las reglas del cortafuegos y la configuración de red.

El informe completo se encuentra en `auditorias/`.

## 7. Estructura del repositorio

```text
ubuntu-server-security-lab/
├── README.md
├── .gitignore
├── auditorias/
│   ├── informes históricos
│   └── auditoria-v5-2026-11-05_10-28-32.txt
├── configuracion/
│   ├── lab-aislado.xml
│   └── scripts/
│       ├── auditoria-seguridad-v2.sh
│       ├── auditoria-seguridad-v3.sh
│       ├── auditoria-seguridad-v4.sh
│       └── auditoria-seguridad-v5.sh
├── documentacion/
└── evidencias/
    └── sistema/
        └── configuracion-seguridad.txt
```

## 8. Tecnologías utilizadas

- Linux.
- Ubuntu Server.
- Zorin OS.
- KVM/QEMU.
- libvirt.
- virt-manager.
- Bash.
- OpenSSH.
- UFW.
- systemd.
- Netplan.
- iproute2.
- unattended-upgrades.
- Git y GitHub.

## 9. Limitaciones y mejoras futuras

El laboratorio representa un entorno de aprendizaje y pruebas. No debe considerarse una arquitectura de producción ni una auditoría de seguridad integral.

Posibles ampliaciones:

- Análisis contextual de exposición de puertos.
- Comparación histórica de auditorías.
- Comprobaciones de integridad y permisos.
- Monitorización de servicios y recursos.
- Automatización de auditorías periódicas.

## 10. Estado del proyecto

**Versión estable documentada: V5.**

Despliegue, configuración de red, hardening SSH, UFW y auditoría automatizada implementados y probados.

Proyecto desarrollado como portfolio práctico de administración de sistemas Linux y ciberseguridad.
