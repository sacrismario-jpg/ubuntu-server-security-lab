#!/usr/bin/env bash

set -u

FECHA=$(date +%Y-%m-%d_%H-%M-%S)
DIRECTORIO="$HOME/auditorias"
INFORME="$DIRECTORIO/auditoria-v3-$FECHA.txt"

mkdir -p "$DIRECTORIO"

CRITICAL=0
WARNING=0
INFO=0

alerta() {
    NIVEL="$1"
    MENSAJE="$2"

    echo "[$NIVEL] $MENSAJE"

    case "$NIVEL" in
        CRITICAL) ((CRITICAL+=1)) ;;
        WARNING)  ((WARNING+=1)) ;;
        INFO)     ((INFO+=1)) ;;
    esac
}

{
echo "========================================"
echo "       AUDITORÍA DE SEGURIDAD V3"
echo "========================================"
echo "Fecha: $(date)"
echo "Servidor: $(hostname)"
echo

echo "=== 1. SISTEMA ==="
grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
uname -r
echo

echo "=== 2. MEMORIA Y SWAP ==="
free -h
echo

MEMORIA=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')

if [ "$MEMORIA" -ge 95 ]; then
    alerta CRITICAL "Uso de memoria superior al 95%."
elif [ "$MEMORIA" -ge 85 ]; then
    alerta WARNING "Uso de memoria elevado: ${MEMORIA}%."
else
    alerta INFO "Uso de memoria dentro de los umbrales: ${MEMORIA}%."
fi
echo

echo "=== 3. ESPACIO EN DISCO ==="
df -h /
DISCO=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')

if [ "$DISCO" -ge 95 ]; then
    alerta CRITICAL "Disco raíz ocupado al ${DISCO}%."
elif [ "$DISCO" -ge 85 ]; then
    alerta WARNING "Espacio en disco reducido: ${DISCO}% ocupado."
else
    alerta INFO "Espacio en disco dentro de los umbrales: ${DISCO}% ocupado."
fi
echo

echo "=== 4. RED Y RUTAS ==="
ip -br addr
ip route

if ip -4 route show default | grep -q .; then
    alerta WARNING "Existe una ruta IPv4 predeterminada. Revisar aislamiento."
else
    alerta INFO "No existe ruta IPv4 predeterminada."
fi
echo

echo "=== 5. CORTAFUEGOS ==="
sudo ufw status verbose

if sudo ufw status | grep -q "Status: active"; then
    alerta INFO "UFW está activo."
else
    alerta CRITICAL "UFW no está activo."
fi
echo

echo "=== 6. PUERTOS EN ESCUCHA ==="
sudo ss -lntup
echo

if sudo ss -lnt | grep -q ':22 '; then
    alerta WARNING "Puerto SSH 22 en escucha."
else
    alerta INFO "No se detecta SSH escuchando en TCP/22."
fi
echo

echo "=== 7. CONFIGURACIÓN SSH ==="

if systemctl is-active --quiet ssh; then
    alerta INFO "Servicio SSH activo."
else
    alerta INFO "Servicio SSH inactivo."
fi

if command -v sshd >/dev/null 2>&1; then
    sudo sshd -T 2>/dev/null | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
fi
echo

echo "=== 8. CUENTAS CON UID 0 ==="
awk -F: '$3 == 0 {print $1}' /etc/passwd

CUENTAS_ROOT=$(awk -F: '$3 == 0 {n++} END {print n+0}' /etc/passwd)

if [ "$CUENTAS_ROOT" -gt 1 ]; then
    alerta WARNING "Se detectan varias cuentas con UID 0."
else
    alerta INFO "No se detectan cuentas adicionales con UID 0."
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

if systemctl is-active --quiet unattended-upgrades; then
    alerta INFO "unattended-upgrades está activo."
elif systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
    alerta INFO "unattended-upgrades está habilitado."
else
    alerta WARNING "No se confirma la activación de actualizaciones automáticas."
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
