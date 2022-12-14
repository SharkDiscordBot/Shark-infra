#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  # rootユーザーにしか実行させない
  echo "rootユーザーで実行してください"
  exit 1
fi

CONTAINERD_VERSION=1.6.12
RUNC_VERSION=1.1.4
CNI_VERSION=1.1.1

#!/bin/bash

timedatectl set-timezone Asia/Tokyo

sudo apt update
sudo apt upgrade -y

# swapの無効化
sudo swapoff -a
sudo sed -i "/swap/s/^/#/g" /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "sshの公開鍵を入力してください: "
read PUB_KEY
echo "公開鍵を登録するユーザーを設定してください(rootユーザーは設定しないでください): "
read KEY_USER
echo "sshのポート番号を入力してください: "
read PORT_SSH

# sshディレクトリ作成
sudo -u $KEY_USER mkdir -p /home/$KEY_USER/.ssh

# 公開鍵追記,パーミッション設定

cat <<EOF | sudo -u $KEY_USER tee /home/$KEY_USER/.ssh/authorized_keys
$PUB_KEY
EOF
sudo -u $KEY_USER chmod -R 700 /home/$KEY_USER/.ssh
sudo -u $KEY_USER chmod 600 /home/$KEY_USER/.ssh/authorized_keys

sudo mv /etc/ssh/sshd_config /etc/ssh/sshd_config_backup.$(date '+%Y%m%d')

cat <<EOF | sudo tee /etc/ssh/sshd_config
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Include /etc/ssh/sshd_config.d/*.conf

Protocol 2

Port $PORT_SSH
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
PermitRootLogin no
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile	.ssh/authorized_keys .ssh/authorized_keys2

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
#PasswordAuthentication yes
#PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
ChallengeResponseAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and ChallengeResponseAuthentication to 'no'.
UsePAM no

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /var/run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem sftp	/usr/lib/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server
PasswordAuthentication no
EOF

sudo systemctl restart sshd

echo "sshの設定を変更しました。"

# 関連パッケージのインストール

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl wget

# CRIのインストール

sudo wget https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz

sudo wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

sudo mv containerd.service /etc/systemd/system/containerd.service

systemctl daemon-reload
systemctl enable --now containerd

# runc

sudo wget https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/runc.amd64

sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# cni plugin

sudo wget https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-amd64-v$CNI_VERSION.tgz

sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v$CNI_VERSION.tgz

# リポジトリの追加

sudo mkdir -p /etc/apt/keyrings/
sudo wget https://packages.cloud.google.com/apt/doc/apt-key.gpg
sudo mv apt-key.gpg /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# kustomizeとHelmのインストール
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install helm -y
sudo curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
sudo mv ./kustomize /usr/bin

echo "kubeadmのインストールに成功しました"

function yes_no {
  while true; do
    echo -n "$* [y/n]: "
    read ANS
    case $ANS in
      [Yy]*)
        return 0
        ;;
      [Nn]*)
        return 1
        ;;
      *)
        echo "yまたはnを入力してください"
        ;;
    esac
  done
}

if yes_no "このサーバーをマスターサーバーとして使用しますか？"; then
  echo "このサーバーのローカルIPアドレスを入力してください"
  read MASTER_IP
  echo "マスターサーバーのIP: $MASTER_IP"

  kubeadm init --pod-network-cidr 10.244.0.0/16 --control-plane-endpoint=$MASTER_IP --apiserver-advertise-address=$MASTER_IP

  # cilium setup
  echo "上記の kubeadm joinコマンドをメモしてください20秒後に処理を再開します"
  sleep 20
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  export KUBECONFIG=/etc/kubernetes/admin.conf

  helm repo add cilium https://helm.cilium.io/
  helm install cilium cilium/cilium --version 1.12.4 --namespace kube-system

  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
  CLI_ARCH=amd64
  if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
  sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
  rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

  echo "Workerノードを追加したらエンターキーを押してください :"
  read worker_check

  # 参加処理を少しまつ
  sleep 10
  echo "Ciliumのステータスを取得中です... 30秒程度経過してもステータス処理が表示されない場合podの配置に失敗している可能性があります"
  cilium status --wait

  echo "k8sクラスタの構築処理が終了しました。"
  echo "kubeconfigは /etc/kubernetes/admin.conf  にあります"

else
  echo "マスターサーバーのセットアップ時に表示されたコマンドを入力してください"
  read INIT_CMD
  $INIT_CMD
fi
