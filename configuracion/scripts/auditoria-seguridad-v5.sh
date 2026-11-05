#!/usr/bin/env bash
#
# AUDITORÍA DE SEGURIDAD V5
# Laboratorio Ubuntu Server
#
# Herramienta de auditoría local, de solo lectura.
#

set -o pipefail
umask 077

FECHA=$(date '+%Y-%m-%d_%H-%M-%S')
HOST=$(hostname)
DIRECTORIO="$HOME/auditorias"
INFORME="$DIRECTORIO/auditoria-v5-$FECHA.txt"

mkdir -p "$DIRECTORIO" || {
    echo "[ERROR] No se pudo crear el directorio de informes."
    exit 1
}

touch "$INFORME" || {
    echo "[ERROR] No se pudo crear el informe."
    exit 1
}

chmod 600 "$INFORME"

# Contadores
CRITICAL=0
WARNING=0
INFO=0
ERROR=0

# Función para registrar resultados
registrar() {
    local NIVEL="$1"
    local MENSAJE="$2"

    printf '[%s] %s\n' "$NIVEL" "$MENSAJE"

    case "$NIVEL" in
        CRITICAL) ((CRITICAL+=1)) ;;
        WARNING)  ((WARNING+=1)) ;;
        INFO)     ((INFO+=1)) ;;
        ERROR)    ((ERROR+=1)) ;;
    esac
}

