#!/bin/bash

mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd

# Cria o file system
mkfs.ext4 /dev/md0

# Cria a diretoria
mkdir -p /ponto10_raid

# Monta o RAID na diretoria
mount /dev/md0 /ponto10_raid

# Salva a configuração do RAID para persistência
mdadm --detail --scan >> /etc/mdadm.conf

# Adiciona ao fstab se ainda não existir
if ! grep -q "/dev/md0" /etc/fstab; then
    echo "/dev/md0 /ponto10_raid ext4 defaults,noauto,x-systemd.automount 0 0" >> /etc/fstab
fi

echo "RAID 5 montado em /ponto10_raid"