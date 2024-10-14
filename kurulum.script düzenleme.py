#!/bin/bash

LOGFILE="/var/log/gardiyan_install.log"  # Log dosyasının yolu

# Log fonksiyonu
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Hata kontrol fonksiyonu
check_error() {
    if [[ $? -ne 0 ]]; then
        log "Hata oluştu: $1"
        exit 1
    fi
}

log "Kurulum başlıyor..."
log "Gardiyan çıkartılıyor."
tar -xf disk1_v2.tar.gz -C /home/gardiyan 2>> "$LOGFILE"
check_error "disk1_v2.tar.gz' dosyası çıkartılamadı."
tar -xf dist.tar.gz -C /usr/local/lib/python3.8/dist-packages 2>> "$LOGFILE"
check_error "dist.tar.gz' dosyası çıkartılamadı."
tar -xf paping.tar.gz -C /usr/local/bin 2>> "$LOGFILE"
check_error "paping.tar.gz' dosyası çıkartılamadı."
chmod 755 /usr/local/bin/paping
rm -r paping.tar.gz
sleep 2
clear

log "Oracle Java8 kuruluyor."
sleep 2
mkdir -p /usr/lib/jvm/ && tar -xf java-8-oracle.tar.gz -C /usr/lib/jvm/ 2>> "$LOGFILE"
check_error "java-8-oracle.tar.gz' dosyası çıkartılamadı."
export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export PATH=$JAVA_HOME/bin:$PATH
clear
java -version 2>> "$LOGFILE"
check_error "Java sürümü kontrol edilemedi."
sleep 2

echo 'export JAVA_HOME=/usr/lib/jvm/java-8-oracle' >> /root/.bashrc
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-oracle' >> /home/gardiyan/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /root/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /home/gardiyan/.bashrc
log "Oracle Java8 kuruldu."
sleep 2
clear

log "Karaf repoları aktarılıyor..."
tar -xf karaf_m2.tar.gz -C /home/gardiyan 2>> "$LOGFILE"
check_error "karaf_m2.tar.gz' dosyası çıkartılamadı."
ln -s /home/gardiyan/.m2 /root/.m2
log "Karaf repoları aktarıldı."
clear

log "Nginx kuruluyor..."
sleep 2
apt-get install nginx -y >> "$LOGFILE" 2>&1
check_error "Nginx kurulurken hata oluştu."
clear

log "Nginx kuruldu."
sleep 2
clear

log "Postgresql kuruluyor."
sleep 2
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' 2>> "$LOGFILE"
check_error "PostgreSQL repo eklenirken hata oluştu."
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - 2>> "$LOGFILE"
check_error "PostgreSQL anahtar eklenirken hata oluştu."
sudo apt-get update 2>> "$LOGFILE"
check_error "PostgreSQL güncellenirken hata oluştu."
apt-get install postgresql-13 postgresql-client-13 -y >> "$LOGFILE" 2>&1
clear
sleep 5
clear

cd postgres_config && cp -r * /etc/postgresql/13/main/ 2>> "$LOGFILE"
check_error "PostgreSQL yapılandırması kopyalanırken hata oluştu."
systemctl daemon-reload
systemctl restart postgresql
cd ..
log "Postgresql kuruldu."
sleep 2
clear

log "Guacamole bileşenleri kuruluyor..."
sleep 2
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y gcc g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh․․․