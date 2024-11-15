#!/bin/bash

# Sunucu bilgileri
PRIMARY_IP="192.168.60.132"
STANDBY_IP="192.168.60.133"
PRIMARY_USER="postgres"
PRIMARY_PASSWORD="admin@123"
STANDBY_USER="replicator"  # Replikasyon kullanıcı adı
STANDBY_PASSWORD="admin@123"  # Replikasyon kullanıcısının şifresi
SSH_PASSWORD="12345"  # SSH root şifresi
DATA_DIR="/var/lib/postgresql/14/main"  # PostgreSQL veri dizini

# Kontrol periyodu (saniye cinsinden)
CHECK_INTERVAL=10
WAIT_AFTER_PRIMARY_COMES_BACK=20  # Ana sunucu geri geldiğinde bekleme süresi (saniye)

# Yedek sunucuyu ana olarak terfi ettir
promote_standby() {
  echo "Yedek sunucunun recovery modunda olup olmadığı kontrol ediliyor..."

  RECOVERY_MODE=$(PGPASSWORD=$STANDBY_PASSWORD psql -h $STANDBY_IP -U $PRIMARY_USER -t -c "SELECT pg_is_in_recovery();" | xargs)

  if [ "$RECOVERY_MODE" == "t" ]; then
    echo "Yedek sunucu recovery modunda, terfi işlemi başlatılıyor..."

    sleep 5
    PGPASSWORD=$STANDBY_PASSWORD psql -h $STANDBY_IP -U $PRIMARY_USER -c "SELECT pg_promote();"

    if [ $? -eq 0 ]; then
      echo "Yedek sunucu başarıyla ana sunucu olarak terfi ettirildi."
    else
      echo "Yedek sunucu terfi sırasında bir hata oluştu. Lütfen recovery modunu ve logları kontrol edin."
    fi
  else
    echo "Uyarı: Yedek sunucu zaten ana olarak çalışıyor veya recovery modunda değil."
  fi
}

# Eski ana sunucuyu yedekten senkronize et ve terfi ettir
sync_primary_with_standby_and_promote() {
  echo "Ana sunucu geri geldi, yedek sunucudan veri ile senkronize ediliyor..."

  echo "Ana sunucuda PostgreSQL servisi durduruluyor..."
  sshpass -p "$SSH_PASSWORD" ssh root@$PRIMARY_IP "systemctl stop postgresql@14-main.service || systemctl stop postgresql.service"

  if [ $? -ne 0 ]; then
    echo "Ana sunucuda PostgreSQL servisi durdurulamadı. Senkronizasyon başarısız."
    return 1
  fi

  echo "Ana sunucudaki eski veriler temizleniyor..."
  sshpass -p "$SSH_PASSWORD" ssh root@$PRIMARY_IP "rm -rf $DATA_DIR/*"
  if [ $? -ne 0 ]; then
    echo "Ana sunucudaki veri temizleme işlemi başarısız oldu."
    return 1
  fi

  echo "Yedek sunucudan ana sunucuya veri çekiliyor..."
  sshpass -p "$SSH_PASSWORD" ssh root@$PRIMARY_IP "PGPASSWORD=$STANDBY_PASSWORD pg_basebackup -h $STANDBY_IP -D $DATA_DIR -U $STANDBY_USER -P -v -R -X stream -C -S slaveslot3"
  sshpass -p "$SSH_PASSWORD" ssh root@$PRIMARY_IP "sudo chown -R postgres:postgres /var/lib/postgresql/14/main"
  sshpass -p "$SSH_PASSWORD" ssh root@$PRIMARY_IP "sudo chmod 700 /var/lib/postgresql/14/main"

  if [ $? -ne 0 ]; then
    echo "Yedek sunucudan veri çekme işlemi başarısız oldu. Bağlantıyı ve izinleri kontrol edin."
    return 1
  fi

  echo "Ana sunucuda PostgreSQL servisi başlatılıyor..."
  sshpass -p "$SSH_PASSWORD" ssh root@$PRIMARY_IP "systemctl start postgresql@14-main.service || systemctl start postgresql.service"
  if [ $? -eq 0 ]; then
    echo "Ana sunucu yeniden yedek ile senkronize edildi."

    echo "Ana sunucu tekrar primary olarak terfi ettiriliyor..."
    PGPASSWORD=$PRIMARY_PASSWORD psql -h $PRIMARY_IP -U $PRIMARY_USER -c "SELECT pg_promote();"
    if [ $? -eq 0 ]; then
      echo "Ana sunucu tekrar primary rolüne terfi ettirildi."

      echo "Yedek sunucu standby moduna geçiriliyor..."
      sshpass -p "$SSH_PASSWORD" ssh root@$STANDBY_IP "touch $DATA_DIR/standby.signal"
    else
      echo "Ana sunucu primary olarak terfi ettirilemedi. Kontrol edin."
    fi

  else
    echo "Ana sunucuda PostgreSQL servisi başlatılamadı. Kontrol edin."
  fi
}

# Ana ve yedek sunucu erişilebilirliğini kontrol et
while true; do
  if ping -c 1 $PRIMARY_IP &> /dev/null; then
    echo "Ana sunucu erişilebilir durumda."

    if [ "$IS_FAILOVER" = true ]; then
      echo "Ana sunucu geri geldi, $WAIT_AFTER_PRIMARY_COMES_BACK saniye bekleniyor..."
      sleep $WAIT_AFTER_PRIMARY_COMES_BACK
      echo "Failback ve veri senkronizasyon işlemi başlatılıyor..."
      sync_primary_with_standby_and_promote
      if [ $? -eq 0 ]; then
        IS_FAILOVER=false
      else
        echo "Senkronizasyon sırasında bir hata oluştu. Tekrar deneniyor..."
      fi
    fi

  else
    echo "Ana sunucuya erişilemiyor. Failover işlemi başlatılıyor..."

    promote_standby
    IS_FAILOVER=true
  fi

  sleep $CHECK_INTERVAL
done

