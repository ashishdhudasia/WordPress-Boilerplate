#!/bin/bash

WP="./wp-cli.phar"

echo "Welcome to the WordPress Auto Installer"

read -p "Database Name: " DB_NAME
read -p "Database User: " DB_USER
read -s -p "Database Password: " DB_PASS
echo
read -p "Database Host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Site URL (e.g. http://example.com): " SITE_URL
read -p "Site Title: " SITE_TITLE
read -p "Admin Username: " ADMIN_USER
read -s -p "Admin Password: " ADMIN_PASS
echo
read -p "Admin Email: " ADMIN_EMAIL
read -p "Custom Theme Folder Name (inside wp-content/themes): " THEME_NAME

if [ ! -f wp-cli.phar ]; then
  echo "wp-cli.phar not found! Please run install.sh first."
  exit 1
fi

echo "Downloading WordPress..."
php $WP core download --force

echo "Creating wp-config.php..."
php $WP config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="$DB_HOST" --skip-check

echo "Creating database (if needed)..."
php $WP db create || echo "Database exists or could not be created."

echo "Installing WordPress..."
php $WP core install --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --skip-email

echo "Installing and activating plugins..."
php $WP plugin install contact-form-7 wk-google-analytics cookie-law-info --activate

echo "Removing default themes except your custom theme ($THEME_NAME)..."
THEMES=$(php $WP theme list --field=name)
for t in $THEMES; do
  if [[ "$t" != "$THEME_NAME" ]]; then
    echo "Deleting theme: $t"
    php $WP theme delete "$t"
  fi
done

echo "Activating your custom theme: $THEME_NAME"
php $WP theme activate "$THEME_NAME"

echo "Removing default sample posts and pages..."
# Delete all posts/pages except those authored by admin (optional)
POST_IDS=$(php $WP post list --post_type=post --field=ID)
PAGE_IDS=$(php $WP post list --post_type=page --field=ID)
for id in $POST_IDS $PAGE_IDS; do
  php $WP post delete $id --force
done

echo "Setting WordPress to discourage search engines..."
php $WP option update blog_public 0

echo "Installation complete! Visit $SITE_URL to start using your site."
