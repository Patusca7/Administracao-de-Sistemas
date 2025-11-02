#!/bin/bash

# Verifica se o nfs-utils está instalado
if ! rpm -q nfs-utils > /dev/null; then
    yum install -y nfs-utils
fi

if ! rpm -q rpcbind > /dev/null; then
    yum install -y rpcbind
fi

# Ativa e inicia o serviço NFS e do rpcbind
systemctl enable --now nfs-utils
systemctl enable --now rpcbind

clear 

while true; do
        read -p "Insira o IP do servidor NFS: " SERVER_IP
        if [[ "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            break
        else
            echo " IP inválido"
        fi
done

# Solicita o caminho da partilha no servidor (ex: /script)
while true; do
    read -p "Insira o caminho da partilha no servidor (ex: /script): " REMOTE_PATH
    if [[ "$REMOTE_PATH" == /* ]]; then
        break
    else
        echo "O caminho deve começar com '/'. Tente novamente."
    fi
done

# Solicita o caminho local onde montar a partilha
while true; do
    read -p "Insira o caminho local para montar a partilha (ex: /mnt/nfs): " LOCAL_MOUNT
    if [[ "$LOCAL_MOUNT" == /* ]]; then
        break
    else
        echo "O caminho deve começar com '/'. Tente novamente."
    fi
done

# Cria a diretoria local se não existir
mkdir -p "$LOCAL_MOUNT"

echo -e "mount -t nfs "${SERVER_IP}:${REMOTE_PATH}" "$LOCAL_MOUNT""

# Monta a partilha
mount -t nfs "${SERVER_IP}:${REMOTE_PATH}" "$LOCAL_MOUNT"

# Verifica se o comando teve sucesso
if [ $? -eq 0 ]; then
    echo "Partilha montada com sucesso em $LOCAL_MOUNT"
else
    echo "Erro ao montar a partilha. Verifique o IP e caminho."
    exit 1
fi

# Pergunta se quer tornar o ponto de montagem persistente
read -p "Deseja tornar esta montagem permanente (adicionar ao /etc/fstab)? [s/n]: " RESPOSTA
if [[ "$RESPOSTA" =~ ^[Ss]$ ]]; then
    echo "${SERVER_IP}:${REMOTE_PATH}    ${LOCAL_MOUNT}    nfs    defaults    0 0" >> /etc/fstab
    echo "Entrada adicionada ao /etc/fstab"
fi
