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
log "Guacamole bileşenleri kuruluyor..."
sleep 2
apt-get update >> "$LOGFILE" 2>&1
apt-get install -y gcc g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libssl-dev libvorbis-dev libwebp-dev libpulse-dev libavformat-dev ffmpeg cowsay make openjdk-8-jdk tomcat9 tomcat9-admin tomcat9-common tomcat9-user >> "$LOGFILE" 2>&1
check_error "Guacamole bileşenleri kurulurken hata oluştu."
log "Guacamole bileşenleri kuruldu."
sleep 7
clear

log "Guacamole derleniyor..."
sleep 2
cd /home/gardiyan/Gardiyan_Setup/gardiyan_v2_s1/guacamole_setup_new && tar -xf guacamole-server-1.3.0.tar.gz 2>> "$LOGFILE"
check_error "guacamole-server-1.3.0.tar.gz' dosyası çıkartılamadı."
cd guacamole-server-1.3.0/
./configure --with-init-dir=/etc/init.d --disable-dependency-tracking >> "$LOGFILE" 2>&1
check_error "Guacamole yapılandırması sırasında hata oluştu."
sleep 2
make >> "$LOGFILE" 2>&1
check_error "Make işlemi sırasında hata oluştu."
sleep 2
make install >> "$LOGFILE" 2>&1
check_error "Make install sırasında hata oluştu."
sleep 2
ldconfig
sleep 2
systemctl stop guacd
cd /home/gardiyan/Gardiyan_Setup/gardiyan_v2_s1
clear

log "Openfire kuruluyor..."
cd /home/gardiyan/Gardiyan_Setup/gardiyan_v2_s1
sleep 2
dpkg -i openfire_4.7.1_all.deb >> "$LOGFILE" 2>&1
check_error "Openfire kurulurken hata oluştu."
log "Openfire kuruldu."
sleep 2
clear

log "SSHPass kuruluyor..."
sleep 2
apt-get install sshpass -y >> "$LOGFILE" 2>&1
check_error "SSHPass kurulurken hata oluştu."
log "SSHPass kuruldu."
sleep 2
clear

systemctl daemon-reload
chown gardiyan:gardiyan -R /home/gardiyan/Gardiyan
export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export PATH=$JAVA_HOME/bin:$PATH
clear

log "Araçlar kuruluyor..."
apt-get install -y unzip zip inxi net-tools >> "$LOGFILE" 2>&1
check_error "Araçlar kurulurken hata oluştu."
log "Araçlar kuruldu."
sleep 3
clear

# Eğer NFS Server kurulumu gerekiyorsa bu bölümü açabiliriz
# log "NFS Server kuruluyor..."
# apt-get install nfs-kernel-server -y >> "$LOGFILE" 2>&1
# check_error "NFS Server kurulurken hata oluştu."
# log "NFS Server kuruldu."
# log "NFS Yapılandırma ayarlarını yapınız!!"
# sleep 5
# nano exports
# cp -r exports /etc/
# sleep 3
# systemctl daemon-reload
# systemctl restart nfs-server
# clear

log "Gardiyan test amaçlı ilk kez çalıştırılıyor..."
cd /home/gardiyan/Gardiyan/Server/Main/apache-karaf-4.0.10/bin/ && ./start >> "$LOGFILE" 2>&1
check_error "Gardiyan başlangıcı sırasında hata oluştu."
sleep 90
log "Gardiyan M2 uygulandı."
sleep 2
clear

log "Sunucunun saat dilimi ayarlanıyor..."
timedatectl set-timezone Europe/Istanbul >> "$LOGFILE" 2>&1
check_error "Saat dilimi ayarlanırken hata oluştu."
log "Saat dilimi ayarlandı."
cat /etc/timezone
clear

log "Docker kuruluyor..."
cd /home/gardiyan/Gardiyan_Setup/gardiyan_v2_s1/docker/
sudo dpkg -i ./containerd.io_1.6.25-1_amd64.deb \
./docker-ce_24.0.7-1~ubuntu.20.04~focal_amd64.deb \
sudo dpkg -i ./containerd.io_1.6.25-1_amd64.deb \
./docker-ce_24.0.7-1~ubuntu.20.04~focal_amd64.deb \
./docker-ce-cli_24.0.7-1~ubuntu.20.04~focal_amd64.deb \
./docker-buildx-plugin_0.11.2-1~ubuntu.20.04~focal_amd64.deb \
./docker-compose-plugin_2.21.0-1~ubuntu.20.04~focal_amd64.deb >> "$LOGFILE" 2>&1
check_error "Docker kurulurken hata oluştu."
log "Docker kuruldu."
clear

cd /home/gardiyan/DBs
./import_dbs.sh >> "$LOGFILE" 2>&1
check_error "Veritabanları içe aktarılırken hata oluştu."
sleep 10

cd /home/gardiyan/Gardiyan_Setup/gardiyan_v2_s1
./Setup_2.sh >> "$LOGFILE" 2>&1
check_error "Setup 2 işlemi sırasında hata oluştu."

cowsay -f tux "Kurulum Tamamlandı. Sunucuyu Yeniden Başlatın..." | tee -a "$LOGFILE"
