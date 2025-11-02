#!/bin/bash

# Função para configurar o Fail2Ban para o SSH
configure_fail2ban_ssh() {
    echo -e "[sshd]\nenabled = true\nport = ssh\nlogpath = %(sshd_log)s\nmaxretry = 3\nbantime = 3600\nfindtime = 600\nbanaction = iptables-multiport" | tee /etc/fail2ban/jail.local > /dev/null
    echo "A reiniciar o Fail2Ban para aplicar a configuração!"
    systemctl restart fail2ban
    echo "Fail2Ban reiniciado com sucesso."
}

# Função para mostrar os IP bloqueados
show_banned_ips() {
    BANNED_IPS=$(fail2ban-client status sshd | grep 'Banned IP list' | sed 's/.*Banned IP list:[[:space:]]*//')
    if [ -z "$BANNED_IPS" ]; then
        echo "Não há IP bloqueados."
    else
        echo "IP bloqueados pelo Fail2Ban:"
        echo "$BANNED_IPS"
    fi
}

# Função para desbloquear um IP
unban_ip() {
    BANNED_IPS=$(fail2ban-client status sshd | grep 'Banned IP list' | sed 's/.*Banned IP list:[[:space:]]*//')

    if [ -z "$BANNED_IPS" ]; then
        echo "Não há IP bloqueados para desbloquear."
        return
    fi

    while true; do
        echo "IP atualmente bloqueados: $BANNED_IPS"
        echo ""
        read -p "Digite o IP que deseja desbloquear: " IP

        if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            if echo "$BANNED_IPS" | grep -qw "$IP"; then
                fail2ban-client set sshd unbanip "$IP"
                echo "IP $IP foi desbloqueado."
                break
            else
                echo "O IP $IP não está bloqueado."
            fi
        else
            echo "Insita um IP válido."
        fi
    done
}

# Função para bloquear um IP
ban_ip() {
    BANNED_IPS=$(fail2ban-client status sshd | grep 'Banned IP list' | sed 's/.*Banned IP list:[[:space:]]*//')

    while true; do
        echo ""
        read -p "Digite o IP que deseja bloquear: " IP

        if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            if echo "$BANNED_IPS" | grep -qw "$IP"; then
                echo "O IP $IP já está bloqueado."
            else
                fail2ban-client set sshd banip "$IP"
                echo "IP $IP foi bloqueado."
            fi
            break
        else
            echo "Insira um IP válido."
        fi
    done
}

# Função para o menu
menu() {
    echo ""
    echo "MENU PRINCIPAL"
    echo "1) Configurar Fail2Ban para SSH"
    echo "2) Mostrar IP bloqueados"
    echo "3) Desbloquear um IP"
    echo "4) Banir um IP"
    echo "5) Sair"
    read -p "Escolha uma opção: " OPTION

    case $OPTION in
        1) configure_fail2ban_ssh ;;
        2) show_banned_ips ;;
        3) unban_ip ;;
        4) ban_ip ;;
        5) exit 0 ;;
        *) echo "Opção inválida." ;;
    esac
}

# Loop para o menu
while true; do
    menu
done
