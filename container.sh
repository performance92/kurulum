#!/bin/bash

# === Konfigürasyon ===
PRIMARY_CONTAINER="pg_primary"          # Ana konteyner adı
STANDBY_CONTAINER="pg_standby"          # Yedek konteyner adı
NETWORK="pg_network"                    # Her iki konteynerin bağlı olduğu Docker ağı

PRIMARY_USER="postgres"
PRIMARY_PASSWORD="Cekino.123!"

STANDBY_USER="replicator"
STANDBY_PASSWORD="admin@123"

# Host üzerindeki volume data dizinleri (docker volume inspect ile bulabilirsiniz)
PRIMARY_DATA_DIR="/var/lib/docker/volumes/pg_primary_data/_data"
STANDBY_DATA_DIR="/var/lib/docker/volumes/pg_standby_data/_data"

CHECK_INTERVAL=10                        # Kontrol periyodu (saniye)
WAIT_AFTER_PRIMARY_BACK=20               # Ana döndüğünde bekleme (saniye)

# === Yardımcı fonksiyonlar ===

# Docker konteyner IP'sini al
get_ip() {
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1"
}

# Yedek konteyneri terfi ettir
promote_standby() {
  echo ">>> Standby içinde pg_is_in_recovery() kontrol ediliyor..."
  STANDBY_IP=$(get_ip "$STANDBY_CONTAINER")
  RECOVERY=$(docker exec -u postgres "$STANDBY_CONTAINER" \
    bash -c "PGPASSWORD=$STANDBY_PASSWORD psql -tA -U $PRIMARY_USER -h localhost -c 'SELECT pg_is_in_recovery();'")
  if [ "$RECOVERY" = "t" ]; then
    echo ">>> Standby modunda, terfi başlatılıyor..."
    sleep 5
    docker exec -u postgres "$STANDBY_CONTAINER" \
      bash -c "PGPASSWORD=$STANDBY_PASSWORD psql -U $PRIMARY_USER -h localhost -c 'SELECT pg_promote();'"
    echo ">>> Standby başarıyla primary yapıldı."
  else
    echo ">>> Standby zaten primary ya da recovery değil (değeri: $RECOVERY)."
  fi
}

# Failback: primary'yi durdur, temizle, basebackup al, yeniden başlat, promote et, standby.signal oluştur
sync_primary_and_promote() {
  echo ">>> Failback: primary container durduruluyor..."
  docker stop "$PRIMARY_CONTAINER" || { echo "! primary durdurulamadı"; return 1; }

  echo ">>> Primary data dizini siliniyor: $PRIMARY_DATA_DIR"
  rm -rf "$PRIMARY_DATA_DIR"/*

  echo ">>> pg_basebackup ile standby’den veri çekiliyor..."
  docker run --rm \
    --network "$NETWORK" \
    -v "$PRIMARY_DATA_DIR":/var/lib/postgresql/14/main \
    -e PGPASSWORD="$STANDBY_PASSWORD" \
    postgres:14 \
    pg_basebackup \
      -h "$STANDBY_CONTAINER" \
      -D /var/lib/postgresql/14/main \
      -U "$STANDBY_USER" \
      -v -R -X stream

  echo ">>> Primary konteyner yeniden başlatılıyor..."
  docker start "$PRIMARY_CONTAINER" || { echo "! primary başlayamadı"; return 1; }

  echo ">>> Primary içinde pg_promote() çalıştırılıyor..."
  docker exec -u postgres "$PRIMARY_CONTAINER" \
    bash -c "PGPASSWORD=$PRIMARY_PASSWORD psql -U $PRIMARY_USER -h localhost -c 'SELECT pg_promote();'"

  echo ">>> Standby içinde standby.signal dosyası oluşturuluyor..."
  docker exec "$STANDBY_CONTAINER" \
    bash -c "touch /var/lib/postgresql/14/main/standby.signal"

  echo ">>> Failback tamam."
}

# === Ana döngü ===
IS_FAILOVER=false

while true; do
  PRIMARY_IP=$(get_ip "$PRIMARY_CONTAINER")

  if ping -c1 -W1 "$PRIMARY_IP" &>/dev/null; then
    echo "$(date +'%T') Ana konteyner erişilebilir."

    if [ "$IS_FAILOVER" = true ]; then
      echo ">>> Ana geri döndü, $WAIT_AFTER_PRIMARY_BACK saniye bekleniyor..."
      sleep "$WAIT_AFTER_PRIMARY_BACK"
      sync_primary_and_promote && IS_FAILOVER=false
    fi

  else
    echo "$(date +'%T') Ana konteyner erişilemedi, failover başlatılıyor..."
    promote_standby
    IS_FAILOVER=true
  fi

  sleep "$CHECK_INTERVAL"
done
