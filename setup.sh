#!/bin/bash

WP="./wp-cli.phar"

echo "Welcome to the WordPress Auto Installer"

read -p "Database Name: " DB_NAME
read -p "Database User: " DB_USER
read -s -p "Database Password: " DB_PASS
echo
read -p "Database Host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Database Table Prefix (default: wp_): " DB_PREFIX
DB_PREFIX=${DB_PREFIX:-wp_}
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
php $WP config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="$DB_HOST" --dbprefix="$DB_PREFIX" --skip-check

echo "Creating database (if needed)..."
php $WP db create || echo "Database exists or could not be created."

echo "Installing WordPress..."
php $WP core install --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --skip-email

echo "Installing and activating plugins..."
php $WP plugin install contact-form-7 wk-google-analytics cookie-law-info --activate

echo "Removing Hello Dolly plugin file (hello.php) if exists..."
if [ -f "wp-content/plugins/hello.php" ]; then
  rm -f wp-content/plugins/hello.php
  echo "Hello Dolly plugin file removed."
else
  echo "Hello Dolly plugin file not found."
fi

echo "Removing Akismet plugin folder if exists..."
php $WP plugin delete akismet || echo "Akismet plugin not found or already removed."

echo "Installing and activating your custom theme: $THEME_NAME"
php $WP theme install "$THEME_NAME" --activate

echo "Deleting all other themes except $THEME_NAME..."
THEMES=$(php $WP theme list --field=name)
for t in $THEMES; do
  if [[ "$t" != "$THEME_NAME" ]]; then
    echo "Deleting theme: $t"
    php $WP theme delete "$t"
  fi
done

echo "Setting permalink structure to 'post name'..."
php $WP option update permalink_structure '/%postname%/'
php $WP rewrite flush --hard

echo "Removing default sample posts and pages..."
POST_IDS=$(php $WP post list --post_type=post --field=ID)
PAGE_IDS=$(php $WP post list --post_type=page --field=ID)
for id in $POST_IDS $PAGE_IDS; do
  php $WP post delete $id --force
done

echo "Disabling comments site-wide..."
php $WP post update $(php $WP post list --post_type=post --format=ids) --comment_status=closed
php $WP post update $(php $WP post list --post_type=page --format=ids) --comment_status=closed
php $WP option update default_comment_status closed
php $WP option update default_ping_status closed
php $WP option update close_comments_for_old_posts 1
php $WP option update close_comments_days_old 0
php $WP option update comments_notify 0
php $WP option update moderation_notify 0

echo "Setting WordPress to discourage search engines..."
php $WP option update blog_public 0

echo "Cleaning up installation files..."

rm -f install.sh setup.sh README.md wp-cli.phar

echo "Installation complete! Visit $SITE_URL to start using your current site."
