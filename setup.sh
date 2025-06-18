#!/bin/bash

set -e  # Exit on error

WP="./wp-cli.phar"

# Function to prompt until non-empty input is received
prompt_required() {
  local var
  while true; do
    read -p "$1: " var
    if [[ -n "$var" ]]; then
      eval "$2=\"\$var\""
      break
    else
      echo "❌ $1 is required. Please enter a value."
    fi
  done
}

# Optional secret input
prompt_optional_secret() {
  read -s -p "$1 (optional): " val
  echo
  eval "$2=\"\$val\""
}

# Function to generate a random 16-character password
generate_random_password() {
  LC_ALL=C tr -dc 'A-Za-z0-9@#%&+=' < /dev/urandom | head -c 16
}

echo "🚀 Welcome to the WordPress Auto Installer"

prompt_required "Database Name" DB_NAME
prompt_required "Database User" DB_USER
prompt_optional_secret "Database Password" DB_PASS

read -p "Database Host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}

read -p "Database Table Prefix (default: wp_): " DB_PREFIX
DB_PREFIX=${DB_PREFIX:-wp_}

prompt_required "Site URL (e.g. http://example.com)" SITE_URL
prompt_required "Site Title" SITE_TITLE
prompt_required "Admin Username" ADMIN_USER

# Always suggest a strong password and allow override
echo
SUGGESTED_PASS=$(generate_random_password)
echo "💡 Suggested Admin Password: $SUGGESTED_PASS"
read -s -p "Press Enter to accept or type your own secure Admin Password: " ADMIN_PASS
echo

# Enforce required password
while [[ -z "$ADMIN_PASS" ]]; do
  echo "❌ Admin Password is required."
  read -s -p "Please enter Admin Password: " ADMIN_PASS
  echo
done

# If they pressed enter (accepted the suggestion), use it
if [[ "$ADMIN_PASS" == "$SUGGESTED_PASS" || -z "$ADMIN_PASS" ]]; then
  ADMIN_PASS="$SUGGESTED_PASS"
  AUTO_PASS=true
else
  AUTO_PASS=false
fi

prompt_required "Admin Email" ADMIN_EMAIL
prompt_required "Custom Theme Folder Name (inside wp-content/themes)" THEME_NAME

# Check wp-cli.phar exists
if [[ ! -f $WP ]]; then
  echo "❌ wp-cli.phar not found! Please run install.sh or download WP CLI."
  exit 1
fi

echo "📥 Downloading WordPress..."
php $WP core download --force

echo "⚙️ Creating wp-config.php..."
CONFIG_CMD=(php $WP config create
  --dbname="$DB_NAME"
  --dbuser="$DB_USER"
  --dbhost="$DB_HOST"
  --dbprefix="$DB_PREFIX"
  --skip-check
)
[[ -n "$DB_PASS" ]] && CONFIG_CMD+=(--dbpass="$DB_PASS")
"${CONFIG_CMD[@]}"

echo "🗄️ Creating database (if needed)..."
php $WP db create || echo "ℹ️ Database exists or couldn't be created."

echo "📦 Installing WordPress..."
php $WP core install \
  --url="$SITE_URL" \
  --title="$SITE_TITLE" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASS" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email

echo "🔌 Installing and activating essential plugins..."
php $WP plugin install contact-form-7 wk-google-analytics cookie-law-info --activate

echo "🧹 Removing Hello Dolly plugin if exists..."
php $WP plugin delete hello-dolly || echo "Already removed or not found."

echo "🧹 Removing Akismet plugin if exists..."
php $WP plugin delete akismet || echo "Already removed or not found."

echo "🎨 Activating custom theme: $THEME_NAME"
php $WP theme activate "$THEME_NAME" || {
  echo "❌ Theme '$THEME_NAME' not found in wp-content/themes/"
  exit 1
}

echo "🧼 Deleting all other themes except '$THEME_NAME'..."
THEMES=$(php $WP theme list --field=name)
for t in $THEMES; do
  [[ "$t" != "$THEME_NAME" ]] && php $WP theme delete "$t"
done

echo "🔗 Setting permalink structure to 'post name'..."
php $WP option update permalink_structure '/%postname%/'
php $WP rewrite flush --hard

echo "🧽 Removing sample posts and pages..."
POST_IDS=$(php $WP post list --post_type=post --format=ids)
PAGE_IDS=$(php $WP post list --post_type=page --format=ids)
for id in $POST_IDS $PAGE_IDS; do
  php $WP post delete "$id" --force
done

echo "🚫 Disabling comments site-wide..."
ALL_POSTS=$(php $WP post list --post_type=any --format=ids)
for id in $ALL_POSTS; do
  php $WP post update "$id" --comment_status=closed
done

php $WP option update default_comment_status closed
php $WP option update default_ping_status closed
php $WP option update close_comments_for_old_posts 1
php $WP option update close_comments_days_old 0
php $WP option update comments_notify 0
php $WP option update moderation_notify 0

echo "🔒 Discouraging search engines from indexing..."
php $WP option update blog_public 0

echo "🧹 Cleaning up installation files..."
rm -f install.sh setup.sh README.md wp-cli.phar

echo
echo "✅ WordPress Installation Complete!"
echo "🌐 Site URL:        $SITE_URL"
echo "👤 Admin Username:  $ADMIN_USER"
echo "🔐 Admin Password:  $ADMIN_PASS"
