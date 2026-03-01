# Compute Engine - Application VM Instance
# e2-standard-4: 4 vCPU, 16GB RAM

# Reference existing static IP reservation "exit8-static-ip"
data "google_compute_address" "exit8_static_ip" {
  name    = "exit8-static-ip"
  project = var.project_id
  region  = var.region
}

# Service Account for the VM
resource "google_service_account" "vm_service_account" {
  account_id   = "${var.instance_name}-sa"
  display_name = "Exit8 VM Service Account"
  project      = var.project_id
}

# Grant Secret Manager accessor role
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Grant Cloud SQL Client role
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Grant Logging and Monitoring roles
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Firewall Rules
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.instance_name}-allow-health-check"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8081"]
  }

  source_ranges = [
    "35.191.0.0/16",   # Google HTTP(S) Load Balancing
    "130.211.0.0/22"   # Google HTTP(S) Load Balancing
  ]

  target_tags = [var.instance_name]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.instance_name}-allow-ssh"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Consider restricting to your IP

  target_tags = [var.instance_name]
}
resource "google_compute_firewall" "allow_load_test" {
  name    = "${var.instance_name}-allow-load-test"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8082"]
  }

  # Only allow from load test client IP
  source_ranges = ["115.23.208.104/32"]

  target_tags = [var.instance_name]
}



resource "google_compute_firewall" "allow_internal" {
  name    = "${var.instance_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]  # Internal traffic

  target_tags = [var.instance_name]
}

