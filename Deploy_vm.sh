#!/bin/bash

# ----- Variabler -----
RG_NAME="GaisResourceGroup1"
LOCATION="northeurope"          
VM_NAME="GaisVM1"
ADMIN_USER="azureuser"
HTML_PATH="/c/Azure/Html_filer"
VM_SIZE="Standard_B1s"           
IMAGE="Ubuntu2204"
DB_ROOT_PASSWORD="Jonte0191!"
DB_NAME="contactdb"
DB_USER="webuser"
DB_PASSWORD="Jonte0191!"

# ----- Skapa Resource Group -----
echo "🔄 Skapar Resource Group..."
az group create --name $RG_NAME --location $LOCATION

# ----- Skapa VM -----
echo "🔄 Skapar VM..."
az vm create \
  --resource-group $RG_NAME \
  --name $VM_NAME \
  --image $IMAGE \
  --size $VM_SIZE \
  --admin-username $ADMIN_USER \
  --generate-ssh-keys

# ----- Öppna port 80 för HTTP -----
echo "🔄 Öppnar port 80..."
az vm open-port --port 80 --resource-group $RG_NAME --name $VM_NAME

# ----- Hämta VM IP -----
VM_IP=$(az vm show -d -g $RG_NAME -n $VM_NAME --query publicIps -o tsv)
echo "VM skapad med IP: $VM_IP"

