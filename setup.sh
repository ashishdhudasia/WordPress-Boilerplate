#!/bin/bash

WP="./wp-cli.phar"

# Generate a strong random password
generate_password() {
  tr -dc 'A-Za-z0-9@#%^+=_' </dev/urandom | head -c 14
}

# Prompt until a value is entered
prompt_required() {
  local var
  while true; do
    read -p "$1: " var
    if [[ -n "$var" ]]; then
      eval "$2=\"\$var\""
      break
    else
      echo "❌ $1 is required."
    fi
  done
}

echo "🚀 Welcome to the WordPress Auto Installer (XAMPP Friendly)"

prompt_required "Database Name" DB_NAME
prompt_required "Database User" DB_USER
read -s -p "Database Password (leave blank if none): " DB_PASS
echo
read -p "Database Host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Database Table Prefix (default: wp_): " DB_PREFIX
DB_PREFIX=${DB_PREFIX:-wp_}
prompt_required "Site URL (e.g. http://localhost/my-site)" SITE_URL
prompt_required "Site Title" SITE_TITLE
prompt_required "Admin Username" ADMIN_USER

echo
echo "💡 Suggested Admin Password: "
SUGGESTED_PASS=$(generate_password)
echo "$SUGGESTED_PASS"
read -p "Use suggested password? (Y/n): " use_suggested
if [[ "$use_suggested" =~ ^[Nn]$ ]]; then
  while true; do
    read -s -p "Enter your custom Admin Password: " ADMIN_PASS
    echo
    if [[ -n "$ADMIN_PASS" ]]; then
      break
    else
      echo "❌ Password is required."
    fi
  done
else
  ADMIN_PASS="$SUGGESTED_PASS"
fi

prompt_required "Admin Email" ADMIN_EMAIL
prompt_required "Custom Theme Folder Name (inside wp-content/themes)" THEME_NAME

if [[ ! -f $WP ]]; then
  echo "❌ wp-cli.phar not found! Please make sure it's in this directory."
  exit 1
fi

echo "📥 Downloading WordPress..."
php $WP core download --force

echo "⚙️ Creating wp-config.php..."
php $WP config create \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASS" \
  --dbhost="$DB_HOST" \
  --dbprefix="$DB_PREFIX" \
  --skip-check

echo "📦 Installing WordPress..."
php $WP core install \
  --url="$SITE_URL" \
  --title="$SITE_TITLE" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASS" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email

echo "🔌 Installing essential plugins..."
php $WP plugin install contact-form-7 wk-google-analytics cookie-law-info --activate

echo "🧹 Removing Hello Dolly plugin file (hello.php) if exists..."
if [ -f "wp-content/plugins/hello.php" ]; then
  rm -f wp-content/plugins/hello.php
  echo "✅ Hello Dolly plugin file removed."
else
  echo "ℹ️ Hello Dolly plugin file not found."
fi

echo "🧹 Removing Akismet plugin if exists..."
php $WP plugin delete akismet || echo "ℹ️ Akismet plugin not found or already removed."

echo "🎨 Activating theme: $THEME_NAME"
php $WP theme activate "$THEME_NAME" || {
  echo "❌ Theme '$THEME_NAME' not found in wp-content/themes."
  exit 1
}

echo "🧼 Removing other themes..."
for t in $(php $WP theme list --field=name); do
  if [[ "$t" != "$THEME_NAME" ]]; then
    php $WP theme delete "$t"
  fi
done

echo "🔗 Setting permalink structure..."
php $WP option update permalink_structure '/%postname%/'
php $WP rewrite flush --hard

echo "🧽 Deleting default posts/pages..."
POSTS=$(php $WP post list --post_type=post,page --format=ids)
if [[ -n "$POSTS" ]]; then
  php $WP post delete $POSTS --force
fi

echo "🚫 Disabling comments..."
ALL_IDS=$(php $WP post list --post_type=any --format=ids)
if [[ -n "$ALL_IDS" ]]; then
  php $WP post update $ALL_IDS --comment_status=closed
fi
php $WP option update default_comment_status closed
php $WP option update default_ping_status closed
php $WP option update close_comments_for_old_posts 1
php $WP option update close_comments_days_old 0
php $WP option update comments_notify 0
php $WP option update moderation_notify 0

echo "🔒 Discouraging search engines..."
php $WP option update blog_public 0

echo "🧹 Cleaning up installation files..."
rm -f install.sh setup.sh README.md

echo
echo "✅ WordPress installation complete!"
echo "🌐 Site URL: $SITE_URL"
echo "👤 Admin Username: $ADMIN_USER"
echo "🔐 Admin Password: $ADMIN_PASS"