# SSH Public Keys
locals {
  ssh_public_keys = join("\n", [
    "kylekim1223:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1stv8HhAY2LInyKzehtc90xMdt4E3aL/26nF5bAawNqEXxy4PBXQ6aIRG/4hlXS5dUDPd2yG/J6taA6IDcLVkb1+BSdSnDL0fqETjEfY9UMznWrAJ5XrTVsVHFl+/MYyUB3aQAMxOtjfE2XOq56PGeeK+Lh9MOe5bfCBHXZbAD18KjWcQl4fmvzNB1d3HN+0XJJ4kuxbojIUPR9YncVdQFGkXD6RBRSlW1v5iK1p16Bscaftn7NyLJ/XV/ksA1GuLexQTAkAnChhtibARIIjbkhEPj1D+AR1sq2luFCtuK10DYzYKKcTWeboFOMq4iLu2XH0H/MqJHi7xEaWH0fBcNgqWPVt614SV59i3hyeV8vPBpGllohr4LucwiBvmDJtZATu4IcTrMOAEF1ZASvTjRWAx61NpzQ/fxA0kNhcw3fXL7y/cuopiH4qiyJ9ZWULsS3E28Y0FGXc/yqHrwDTJ30kp2U+7GvDeqF1vjDg34xB9oJO1mbBhHt5PsWXDCYU= kylekim1223@kylekim1223ui-MacBookPro.local",
    "kylekim1223:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCoLQMBhJtA1C8jH2a5z8uq3cuR4YBdMj4tLtShJkOZ2/aOukDwx0gw5dBQGGSFBJ5SMk1nyQVh7x1HZF3fr3PdT/fufoRX9N1Oz1GWaYehJ07Ql0N2HjDpgT2HkEAKpgbeB8Bj+exQ5bjHACHuz79z1P4tuj85Izap5NpJayP8SOxioXTUEegNVr2LRKlGT+WDF9DviSZjSglJcnXmJBEkFhYGjRVTrmhuwQi+l3HcxweLfg3YBhudQLZOXuBgaQblV7YP/f728ddwQ+twXettPrCdfTmeepBk6CWVzLj3xsCOhcJMXMu8rQz9KhiMwNhM1vgzU6a6QOMiy2YdML9X kylekim1223@exit8",
    "user:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDummPt7a1AQQync9y4gDN3zuvI0ky7hhWf3xsMecI1ZDl+b3hcWu0RVdT2QSpIJVvh3jfB/KdYpkQUk7pJ0asVBr6pHOML1ad207ZBVm4XcYcHPptlN4euyJOIe3mB3pGfw8ogKkbxOrmlvIhn8A1twd2ifzXGPqql6F6w2GxSGYo9sOT6M8zUbG24XFfoLgGVnbXqlPbJiv/vm41AbODlGDGx/8wcmxyiww2/2wqRulyV9P8/fO5FcSbBNninlJeYNJXPNvaEot8Rd9+05yssOEjXHvtWoiwCxBzcoQhreUWAcJRk0JV/GBEcrEffG7B7X7TpuRdHfcLuEGbbc22NSETeYNHUpnnAwKk5G7uiWKxgXD/5VokESiCXkS7SPE9zP9Ov/9HpouX1/BX1nIZsQiiUn/chRsXJFL2SeF/oAAGZzWOInz9NWcax5Ram0PrbTIpvZxgVlXiaFkH1MWxAXOjnFDKqQDTuKtZnuCFrcLMaoBHCk3g1NM47iwKXex3Fbcm1zNcLr1gZgOfPT2iJFhE2dbGa2kkSsC527lGpb1CmuuIjmEp/UiIHjNukBPzFG+83850H7pE4Jq2VY3YctCZfwnKlUi4jJ2hPCqQeHsMT8b57YxgPlD/qvIhTjc59gjQYVo0coko1nvs9yk2TCiFfpTYcvW7nsncCOSng0Q== user@DESKTOP-GKPC8P9",
    "user2:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6I1ew7MNmq6YPnuxjkq3b+ZmU9DvuoiQuWYxR4m1M9ilw3M68H3aubAHBvqKfIUBESxZ8ZXtNUaY0wMPVgkdatdWemvN1eSfJojw9uKlRB2RhnrMimKneyUm68guAZWuKrj1rbOaqNpSjIWZ4tjdkO1QhXwVPDMGvtQrt+EfDY8gvZBXUk89ljsEv6A7jZLGl5liZs5vj5gu/cHU4b5R5uo1WHr3nLTNz06c1n0Vtdwewl8k3kiAb7TnW3tvRzlZTaSg8wRYes9a1Es0ZPzbWVso0lVzrE6MKqABGgiujh458Nxs8/rpqlGHBPyIvpaqwVi3/I4o1KEEZV2VhrjlzRv7V9VQ08onUHBbHdrllsLJGQjQbAp+qnqc3Oszcbk066hqxYoOr453fjzIINmmDoFqjkO9e8Q7Scv5Bkyjan1GFuQJmXEDjFsfxOiwiSZoLAmSRCuK6zKl5zyP4H3ybiv4EvXSVltYasKhpV1yRZFNxw3L1NQIV56ExkF0ylsBuvfpZ7XGpkPkDKBrLJ6qadfpVIKuSUd9SVPvRRoyKR7Iu3n1U1dUOwo6WDDyWtrWa+HJHTt7VlOuT7oj6HFlLg2wdebF8mt7ABXl1JPxpfMGkY047C10r3xaE+T3SMCZ4t7zfZtknaXe3/uLq7PGQgSgEEGgN40435ZwsH7lMzQ== user2@BOOK-L4O99T1CST",
    "dlwlg:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEqyaaY7j53pn8YNNZCVccm6TXsY6jUtZUz1zmg9KALXifnXz2GWN+Fl/pJ3gGc8Aft6fb7RqCr5lXhSbzhsZfjqOkbHL2oTsuTh0vA7sA4zdwNDUxMQyElb1GK8DiQNWN7FoPpth6PvcOm6o8t8K9q9vjxomGw79AiMTfdj0LRxQ+QFvm7PNllNVQxweEb7/gpmvg7Uisco0WSUoz1l2YQCsfWo3uMJnqxg/L4YgmGzJYaJrIj6KMQpgMl+ZBLqMPvl2m4L/H2S1XWf6PMjl2tDOdjaWNJrl1xUADrdmzbwI7lBC8u78gAmiiGyqdp/TZ4SrGxevuMBA32Y0kjI5KMWgSUOEiU/VlEZP8X1rwCLSZWrn6Wm1/lVLahb7rmY9URfo/bIkHuWauMEQ48Ct5WSxM9CjEz+t/Pb/gWthnhrjtts3z+IGpDytapLfKy9B04jkMdYet958e5/ShcOYfaJd8LQ4XLM9hcCU7xw9TTd8T/RrQsg19WUdAsG6NRhTigrkk7BY001j6Cqg8JN62SHfmjiboaEvk/KTGXjj5JvArMNS24bVQ6KmPlDQzy4P12GN4gBY3NP2Zjt7ZnDAv4lRXvZyFkr80dXSaSfxhKtIGWYijmMJQ8X/sCQaGThRkgrDbrsixL+VT2dKkoXoCk2gP4UoznAMxrswV1o7m1Q== dlwlg@DESKTOP-21R93OE",
    "owner:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9hVtgtpdf4Ryiv+Ry9190uPY3ty5CA0X3l9G6cniWDvL5yhpSiI8opRFGsH+/d/Bo5VSzmMzSxJuZM3zDzh+L6TuuUsqTi2rIuUdEDZZmq6cw20vqL/4qZJ7vDFmjeKuEUK0xFeFWsA+YKkkwikMHEs0AyKIlo27MUINU6Wj2T/jXKxSa1GuhFFthETqcWAE1+6MxG5OnNF0pi+YRcoh0Pt73Ie1Iv9zWhq6iDL4+Xr3x9ieihSWpY6zpJGq1+fkihR4Jb60Rfsb8cgxEbyuBLIRe88rEp9BxU3dEnU3jtiIQtU2uLDzNyB32/4aDqqepBVbDBlSh6bJ6QylMRdatJBj+B8rGy1G3UUVkNOXad4NYwsli1WMktboFTGjULG6gNPu1UbDSD0lhtMntxUKmwh9izka1d/5ji4zdgatztajIbpV3REqwEHEXE1q8b3fB/EEsP1oZrRsO+7JvMnhj1mlmLkN945rUujmOBJEdhXJS6Y2jM0dRRlPlK1g6XUpFdTieA8c4pHt5wYzk0qANb/PDZvifyN1bEuGnomhqDypOgyTjQpK3pBK0NiSM7QSFcpCKEPhUQzr1KaPptoeDWnirFeqD9+UxbihSaeLW8ALDfcd4iRwi+vNveVCxNFiAnDjBSwNtg6US5K42w3/+fn2JvLDtR2yil7NQSuC3IQ== owner@DESKTOP-99K61QK",
    "deploy-bot:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2ROGpgMjwNmsEoeXyuYwEkl+sgfu3N0BqVjMairoEY deploy-bot@exit8-ci",
  ])
}

