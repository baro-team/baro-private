# Operation Guide

## 1. Overview

본 문서는 프라이빗 클라우드(OpenStack) 운영에 필요한 주요 명령어와 점검 절차를 정리한 운영 가이드이다.

목적은 다음과 같다.

- OpenStack CLI 환경 진입
- Horizon 접속 정보 확인
- VM 상태 및 접속 방법 정리
- K3s 클러스터 점검
- OpenStack 설정 변경 후 재적용 절차 정리
- 재부팅 이후 필수 점검 순서 정리

> 참고  
> 본 문서는 실제 운영용 치트시트 성격으로 유지하며,  
> 구조 설명은 `docs/openstack-private-cloud.md` 에서 관리한다.

---

## 2. OpenStack CLI Initialization

OpenStack CLI 사용 전 아래 환경을 활성화한다.

```bash
source ~/kolla-venv/bin/activate
export OS_CLOUD=kolla-admin
```

### Quick check

```bash
openstack token issue
openstack server list
```

---

## 3. Horizon Dashboard Access

### Access Info

- URL: `http://192.168.203.187`
- ID: `admin`

### Password lookup

```bash
grep keystone_admin_password /etc/kolla/passwords.yml
```

> 주의  
> 실제 비밀번호 값은 문서에 직접 기록하지 않는다.

---

## 4. Basic OpenStack Status Commands

### List instances

```bash
openstack server list
```

### Show instance details

```bash
openstack server show k3s-master
openstack server show k3s-worker-1
openstack server show vpn-gateway
```

### List images

```bash
openstack image list
```

### List flavors

```bash
openstack flavor list
```

### List networks

```bash
openstack network list
openstack subnet list
```

### Check security group rules

```bash
openstack security group rule list default
```

### Check hypervisor resources

```bash
openstack hypervisor list
openstack hypervisor stats show
```

---

## 5. VM SSH Access

현재 VM은 내부 네트워크에 존재하므로, DHCP namespace를 통해 SSH 접속한다.

### Get DHCP namespace dynamically

```bash
openstack network show int-net -f value -c id
```

### SSH to `k3s-master`

```bash
sudo ip netns exec qdhcp-$(openstack network show int-net -f value -c id) \
    ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.116
```

### SSH to `k3s-worker-1`

```bash
sudo ip netns exec qdhcp-$(openstack network show int-net -f value -c id) \
    ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.126
```

### SSH to `vpn-gateway`

```bash
sudo ip netns exec qdhcp-$(openstack network show int-net -f value -c id) \
    ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.177
```

### Optional: save network ID to variable

```bash
NET_ID=$(openstack network show int-net -f value -c id)
sudo ip netns exec qdhcp-$NET_ID ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.116
```

---

## 6. K3s Cluster Operations

아래 명령은 `k3s-master` VM 내부에서 실행한다.

### Check nodes

```bash
sudo kubectl get nodes
```

### Check all pods

```bash
sudo kubectl get pods -A
```

### Check node details

```bash
sudo kubectl get nodes -o wide
```

### Check cluster info

```bash
sudo kubectl cluster-info
```

### Check join token

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

---

## 7. OpenStack Configuration Change Procedure

Kolla-Ansible 설정 변경 후 재적용이 필요할 때 사용한다.

### Step 1. Activate environment

```bash
source ~/kolla-venv/bin/activate
```

### Step 2. Edit configuration

수정 대상 예시:

- `/etc/kolla/globals.yml`
- `/etc/kolla/config/neutron/`

### Step 3. Reconfigure

```bash
kolla-ansible reconfigure -i ~/all-in-one
```

### Step 4. Verify service status

```bash
sudo docker ps
openstack service list
openstack network list
openstack server list
```

> 참고  
> 설정 변경 범위가 크면 Neutron / Nova / OVS 관련 상태를 추가로 확인하는 것이 좋다.

---

## 8. Post-Reboot Checklist

호스트 재부팅 이후에는 아래 순서로 점검한다.

### 1) Check WiFi IP

```bash
ip addr show wlxb0386cf00b2f
```

확인 포인트:
- 호스트 WiFi 인터페이스에 정상 IP가 할당되었는지

### 2) Check Docker containers

```bash
sudo docker ps | wc -l
sudo docker ps
```

확인 포인트:
- 주요 OpenStack 컨테이너가 정상 실행 중인지

