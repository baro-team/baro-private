# Private Cloud Environment (OpenStack)

## 1. Overview

본 문서는 하이브리드 클라우드 기반 무인택시 운영 관제 시스템 프로젝트에서  
**프라이빗 클라우드 영역(OpenStack)** 의 구축 환경과 현재 구성 상태를 정리한 문서이다.

프라이빗 클라우드는 다음 역할을 담당한다.

- OpenStack 기반 내부 인프라 제공
- 분석/운영용 VM 실행 환경 제공
- K3s 기반 내부 서비스 배포 환경 제공
- 퍼블릭 클라우드에서 전달받은 데이터의 저장 및 후처리 기반 마련
- 향후 일 단위 분석 및 정책 생성 기능 수용

현재 문서는 **프라이빗 클라우드 인프라 구축 상태**를 중심으로 정리하며,  
세부 운영 명령어는 `docs/operation-guide.md` 에 별도로 정리한다.

---

## 2. Server Base Environment

### Hardware

| Item | Spec |
|---|---|
| CPU | 16 cores (KVM supported) |
| RAM | 62GB |
| Storage | 476GB NVMe SSD |

### OS

| Item | Value |
|---|---|
| OS | Ubuntu 24.04 LTS Server |

---

## 3. Storage Layout

현재 호스트는 단일 NVMe 디스크를 사용하며, OS 영역과 OpenStack Cinder 영역을 분리하여 구성하였다.

### Disk Partition Layout

| Partition | Size | Usage |
|---|---:|---|
| `nvme0n1p1` | 1GB | `/boot/efi` |
| `nvme0n1p2` | 2GB | `/boot` |
| `nvme0n1p3` | 273GB | LVM (`ubuntu-vg`) |
| `nvme0n1p4` | 200GB | LVM (`cinder-volumes`) |

### LVM Layout

#### `ubuntu-vg`

| Logical Volume | Size | Mount |
|---|---:|---|
| `ubuntu-lv` | 100GB | `/` |
| `var-lv` | 160GB | `/var` |
| `swap-lv` | 8GB | `swap` |

#### `cinder-volumes`

| Volume Group | Purpose |
|---|---|
| `cinder-volumes` | OpenStack Cinder LVM backend |

> 참고  
> `cinder-volumes`는 Cinder 백엔드용 LVM 영역이다.  
> 실제 인스턴스 디스크가 Nova ephemeral 기반인지, Cinder boot-from-volume 기반인지는  
> 별도 OpenStack 리소스 확인을 통해 구분해야 한다.

---

## 4. Network Topology

현재 환경은 **WiFi 인터페이스 기반 단일 노드 OpenStack** 환경이며,  
VM 네트워크의 외부 통신을 위해 `br-ex`와 NAT 규칙을 사용한다.

### Host Network

| Interface | Role | Address / Description |
|---|---|---|
| `wlxb0386cf00b2f` | Host WiFi NIC | `192.168.203.187/22` |
| `dummy0` | Neutron external interface | OVS `br-ex` 연결용 |
| `br-ex` | VM external bridge / gateway | `10.10.10.1/24` |

### VM Network

| Network | Type | CIDR | Description |
|---|---|---|---|
| `int-net` | flat (`physnet1`) | `10.10.10.0/24` | OpenStack VM internal network |

### Provisioned VM IPs

| VM | IP | Role |
|---|---|---|
| `k3s-master` | `10.10.10.116` | K3s control-plane |
| `k3s-worker-1` | `10.10.10.126` | K3s worker |
| `vpn-gateway` | `10.10.10.177` | WireGuard VPN gateway |

### Traffic Flow

#### VM outbound traffic

```text
VM (10.10.10.X)
  → br-ex (10.10.10.1, NAT)
    → wlxb0386cf00b2f (192.168.203.187)
      → WiFi router
        → Internet
```

#### Host inbound SSH

```text
External PC
  → WiFi
    → 192.168.203.187:22
      → OpenStack host SSH
```

### NAT Rules

```bash
POSTROUTING -s 10.10.10.0/24 -o wlxb0386cf00b2f -j MASQUERADE
FORWARD     -i br-ex -o wlxb0386cf00b2f -j ACCEPT
FORWARD     -i wlxb0386cf00b2f -o br-ex -m state --state RELATED,ESTABLISHED -j ACCEPT
```

---

## 5. OpenStack Deployment

### Deployment Method

| Item | Value |
|---|---|
| Deployment Tool | Kolla-Ansible 21.0.0 |
| OpenStack Release | 2025.2 |
| Base Distro | Ubuntu |

### `globals.yml` Core Settings

```yaml
openstack_release: "2025.2"
kolla_base_distro: "ubuntu"
network_interface: "wlxb0386cf00b2f"
neutron_external_interface: "dummy0"
kolla_internal_vip_address: "192.168.203.187"
enable_haproxy: "no"
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
cinder_volume_group: "cinder-volumes"
neutron_plugin_agent: "openvswitch"
enable_neutron_provider_networks: "yes"
neutron_tenant_network_types: "vlan"
nova_compute_virt_type: "kvm"
```

### Neutron Custom Configuration

커스텀 설정 경로:

- `/etc/kolla/config/neutron/`

구성 목적:

- `type_drivers: flat,vlan`
- `tenant_network_types: vlan`
- `tunnel_types` 비활성화

### Why VXLAN was disabled

WiFi 환경에서는 Open vSwitch agent가 VXLAN용 `local_ip`를 안정적으로 찾지 못하는 문제가 발생할 수 있었다.  
본 환경은 단일 노드 기반 실습 환경이며, overlay 네트워크(VXLAN)보다 provider network 기반 구성이 더 단순하고 안정적이므로 다음과 같이 구성하였다.

- ML2 `type_drivers`를 `flat,vlan`으로 설정
- `tenant_network_types`를 `vlan`으로 설정
- `openvswitch_agent.ini`에서 `tunnel_types`를 비움
- 실제 VM 네트워크는 provider flat network 기반으로 사용

이를 통해 WiFi 기반 단일 노드 환경에서도 VM 통신 및 외부 NAT 구성이 가능하도록 하였다.

---

## 6. Enabled / Disabled Services

### Enabled Services

- Keystone
- Nova
- Neutron
- Glance
- Cinder
- Horizon
- MariaDB
- RabbitMQ
- Memcached

### Disabled or Omitted Services

- HAProxy
- Heat
- Swift
- Ceilometer
- Central Logging

### Notes

- HAProxy는 단일 노드 환경이므로 비활성화하였다.
- Heat, Swift, Ceilometer, Central Logging은 현재 프로젝트 범위 및 자원 절약 목적상 제외하였다.

---

## 7. OpenStack Resources

### Image

| Name | Description |
|---|---|
| `ubuntu-22.04` | Jammy cloud image (`qcow2`) |

### Flavor

| Flavor | vCPU | RAM | Disk |
|---|---:|---:|---:|
| `k3s-master` | 4 | 8GB | 40GB |
| `k3s-worker` | 4 | 16GB | 60GB |
| `lightweight` | 2 | 2GB | 20GB |

### Security Group (`default`)

#### TCP
- 22
- 80
- 443
- 6443
- 10250
- 30000-32767

#### UDP
- 51820

#### Other
- ICMP allowed

### Keypair

| Name | Type |
|---|---|
| `mykey` | RSA-4096 |

---

## 8. K3s Cluster Status

현재 OpenStack VM 위에 K3s 클러스터를 구성하였다.

| Node | IP | Role | Status |
|---|---|---|---|
| `k3s-master` | `10.10.10.116` | control-plane / master | Ready |
| `k3s-worker-1` | `10.10.10.126` | worker | Ready |
| `vpn-gateway` | `10.10.10.177` | WireGuard VPN gateway | K3s 미설치 |

### Purpose

- `k3s-master`: 클러스터 control-plane 및 관리 노드
- `k3s-worker-1`: 워크로드 실행 노드
- `vpn-gateway`: 외부/내부 네트워크 연계를 위한 VPN 게이트웨이 역할

---

## 9. Current Implementation Status

### Completed

- OpenStack AIO 환경 구축 완료
- Kolla-Ansible 배포 완료
- Cinder LVM backend 연결 완료
- OVS 기반 provider network 구성 완료
- WiFi 기반 NAT 외부 통신 구성 완료
- VM 생성 완료
- K3s master / worker 클러스터 구성 완료
- VPN gateway VM 생성 완료

### In Progress

- 퍼블릭 → 프라이빗 데이터 전송 방식 정의
- 분석용 저장 구조 설계
- 일 단위 분석 파이프라인 설계
- 정책 결과 포맷 설계

### Planned

- 퍼블릭 데이터 수신 API 또는 배치 수신 구조 구현
- 분석 결과 저장 및 버전 관리
- 퍼블릭 반영용 정책 전달 인터페이스 정의
- 내부 운영 대시보드 또는 조회 기능 설계

---

## 10. Recommended Validation Commands

현재 문서의 일부 항목은 실제 OpenStack 리소스 상태를 추가 확인하면 더 정확하게 유지할 수 있다.

### Network object validation

```bash
openstack network list
openstack network show int-net
openstack subnet list
openstack port list --server k3s-master
```

확인 포인트:
- `int-net`의 실제 provider network 속성
- subnet 연결 상태
- VM 포트 상태

### Instance disk / volume validation

```bash
openstack server show k3s-master
openstack server show k3s-worker-1
openstack volume list
```

확인 포인트:
- `volumes_attached` 여부
- Nova ephemeral 기반인지, Cinder volume 기반인지

### Hypervisor resource validation

```bash
openstack hypervisor list
openstack hypervisor stats show
free -h
df -h / /var
sudo vgs
```

확인 포인트:
- CPU / RAM / local storage 상태
- 호스트 파일시스템 여유 공간
- Cinder LVM backend 여유 공간

---

## 11. Related Documents

- `docs/operation-guide.md`
- `docs/troubleshooting.md`
- `docs/network-topology.md`
- `docs/progress-log.md`

---

## 12. Notes

- 본 문서는 팀 내부 협업용 private repository 기준으로 작성한다.
- 실제 비밀번호, 개인 키, 민감한 토큰 등은 저장소에 포함하지 않는다.
- 설정값 변경 후에는 반드시 운영 문서의 점검 절차에 따라 상태를 확인한다.