# ----- Installera LEMP Stack (Linux, Nginx, MySQL, PHP) -----
echo "🔄 Installerar LEMP Stack..."
az vm run-command invoke \
  --resource-group $RG_NAME \
  --name $VM_NAME \
  --command-id RunShellScript \
  --scripts "
    # Uppdatera systemet
    sudo apt-get update -y
    
    # Installera Nginx
    sudo apt-get install -y nginx
    
    # Installera MySQL Server
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
    
    # Installera PHP och nödvändiga moduler
    sudo apt-get install -y php-fpm php-mysql php-cli php-curl php-json php-mbstring
    
    # Starta och aktivera tjänster
    sudo systemctl enable nginx mysql php8.1-fpm
    sudo systemctl start nginx mysql php8.1-fpm
    
    # Säkerställ att MySQL startar korrekt
    sleep 5
    
    # Konfigurera MySQL root-användare med korrekt autentiseringsmetod
    sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASSWORD';\"\
    sudo mysql -e \"FLUSH PRIVILEGES;\"
    
    # Skapa databas och användare
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"CREATE DATABASE IF NOT EXISTS $DB_NAME;\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';\"
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' -e \"FLUSH PRIVILEGES;\"
    
    # Skapa contacts tabell
    sudo mysql -u root -p'$DB_ROOT_PASSWORD' $DB_NAME -e \"
    CREATE TABLE IF NOT EXISTS contacts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );\"
    
    # Konfigurera Nginx för PHP med korrekt index-ordning
    sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.php;
    
    server_name _;
    
    location / {
        try_files \\\$uri \\\$uri/ =404;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \\\$document_root\\\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # Skapa startsida (index.html) med modern design
    sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Jonathan Sandbergs Webbapplikation</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #a8d8f0 0%, #7cc7e8 50%, #4db8e8 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .container { 
            background: rgba(255, 255, 255, 0.95);
            padding: 50px 40px;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 600px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        h1 { 
            color: #2c5282;
            font-size: 2.5em;
            margin-bottom: 20px;
            font-weight: 300;
            letter-spacing: 1px;
        }
        
        .subtitle {
            color: #4a5568;
            font-size: 1.2em;
            margin-bottom: 30px;
            font-weight: 300;
        }
        
        .status { 
            background: rgba(72, 187, 120, 0.1);
            border: 1px solid #48bb78;
            color: #2f855a;
            padding: 20px;
            border-radius: 10px;
            margin: 30px 0;
            font-size: 1.1em;
        }
        
        .links { 
            margin: 40px 0;
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 15px;
        }
        
        .links a { 
            background: linear-gradient(135deg, #4299e1 0%, #2b6cb0 100%);
            color: white;
            padding: 15px 30px;
            border-radius: 50px;
            text-decoration: none;
            font-weight: 500;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(66, 153, 225, 0.3);
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        
        .links a:hover { 
            background: linear-gradient(135deg, #2b6cb0 0%, #2c5282 100%);
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(66, 153, 225, 0.4);
        }
        
        .footer {
            margin-top: 30px;
            color: #718096;
            font-size: 0.9em;
        }
        
        .tech-stack {
            background: rgba(237, 242, 247, 0.8);
            padding: 15px;
            border-radius: 10px;
            margin: 20px 0;
            color: #4a5568;
            font-size: 0.95em;
        }
    </style>
</head>
<body>
    <div class='container'>
        <h1>Jonathan Sandbergs Webbapplikation</h1>
        <p class='subtitle'>Välkommen till min professionella webbplats</p>
        
        <div class='status'>
            ✨ LEMP Stack körs smidigt och är redo för användning
        </div>
        
        <div class='tech-stack'>
            <strong>Teknisk stack:</strong> Linux • Nginx • MySQL • PHP
        </div>
        
        <div class='links'>
            <a href='contact.html'>
                <span>📝</span> Kontaktformulär
            </a>
            <a href='view_contacts.php'>
                <span>👀</span> Visa meddelanden
            </a>
            <a href='info.php'>
                <span>ℹ️</span> Systeminfo
            </a>
        </div>
        
        <div class='footer'>
            <p>Utvecklad med modern webbteknik</p>
            <p>Servern startad: \$(date)</p>
        </div>
    </div>
</body>
</html>
EOF
    
    # Skapa PHP info-sida för testning
    echo '<?php phpinfo(); ?>' | sudo tee /var/www/html/info.php > /dev/null
    
    # Sätt rätt rättigheter för alla filer
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 644 /var/www/html/*
    sudo chmod 755 /var/www/html
    
    # Starta om Nginx för att ladda ny konfiguration
    sudo systemctl restart nginx
    
    # Testa databasanslutning
    mysql -u $DB_USER -p'$DB_PASSWORD' $DB_NAME -e 'SELECT \"Database connection successful!\" as status;' || echo 'Database connection failed'
  "

echo "🔄 Väntar på att servrar ska starta..."
sleep 30

# ----- Skapa PHP kontaktform -----
echo "🔄 Skapar PHP kontaktform..."
ssh -o StrictHostKeyChecking=no $ADMIN_USER@$VM_IP "
# Skapa kontaktform HTML med modern design
sudo tee /var/www/html/contact.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Kontaktformulär - Jonathan Sandbergs Webbapplikation</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #a8d8f0 0%, #7cc7e8 50%, #4db8e8 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container { 
            background: rgba(255, 255, 255, 0.95);
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            max-width: 600px;
            margin: 50px auto;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        h1 { 
            color: #2c5282;
            font-size: 2.2em;
            margin-bottom: 30px;
            text-align: center;
            font-weight: 300;
            letter-spacing: 1px;
        }
        
        .form-group { 
            margin-bottom: 25px; 
        }
        
        label { 
            display: block; 
            margin-bottom: 8px; 
            font-weight: 500;
            color: #2d3748;
        }
        
        input, textarea { 
            width: 100%; 
            padding: 15px; 
            border: 2px solid #e2e8f0; 
            border-radius: 10px;
            font-size: 16px;
            transition: all 0.3s ease;
            background: rgba(255, 255, 255, 0.8);
        }
        
        input:focus, textarea:focus {
            outline: none;
            border-color: #4299e1;
            box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.1);
            background: rgba(255, 255, 255, 1);
        }
        
        button { 
            background: linear-gradient(135deg, #4299e1 0%, #2b6cb0 100%);
            color: white; 
            padding: 15px 30px; 
            border: none; 
            border-radius: 50px; 
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(66, 153, 225, 0.3);
            width: 100%;
        }
        
        button:hover { 
            background: linear-gradient(135deg, #2b6cb0 0%, #2c5282 100%);
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(66, 153, 225, 0.4);
        }
        
        .links {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e2e8f0;
        }
        
        .links a {
            color: #4299e1;
            text-decoration: none;
            margin: 0 15px;
            font-weight: 500;
            transition: color 0.3s ease;
        }
        
        .links a:hover {
            color: #2b6cb0;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class='container'>
        <h1>Kontaktformulär</h1>
        <form action='submit_contact.php' method='POST'>
            <div class='form-group'>
                <label for='name'>Namn:</label>
                <input type='text' id='name' name='name' required>
            </div>
            <div class='form-group'>
                <label for='email'>E-post:</label>
                <input type='email' id='email' name='email' required>
            </div>
            <div class='form-group'>
                <label for='message'>Meddelande:</label>
                <textarea id='message' name='message' rows='6' required></textarea>
            </div>
            <button type='submit'>Skicka meddelande</button>
        </form>
        
        <div class='links'>
            <a href='index.html'>Tillbaka till startsidan</a>
            <a href='view_contacts.php'>Visa alla meddelanden</a>
        </div>
    </div>
</body>
</html>
EOF

# Skapa PHP-script för att hantera formuläret
sudo tee /var/www/html/submit_contact.php > /dev/null <<'EOF'
<?php
\$servername = 'localhost';
\$username = '$DB_USER';
\$password = '$DB_PASSWORD';
\$dbname = '$DB_NAME';

if (\$_SERVER['REQUEST_METHOD'] == 'POST') {
    \$name = htmlspecialchars(trim(\$_POST['name']));
    \$email = htmlspecialchars(trim(\$_POST['email']));
    \$message = htmlspecialchars(trim(\$_POST['message']));
    
    if (empty(\$name) || empty(\$email) || empty(\$message)) {
        \$error = 'Alla fält måste fyllas i.';
    } else {
        try {
            \$pdo = new PDO(\"mysql:host=\$servername;dbname=\$dbname;charset=utf8\", \$username, \$password);
            \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            
            \$stmt = \$pdo->prepare(\"INSERT INTO contacts (name, email, message) VALUES (?, ?, ?)\");
            \$stmt->execute([\$name, \$email, \$message]);
            
            \$success = \"Tack för ditt meddelande! Vi återkommer till dig snart.\";
        } catch(PDOException \$e) {
            \$error = \"Fel vid sparande: \" . \$e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Meddelande skickat</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
        .success { color: green; padding: 15px; background-color: #f0f8f0; border-radius: 4px; margin: 20px 0; }
        .error { color: red; padding: 15px; background-color: #f8f0f0; border-radius: 4px; margin: 20px 0; }
        .links { margin: 20px 0; }
        .links a { display: inline-block; margin-right: 15px; }
    </style>
</head>
<body>
    <h1>Kontaktformulär - Resultat</h1>
    
    <?php if (isset(\$success)): ?>
        <div class='success'>✅ <?php echo \$success; ?></div>
    <?php endif; ?>
    
    <?php if (isset(\$error)): ?>
        <div class='error'>❌ <?php echo \$error; ?></div>
    <?php endif; ?>
    
    <div class='links'>
        <a href='contact.html'>← Tillbaka till kontaktformuläret</a>
        <a href='view_contacts.php'>👀 Visa alla meddelanden</a>
        <a href='index.html'>🏠 Tillbaka till startsidan</a>
    </div>
</body>
</html>
EOF

# Skapa PHP-script för att visa alla meddelanden
sudo tee /var/www/html/view_contacts.php > /dev/null <<'EOF'
<?php
\$servername = 'localhost';
\$username = '$DB_USER';
\$password = '$DB_PASSWORD';
\$dbname = '$DB_NAME';

try {
    \$pdo = new PDO(\"mysql:host=\$servername;dbname=\$dbname;charset=utf8\", \$username, \$password);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    \$stmt = \$pdo->query(\"SELECT * FROM contacts ORDER BY created_at DESC\");
    \$contacts = \$stmt->fetchAll(PDO::FETCH_ASSOC);
} catch(PDOException \$e) {
    \$error = \"Databasfel: \" . \$e->getMessage();
}
?>
<!DOCTYPE html>
<html lang='sv'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Alla meddelanden</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1000px; margin: 50px auto; padding: 20px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f5f5f5; }
        .error { color: red; padding: 15px; background-color: #f8f0f0; border-radius: 4px; margin: 20px 0; }
        .no-data { text-align: center; padding: 20px; background-color: #f0f8f0; border-radius: 4px; }
        .links { margin: 20px 0; }
        .links a { display: inline-block; margin-right: 15px; color: #007cba; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>📋 Alla meddelanden</h1>
    
    <?php if (isset(\$error)): ?>
        <div class='error'>❌ <?php echo \$error; ?></div>
    <?php elseif (empty(\$contacts)): ?>
        <div class='no-data'>📭 Inga meddelanden ännu. <a href='contact.html'>Skriv det första meddelandet!</a></div>
    <?php else: ?>
        <p>📊 Totalt: <?php echo count(\$contacts); ?> meddelanden</p>
        <table>
            <tr>
                <th>ID</th>
                <th>Namn</th>
                <th>E-post</th>
                <th>Meddelande</th>
                <th>Datum</th>
            </tr>
            <?php foreach (\$contacts as \$contact): ?>
            <tr>
                <td><?php echo htmlspecialchars(\$contact['id']); ?></td>
                <td><?php echo htmlspecialchars(\$contact['name']); ?></td>
                <td><a href='mailto:<?php echo htmlspecialchars(\$contact['email']); ?>'><?php echo htmlspecialchars(\$contact['email']); ?></a></td>
                <td><?php echo nl2br(htmlspecialchars(\$contact['message'])); ?></td>
                <td><?php echo \$contact['created_at']; ?></td>
            </tr>
            <?php endforeach; ?>
        </table>
    <?php endif; ?>
    
    <div class='links'>
        <a href='contact.html'>📝 Nytt meddelande</a>
        <a href='index.html'>🏠 Tillbaka till startsidan</a>
    </div>
</body>
</html>
EOF

# Sätt rätt rättigheter för alla nya filer
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 644 /var/www/html/*.html /var/www/html/*.php
sudo chmod 755 /var/www/html

# Starta om webbservern för säkerhets skull
sudo systemctl reload nginx
"

# ----- Ladda upp HTML-filer (om de finns) -----
if [ -d "$HTML_PATH" ]; then
    echo "🔄 Laddar upp HTML-filer..."
    scp -o StrictHostKeyChecking=no -r $HTML_PATH/*.html $ADMIN_USER@$VM_IP:~ 2>/dev/null || echo "Inga HTML-filer att ladda upp"
    ssh -o StrictHostKeyChecking=no $ADMIN_USER@$VM_IP "
        if ls ~/*.html 1> /dev/null 2>&1; then
            sudo mv ~/*.html /var/www/html/ 2>/dev/null
            sudo chown www-data:www-data /var/www/html/*.html
            sudo chmod 644 /var/www/html/*.html
            echo 'HTML-filer uppladdade'
        else
            echo 'Inga HTML-filer att flytta'
        fi
    "
fi

# ----- Slutlig verifiering -----
echo "🔄 Verifierar installation..."
ssh -o StrictHostKeyChecking=no $ADMIN_USER@$VM_IP "
    echo 'Kontrollerar tjänster...'
    sudo systemctl is-active nginx mysql php8.1-fpm
    
    echo 'Kontrollerar databasanslutning...'
    mysql -u $DB_USER -p'$DB_PASSWORD' $DB_NAME -e 'SELECT COUNT(*) as table_count FROM contacts;' 2>/dev/null && echo 'Databasanslutning OK' || echo 'Databasanslutning misslyckades'
    
    echo 'Kontrollerar webbfiler...'
    ls -la /var/www/html/
"

echo ""
echo "🎉 LEMP Stack installerad och konfigurerad!"
echo "📋 Databas information:"
echo "   - Root lösenord: $DB_ROOT_PASSWORD"
echo "   - Databas: $DB_NAME"
echo "   - Användare: $DB_USER"
echo "   - Lösenord: $DB_PASSWORD"
echo ""
echo "🌐 Testa din webbserver:"
echo "   - Startsida: http://$VM_IP"
echo "   - PHP info: http://$VM_IP/info.php"
echo "   - Kontaktform: http://$VM_IP/contact.html"
echo "   - Visa meddelanden: http://$VM_IP/view_contacts.php"
echo ""
echo "🚀 Klart! Din LEMP-stack är nu igång på http://$VM_IP"