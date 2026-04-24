# baro-private

## Overview

본 프로젝트는 무인택시 운영 환경을 가정하여 다음 두 계층으로 역할을 분리합니다.

- **Public Cloud**
  - 메인 서비스 운영
  - 배차, 차량 스트리밍, 위치 관리
  - 외부 사용자 접근 및 서비스 이중화

- **Private Cloud**
  - OpenStack 기반 내부 분석/운영 환경
  - 퍼블릭 서비스 데이터 수신 및 저장
  - 일 단위 분석 수행
  - 차량 재배치 정책 및 가중치 생성 후 퍼블릭 전달

본 저장소에서는 그중 **프라이빗 클라우드 영역**의 구축 및 운영 내용을 중점적으로 다룹니다.

---

## Private Cloud Scope

프라이빗 클라우드는 다음 역할을 담당합니다.

- OpenStack 기반 분석용 인프라 제공
- VM 기반 내부 서비스 실행 환경 제공
- K3s 클러스터 구성
- 퍼블릭에서 전달받은 데이터의 저장 및 후처리 기반 마련
- 향후 분석 파이프라인 및 정책 생성 로직 탑재 예정

---

## Current Implementation Status

### Infrastructure
- Ubuntu 24.04 LTS Server 기반 단일 호스트 구축
- KVM 지원 하드웨어에서 OpenStack AIO 구성
- Kolla-Ansible 기반 OpenStack 배포 완료
- Cinder LVM 백엔드 활성화
- Open vSwitch 기반 Neutron provider network 구성 완료

### Network
- WiFi 인터페이스를 통한 외부 접속 및 인터넷 연결 구성
- `br-ex`를 VM 네트워크 게이트웨이로 사용
- NAT 기반 외부 통신 구성
- `int-net (10.10.10.0/24)` 내부 네트워크 구성 완료

### Virtual Machines
- `k3s-master` 생성 완료
- `k3s-worker-1` 생성 완료
- `vpn-gateway` 생성 완료

### Kubernetes
- K3s control-plane / worker 구성 완료
- 클러스터 노드 Ready 상태 확인 완료

---

## Environment Summary

### Hardware
- CPU: 32 cores (KVM supported)
- RAM: 62GB
- Storage: 476GB NVMe SSD

### OS
- Ubuntu 24.04 LTS Server

### Storage Layout
- `/boot/efi` : 1GB
- `/boot` : 2GB
- `ubuntu-vg`
  - `/` : 100GB
  - `/var` : 160GB
  - `swap` : 8GB
- `cinder-volumes`
  - OpenStack LVM backend for Cinder

> Note  
> 현재 문서 기준으로 `cinder-volumes`는 OpenStack VM 디스크용 스토리지로 설명하고 있으나, 실제 인스턴스가 **boot from volume** 방식인지, 혹은 flavor의 root disk를 사용하는 **ephemeral 기반**인지에 따라 저장 경로 해석이 달라질 수 있습니다. 이 부분은 별도 문서에서 명확히 구분할 예정입니다.

---

## Network Topology

### Host Network
- WiFi NIC: `wlxb0386cf00b2f`
- Host IP: `192.168.203.187/22`
- External bridge: `br-ex`
- External gateway for VM network: `10.10.10.1/24`

### VM Network
- Network: `int-net`
- Type: flat / physnet1
- CIDR: `10.10.10.0/24`

### Provisioned Instances
- `k3s-master` : `10.10.10.116`
- `k3s-worker-1` : `10.10.10.126`
- `vpn-gateway` : `10.10.10.177`

### Traffic Flow
- VM → `br-ex` → host WiFi NIC → router → internet
- External PC → WiFi → host SSH

---

## OpenStack Stack

### Deployment
- Kolla-Ansible 21.0.0
- OpenStack release: 2025.2

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

### Disabled / Omitted Services
- HAProxy (single node)
- Heat
- Swift
- Ceilometer
- Central Logging

---

## OpenStack Resources

### Image
- `ubuntu-22.04` (Jammy cloud image, qcow2)

### Flavors
- `k3s-master` : 4 vCPU / 8GB RAM / 40GB disk
- `k3s-worker` : 4 vCPU / 16GB RAM / 60GB disk
- `lightweight` : 2 vCPU / 2GB RAM / 20GB disk

### Security Group (default)
- TCP: 22, 80, 443, 6443, 10250, 30000-32767
- UDP: 51820
- ICMP allowed

---

## K3s Cluster

- `k3s-master` : control-plane / master
- `k3s-worker-1` : worker
- `vpn-gateway` : WireGuard VPN gateway (not joined to K3s)

---

## Quick Commands

### OpenStack CLI
```bash
source ~/kolla-venv/bin/activate
export OS_CLOUD=kolla-admin
```

## List instances
```bash
openstack server list
```
### Access Horizon
```
URL: http://192.168.203.187
ID: admin
```
### Check K3s nodes
```
sudo kubectl get nodes
sudo kubectl get pods -A
```
