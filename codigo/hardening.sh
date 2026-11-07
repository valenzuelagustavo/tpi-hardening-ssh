#!/usr/bin/env bash
# =============================================================================
# hardening.sh - Hardening basico de acceso SSH en Ubuntu Server 24.04
# Trabajo Integrador - Arquitectura y Sistemas Operativos (TUPaD - UTN)
#
# Aplica, en este orden:
#   1. SSH: solo clave publica, sin root, 3 intentos, sin X11, solo un usuario
#   2. Firewall UFW: deniega todo lo entrante salvo SSH
#   3. fail2ban: bloquea la IP que falla 3 veces (via UFW, 10 minutos)
#   4. Actualizaciones automaticas de seguridad (unattended-upgrades)
#
# Uso (en el servidor, como administrador):
#   sudo bash hardening.sh [usuario]      # por defecto: admin1
#
# IMPORTANTE: antes de ejecutarlo, el usuario debe tener su clave publica en
# ~/.ssh/authorized_keys. Si no, el script se detiene para no dejarte sin
# acceso (porque desactiva la autenticacion por contrasena).
# Probar siempre en una VM de laboratorio, nunca en un servidor ajeno.
# =============================================================================
set -euo pipefail

ADMIN_USER="${1:-admin1}"
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-hardening.conf"
AUTH_KEYS="/home/${ADMIN_USER}/.ssh/authorized_keys"

info() { printf '\n\033[1;34m[+] %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31m[!] %s\033[0m\n' "$*" >&2; exit 1; }

# --- 0. Comprobaciones previas ------------------------------------------------
[[ $EUID -eq 0 ]] || fail "Ejecutar con sudo: sudo bash $0 [usuario]"
id "$ADMIN_USER" >/dev/null 2>&1 || fail "El usuario '$ADMIN_USER' no existe."
[[ -s "$AUTH_KEYS" ]] || fail "No hay clave publica en $AUTH_KEYS. Cargala antes de continuar."

# --- 1. SSH endurecido ---------------------------------------------------------
# En sshd_config.d gana el PRIMER valor que se lee (orden alfabetico), por eso
# el archivo se llama 00-hardening.conf.
info "Configurando SSH ($SSHD_DROPIN)"
apt-get install -y openssh-server >/dev/null
cat > "$SSHD_DROPIN" <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowUsers ${ADMIN_USER}
EOF

# Validar antes de aplicar: si hay un error, se revierte y no se reinicia nada.
if ! sshd -t; then
    rm -f "$SSHD_DROPIN"
    fail "La configuracion de SSH es invalida; se revirtio el cambio."
fi
systemctl restart ssh

# --- 2. Firewall UFW -----------------------------------------------------------
# Permitir SSH ANTES de activar el firewall, o se pierde el acceso remoto.
info "Configurando firewall (UFW)"
apt-get install -y ufw >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable

# --- 3. fail2ban ---------------------------------------------------------------
info "Configurando fail2ban"
apt-get install -y fail2ban >/dev/null
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime   = 10m
findtime  = 10m
maxretry  = 3
banaction = ufw

[sshd]
enabled = true
backend = systemd
EOF
# El paquete arranca el servicio solo al instalarse con la config por defecto:
# hay que REINICIARLO para que lea jail.local (enable --now no alcanza).
systemctl enable fail2ban
systemctl restart fail2ban

# --- 4. Actualizaciones automaticas de seguridad -------------------------------
info "Verificando actualizaciones automaticas"
apt-get install -y unattended-upgrades >/dev/null
dpkg-reconfigure -f noninteractive unattended-upgrades

# --- Verificacion: valores EFECTIVOS, no los escritos ---------------------------
info "Verificacion"
echo "--- sshd -T ---"
sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|x11forwarding|allowusers|logingracetime'
echo "--- ufw ---"
ufw status verbose
echo "--- fail2ban (valores efectivos) ---"
echo "maxretry: $(fail2ban-client get sshd maxretry)"
fail2ban-client get sshd actions
fail2ban-client status sshd

info "Listo. Probar en OTRA terminal que el acceso por clave funciona antes de cerrar esta sesion."
