#!/bin/bash

echo " A desativar a firewalld e Selinux"

# Desativa a firewalld
systemctl stop firewalld
systemctl disable firewalld

# Desativa o Selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# Instala os pacotes
echo " A instalar pacotes."
yum install net-tools epel-release httpd bind bind-utils rpcbind samba nfs-utils cifs-utils rsync tar mdadm  iptables-services -y
yum install fail2ban knock* -y


# Ativa os serviços
systemctl enable --now iptables
systemctl enable --now httpd
systemctl enable --now named
systemctl enable --now smb
systemctl enable --now nmb
systemctl enable --now nfs-server
systemctl enable --now rsyncd
systemctl enable --now fail2ban
systemctl enable --now knockd
systemctl enable --now rpcbind

# Limpa as regras existentes
iptables -F

# Permitir conexões estabelecidas e relacionadas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -m comment --comment "Permitir conexões estabelecidas e relacionadas" -j ACCEPT

# Permitir loopback
iptables -A INPUT -i lo -m comment --comment "Permitir loopback" -j ACCEPT

# Permitir ICMP (ping)
iptables -A INPUT -p icmp -m comment --comment "Permitir ICMP (ping)" -j ACCEPT

# Permitir SSH
iptables -A INPUT -p tcp --dport 22 -m comment --comment "Permitir SSH" -j ACCEPT

# Permitir DNS (porta 53 UDP e TCP)
iptables -A INPUT -p udp --dport 53 -m comment --comment "Permitir DNS UDP" -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -m comment --comment "Permitir DNS TCP" -j ACCEPT

#Permitir NFS
iptables -A INPUT -p tcp --dport 111 -m comment --comment "Permitir NFS TDP"  -j ACCEPT
iptables -A INPUT -p udp --dport 111 -m comment --comment "Permitir NFS UDP"  -j ACCEPT
iptables -A INPUT -p tcp --dport 2049 -m comment --comment "Permitir NFS TDP"  -j ACCEPT
iptables -A INPUT -p udp --dport 2049 -m comment --comment "Permitir NFS UDP"  -j ACCEPT
iptables -A INPUT -p tcp --dport 20048 -m comment --comment "Permitir NFS TDP"  -j ACCEPT
iptables -A INPUT -p udp --dport 20048 -m comment --comment "Permitir NFS UDP" -j ACCEPT

# Permitir HTTP
iptables -A INPUT -p tcp --dport 80 -m comment --comment "Permitir HTTP" -j ACCEPT

# Rejeitar o resto
iptables -A INPUT -m comment --comment "Rejeitar tudo o resto" -j REJECT --reject-with icmp-host-prohibited

# Salvar regras
service iptables save


# Salvar regras para persistência
service iptables save

#Perguntar ao utilizador se quer reiniciar
echo -n "É recomendado reiniciar o sistema, pretende reiniciar agora? (y/n): "
read resposta

if [[ "$resposta" == "y" || "$resposta" == "Y" ]]; then
    echo "A reiniciar o sistema..."
    reboot
else
    echo "Configuração concluída. Reinicie manualmente para aplicar as alterações."
fi
