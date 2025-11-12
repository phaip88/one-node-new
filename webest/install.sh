#!/usr/bin/env sh

set -e

DOMAIN="${DOMAIN:-example.com}"
REMARKS="${REMARKS:-webhostmost-est}"

# Download application files
cd $HOME/domains/$DOMAIN/public_html
curl -sSL -o app.js https://raw.githubusercontent.com/phaip88/one-node-whm/refs/heads/main/webest/app.est.js
curl -sSL -o package.json https://raw.githubusercontent.com/phaip88/one-node-whm/refs/heads/main/webest/package.json

# Install website
cp /usr/sbin/cloudlinux-selector $HOME/cx
$HOME/cx create --json --interpreter=nodejs --user=`whoami` --app-root=$HOME/domains/$DOMAIN/public_html --app-uri=/ --version=22 --app-mode=Production --startup-file=app.js --env-vars='{"DOMAIN":"'$DOMAIN'","REMARKS":"'$REMARKS'"}'
$HOME/nodevenv/domains/$DOMAIN/public_html/22/bin/npm install
rm -rf $HOME/.npm/_logs/*.log

# Keep-alive
mkdir -p $HOME/app
cd $HOME/app
curl -sSL -o backup.sh https://raw.githubusercontent.com/phaip88/one-node-whm/refs/heads/main/webest/cron.sh
sed -i "s/YOUR_DOMAIN/$DOMAIN/g" backup.sh
chmod +x backup.sh
(crontab -l 2>/dev/null; echo "* * * * * $HOME/app/backup.sh >> $HOME/app/backup.log") | crontab -

# Print access information
FIXED_UUID="8b9c2d4e-f1a3-4567-8901-234567890abc"
FIXED_PATH="/8b9c2d4ef1a345678901234567890abc"
ACCESS_URL="https://$DOMAIN$FIXED_PATH"
echo "============================================================"
echo "✅ Service Ready – Access Information (EST Version)"
echo "------------------------------------------------------------"
echo "📁 Fixed Path  : $FIXED_PATH"
echo "🧬 Fixed UUID  : $FIXED_UUID"
echo "🌐 Access URL  : $ACCESS_URL"
echo "🏷️  Domain     : $DOMAIN"
echo "📝 Remarks     : $REMARKS"
echo "============================================================"
