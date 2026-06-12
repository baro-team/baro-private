# Operation Guide

## 문서 목적

이 문서는 Baro Private Cloud의 일상 점검, 장애 확인 및 Terraform 변경 절차를 정리한 운영 가이드입니다.

구조와 관리 범위는 다음 문서를 참고합니다.

- [OpenStack Private Cloud](openstack-private-cloud.md)
- [Network and VPN](network-vpn.md)
- [K3s Cluster](k3s-cluster.md)
- [Backup and Recovery](backup-recovery.md)
- [Terraform and CI/CD](terraform-cicd.md)

Password, token, private key 및 kubeconfig 내용은 이 문서에 기록하지 않습니다.

## 운영 환경

| 구분 | 대상 |
|---|---|
| 메인 서버 | `openstack-aio` |
| 보조 compute 서버 | `openstack-compute` |
| OpenStack VM | `k3s-master`, `k3s-worker-1`, `k3s-worker-2`, `harbor`, `backup` |
| Terraform 디렉터리 | `terraform/openstack`, `terraform/k3s` |
| OpenStack state | `/home/baro/terraform-state/openstack/terraform.tfstate` |
| K3s state | `/home/baro/terraform-state/k3s/terraform.tfstate` |

별도 설명이 없다면 OpenStack, host network, VPN 및 Terraform 명령은 `openstack-aio`에서 실행합니다.

## 빠른 상태 점검

장애 여부를 빠르게 확인할 때 다음 순서로 점검합니다.

```bash
sudo docker ps
openstack server list
openstack network list
sudo ipsec statusall
ip addr show br-ex
ip route
```

K3s 상태는 `k3s-master`에 접속한 후 확인합니다.

```bash
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
```

확인 기준:

- 주요 OpenStack container가 실행 중인지
- VM 5대가 `ACTIVE`인지
- K3s node 3대가 `Ready`인지
- 주요 Pod가 `Running` 또는 정상 완료 상태인지
- 필요한 VPN tunnel이 `ESTABLISHED`인지
- `br-ex`에 gateway IP가 있고 필요한 route가 존재하는지

## OpenStack CLI

OpenStack CLI 환경을 활성화합니다.

```bash
source ~/kolla-venv/bin/activate
export OS_CLOUD=kolla-admin
openstack server list
```

### 주요 리소스 확인

```bash
openstack server list
openstack network list
openstack subnet list
openstack router list
openstack port list
openstack volume list
openstack flavor list
openstack hypervisor list
openstack hypervisor stats show
```

### VM 상세 확인

```bash
openstack server show k3s-master
openstack server show k3s-worker-1
openstack server show k3s-worker-2
openstack server show harbor
openstack server show backup
```

### Security group 확인

```bash
openstack security group list
openstack security group rule list default
```

## VM 접근

메인 서버에서 fixed IP를 사용해 VM에 SSH로 접근합니다.

```bash
ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.170
ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.165
ssh -i ~/.ssh/id_rsa ubuntu@10.10.10.195
ssh -i ~/.ssh/id_rsa ubuntu@10.10.20.4
ssh -i ~/.ssh/id_rsa ubuntu@10.10.20.5
```

접속이 되지 않으면 VM 상태, fixed IP port, security group, `br-ex` 및 `vxlan-net` route를 순서대로 확인합니다.

## K3s 운영

K3s 명령은 `k3s-master`에서 실행합니다.

### Cluster 상태

```bash
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
sudo kubectl get svc -A
sudo kubectl get pvc -A
sudo kubectl get events -A --sort-by=.lastTimestamp
```

### 주요 namespace 점검

```bash
sudo kubectl get all -n monitoring
sudo kubectl get all -n database
sudo kubectl get all -n airflow
sudo kubectl get cronjob -A
```

### Node label 점검

```bash
sudo kubectl get nodes --show-labels
```

