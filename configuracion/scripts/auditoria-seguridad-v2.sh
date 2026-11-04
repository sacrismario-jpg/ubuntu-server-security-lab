#!/usr/bin/env bash

set -u

# Auditoría informativa de seguridad para Ubuntu Server.
# No modifica la configuración del sistema.

FECHA=$(date '+%Y-%m-%d_%H-%M-%S')
DIRECTORIO="$HOME/auditorias"
INFORME="$DIRECTORIO/auditoria-$FECHA.txt"

mkdir -p "$DIRECTORIO"

# Guardamos la salida en un informe y la mostramos por pantalla.
exec > >(tee "$INFORME") 2>&1

echo "========================================"
echo "       AUDITORÍA DE SEGURIDAD V2"
echo "========================================"
echo "Fecha: $(date)"
echo "Servidor: $(hostname)"
echo

echo "=== 1. SISTEMA OPERATIVO ==="
grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
echo

echo "=== 2. TIEMPO ENCENDIDO ==="
uptime
echo

echo "=== 3. MEMORIA Y SWAP ==="
free -h
echo

echo "=== 4. ESPACIO EN DISCO ==="
df -h /
echo

echo "=== 5. RED Y RUTAS ==="
ip -br addr
ip route
echo

echo "=== 6. DIAGNÓSTICO DE RED ==="
if ip -4 route show default | grep -q .; then
    echo "[INFO] Existe una ruta IPv4 predeterminada."
else
    echo "[INFO] No existe una ruta IPv4 predeterminada."
fi
echo

echo "=== 7. CORTAFUEGOS UFW ==="
if command -v ufw >/dev/null 2>&1; then
    sudo ufw status verbose
    ESTADO_UFW=$(sudo ufw status | head -n 1)
    if [[ "$ESTADO_UFW" == *"active"* ]]; then
        echo "[OK] UFW está activo."
    else
        echo "[AVISO] UFW no está activo."
    fi
else
    echo "[AVISO] UFW no está instalado."
fi
echo

echo "=== 8. PUERTOS EN ESCUCHA ==="
sudo ss -lntup
echo

echo "=== 9. SERVICIO SSH ==="
if systemctl is-active --quiet ssh; then
    echo "[INFO] El servicio SSH está activo."
else
    echo "[INFO] El servicio SSH no está activo."
fi

if dpkg-query -W -f='${Status}' openssh-server 2>/dev/null | grep -q 'install ok installed'; then
    echo "[INFO] openssh-server está instalado."
else
    echo "[INFO] openssh-server no figura como instalado."
fi
echo

echo "=== 10. ACTUALIZACIONES AUTOMÁTICAS ==="
if systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
    echo "[INFO] unattended-upgrades está habilitado."
else
    echo "[INFO] unattended-upgrades no figura como habilitado."
fi
echo

echo "=== 11. RESUMEN ==="
echo "Informe guardado en: $INFORME"
echo "Auditoría finalizada."