### 3) Check NAT rules

```bash
sudo iptables -t nat -L POSTROUTING
sudo iptables -L FORWARD
```

확인 포인트:
- MASQUERADE 규칙 유지 여부
- FORWARD 허용 규칙 유지 여부

### 4) Check `br-ex` gateway

```bash
ip addr show br-ex
```

확인 포인트:
- `br-ex`에 `10.10.10.1/24`가 정상 부여되어 있는지

### 5) Check OpenStack instance status

```bash
source ~/kolla-venv/bin/activate
export OS_CLOUD=kolla-admin
openstack server list
```

확인 포인트:
- 인스턴스 상태가 `ACTIVE`인지

---

## 9. Host Network / OVS / NAT Verification

네트워크 이슈가 있을 때 아래 명령으로 점검한다.

### Host interfaces

```bash
ip addr show wlxb0386cf00b2f
ip addr show dummy0
ip addr show br-ex
```

### Routing table

```bash
ip route
```

### OVS topology

```bash
sudo ovs-vsctl show
```

### NAT / forwarding rules

```bash
sudo iptables -t nat -S
sudo iptables -S FORWARD
```

---

## 10. Storage / Resource Verification

호스트 자원 및 스토리지 상태를 점검할 때 사용한다.

### Filesystem usage

```bash
df -h /
df -h /var
```

### Memory usage

```bash
free -h
vmstat 1
```

### CPU info

```bash
lscpu
uptime
```

### LVM status

```bash
sudo pvs
sudo vgs
sudo lvs
```

### Interpretation notes

- `/` 와 `/var` 는 실제 파일시스템 여유 공간 확인용
- `ubuntu-vg` 는 OS 영역용 LVM
- `cinder-volumes` 는 Cinder LVM backend
- thin pool 사용 여부 및 실제 인스턴스 디스크 방식은 OpenStack 리소스 상태와 함께 해석해야 함

---

## 11. OpenStack Resource Validation

현재 리소스 상태를 문서와 맞춰보기 위해 아래 명령을 사용할 수 있다.

### Network validation

```bash
openstack network list
openstack network show int-net
openstack subnet list
```

### Port validation

```bash
openstack port list --server k3s-master
openstack port list --server k3s-worker-1
openstack port list --server vpn-gateway
```

### Volume validation

```bash
openstack volume list
```

### Instance-volume relation

```bash
openstack server show k3s-master
openstack server show k3s-worker-1
```

확인 포인트:
- `volumes_attached`
- `addresses`
- `flavor`
- `status`

---

## 12. Recommended Troubleshooting Flow

문제가 발생했을 때 아래 순서로 확인하는 것을 권장한다.

### Case 1. Horizon 접속 불가
1. 호스트 IP 확인
2. Docker 컨테이너 상태 확인
3. 관련 서비스 포트 확인
4. `openstack service list` 확인

### Case 2. VM 외부 통신 불가
1. `br-ex` IP 확인
2. NAT 규칙 확인
3. OVS 연결 상태 확인
4. VM 내부 default route 및 DNS 확인

### Case 3. VM SSH 접속 불가
1. `openstack server list` 로 상태 확인
2. DHCP namespace 이름 확인
3. 보안 그룹 규칙 확인
4. VM IP 재확인

### Case 4. K3s 노드 비정상
1. `kubectl get nodes`
2. `kubectl get pods -A`
3. master / worker VM 상태 확인
4. VM 리소스 사용량 확인

---

## 13. Useful Paths

| Path | Purpose |
|---|---|
| `~/kolla-venv/` | Kolla-Ansible virtualenv |
| `/etc/kolla/globals.yml` | Kolla 주요 설정 |
| `/etc/kolla/config/neutron/` | Neutron custom config |
| `~/all-in-one` | Kolla inventory |
| `/etc/kolla/passwords.yml` | OpenStack passwords |
| `/var/lib/rancher/k3s/` | K3s 관련 데이터 |

---

## 14. Notes

- 운영 명령 실행 전에는 가능한 한 `source ~/kolla-venv/bin/activate` 와 `export OS_CLOUD=kolla-admin` 를 먼저 적용한다.
- 비밀번호, private key, 민감한 토큰은 문서에 직접 기록하지 않는다.
- 설정 변경 후에는 반드시 재적용 및 상태 확인 절차를 수행한다.
