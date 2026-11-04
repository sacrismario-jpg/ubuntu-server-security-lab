#!/usr/bin/env bash

set -u

FECHA=$(date +%Y-%m-%d_%H-%M-%S)
DIRECTORIO="$HOME/auditorias"
INFORME="$DIRECTORIO/auditoria-v4-$FECHA.txt"

mkdir -p "$DIRECTORIO"

CRITICAL=0
WARNING=0
INFO=0

alerta() {
    local NIVEL="$1"
    local MENSAJE="$2"

    printf '[%s] %s\n' "$NIVEL" "$MENSAJE"

    case "$NIVEL" in
        CRITICAL) ((CRITICAL+=1)) ;;
        WARNING)  ((WARNING+=1)) ;;
        INFO)     ((INFO+=1)) ;;
    esac
}

{
echo "========================================"
echo "       AUDITORÍA DE SEGURIDAD V4"
echo "========================================"
echo "Fecha: $(date)"
echo "Servidor: $(hostname)"
echo

echo "=== 1. SISTEMA ==="
grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
uname -r
echo

echo "=== 2. MEMORIA ==="
free -h

MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

if [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_USED=$((100 * (MEM_TOTAL - MEM_AVAILABLE) / MEM_TOTAL))

    if [ "$MEM_USED" -ge 95 ]; then
        alerta CRITICAL "Memoria disponible inferior al 5%."
    elif [ "$MEM_USED" -ge 85 ]; then
        alerta WARNING "Presión de memoria elevada: ${MEM_USED}%."
    else
        alerta INFO "Memoria disponible dentro de los umbrales: ${MEM_USED}% utilizada."
    fi
fi
echo

echo "=== 3. ESPACIO EN DISCO ==="
df -h /

DISCO=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')

if [ "$DISCO" -ge 95 ]; then
    alerta CRITICAL "Disco raíz ocupado al ${DISCO}%."
elif [ "$DISCO" -ge 85 ]; then
    alerta WARNING "Espacio en disco reducido: ${DISCO}%."
else
    alerta INFO "Espacio en disco correcto: ${DISCO}%."
fi
echo

echo "=== 4. RED Y RUTAS ==="
ip -br addr
ip route

if ip -4 route show default | grep -q .; then
    alerta WARNING "Existe una ruta IPv4 predeterminada."
else
    alerta INFO "No existe ruta IPv4 predeterminada."
fi
echo

echo "=== 5. CORTAFUEGOS ==="
sudo ufw status verbose

if sudo ufw status | grep -q '^Status: active'; then
    alerta INFO "UFW está activo."
else
    alerta CRITICAL "UFW está inactivo."
fi
echo

echo "=== 6. PUERTOS EN ESCUCHA ==="
sudo ss -lntup

if sudo ss -lnt | awk 'NR>1 {print $4}' | grep -Eq '(^|\])(:|\])22$'; then
    alerta WARNING "SSH escucha en TCP/22. Revisar exposición y reglas UFW."
fi

if sudo ss -lnt | awk 'NR>1 {print $4}' | grep -Eq '0\.0\.0\.0:|\\*:'; then
    alerta WARNING "Hay servicios TCP escuchando en todas las interfaces IPv4."
fi

echo

echo "=== 7. CONFIGURACIÓN SSH EFECTIVA ==="

if command -v sshd >/dev/null 2>&1; then
    SSH_CONFIG=$(sudo sshd -T 2>/dev/null)

    echo "$SSH_CONFIG" | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) '

    if echo "$SSH_CONFIG" | grep -q '^passwordauthentication yes'; then
        alerta CRITICAL "SSH permite autenticación mediante contraseña."
    else
        alerta INFO "Autenticación SSH por contraseña deshabilitada."
    fi

    if echo "$SSH_CONFIG" | grep -q '^permitrootlogin yes'; then
        alerta CRITICAL "SSH permite acceso directo de root."
    else
        alerta INFO "Acceso SSH directo de root restringido."
    fi

    if echo "$SSH_CONFIG" | grep -q '^pubkeyauthentication yes'; then
        alerta INFO "Autenticación mediante clave pública habilitada."
    else
        alerta WARNING "Autenticación mediante clave pública deshabilitada."
    fi
else
    alerta INFO "OpenSSH Server no está instalado."
fi
echo

echo "=== 8. CUENTAS CON UID 0 ==="
awk -F: '$3 == 0 {print $1}' /etc/passwd

CUENTAS_ROOT=$(awk -F: '$3 == 0 {n++} END {print n+0}' /etc/passwd)

if [ "$CUENTAS_ROOT" -gt 1 ]; then
    alerta CRITICAL "Existen varias cuentas con UID 0."
else
    alerta INFO "Solo existe la cuenta root con UID 0."
fi
echo

echo "=== 9. SERVICIOS FALLIDOS ==="
systemctl --failed --no-legend

FALLIDOS=$(systemctl --failed --no-legend | wc -l)

if [ "$FALLIDOS" -gt 0 ]; then
    alerta WARNING "Se detectan $FALLIDOS servicios fallidos."
else
    alerta INFO "No se detectan servicios fallidos."
fi
echo

echo "=== 10. ACTUALIZACIONES AUTOMÁTICAS ==="

if systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
    alerta INFO "unattended-upgrades está habilitado."
else
    alerta WARNING "No se confirma que unattended-upgrades esté habilitado."
fi
echo

echo "=== 11. RESUMEN DE SEGURIDAD ==="
echo "CRITICAL: $CRITICAL"
echo "WARNING:  $WARNING"
echo "INFO:     $INFO"
echo
echo "Informe: $INFORME"
echo "Auditoría finalizada."

} 2>&1 | tee "$INFORME"