# Captura de informe y salida por terminal
{
    echo "========================================"
    echo "       AUDITORÍA DE SEGURIDAD V5"
    echo "========================================"
    echo "Fecha: $(date)"
    echo "Servidor: $HOST"
    echo

    # =====================================
    echo "=== 1. SISTEMA ==="

    if [ -r /etc/os-release ]; then
        grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
        uname -r
        uname -m
        registrar INFO "Información del sistema recopilada."
    else
        registrar ERROR "No se pudo consultar /etc/os-release."
    fi

    echo

    # =====================================
    echo "=== 2. MEMORIA ==="

    if MEMORIA=$(free -b 2>/dev/null); then
        echo "$MEMORIA"

        TOTAL=$(awk '/^Mem:/ {print $2}' <<< "$MEMORIA")
        DISPONIBLE=$(awk '/^Mem:/ {print $7}' <<< "$MEMORIA")

        if [[ "$TOTAL" =~ ^[0-9]+$ ]] &&
           [[ "$DISPONIBLE" =~ ^[0-9]+$ ]] &&
           (( TOTAL > 0 )); then

            USO=$(( (TOTAL - DISPONIBLE) * 100 / TOTAL ))

            echo "Memoria utilizada: ${USO}%"

            if (( USO >= 95 )); then
                registrar CRITICAL "Uso de memoria crítico: ${USO}%."
            elif (( USO >= 80 )); then
                registrar WARNING "Uso elevado de memoria: ${USO}%."
            else
                registrar INFO "Memoria dentro de los umbrales: ${USO}%."
            fi
        else
            registrar ERROR "No se pudieron calcular los valores de memoria."
        fi
    else
        registrar ERROR "No se pudo ejecutar free."
    fi

    echo

    # =====================================
    echo "=== 3. ESPACIO EN DISCO ==="

    if DISCO=$(df -P / 2>/dev/null); then
        echo "$DISCO"

        USO_DISCO=$(awk 'NR==2 {gsub("%","",$5); print $5}' <<< "$DISCO")

        if [[ "$USO_DISCO" =~ ^[0-9]+$ ]]; then
            if (( USO_DISCO >= 95 )); then
                registrar CRITICAL "Espacio en disco crítico: ${USO_DISCO}%."
            elif (( USO_DISCO >= 85 )); then
                registrar WARNING "Espacio en disco elevado: ${USO_DISCO}%."
            else
                registrar INFO "Espacio en disco correcto: ${USO_DISCO}%."
            fi
        else
            registrar ERROR "No se pudo interpretar el uso del disco."
        fi
    else
        registrar ERROR "No se pudo ejecutar df."
    fi

    echo

    # =====================================
    echo "=== 4. RED IPv4 ==="

    if ip -4 addr show; then
        registrar INFO "Direcciones IPv4 recopiladas."
    else
        registrar ERROR "No se pudieron consultar las direcciones IPv4."
    fi

    echo
    echo "--- Rutas IPv4 ---"

    if RUTAS4=$(ip -4 route show); then
        echo "$RUTAS4"

        if grep -q '^default' <<< "$RUTAS4"; then
            registrar WARNING "Existe una ruta IPv4 predeterminada."
        else
            registrar INFO "No existe ruta IPv4 predeterminada."
        fi
    else
        registrar ERROR "No se pudieron consultar las rutas IPv4."
    fi

    echo

    # =====================================
    echo "=== 5. RED IPv6 ==="

    if DIRECCIONES6=$(ip -6 addr show); then
        echo "$DIRECCIONES6"

        if grep -Eq 'inet6 [23][0-9a-fA-F]{3}:' <<< "$DIRECCIONES6"; then
            registrar WARNING "Existe al menos una dirección IPv6 global."
        else
            registrar INFO "No se detectan direcciones IPv6 globales."
        fi
    else
        registrar ERROR "No se pudieron consultar las direcciones IPv6."
    fi

    echo
    echo "--- Rutas IPv6 ---"

    if RUTAS6=$(ip -6 route show); then
        echo "$RUTAS6"

        if grep -q '^default' <<< "$RUTAS6"; then
            registrar WARNING "Existe una ruta IPv6 predeterminada."
        else
            registrar INFO "No existe ruta IPv6 predeterminada."
        fi
    else
        registrar ERROR "No se pudieron consultar las rutas IPv6."
    fi

    echo

    # =====================================
    echo "=== 6. CORTAFUEGOS UFW ==="

    if command -v ufw >/dev/null 2>&1; then

        if UFW=$(sudo ufw status verbose 2>&1); then
            echo "$UFW"

            if grep -q '^Status: active' <<< "$UFW"; then
                registrar INFO "UFW está activo."
            else
                registrar CRITICAL "UFW no está activo."
            fi

            if grep -qi 'Default: deny (incoming)' <<< "$UFW"; then
                registrar INFO "Política entrante: deny."
            else
                registrar CRITICAL "La política entrante no es deny."
            fi

            if grep -qi 'allow (outgoing)' <<< "$UFW"; then
                registrar INFO "Política saliente: allow."
            else
                registrar WARNING "La política saliente no es allow."
            fi

            if grep -Eq '22/tcp[[:space:]]+ALLOW IN[[:space:]]+192\.168\.50\.1' <<< "$UFW"; then
                registrar INFO "Regla SSH desde el anfitrión detectada."
            else
                registrar WARNING "No se encuentra la regla SSH esperada para el anfitrión."
            fi

        else
            echo "$UFW"
            registrar ERROR "No se pudo consultar el estado de UFW."
        fi
    else
        registrar CRITICAL "UFW no está instalado."
    fi

    echo

    # =====================================
    echo "=== 7. PUERTOS EN ESCUCHA ==="

    if PUERTOS=$(ss -lntup 2>&1); then
        echo "$PUERTOS"

        if grep -qE 'LISTEN|UNCONN' <<< "$PUERTOS"; then
            registrar INFO "Se han identificado sockets en escucha."
        else
            registrar INFO "No se detectan sockets en escucha."
        fi

        if awk '
            NR > 1 && $1 == "tcp" && $2 == "LISTEN" {
                if ($5 ~ /^0\.0\.0\.0:/ || $5 ~ /^\*:/) {
                    found=1
                }
            }
            END { exit !found }
        ' <<< "$PUERTOS"; then
            registrar WARNING "Existen servicios TCP escuchando en todas las interfaces IPv4."
        else
            registrar INFO "No se detectan listeners TCP wildcard IPv4."
        fi

        if awk '
            NR > 1 && $1 == "tcp" && $2 == "LISTEN" {
                if ($5 ~ /^\[::\]:/ || $5 == "*:*") {
                    found=1
                }
            }
            END { exit !found }
        ' <<< "$PUERTOS"; then
            registrar WARNING "Existen servicios TCP escuchando en todas las interfaces IPv6."
        else
            registrar INFO "No se detectan listeners TCP wildcard IPv6."
        fi

    else
        echo "$PUERTOS"
        registrar ERROR "No se pudieron consultar los puertos."
    fi

    echo

    # =====================================
    echo "=== 8. CONFIGURACIÓN SSH EFECTIVA ==="

    if command -v sshd >/dev/null 2>&1; then

        if SSH_CONFIG=$(sudo sshd -T 2>&1); then

            echo "$SSH_CONFIG" |
                grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication) '

            ROOT=$(awk '$1=="permitrootlogin" {print $2}' <<< "$SSH_CONFIG")
            PUBKEY=$(awk '$1=="pubkeyauthentication" {print $2}' <<< "$SSH_CONFIG")
            PASSWORD=$(awk '$1=="passwordauthentication" {print $2}' <<< "$SSH_CONFIG")
            INTERACTIVE=$(awk '$1=="kbdinteractiveauthentication" {print $2}' <<< "$SSH_CONFIG")

            if [[ "$ROOT" == "no" ]]; then
                registrar INFO "Acceso SSH directo de root deshabilitado."
            else
                registrar CRITICAL "Acceso SSH directo de root permitido o no restringido."
            fi

            if [[ "$PUBKEY" == "yes" ]]; then
                registrar INFO "Autenticación mediante clave pública habilitada."
            else
                registrar WARNING "Autenticación mediante clave pública deshabilitada."
            fi

            if [[ "$PASSWORD" == "no" ]]; then
                registrar INFO "Autenticación SSH por contraseña deshabilitada."
            else
                registrar CRITICAL "Autenticación SSH por contraseña habilitada."
            fi

            if [[ "$INTERACTIVE" == "no" ]]; then
                registrar INFO "Autenticación interactiva deshabilitada."
            else
                registrar WARNING "Autenticación interactiva habilitada."
            fi

        else
            echo "$SSH_CONFIG"
            registrar ERROR "No se pudo obtener la configuración efectiva de SSH."
        fi

    else
        registrar ERROR "No se encuentra el ejecutable sshd."
    fi

    echo

    # =====================================
    echo "=== 9. CUENTAS CON UID 0 ==="

    if USUARIOS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd); then
        echo "$USUARIOS"

        NUM_UID0=$(wc -l <<< "$USUARIOS")

        if (( NUM_UID0 == 1 )) && [[ "$USUARIOS" == "root" ]]; then
            registrar INFO "Solo existe la cuenta root con UID 0."
        else
            registrar CRITICAL "Se detectan cuentas adicionales con UID 0."
        fi
    else
        registrar ERROR "No se pudieron consultar las cuentas."
    fi

    echo

    # =====================================
    echo "=== 10. SERVICIOS FALLIDOS ==="

    if FALLIDOS=$(systemctl --failed --no-legend 2>&1); then

        if [[ -z "$FALLIDOS" ]]; then
            registrar INFO "No se detectan servicios fallidos."
        else
            echo "$FALLIDOS"
            registrar WARNING "Se detectan servicios fallidos."
        fi

    else
        echo "$FALLIDOS"
        registrar ERROR "No se pudo consultar systemd."
    fi

    echo

    # =====================================
    echo "=== 11. ACTUALIZACIONES AUTOMÁTICAS ==="

    if command -v dpkg-query >/dev/null 2>&1 &&
       dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null |
       grep -q 'install ok installed'; then

        if grep -Eq 'APT::Periodic::(Update-Package-Lists|Unattended-Upgrade) "[1-9]' \
            /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
            registrar INFO "unattended-upgrades está instalado y configurado."
        else
            registrar WARNING "unattended-upgrades está instalado, pero no se confirma su configuración automática."
        fi

    else
        registrar WARNING "unattended-upgrades no está instalado."
    fi

    echo

    # =====================================
    echo "=== 12. RESUMEN DE SEGURIDAD ==="

    echo "CRITICAL: $CRITICAL"
    echo "WARNING:  $WARNING"
    echo "INFO:     $INFO"
    echo "ERROR:    $ERROR"

    echo
    echo "Informe: $INFORME"
    echo "Auditoría V5 finalizada."

} > "$INFORME" 2>&1

# Mostrar el informe generado
if ! cat "$INFORME"; then
    echo "[ERROR] No se pudo leer el informe generado."
    exit 1
fi

# Proteger los permisos del informe
if ! chmod 600 "$INFORME"; then
    echo "[ERROR] No se pudieron establecer los permisos del informe."
    exit 1
fi

# Comprobar errores durante la auditoría
if (( ERROR > 0 )); then
    echo "[ERROR] La auditoría terminó con $ERROR comprobaciones no realizadas correctamente."
    exit 2
fi

echo "[OK] Auditoría V5 completada sin errores de comprobación."
exit 0