# Compute Engine Instance
resource "google_compute_instance" "exit8_vm" {
  name         = var.instance_name
  project      = var.project_id
  zone         = var.zone
  machine_type = "e2-standard-4"  # 4 vCPU, 16GB RAM

  tags = [var.instance_name, "exit8", "docker"]

  # Boot disk
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100  # 100GB SSD
      type  = "pd-ssd"
    }
  }

  # Network interface
  network_interface {
    network    = google_compute_network.exit8-vpc.id
    subnetwork = google_compute_subnetwork.exit8-subnet.id

    access_config {
      nat_ip = data.google_compute_address.exit8_static_ip.address
    }
  }

  # Service account
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  # Metadata for startup script and instance info
  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = local.ssh_public_keys
    # Startup script will be added via Ansible
    startup-script = <<-EOF
      #!/bin/bash
      # Install Docker
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      usermod -aG docker ubuntu

      # Install Docker Compose
      curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose

      # Create app directory
      mkdir -p /opt/exit8
      chown ubuntu:ubuntu /opt/exit8

      # =====================================================
      # Log Retention: 7-day local policy
      # BigQuery keeps 90 days externally via log sink
      # =====================================================

      # Systemd journal: 7일 보관, 최대 500MB
      mkdir -p /etc/systemd/journald.conf.d
      cat > /etc/systemd/journald.conf.d/retention.conf <<'JOURNALD'
