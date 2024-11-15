#!/bin/bash

# Ana sunucu ve yedek sunucu bilgileri
PRIMARY_IP="192.168.60.132"
STANDBY_IP="192.168.60.133"
PRIMARY_USER="postgres"
PRIMARY_PASSWORD="admin@123"
STANDBY_USER="replicator"  # Replication işlemi için kullanılan kullanıcı
STANDBY_PASSWORD="admin@123"  # Replication kullanıcısının şifresi
DATA_DIR="/var/lib/postgresql/14/main"  # PostgreSQL veri dizini

# Kontrol periyodu (saniye cinsinden)
CHECK_INTERVAL=10
WAIT_AFTER_PRIMARY_COMES_BACK=20  # Ana sunucu geri geldiğinde bekleme süresi (saniye)

# Yedek sunucuyu ana olarak terfi ettir
promote_standby() {
  echo "Yedek sunucu, standby modunda mı kontrol ediliyor..."

  RECOVERY_MODE=$(PGPASSWORD=$STANDBY_PASSWORD psql -h $STANDBY_IP -U $PRIMARY_USER -t -c "SELECT pg_is_in_recovery();" | xargs)

  if [ "$RECOVERY_MODE" == "t" ]; then
    echo "Yedek sunucu standby modunda, terfi işlemi başlatılıyor..."

    # Terfi işlemi öncesi kısa bir bekleme süresi
    sleep 5
    PGPASSWORD=$STANDBY_PASSWORD psql -h $STANDBY_IP -U $PRIMARY_USER -c "SELECT pg_promote();"

    if [ $? -eq 0 ]; then
      echo "Yedek sunucu başarılı bir şekilde ana sunucu olarak terfi ettirildi."
    else
      echo "Yedek sunucu terfi sırasında bir hata oluştu. Lütfen standby modunu ve logları kontrol edin."
    fi
  else
    echo "Uyarı: Yedek sunucu zaten ana olarak çalışıyor veya standby modunda değil. Terfi işlemi gereksiz."
  fi
}

# Eski ana sunucuyu geri döndüğünde yedek sunucudan veri çekerek senkronize et ve tekrar ana rolüne terfi ettir
sync_primary_with_standby_and_promote() {
  echo "Eski ana sunucu geri geldi, yedek sunucudaki verilerle senkronize ediliyor..."

  # Ana sunucuda PostgreSQL sunucusunu durdur
  echo "Ana sunucu PostgreSQL hizmeti durduruluyor..."
  ssh root@$PRIMARY_IP "systemctl stop postgresql@14-main.service || systemctl stop postgresql.service"

  if [ $? -ne 0 ]; then
    echo "Ana sunucu PostgreSQL hizmeti durdurulamadı. Senkronizasyon başarısız."
    return 1
  fi

  # Ana sunucuda eski verileri temizle
  echo "Ana sunucudaki eski veriler temizleniyor..."
  ssh root@$PRIMARY_IP "rm -rf $DATA_DIR/*"
  if [ $? -ne 0 ]; then
    echo "Ana sunucudaki veri temizleme işlemi başarısız oldu."
    return 1
  fi

  # Yedek sunucudan ana sunucuya veri çek
 
  echo "Yedek sunucudan ana sunucuya veri çekiliyor..."
 ssh root@$PRIMARY_IP " PGPASSWORD=$STANDBY_PASSWORD pg_basebackup -h $STANDBY_IP -D $DATA_DIR -U $STANDBY_USER -P -v -R -X stream -C -S slaveslot3"
 ssh root@$PRIMARY_IP "sudo chown -R postgres:postgres /var/lib/postgresql/14/main"
 ssh root@$PRIMARY_IP "sudo chmod 700 /var/lib/postgresql/14/main"

 if [ $? -ne 0 ]; then
    echo "Yedek sunucudan veri çekme işlemi başarısız oldu. Lütfen bağlantıyı ve izinleri kontrol edin."
    return 1
  fi
  
  #Postgres tekrar başlatılıyor

  echo "Ana sunucuda PostgreSQL hizmeti başlatılıyor..."
  ssh root@$PRIMARY_IP "systemctl start postgresql@14-main.service || systemctl start postgresql.service"
  if [ $? -eq 0 ]; then
    echo "Eski ana sunucu yedek sunucudan veri çekme işlemini tamamladı ve yeniden senkronize edildi."
 
    # Ana sunucuyu ana rolüne terfi ettirme
    echo "Ana sunucu tekrar primary olarak terfi ettiriliyor..."
    PGPASSWORD=$PRIMARY_PASSWORD psql -h $PRIMARY_IP -U $PRIMARY_USER -c "SELECT pg_promote();"
    if [ $? -eq 0 ]; then
      echo "Ana sunucu başarılı bir şekilde tekrar primary rolüne terfi ettirildi."

      # Yedek sunucuyu standby rolüne döndürmek için trigger oluşturma
      echo "Yedek sunucu standby moduna geçiriliyor..."
      ssh root@$STANDBY_IP "touch $DATA_DIR/standby.signal"
    else
      echo "Ana sunucu primary olarak terfi ettirilemedi. Lütfen kontrol edin."
    fi

  else
    echo "Ana sunucu PostgreSQL hizmeti başlatılamadı. Lütfen kontrol edin."
  fi
}

# Ana sunucu ve yedek sunucunun erişilebilirliğini kontrol etme
while true; do
  if ping -c 1 $PRIMARY_IP &> /dev/null; then
    echo "Ana sunucu erişilebilir durumda."

    # Eğer yedek sunucu ana olarak terfi ettirildiyse, failback ve veri senkronizasyon işlemini başlat
    if [ "$IS_FAILOVER" = true ]; then
      echo "Ana sunucu geri geldi, $WAIT_AFTER_PRIMARY_COMES_BACK saniye bekleniyor..."
      sleep $WAIT_AFTER_PRIMARY_COMES_BACK  # Ana sunucu geri geldiğinde 20 saniye bekle
      echo "Failback ve veri senkronizasyon işlemi başlatılıyor..."
      sync_primary_with_standby_and_promote
      if [ $? -eq 0 ]; then
        IS_FAILOVER=false
      else
        echo "Senkronizasyon sırasında bir hata oluştu. İşlem tekrarlanacak."
      fi
    fi

  else
    echo "Ana sunucuya erişilemiyor. Failover işlemi başlatılıyor."

    # Yedek sunucuyu ana olarak terfi ettir
    promote_standby
    IS_FAILOVER=true
  fi

  # Belirtilen süre boyunca bekleyin
  sleep $CHECK_INTERVAL
done

