Senaryo
🖥️ 1 adet Monitoring sunucun var. (Grafana + Prometheus burada)

🐳 Birden fazla Docker host izlemek istiyorsun.

Bu hostlarda sadece Docker çalışıyor (yani sistem detayları değil, sadece container performansı önemli).

İzlemek için Portainer + cAdvisor yeterli diyorsun (log vs. istemiyorsun).

🧩 Gerekenler
Monitoring Sunucunda:
Prometheus

Grafana

Her izlenecek Docker hostta:
cAdvisor (container performansını verir)

(İstersen Portainer – sadece yönetim için)

🚀 Kurulum
1️⃣ İzlenecek Her Docker Host’a cAdvisor Kurulumu
SSH ile Docker host’una gir ve şu komutu çalıştır:

bash
Kopyala
Düzenle
docker run -d \
  --name=cadvisor \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --publish=8080:8080 \
  gcr.io/cadvisor/cadvisor:latest
🔁 Bu container, http://host_ip:8080/metrics üzerinden Prometheus’a veri sağlar.

2️⃣ Monitoring Sunucunda Prometheus + Grafana (docker-compose)
Aşağıdaki dosyayı monitoring sunucuna kaydet: docker-compose.yml

yaml
Kopyala
Düzenle
version: '3'

services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
3️⃣ Prometheus Ayar Dosyası: prometheus.yml
yaml
Kopyala
Düzenle
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'cadvisor-hosts'
    static_configs:
      - targets:
          - 192.168.1.100:8080
          - 192.168.1.101:8080
          - 192.168.1.102:8080
👉 Yukarıdaki IP'lere kendi Docker hostlarının IP adreslerini yaz.

4️⃣ Başlat
bash
Kopyala
Düzenle
docker-compose up -d
5️⃣ Grafana Ayarları
Adres: http://<monitoring_ip>:3000

Giriş: admin / admin

Data Source ekle:

Name: Prometheus

URL: http://prometheus:9090

6️⃣ Dashboard Yükle
Grafana’da şunu yükle:
🔗 Docker Container Metrics Dashboard (ID: 193)

🧠 Ekstra (Opsiyonel)
Portainer İstiyorsan:
Her Docker hosta aşağıdaki komutla kurabilirsin:

bash
Kopyala
Düzenle
docker run -d -p 9000:9000 \
  --name=portainer \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce
✅ SONUÇ
Bileşen	Nerede Çalışıyor	Görev
Prometheus	Monitoring sunucusu	cAdvisor'dan metrik toplar
Grafana	Monitoring sunucusu	Görselleştirme
cAdvisor	İzlenen her hostta	Docker container performansını verir
Portainer	(İsteğe bağlı)	Container'ları web arayüzüyle yönet