`k3s-master`에는 모니터링 workload 배치를 위한 label이 있어야 하며, TimescaleDB와 Airflow는 Helm values에 지정된 hostname으로 배치됩니다.

### 민감정보 주의

K3s join token, Secret 내용 및 kubeconfig 원문은 terminal log, issue 또는 문서에 남기지 않습니다. 확인이 꼭 필요할 때도 출력 결과가 기록되지 않는 안전한 환경에서만 수행합니다.

## 서비스 점검

### NodePort

```bash
sudo kubectl get svc -A -o wide
```

주요 고정 NodePort:

| 서비스 | NodePort |
|---|---:|
| Grafana | `30300` |
| Prometheus | `30900` |
| Airflow | `30800` |

TimescaleDB NodePort는 chart 제약으로 자동 할당됩니다. 재설치 후 번호가 바뀌면 메인 서버 DNAT rule도 함께 갱신해야 합니다.

### Harbor 및 MinIO

```bash
curl -I http://10.10.20.4
curl -I http://10.10.20.5:9001
```

서비스 응답이 없으면 VM 상태, container 상태, `internal-router`, host route를 확인합니다.

## Host Network 및 DNAT

### Interface와 route

```bash
ip addr show br-ex
ip route
sudo ovs-vsctl show
```

필수 확인 항목:

- `br-ex`가 `UP`인지
- `br-ex`에 `10.10.10.1/24`가 할당되어 있는지
- `10.10.20.0/24 via 10.10.10.2 dev br-ex` route가 존재하는지

### iptables

```bash
sudo iptables -t nat -S
sudo iptables -S FORWARD
```

PostgreSQL `5432` DNAT에는 메인 서버 목적지 조건이 있어야 합니다. 이 조건이 없으면 AWS RDS 트래픽이 TimescaleDB로 잘못 전달될 수 있습니다.

### Host network 복구

재부팅 후 `br-ex`, route 또는 DNAT rule이 복구되지 않았다면 관련 systemd unit과 script 상태를 확인합니다.

```bash
systemctl --failed
systemctl list-units --type=service | grep -E "br-ex|network"
journalctl -b -p warning
```

Host script를 수정하거나 직접 실행하기 전에는 현재 iptables와 route를 기록하고 영향 범위를 확인합니다.

## VPN 점검

### Tunnel 상태

```bash
sudo ipsec statusall
ip link show type vti
```

### AWS route 확인

```bash
ip route show table 220
ip route show dev vti300
ip route show dev vti400
ip route get 10.20.11.63
```

AWS 목적지 route는 Wi-Fi interface가 아니라 올바른 VTI interface를 사용해야 합니다.

### 연결 확인

```bash
nc -zv 10.20.11.63 5432 -w 5
nc -zv 10.20.10.253 9092 -w 5
```

연결에 실패하면 다음 순서로 확인합니다.

1. 필요한 tunnel이 `ESTABLISHED`인지 확인
2. 목적지 CIDR의 VTI route 확인
3. `ip route get`으로 실제 선택 route 확인
4. table 220에 충돌하는 policy route가 있는지 확인
5. AWS route table 및 security group 확인

## Terraform 운영

### 변경 전

```bash
git status
git pull --ff-only
```

현재 작업 중인 변경이 없는지 확인하고 원격 `main`과 동기화합니다.

### OpenStack

```bash
cd terraform/openstack
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

### K3s Helm release

```bash
cd terraform/k3s
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Plan 검토 시 다음 변경은 특히 주의합니다.

- VM, Cinder volume 또는 network의 교체 및 삭제
- Fixed IP 변경
- Subnet 또는 router 재생성
- Helm release 삭제 후 재설치
- TimescaleDB NodePort 및 local-path PVC 영향

예상하지 않은 변경이 있으면 apply하지 않고 코드, state 및 실제 리소스를 먼저 대조합니다.

### GitHub Actions

