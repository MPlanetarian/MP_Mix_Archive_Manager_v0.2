#!/bin/bash
set -e

echo "=== 1. Restoring standard nx user in nxserver.service ==="
sed -i 's/^#User=nx/User=nx/' /etc/systemd/system/nxserver.service
sed -i 's/^#Group=nx/Group=nx/' /etc/systemd/system/nxserver.service
systemctl reset-failed nxserver.service 2>/dev/null || true
systemctl daemon-reload

echo "=== 2. Installing SUID root environment reader ==="
cp /var/home/mplanetarian/Documents/BASH_SCRIPTS/nxcat_environ /var/nomachine/NX/bin/nxcat_environ
chown root:root /var/nomachine/NX/bin/nxcat_environ
chmod 4755 /var/nomachine/NX/bin/nxcat_environ

echo "=== 3. Hooking nxcat_environ into nxenvironmentget.sh ==="
if ! grep -q "nxcat_environ" /var/nomachine/NX/scripts/restricted/nxenvironmentget.sh; then
  sed -i '/^PROCESS_ID=/a \
if [ -x "/var/nomachine/NX/bin/nxcat_environ" ]; then\
  exec /var/nomachine/NX/bin/nxcat_environ "$@"\
fi' /var/nomachine/NX/scripts/restricted/nxenvironmentget.sh
fi

echo "=== 4. Syncing active Xauthority credentials ==="
ACTIVE_AUTH=$(find /run/user/1000/ -name "xauth_*" 2>/dev/null | head -n 1)
if [ -n "$ACTIVE_AUTH" ]; then
  echo "Found active Xauthority at $ACTIVE_AUTH"
  cp "$ACTIVE_AUTH" /var/home/mplanetarian/.Xauthority
  chmod 644 /var/home/mplanetarian/.Xauthority
  chmod 711 /var/home/mplanetarian
  
  mkdir -p /var/NX/nx/
  cp "$ACTIVE_AUTH" /var/NX/nx/.Xauthority
  chown nx:nx /var/NX/nx/.Xauthority
  chmod 644 /var/NX/nx/.Xauthority
fi

echo "=== 5. Restarting NoMachine server ==="
pkill -9 -f "nxserver.bin --restart" 2>/dev/null || true
pkill -9 -f "nxserver.bin --login" 2>/dev/null || true
systemctl restart nxserver.service

echo "=== 6. Waiting for server to initialize ==="
sleep 3
chmod 644 /var/nomachine/NX/var/log/server.log 2>/dev/null || true

echo "=== 7. Recent Server Logs ==="
tail -n 25 /var/nomachine/NX/var/log/server.log

echo "=== 8. Server Status ==="
/var/nomachine/NX/bin/nxserver --status

echo "=== Done! Now connect from your Windows client. ==="
