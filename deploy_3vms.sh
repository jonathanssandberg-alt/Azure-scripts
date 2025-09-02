#!/bin/bash

# ----- Variabler -----
RG_NAME="GaisSecureResourceGroup"
LOCATION="northeurope"
VNET_NAME="GaisVNet"
PUBLIC_SUBNET="PublicSubnet"
PRIVATE_SUBNET="PrivateSubnet"
BASTION_SUBNET="BastionSubnet"
NSG_BASTION="BastionNSG"
NSG_PROXY="ProxyNSG"
NSG_PRIVATE="PrivateNSG"

# VM-konfiguration
BASTION_VM="BastionHost"
PROXY_VM="ReverseProxy"
WEB_VM="WebServer"
ADMIN_USER="azureuser"
VM_SIZE_SMALL="Standard_B1s"
VM_SIZE_MEDIUM="Standard_B2s"
IMAGE="Ubuntu2204"

# Databasvariabler
DB_ROOT_PASSWORD="SecurePass2024!"
DB_NAME="contactdb"
DB_USER="webuser"
DB_PASSWORD="WebUser2024!"

echo "Skapar säker Azure-arkitektur med bastion host och reverse proxy..."

# ----- Ta bort befintlig resource group om den finns -----
echo "Kontrollerar befintlig Resource Group..."
if az group show --name $RG_NAME &> /dev/null; then
    echo "Tar bort befintlig Resource Group..."
    az group delete --name $RG_NAME --yes --no-wait
    echo "Väntar på att gamla resurser ska tas bort..."
    sleep 120
fi

# ----- Skapa Resource Group -----
echo "Skapar Resource Group..."
az group create --name $RG_NAME --location $LOCATION

# ----- Skapa Virtual Network med subnät -----
echo "Skapar Virtual Network..."
az network vnet create \
  --resource-group $RG_NAME \
  --name $VNET_NAME \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $PUBLIC_SUBNET \
  --subnet-prefix 10.0.1.0/24

# Privat subnät för webbserver
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name $PRIVATE_SUBNET \
  --address-prefix 10.0.2.0/24

# Bastion subnät
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name $BASTION_SUBNET \
  --address-prefix 10.0.3.0/24

# ----- Skapa Network Security Groups -----
echo "Skapar säkerhetsgrupper..."

# NSG för Bastion Host
az network nsg create --resource-group $RG_NAME --name $NSG_BASTION
az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_BASTION \
  --name AllowSSH \
  --priority 1000 \
  --source-address-prefixes Internet \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

# NSG för Reverse Proxy
az network nsg create --resource-group $RG_NAME --name $NSG_PROXY
az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_PROXY \
  --name AllowHTTP \
  --priority 1000 \
  --source-address-prefixes Internet \
  --destination-port-ranges 80 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_PROXY \
  --name AllowSSHFromBastion \
  --priority 1100 \
  --source-address-prefixes 10.0.3.0/24 \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

# NSG för privat webbserver
az network nsg create --resource-group $RG_NAME --name $NSG_PRIVATE
az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_PRIVATE \
  --name AllowHTTPFromProxy \
  --priority 1000 \
  --source-address-prefixes 10.0.1.0/24 \
  --destination-port-ranges 80 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

az network nsg rule create \
  --resource-group $RG_NAME \
  --nsg-name $NSG_PRIVATE \
  --name AllowSSHFromBastion \
  --priority 1100 \
  --source-address-prefixes 10.0.3.0/24 \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --direction Inbound

# ----- Skapa Bastion Host -----
echo "Skapar Bastion Host..."
az vm create \
  --resource-group $RG_NAME \
  --name $BASTION_VM \
  --image $IMAGE \
  --size $VM_SIZE_SMALL \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --vnet-name $VNET_NAME \
  --subnet $BASTION_SUBNET \
  --nsg $NSG_BASTION \
  --public-ip-sku Standard

echo "Bastion Host skapad."

# ----- Skapa Reverse Proxy -----
echo "Skapar Reverse Proxy..."
az vm create \
  --resource-group $RG_NAME \
  --name $PROXY_VM \
  --image $IMAGE \
  --size $VM_SIZE_MEDIUM \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --vnet-name $VNET_NAME \
  --subnet $PUBLIC_SUBNET \
  --nsg $NSG_PROXY \
  --public-ip-sku Standard