Terraform 경로 또는 workflow 변경이 `main`에 push되면 관련 Terraform job이 실행됩니다.
`main` 대상 pull request에서는 승인 정책에 따라 plan 단계까지 실행되며, 실제 apply는 `main` push에서만 실행됩니다.

```text
변경 감지
  -> terraform fmt -check
  -> terraform init
  -> terraform validate
  -> terraform plan
  -> main push에서 terraform apply
```

Self-hosted runner는 운영 인프라에 접근할 수 있으므로 workflow 변경도 인프라 변경과 동일하게 검토합니다.

## Backup 점검

TimescaleDB와 K3s SQLite backup은 `k3s-master`에서 확인합니다.

### TimescaleDB backup

```bash
sudo kubectl get cronjob -n database
sudo kubectl get job -n database
sudo kubectl logs -n database job/<최근-job-name>
```

### K3s SQLite backup

```bash
crontab -l
ls -lh /var/lib/rancher/k3s/server/db/state.db
```

### Terraform state backup

Terraform state는 `openstack-aio`에서 확인합니다.

```bash
ls -lh /home/baro/terraform-state/openstack/terraform.tfstate
ls -lh /home/baro/terraform-state/k3s/terraform.tfstate
```

MinIO에서 최신 TimescaleDB, K3s SQLite 및 Terraform state backup이 생성되었는지 정기적으로 확인합니다. 복원 절차는 운영 장애가 없는 시점에 별도 환경에서 주기적으로 검증해야 합니다.

## 재부팅 후 점검

메인 서버 재부팅 후 다음 순서로 확인합니다.

1. Docker 및 OpenStack container 상태
2. `br-ex` 상태와 gateway IP
3. Host route 및 iptables DNAT
4. OpenStack VM 상태
5. K3s node 및 Pod 상태
6. StrongSwan tunnel과 VTI route
7. 외부 서비스 접근
8. Backup 작업 상태

```bash
sudo docker ps
ip addr show br-ex
ip route
sudo iptables -t nat -S
openstack server list
sudo ipsec statusall
```

이후 `k3s-master`에 접속해 cluster 상태를 확인합니다.

```bash
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
```

## 장애별 점검 순서

### OpenStack VM이 보이지 않음

1. OpenStack container 상태 확인
2. `openstack service list` 확인
3. Hypervisor 상태 확인
4. Nova 및 Neutron 관련 log 확인

### VM에서 외부 통신 불가

1. VM default route와 DNS 확인
2. Security group 확인
3. `br-ex` 상태 확인
4. Host forwarding 및 NAT 확인

### Harbor 또는 MinIO 접근 불가

1. VM과 service container 상태 확인
2. `internal-router` 상태 확인
3. `10.10.20.0/24` host route 확인
4. DNAT rule 확인

### K3s 서비스 접근 불가

1. Node와 Pod 상태 확인
2. Service 및 NodePort 확인
3. 대상 node의 listener 확인
4. 메인 서버 DNAT rule 확인

### AWS RDS 또는 Kafka 접근 불가

1. StrongSwan tunnel 상태 확인
2. VTI interface와 route 확인
3. Table 220 충돌 확인
4. AWS route table 및 security group 확인

## 주요 경로

| 경로 | 용도 |
|---|---|
| `~/kolla-venv/` | Kolla-Ansible virtual environment |
| `/etc/kolla/globals.yml` | Kolla 주요 설정 |
| `/etc/kolla/config/` | OpenStack service custom 설정 |
| `/etc/kolla/passwords.yml` | OpenStack credential 저장 파일 |
| `/etc/rancher/k3s/` | K3s 설정 |
| `/var/lib/rancher/k3s/` | K3s runtime 및 SQLite DB |
| `/home/baro/terraform-state/` | Terraform local backend |

Credential 저장 파일은 권한을 제한하고 내용을 문서, Git 또는 CI log에 출력하지 않습니다.
