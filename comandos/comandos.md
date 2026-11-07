# Comandos usados

## Línea base (en la VM)

```bash
sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|x11forwarding|allowusers|logingracetime'
sudo ufw status
apt list --upgradable 2>/dev/null | grep -c upgradable
ls /etc/ssh/sshd_config.d/
```

## Incidente controlado (desde Windows, PowerShell)

```powershell
ssh prueba@192.168.56.102        # repetir con contraseña incorrecta
```

```bash
# en la VM: evidencia en el registro
sudo journalctl -u ssh --since "10 min ago" | grep -i "failed password"
sudo journalctl -u ssh --since "10 min ago" | grep -ci "failed password"
```

## Clave pública (desde Windows)

```powershell
ssh-keygen -t ed25519
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh admin1@192.168.56.102 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
ssh admin1@192.168.56.102
```

## Hardening (en la VM)

```bash
sudo bash ~/hardening.sh admin1
sudo sshd -t                                 # validar configuración
sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|maxauthtries|x11forwarding|allowusers'
sudo ufw status verbose
sudo fail2ban-client status sshd
sudo fail2ban-client get sshd maxretry
```

## Verificación

```powershell
ssh -o PreferredAuthentications=password admin1@192.168.56.102   # debe rechazar
ssh -o ConnectTimeout=5 admin1@192.168.56.102                    # tras el ban: Connection timed out
```

```bash
sudo ufw status numbered                      # regla REJECT de la IP baneada
sudo fail2ban-client set sshd unbanip 192.168.56.1
sudo unattended-upgrade --dry-run --debug
systemctl list-timers | grep -i apt
```
