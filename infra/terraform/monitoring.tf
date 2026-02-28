# Cloud Monitoring & Logging Configuration
# Centralized observability for Exit8 infrastructure

# ============================================================================
# Log Router - Aggregate logs from all resources
# ============================================================================

# BigQuery Dataset for long-term log storage
resource "google_bigquery_dataset" "exit8_logs" {
  dataset_id  = "exit8_logs"
  project     = var.project_id
  location    = var.region
  description = "Exit8 infrastructure and application logs (long-term storage)"

  # 90일 자동 만료: 비용 제어 (ERROR+ 는 GCS 아카이브로 별도 장기 보관)
  default_table_expiration_ms = 7776000000 # 90 days = 90 * 24 * 60 * 60 * 1000

  delete_contents_on_destroy = false
}

# Grant log sink's writer identity access to the BigQuery dataset
resource "google_bigquery_dataset_iam_member" "log_sink_writer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.exit8_logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.exit8_logs_sink.writer_identity

  depends_on = [google_logging_project_sink.exit8_logs_sink]
}

# Log Sink for BigQuery (app + infra 로그, 90일 보관)
# - gce_instance: Docker gcplogs 드라이버로 전달되는 앱 컨테이너 로그 (INFO+)
# - cloudsql_database / redis_instance: 인프라 경고/오류만 (WARNING+)
resource "google_logging_project_sink" "exit8_logs_sink" {
  name                   = "exit8-logs-sink"
  project                = var.project_id
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.exit8_logs.dataset_id}"
  filter                 = "(resource.type=\"gce_instance\" AND severity>=\"INFO\") OR (resource.type=\"cloudsql_database\" AND severity>=\"WARNING\") OR (resource.type=\"redis_instance\" AND severity>=\"WARNING\")"
  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }

  depends_on = [google_bigquery_dataset.exit8_logs]
}

# ============================================================================
# Error Archive - Cloud Storage (ERROR+ 장기 보관, BigQuery보다 저렴)
# ============================================================================

# GCS 버킷: ERROR+ 로그 1년 보관
# 스토리지 클래스 자동 전환으로 비용 최소화
resource "google_storage_bucket" "exit8_error_archive" {
  name          = "${var.project_id}-exit8-error-archive"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  # STANDARD → NEARLINE (30일): $0.02/GB → $0.01/GB
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition { age = 30 }
  }

  # NEARLINE → COLDLINE (90일): $0.01/GB → $0.004/GB
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition { age = 90 }
  }

  # 1년 후 자동 삭제
  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
}

# Log Sink for GCS (ERROR+ 전용, 1년 보관)
resource "google_logging_project_sink" "exit8_error_archive_sink" {
  name                   = "exit8-error-archive-sink"
  project                = var.project_id
  destination            = "storage.googleapis.com/${google_storage_bucket.exit8_error_archive.name}"
  filter                 = "(resource.type=\"gce_instance\" OR resource.type=\"cloudsql_database\" OR resource.type=\"redis_instance\") AND severity>=\"ERROR\""
  unique_writer_identity = true

  depends_on = [google_storage_bucket.exit8_error_archive]
}

# GCS 버킷 쓰기 권한
resource "google_storage_bucket_iam_member" "error_archive_writer" {
  bucket = google_storage_bucket.exit8_error_archive.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.exit8_error_archive_sink.writer_identity
}

# ============================================================================
# Monitoring Dashboard
# ============================================================================

