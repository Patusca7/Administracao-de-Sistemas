#!/bin/bash

# Função que cria o backup do sistema
criar_backup_sistema(){
    
    BACKUP_SYSTEM="/backups/sistema"
    DATE_NOW=$(date +%F_%H-%M)

    mkdir -p "$BACKUP_SYSTEM"

    tar -czvf "$BACKUP_SYSTEM/$DATE_NOW.tar.gz" /etc/passwd /etc/shadow /etc/group /etc/gshadow
    echo "Backup dos ficheiros cruciais guardado em: $BACKUP_SYSTEM/$DATE_NOW.tar.gz"
}

# Função que cria o backup da home dos utilizadores
criar_backup_user(){
    SRC="/home"
    BACKUP_USERS="/backups/users"
    DATE_NOW=$(date +%F_%H-%M)

    TARGET="$BACKUP_USERS/$DATE_NOW"

    # Verifica se existe um backup anterior
    LINK_DEST=$(ls -dt "$BACKUP_USERS"/*/ 2>/dev/null | head -n 1)

    mkdir -p "$TARGET"

    # Se existir um backup anterior, usa-o como referência com --link-dest
    if [ -d "$LINK_DEST" ]; then
        rsync -a --delete --link-dest="$LINK_DEST" "$SRC/" "$TARGET"
    else # Faz cópia completa
        rsync -a --delete "$SRC/" "$TARGET"
    fi

    echo "Backup dos utilizadores guardado em: $TARGET"
}

if [[ "$1" == "auto-user-backup" ]]; then
    criar_backup_user
    exit 0
fi

# Definir o dia e horario do backup incremental das home
if ! crontab -l 2>/dev/null | grep -q .; then
    echo "30 8 * * * /scripts/ponto9.sh auto-user-backup >> /var/log/backup_users.log 2>&1" | crontab -
    echo "Backup incremental agendado"
fi


# Mostra o menu principal com as opções
menu() {
    echo "MENU PRINCIPAL"
    echo "1. Backup do sistema (ficheiros críticos)"
    echo "2. Backup dos utilizadores (/home)"
    echo "3. Fazer ambos os backups"
    echo "4. Sair"
    read -p "Escolha a opção: " OPCAO

    case $OPCAO in
        1) criar_backup_sistema;;
        2) criar_backup_user;;
        3) criar_backup_sistema ; criar_backup_user ;;
        4) exit 0;;
        *) echo "Opção inválida";;
    esac
}

while true; do
    menu
done