echo "Reverse Proxy skapad."

# ----- Skapa Web Server (utan publik IP) -----
echo "Skapar Web Server..."

# Först skapa ett Network Interface utan publik IP
az network nic create \
  --resource-group $RG_NAME \
  --name "${WEB_VM}NIC" \
  --vnet-name $VNET_NAME \
  --subnet $PRIVATE_SUBNET \
  --network-security-group $NSG_PRIVATE

# Skapa VM med det förberedda nätverksinterfacet
az vm create \
  --resource-group $RG_NAME \
  --name $WEB_VM \
  --image $IMAGE \
  --size $VM_SIZE_MEDIUM \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys \
  --nics "${WEB_VM}NIC"

echo "Web Server skapad utan publik IP."

# Vänta på att VM:ar ska starta helt
echo "Väntar på att VM:ar ska starta..."
sleep 90

# ----- Hämta IP-adresser -----
BASTION_IP=$(az vm show -d -g $RG_NAME -n $BASTION_VM --query publicIps -o tsv)
PROXY_IP=$(az vm show -d -g $RG_NAME -n $PROXY_VM --query publicIps -o tsv)
WEB_PRIVATE_IP=$(az vm show -d -g $RG_NAME -n $WEB_VM --query privateIps -o tsv)

echo "IP-adresser hämtade:"
echo "   Bastion Host: $BASTION_IP"
echo "   Reverse Proxy: $PROXY_IP"
echo "   Web Server (privat): $WEB_PRIVATE_IP"

# Kontrollera att IP:ar finns
if [ -z "$BASTION_IP" ] || [ -z "$PROXY_IP" ] || [ -z "$WEB_PRIVATE_IP" ]; then
    echo "VARNING: Alla IP-adresser kunde inte hämtas. Försöker igen..."
    sleep 30
    BASTION_IP=$(az vm show -d -g $RG_NAME -n $BASTION_VM --query publicIps -o tsv)
    PROXY_IP=$(az vm show -d -g $RG_NAME -n $PROXY_VM --query publicIps -o tsv)
    WEB_PRIVATE_IP=$(az vm show -d -g $RG_NAME -n $WEB_VM --query privateIps -o tsv)
fi

# ----- Installera LEMP Stack på webbserver -----
echo "Installerar LEMP Stack på webbserver..."
az vm run-command invoke \
  --resource-group $RG_NAME \
  --name $WEB_VM \
  --command-id RunShellScript \
  --scripts "
    # Uppdatera systemet
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -y
    
    # Installera LEMP Stack
    sudo apt-get install -y nginx mysql-server php-fpm php-mysql php-cli php-curl php-json php-mbstring
    
    # Starta tjänster
    sudo systemctl enable nginx mysql php8.1-fpm
    sudo systemctl start nginx mysql php8.1-fpm
    
    # Vänta lite för att MySQL ska starta helt
    sleep 10
    
    # Konfigurera MySQL säkert
    sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASSWORD';\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"CREATE DATABASE IF NOT EXISTS $DB_NAME;\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"FLUSH PRIVILEGES;\"
    
    # Skapa databas tabell
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e \"
    CREATE TABLE IF NOT EXISTS contacts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );\"
    
    # Konfigurera Nginx för PHP
    sudo tee /etc/nginx/sites-available/default > /dev/null <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.php;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINXEOF
    
    sudo nginx -t && sudo systemctl reload nginx
  " --no-wait

echo "LEMP installation startad på webbserver."
sleep 45