[Journal]
MaxRetentionSec=7day
SystemMaxUse=500M
SystemKeepFree=1G
JOURNALD
      systemctl restart systemd-journald

      # 시스템 로그 (syslog, auth, kern): 7일 보관 / 100MB 초과 시 즉시 로테이션
      cat > /etc/logrotate.d/rsyslog <<'LOGROTATE'
/var/log/syslog
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
    daily
    rotate 7
    size 100M
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
LOGROTATE

      # NPM nginx 로그: 7일 보관 / 50MB 초과 시 즉시 로테이션
      cat > /etc/logrotate.d/npm-logs <<'LOGROTATE'
/var/lib/docker/volumes/self-managed-infrastructure_npm_data/_data/logs/*.log {
    daily
    rotate 7
    size 50M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
LOGROTATE

      # Wazuh 로그: 7일 보관 (보안 사고 시점 최소 확인 기간)
      cat > /etc/logrotate.d/wazuh-logs <<'LOGROTATE'
/var/lib/docker/volumes/self-managed-infrastructure_wazuh_logs/_data/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
LOGROTATE

      # GCS 업로드 스크립트: logrotate가 만든 .gz 파일을 매일 새벽 GCS로 전송
      # - system/, nginx/: 30일 보관 (장애 분석용)
      # - wazuh/: 180일 보관 (보안 규정 및 침해 사고 조사용)
      cat > /usr/local/bin/upload-logs-to-gcs.sh <<'UPLOAD'
#!/bin/bash
BUCKET="${var.project_id}-exit8-vm-log-archive"
DATE=$(date +%Y/%m/%d)

upload() {
    local src="$1" dest="$2"
    gcloud storage cp "$src" "$dest" --quiet \
        && echo "[gcs-upload] OK: $(basename $src) → $dest" \
        || echo "[gcs-upload] FAIL: $src"
}

# System logs → gs://BUCKET/system/YYYY/MM/DD/
find /var/log -maxdepth 1 -name "*.gz" -mtime -1 2>/dev/null | while read f; do
    upload "$f" "gs://$BUCKET/system/$DATE/$(basename $f)"
done

# NPM nginx logs → gs://BUCKET/nginx/YYYY/MM/DD/
find /var/lib/docker/volumes/self-managed-infrastructure_npm_data/_data/logs \
    -name "*.gz" -mtime -1 2>/dev/null | while read f; do
    upload "$f" "gs://$BUCKET/nginx/$DATE/$(basename $f)"
done

# Wazuh logs → gs://BUCKET/wazuh/YYYY/MM/DD/
find /var/lib/docker/volumes/self-managed-infrastructure_wazuh_logs/_data \
    -name "*.gz" -mtime -1 2>/dev/null | while read f; do
    upload "$f" "gs://$BUCKET/wazuh/$DATE/$(basename $f)"
done
UPLOAD
      chmod +x /usr/local/bin/upload-logs-to-gcs.sh

      # 매일 새벽 3시 GCS 업로드 (logrotate 완료 후)
      echo "0 3 * * * root /usr/local/bin/upload-logs-to-gcs.sh >> /var/log/upload-logs-to-gcs.log 2>&1" \
          > /etc/cron.d/exit8-log-upload

      # Log completion
      echo "Startup script completed at $(date)" >> /var/log/startup-script.log
    EOF
  }

  # Labels for organization
  labels = {
    environment = "demo"
    project     = "exit8"
    managed_by  = "terraform"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_compute_firewall.allow_health_check,
    google_compute_firewall.allow_ssh,
    google_compute_firewall.allow_internal
  ]
}

