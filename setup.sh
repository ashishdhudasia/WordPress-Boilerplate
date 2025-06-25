#!/bin/bash

WP="./wp-cli.phar"
export PHP_CLI="php -d memory_limit=512M -d display_errors=Off"
export WP_CLI_CACHE_DIR="$PWD/.wp-cli-cache"
mkdir -p "$WP_CLI_CACHE_DIR"

# Wrapper function to suppress warnings
wp() {
  $PHP_CLI $WP "$@" 2>/dev/null
}

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
      eval "$2=\"$var\""
      break
    else
      echo "❌ $1 is required."
    fi
  done
}

echo "🚀 Welcome to the WordPress Auto Installer"

echo
echo "📦 Choose installation type:"
echo "1) Basic Setup"
echo "2) Full Setup"
while true; do
  read -p "Enter 1 or 2: " SETUP_TYPE
  if [[ "$SETUP_TYPE" == "1" ]]; then
    SETUP_MODE="basic"
    break
  elif [[ "$SETUP_TYPE" == "2" ]]; then
    SETUP_MODE="full"
    break
  else
    echo "❌ Invalid input. Please enter 1 or 2."
  fi
done

prompt_required "Database Name" DB_NAME
prompt_required "Database User" DB_USER
read -s -p "Database Password (leave blank if none): " DB_PASS
echo
if [[ -n "$DB_PASS" ]]; then
  echo "✔️ Database Password: ********"
else
  echo "ℹ️ No Database Password entered."
fi
read -p "Database Host (default: localhost): " DB_HOST
DB_HOST=${DB_HOST:-localhost}
read -p "Database Table Prefix (default: wp_): " DB_PREFIX
DB_PREFIX=${DB_PREFIX:-wp_}

# 🔒 Strict Site URL validation, no modification
while true; do
  read -p "Site URL (e.g. https://basicplan.brightness-demo.com): " SITE_URL
  SITE_URL="${SITE_URL%%/}" # remove trailing slash only
  if [[ "$SITE_URL" =~ ^https?://[a-zA-Z0-9.-]+\.[a-z]{2,}$ ]]; then
    break
  else
    echo "❌ Invalid URL format. Must start with http:// or https:// and contain a valid domain."
  fi
done

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
wp core download --force

echo "⚙️ Creating wp-config.php..."
wp config create \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASS" \
  --dbhost="$DB_HOST" \
  --dbprefix="$DB_PREFIX" \
  --skip-check

echo "📦 Installing WordPress..."
echo "🌐 Final Site URL: $SITE_URL"
wp core install \
  --url="$SITE_URL" \
  --title="$SITE_TITLE" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASS" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email

# ✅ Force correct site URL after install
wp option update siteurl "$SITE_URL"
wp option update home "$SITE_URL"

echo "🔌 Installing essential plugins..."
if [[ "$SETUP_MODE" == "full" ]]; then
  wp plugin install contact-form-7 wk-google-analytics cookie-law-info updraftplus wordpress-seo --activate

  echo "📦 Installing custom ZIP plugins for full setup..."

  for plugin_zip in wp-rocket.zip schema-pro.zip rank-math.zip; do
    if [[ -f "$plugin_zip" ]]; then
      echo "🧩 Installing $plugin_zip..."
      wp plugin install "$plugin_zip" --activate && rm -f "$plugin_zip" && \
        echo "🗑️ Removed $plugin_zip after installation."
    else
      echo "❌ Plugin ZIP '$plugin_zip' not found in the current directory."
    fi
  done
else
  wp plugin install contact-form-7 wk-google-analytics cookie-law-info updraftplus --activate
fi

echo "🧹 Removing Hello Dolly plugin file (hello.php) if exists..."
if [ -f "wp-content/plugins/hello.php" ]; then
  rm -f wp-content/plugins/hello.php
  echo "✅ Hello Dolly plugin file removed."
else
  echo "ℹ️ Hello Dolly plugin file not found."
fi

echo "🧹 Removing Akismet plugin if exists..."
wp plugin delete akismet || echo "ℹ️ Akismet plugin not found or already removed."

echo "🎨 Activating theme: $THEME_NAME"
wp theme activate "$THEME_NAME" || {
  echo "❌ Theme '$THEME_NAME' not found in wp-content/themes."
  exit 1
}

echo "🧼 Removing other themes..."
for t in $(wp theme list --field=name); do
  if [[ "$t" != "$THEME_NAME" ]]; then
    wp theme delete "$t"
  fi
done

echo "🔗 Setting permalink structure..."
wp option update permalink_structure '/%postname%/'
wp rewrite flush --hard

echo "🧽 Deleting default posts/pages..."
POSTS=$(wp post list --post_type=post,page --format=ids)
if [[ -n "$POSTS" ]]; then
  wp post delete $POSTS --force
fi

echo "🚫 Disabling comments..."
ALL_IDS=$(wp post list --post_type=any --format=ids)
if [[ -n "$ALL_IDS" ]]; then
  wp post update $ALL_IDS --comment_status=closed
fi
wp option update default_comment_status closed
wp option update default_ping_status closed
wp option update close_comments_for_old_posts 1
wp option update close_comments_days_old 0
wp option update comments_notify 0
wp option update moderation_notify 0

echo "🔒 Discouraging search engines..."
wp option update blog_public 0

echo "🗑️ Cleaning up WP CLI cache..."
rm -rf .wp-cli-cache

echo
echo "✅ WordPress installation complete!"
echo "🌐 Site URL: $SITE_URL"
echo "👤 Admin Username: $ADMIN_USER"
echo "🔐 Admin Password: $ADMIN_PASS"
