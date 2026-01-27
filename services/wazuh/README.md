# Wazuh SIEM/HIDS

Wazuh는 리소스를 많이 사용하므로 별도의 compose 파일로 분리했습니다.

## Quick Start

```bash
# Wazuh 스택 실행
docker-compose -f services/wazuh/docker-compose.wazuh.yml up -d

# 상태 확인
docker-compose -f services/wazuh/docker-compose.wazuh.yml ps
```

## Access

- **Wazuh Dashboard**: https://localhost:5601
  - Username: `admin`
  - Password: `SecretPassword`

## Components

| Component | Port | Description |
|-----------|------|-------------|
| Wazuh Manager | 55000 | API |
| Wazuh Manager | 1514 | Agent connection |
| Wazuh Manager | 1515 | Agent enrollment |
| Wazuh Indexer | 9200 | OpenSearch |
| Wazuh Dashboard | 5601 | Web UI |

## Requirements

- Minimum 4GB RAM for Wazuh stack
- `vm.max_map_count=262144` (for OpenSearch)

```bash
# Set vm.max_map_count (required for OpenSearch)
sudo sysctl -w vm.max_map_count=262144

# Make it persistent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```