# ----- Skapa webbsidor -----
echo "Skapar webbsidor..."
az vm run-command invoke \
  --resource-group $RG_NAME \
  --name $WEB_VM \
  --command-id RunShellScript \
  --scripts "
    # Skapa startsida
    sudo tee /var/www/html/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Jonathan Sandbergs Säkra Webbapplikation</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #a8d8f0 0%, #7cc7e8 50%, #4db8e8 100%);
            min-height: 100vh; display: flex; align-items: center; justify-content: center;
        }
        .container { 
            background: rgba(255, 255, 255, 0.95); padding: 50px 40px;
            border-radius: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center; max-width: 600px;
            backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.2);
        }
        h1 { color: #2c5282; font-size: 2.5em; margin-bottom: 20px; font-weight: 300; letter-spacing: 1px; }
        .security { background: rgba(34, 197, 94, 0.1); border: 1px solid #22c55e; 
            color: #166534; padding: 20px; border-radius: 10px; margin: 30px 0; font-size: 1.1em; }
        .links { margin: 40px 0; display: flex; flex-wrap: wrap; justify-content: center; gap: 15px; }
        .links a { background: linear-gradient(135deg, #4299e1 0%, #2b6cb0 100%);
            color: white; padding: 15px 30px; border-radius: 50px; text-decoration: none;
            font-weight: 500; transition: all 0.3s ease; box-shadow: 0 4px 15px rgba(66, 153, 225, 0.3); }
        .links a:hover { background: linear-gradient(135deg, #2b6cb0 0%, #2c5282 100%);
            transform: translateY(-2px); box-shadow: 0 8px 25px rgba(66, 153, 225, 0.4); }
    </style>
</head>
<body>
    <div class='container'>
        <h1>Jonathan Sandbergs Säkra Webbapplikation</h1>
        <div class='security'>
            Denna applikation körs bakom en säker reverse proxy med bastion host-arkitektur
        </div>
        <div class='links'>
            <a href='contact.html'>Kontaktformulär</a>
            <a href='view_contacts.php'>Visa meddelanden</a>
        </div>
    </div>
</body>
</html>
EOF

    # Skapa kontaktformulär  
    sudo tee /var/www/html/contact.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <title>Kontaktformulär - Jonathan Sandbergs Webbapplikation</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #a8d8f0 0%, #4db8e8 100%);
            min-height: 100vh; padding: 20px;
        }
        .container { 
            background: rgba(255, 255, 255, 0.95); padding: 40px; border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1); max-width: 600px; margin: 50px auto;
        }
        h1 { color: #2c5282; font-size: 2.2em; margin-bottom: 30px; text-align: center; }
        .form-group { margin-bottom: 25px; }
        label { display: block; margin-bottom: 8px; font-weight: 500; color: #2d3748; }
        input, textarea { width: 100%; padding: 15px; border: 2px solid #e2e8f0; 
            border-radius: 10px; font-size: 16px; }
        button { background: linear-gradient(135deg, #4299e1 0%, #2b6cb0 100%);
            color: white; padding: 15px 30px; border: none; border-radius: 50px;
            cursor: pointer; font-size: 16px; font-weight: 500; width: 100%; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>Kontaktformulär</h1>
        <form action='submit_contact.php' method='POST'>
            <div class='form-group'>
                <label>Namn:</label>
                <input type='text' name='name' required>
            </div>
            <div class='form-group'>
                <label>E-post:</label>
                <input type='email' name='email' required>
            </div>
            <div class='form-group'>
                <label>Meddelande:</label>
                <textarea name='message' rows='6' required></textarea>
            </div>
            <button type='submit'>Skicka meddelande</button>
        </form>
        <p style='text-align: center; margin-top: 20px;'>
            <a href='index.html'>Tillbaka till startsidan</a>
        </p>
    </div>
</body>
</html>
EOF

    # Skapa PHP-script för att hantera formuläret (utan backslashes)
    cat > /tmp/submit_contact.php << 'PHPEOF'
<?php
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $name = htmlspecialchars(trim($_POST['name']));
    $email = htmlspecialchars(trim($_POST['email']));
    $message = htmlspecialchars(trim($_POST['message']));
    
    try {
        $pdo = new PDO('mysql:host=localhost;dbname=contactdb;charset=utf8', 'webuser', 'WebUser2024!');
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        $stmt = $pdo->prepare('INSERT INTO contacts (name, email, message) VALUES (?, ?, ?)');
        $stmt->execute([$name, $email, $message]);
        
        echo '<!DOCTYPE html><html><head><title>Tack</title></head><body style=\"font-family: sans-serif; text-align: center; padding: 50px;\"><h1>Tack för ditt meddelande!</h1><p>Vi återkommer till dig snart.</p><a href=\"index.html\">Tillbaka till startsidan</a></body></html>';
    } catch(PDOException $e) {
        echo '<!DOCTYPE html><html><head><title>Fel</title></head><body style=\"font-family: sans-serif; text-align: center; padding: 50px;\"><h1>Ett fel uppstod</h1><p>' . $e->getMessage() . '</p><a href=\"contact.html\">Försök igen</a></body></html>';
    }
}
?>
PHPEOF
    
    sudo cp /tmp/submit_contact.php /var/www/html/submit_contact.php
    rm /tmp/submit_contact.php

    # Skapa sida för att visa meddelanden (utan backslashes)
    cat > /tmp/view_contacts.php << 'PHPEOF'
<?php
try {
    $pdo = new PDO('mysql:host=localhost;dbname=contactdb;charset=utf8', 'webuser', 'WebUser2024!');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $stmt = $pdo->query('SELECT * FROM contacts ORDER BY created_at DESC');
    $contacts = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch(PDOException $e) {
    echo '<!DOCTYPE html><html><head><title>Fel</title></head><body><h1>Databasfel</h1><p>' . $e->getMessage() . '</p></body></html>';
    exit;
}
?>
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <title>Alla meddelanden</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; max-width: 1000px; margin: 20px auto; padding: 20px; }
        h1 { color: #2c5282; text-align: center; margin-bottom: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4299e1; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .links { text-align: center; margin-top: 30px; }
        .links a { margin: 0 15px; color: #4299e1; text-decoration: none; }
    </style>
</head>
<body>
    <h1>Alla meddelanden</h1>
    
    <?php if (empty($contacts)): ?>
        <p style='text-align: center;'>Inga meddelanden ännu.</p>
    <?php else: ?>
        <table>
            <tr><th>Namn</th><th>E-post</th><th>Meddelande</th><th>Datum</th></tr>
            <?php foreach ($contacts as $contact): ?>
            <tr>
                <td><?php echo htmlspecialchars($contact['name']); ?></td>
                <td><?php echo htmlspecialchars($contact['email']); ?></td>
                <td><?php echo nl2br(htmlspecialchars($contact['message'])); ?></td>
                <td><?php echo $contact['created_at']; ?></td>
            </tr>
            <?php endforeach; ?>
        </table>
    <?php endif; ?>
    
    <div class='links'>
        <a href='contact.html'>Nytt meddelande</a>
        <a href='index.html'>Tillbaka till startsidan</a>
    </div>
</body>
</html>
PHPEOF
    
    sudo cp /tmp/view_contacts.php /var/www/html/view_contacts.php
    rm /tmp/view_contacts.php
    
    # Sätt rättigheter
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 644 /var/www/html/*
    sudo chmod 755 /var/www/html
  " --no-wait

echo "Webbsidor skapade."
sleep 30

# ----- Konfigurera Reverse Proxy -----
echo "Konfigurerar Reverse Proxy..."
az vm run-command invoke \
  --resource-group $RG_NAME \
  --name $PROXY_VM \
  --command-id RunShellScript \
  --scripts "
    # Installera och konfigurera Nginx
    sudo apt-get update -y
    sudo apt-get install -y nginx
    
    # Konfigurera som reverse proxy
    sudo tee /etc/nginx/sites-available/default > /dev/null <<'PROXYEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    # Säkerhets-headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection \"1; mode=block\";
    
    location / {
        proxy_pass http://$WEB_PRIVATE_IP;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
PROXYEOF
    
    # Testa och starta om Nginx
    sudo nginx -t && sudo systemctl restart nginx
    sudo systemctl enable nginx
  "

echo "Reverse proxy konfigurerad."

echo ""
echo "Säker arkitektur skapad framgångsrikt!"
echo ""
echo "Anslutningsinformation:"
echo "   Bastion Host SSH: ssh $ADMIN_USER@$BASTION_IP"
echo "   Webbapplikation: http://$PROXY_IP"
echo ""
echo "Säkerhetsarkitektur:"
echo "   - Webbserver ($WEB_PRIVATE_IP) är privat utan publik IP"
echo "   - All webbtrafik filtreras genom reverse proxy ($PROXY_IP)"
echo "   - SSH-åtkomst till privata servrar endast via bastion host"
echo ""
echo "För att administrera den privata webbservern:"
echo "   1. SSH till bastion: ssh $ADMIN_USER@$BASTION_IP"
echo "   2. Från bastion SSH till webserver: ssh $ADMIN_USER@$WEB_PRIVATE_IP"
echo ""
echo "Testa webbapplikationen på: http://$PROXY_IP"