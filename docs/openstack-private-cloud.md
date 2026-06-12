# OpenStack Private Cloud

## 문서 목적

이 문서는 Terraform으로 관리하는 OpenStack 리소스의 상세 구성을 설명합니다. 전체 아키텍처는 [README](../README.md), host network와 VPN은 [Network and VPN](network-vpn.md), 운영 명령은 [Operation Guide](operation-guide.md)를 참고합니다.

## 물리 서버와 배치

| 서버 | OpenStack 역할 | 배치 workload |
|---|---|---|
| `openstack-aio` | Controller 및 compute node | K3s VM 3대 |
| `openstack-compute` | Compute node | Harbor 및 backup VM |

Terraform은 instance의 `availability_zone`을 통해 VM 배치 위치를 선언합니다.

## Network 리소스

| Network | 속성 | CIDR | Gateway | 용도 |
|---|---|---|---|---|
| `int-net` | External | `10.10.10.0/24` | `10.10.10.1` | K3s VM 및 외부 연결 |
| `vxlan-net` | Internal | `10.10.20.0/24` | `10.10.20.1` | Harbor 및 MinIO |

`internal-router`는 `int-net`을 external network로 사용하고 `vxlan-net` subnet을 연결합니다. `int-subnet`에는 `vxlan-net` 목적지에 대한 subnet route가 선언되어 있습니다.

```text
destination: 10.10.20.0/24
next hop:    10.10.10.2
```

`br-ex` IP, host route, NAT 및 DNAT는 OpenStack 리소스가 아니므로 Terraform 관리 범위 밖입니다.

## Fixed-IP Port

| Port | Fixed IP | Network | Security |
|---|---|---|---|
| `k3s-master-port` | `10.10.10.170` | `int-net` | Default security group |
| `k3s-worker-1-port` | `10.10.10.165` | `int-net` | Default security group |
| `k3s-worker-2-port` | `10.10.10.195` | `int-net` | Default security group |
| `harbor-vxlan-port` | `10.10.20.4` | `vxlan-net` | Port security disabled |
| `backup-port` | `10.10.20.5` | `vxlan-net` | Port security disabled |

고정 IP는 현재 운영 리소스를 import한 상태와 일치하도록 선언되어 있습니다.

## Flavor와 Instance

| VM | 배치 위치 | vCPU | RAM | Boot volume | 역할 |
|---|---|---:|---:|---:|---|
| `k3s-master` | `openstack-aio` | 4 | 8 GB | 40 GB | K3s control plane |
| `k3s-worker-1` | `openstack-aio` | 4 | 12 GB | 40 GB | TimescaleDB |
| `k3s-worker-2` | `openstack-aio` | 4 | 12 GB | 40 GB | Airflow |
| `harbor` | `openstack-compute` | 4 | 8 GB | 40 GB | Container registry |
| `backup` | `openstack-compute` | 4 | 4 GB | 100 GB | MinIO |

모든 VM은 `ubuntu-22.04` image 기반 Cinder volume에서 시작합니다.

- `source_type = "volume"`
- `destination_type = "volume"`
- `delete_on_termination = false`
- Instance에 `prevent_destroy = true`

Instance의 block device, network 및 availability zone은 import된 운영 상태를 보호하기 위해 lifecycle `ignore_changes` 대상에 포함되어 있습니다. 해당 항목을 변경할 때는 실제 리소스와 state를 먼저 대조해야 합니다.

## Security Group

K3s VM은 Terraform으로 import한 OpenStack `default` security group을 사용합니다.

| Direction | Protocol | Port | Source 또는 대상 |
|---|---|---:|---|
| Ingress | TCP | 22, 80, 443 | `0.0.0.0/0` |
| Ingress | TCP | 6443, 10250 | `0.0.0.0/0` |
| Ingress | TCP | 30000-32767 | `0.0.0.0/0` |
| Ingress | UDP | 51820 | `0.0.0.0/0` |
| Ingress | ICMP | All | `0.0.0.0/0` |
| Ingress | All | All | 동일 security group |
| Egress | All | All | IPv4 및 IPv6 |

현재 rule은 기존 운영 상태의 선언을 우선한 것입니다. 접근 범위 축소와 불필요 rule 제거는 별도 보안 강화 작업으로 진행합니다.

## Terraform 파일 구성

| 파일 | 관리 대상 |
|---|---|
| `network.tf` | Network, subnet, subnet route, router |
| `ports.tf` | Fixed-IP port |
| `compute.tf` | Boot volume 및 instance |
| `flavors.tf` | Flavor |
| `secgroup.tf` | Default security group 및 rule |
| `variables.tf` | Provider, network 및 compute 변수 |
| `outputs.tf` | VM IP 및 내부 endpoint |
| `versions.tf` | Provider와 local backend |

## 변경 시 주의사항

- Network, subnet, router 및 volume 교체가 표시되면 apply하지 않고 원인을 확인합니다.
- Fixed IP나 VM 배치 위치 변경은 연결 경로와 운영 서비스에 영향을 줍니다.
- `prevent_destroy` 또는 `ignore_changes`를 변경하기 전 실제 리소스와 state를 비교합니다.
- OpenStack API password, `.tfvars`, state 및 plan 파일은 Git에 commit하지 않습니다.

## 관련 문서

- [Network and VPN](network-vpn.md)
- [K3s Cluster](k3s-cluster.md)
- [Terraform and CI/CD](terraform-cicd.md)
- [Operation Guide](operation-guide.md)