resource "google_monitoring_dashboard" "exit8_dashboard" {
  dashboard_json = jsonencode({
    displayName = "Exit8 Infrastructure Dashboard"
    gridLayout = {
      columns = 2
      widgets = [
        # VM CPU Usage
        {
          title = "VM CPU Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/usage_time\" AND resource.label.zone=\"${var.zone}\""
                  aggregation = {
                    alignmentPeriod     = "60s"
                    perSeriesAligner    = "ALIGN_RATE"
                    crossSeriesReducer  = "REDUCE_NONE"
                  }
                }
              }
            }]
          }
        },
        # VM Memory Usage (requires Ops Agent)
        {
          title = "VM Memory Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"gce_instance\" AND metric.type=\"agent.googleapis.com/memory/percent_used\" AND resource.label.zone=\"${var.zone}\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_NONE"
                  }
                }
              }
            }]
          }
        },
        # Cloud SQL CPU
        {
          title = "Cloud SQL CPU Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/usage_time\" AND resource.label.database_id=\"${var.project_id}:${var.db_name}\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_NONE"
                  }
                }
              }
            }]
          }
        },
        # Cloud SQL Connections
        {
          title = "Cloud SQL Connections"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\" AND resource.label.database_id=\"${var.project_id}:${var.db_name}\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_NONE"
                  }
                }
              }
            }]
          }
        },
        # Redis Memory
        {
          title = "Redis Memory Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"redis_instance\" AND metric.type=\"redis.googleapis.com/stats/memory/usage\" AND resource.label.instance_id=\"${var.redis_name}\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_NONE"
                  }
                }
              }
            }]
          }
        },
        # Redis Hit Ratio
        {
          title = "Redis Hit Ratio"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"redis_instance\" AND metric.type=\"redis.googleapis.com/stats/cache_hit_ratio\" AND resource.label.instance_id=\"${var.redis_name}\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_NONE"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}

# ============================================================================
# Alert Policies
# ============================================================================

# High CPU Alert
resource "google_monitoring_alert_policy" "high_cpu" {
  display_name = "Exit8 - High CPU Usage"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "VM CPU > 80%"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/usage_time\" AND resource.label.zone=\"${var.zone}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_NONE"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = []  # Add notification channels as needed

  alert_strategy {
    auto_close = "604800s"  # 7 days
  }
}

# Cloud SQL High Connections Alert
resource "google_monitoring_alert_policy" "high_db_connections" {
  display_name = "Exit8 - High DB Connections"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "DB Connections > 80% of max"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\" AND resource.label.database_id=\"${var.project_id}:${var.db_name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 160  # 80% of 200 max_connections

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_NONE"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = []

  alert_strategy {
    auto_close = "604800s"
  }
}

# Redis Memory Alert
resource "google_monitoring_alert_policy" "high_redis_memory" {
  display_name = "Exit8 - High Redis Memory"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Redis Memory > 80%"
    condition_threshold {
      filter          = "resource.type=\"redis_instance\" AND metric.type=\"redis.googleapis.com/stats/memory/usage_ratio\" AND resource.label.instance_id=\"${var.redis_name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_NONE"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = []

  alert_strategy {
    auto_close = "604800s"
  }
}

# Load Balancer 5xx Errors
resource "google_monitoring_alert_policy" "lb_5xx_errors" {
  display_name = "Exit8 - High 5xx Error Rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "5xx Error Rate > 5%"
    condition_threshold {
      filter          = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND resource.label.url_map_name=\"${var.lb_name}-urlmap\" AND metric.label.response_code_class=\"500\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5  # ALIGN_RATE 기준 초당 5건 (= 분당 300건) 이상 5xx 시 알림

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.url_map_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = []

  alert_strategy {
    auto_close = "604800s"
  }
}

# ============================================================================
# Uptime Checks
# ============================================================================

resource "google_monitoring_uptime_check_config" "exit8_https" {
  display_name = "Exit8 HTTPS Uptime Check"
  project      = var.project_id
  timeout      = "10s"
  period       = "60s"

  http_check {
    request_method = "GET"
    path           = "/health"  # 앱의 헬스체크 엔드포인트 (LB health check와 동일하게 맞춤)
    use_ssl        = true
    validate_ssl   = false  # IP 주소로 요청 시 도메인-인증서 불일치로 SSL 검증 실패하므로 비활성화
                            # 실제 도메인(exit8.example.com)을 LB IP에 연결한 후 true로 변경
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_compute_global_address.lb_ip.address
    }
  }
}
