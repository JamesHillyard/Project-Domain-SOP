#!/bin/bash

email="it.operations@payara.fish"
rsa_key_size=4096
data_path="./certbot"
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

# Prompt the user for domains
read -p "Enter domain names (space-separated with the domain name in the ssl_certificate entry in nginx.conf first): " -a domains

if [ -d "$data_path" ]; then
  read -p "Existing data found for ${domains[*]}. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

rm -r $data_path

echo "### Creating dummy certificate for ${domains[*]} ..."
path="/etc/letsencrypt/live/${domains[0]}"
mkdir -p "$data_path/conf/live/${domains[0]}"
docker compose run --rm --entrypoint "\
  mkdir -p '$path' && \
  touch '$path/privkey.pem'" certbot
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Starting nginx ..."
docker compose up --force-recreate -d nginx
echo

docker ps

echo "### Deleting dummy certificate for ${domains[*]} ..."
docker compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/${domains[0]} && \
  rm -Rf /etc/letsencrypt/archive/${domains[0]} && \
  rm -Rf /etc/letsencrypt/renewal/${domains[0]}.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for ${domains[*]} ..."
# Join each of the domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--no-eff-email --email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Stopping Compose ..."
docker compose down

echo "### Trying to create cron job for auto renewal"
# Check for the certificate renewal cron job
if crontab -l | grep -q "docker compose -f $(pwd)/docker-compose.yml run --rm --entrypoint 'certbot renew' certbot"; then
  echo "Cron job for certificate renewal already exists."
else
  # Add the cron job for certificate renewal
  (crontab -l 2>/dev/null; echo "0 9 * * * docker compose -f $(pwd)/docker-compose.yml run --rm --entrypoint 'certbot renew' certbot") | crontab -
  echo "Cron job for certificate renewal added."
fi

# Check for the nginx reload cron job
if crontab -l | grep -q "docker compose -f $(pwd)/docker-compose.yml exec nginx nginx -s reload"; then
  echo "Cron job for nginx reload already exists."
else
  # Add the cron job for nginx reload
  (crontab -l 2>/dev/null; echo "5 9 * * * docker compose -f $(pwd)/docker-compose.yml exec nginx nginx -s reload") | crontab -
  echo "Cron job for nginx reload added."
fi
