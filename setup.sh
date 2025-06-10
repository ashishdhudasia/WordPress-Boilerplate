#!/bin/bash

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

if ! command -v wp &> /dev/null; then
  echo "WP-CLI is not installed. Please install it before running this script."
  exit 1
fi

echo "Downloading WordPress..."
wp core download --force

echo "Creating wp-config.php..."
wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="$DB_HOST" --skip-check

echo "Creating database (if needed)..."
wp db create || echo "Database exists or could not be created."

echo "Installing WordPress..."
wp core install --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --skip-email

echo "Installing and activating Contact Form 7 plugin..."
wp plugin install contact-form-7 --activate

echo "Setting WordPress to discourage search engines..."
wp option update blog_public 0

echo "Installation complete! Visit $SITE_URL to start using your site."
