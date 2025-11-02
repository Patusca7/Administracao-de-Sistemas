#!/bin/bash

NAMED_CONF="/etc/named.conf"
ZONES_DIR="/var/named"
HTTPD_CONF="/etc/httpd/conf/httpd.conf"
DOMINIOS_DIR="/dominios"

# Cria a zona master e o VirtualHost
criar_zona_master() {

    # Atualiza named.conf para permitir ligações externas
    sed -i 's|listen-on port 53 { 127.0.0.1; };|listen-on port 53 { 127.0.0.1; any; };|' "$NAMED_CONF"
    sed -i 's|allow-query     { localhost; };|allow-query     { localhost; any; };|' "$NAMED_CONF"

    read -p "Introduz o nome do domínio pretendido: " DOMINIO

    # Verifica se a zona já existe
    if grep -q -E "zone\s+\"$DOMINIO\"\s+IN\s+\{" "$NAMED_CONF"; then
        echo "A zona \"$DOMINIO\" já existe. Não é possível criar novamente."
        return
    fi

    # Valida o IP introduzido pelo utilizador
    while true; do
        read -p "Qual o IP para o registo IN A do dominio pedido: " IP
        if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            break
        else
            echo " IP inválido"
        fi
    done

    ZONE_FILE="$ZONES_DIR/${DOMINIO}.hosts"

    # Adiciona a nova zona ao ficheiro de configuração do named.conf
    echo -e "zone \"$DOMINIO\" IN {\n\ttype master;\n\tfile \"$ZONE_FILE\";\n};" >> "$NAMED_CONF"
    
    # Cria o ficheiro da zona DNS
    echo -e "\$TTL 38400\n@ IN SOA projeto.as.pt. mail.$DOMINIO. (\n\t\t\t$(date +%Y%m%d%H) ; serial\n\t\t\t10800 ; refresh\n\t\t\t3600 ; retry\n\t\t\t604800 ; expire\n\t\t\t38400 ; minimum\n\t\t\t)\n\tIN NS projeto.as.pt.\n\tIN A $IP\nwww IN A $IP" > "$ZONE_FILE"

    echo "Zona master criada em $ZONE_FILE"
    systemctl restart named

    # Cria a diretoria com página inicial do VirtualHost
    mkdir -p "$DOMINIOS_DIR/$DOMINIO"
    echo "<html><head><title>Bem-vindo</title></head><body><h1>Bem-vindo ao domínio $DOMINIO!</h1></body></html>" > "$DOMINIOS_DIR/$DOMINIO/index.html"
    chmod 755 "$DOMINIOS_DIR" -R

    # Garante o Apache na porta 80
    grep -q "Listen 80" "$HTTPD_CONF" || echo "Listen 80" >> "$HTTPD_CONF"

    # Adiciona configuração do VirtualHost no Apache
    echo -e "\n<VirtualHost *:80>\n\tDocumentRoot \"$DOMINIOS_DIR/$DOMINIO\"\n\tServerName www.$DOMINIO\n\tServerAlias $DOMINIO\n\t<Directory \"$DOMINIOS_DIR/$DOMINIO\">\n\t\tOptions Indexes FollowSymLinks\n\t\tAllowOverride All\n\t\tOrder allow,deny\n\t\tAllow from all\n\t\tRequire method GET POST OPTIONS\n\t</Directory>\n</VirtualHost>" >> "$HTTPD_CONF"
    systemctl restart httpd

    # Pergunta se o utilizador quer adicionar registos A ou MX agora
    read -p "Pretende adicionar registos A ou MX agora? (s/n): " RESPOSTA
    [[ "$RESPOSTA" =~ ^[Ss]$ ]] && adicionar_registos "$DOMINIO"
}

# Adiciona os registos A ou MX ao dominio
adicionar_registos() {
    local DOMINIO="$1"
    local ZONE_FILE="$ZONES_DIR/${DOMINIO}.hosts"

    # Verifica se a zona existe
    if [ ! -f "$ZONE_FILE" ]; then
        echo "O domínio '$DOMINIO' não existe. Crie a zona master primeiro."
        return
    fi

    # Permite adicionar vários registos até o utilizador parar
    while true; do
        read -p "Tipo de registo a adicionar (A ou MX): " TIPO
        TIPO=$(echo "$TIPO" | tr 'a-z' 'A-Z')

        if [[ "$TIPO" != "A" && "$TIPO" != "MX" ]]; then
            echo "Tipo de registo inválido. Apenas A ou MX são suportados."
            continue
        fi

        if [[ "$TIPO" == "A" ]]; then
            read -p "Nome do subdomínio (ftp, webmail, mail): " NOME
            while true; do
                read -p "Qual o IP para o registo A do dominio pedido: " VALOR
                if [[ "$VALOR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                    break
                else
                    echo " IP inválido"
                fi
            done

            # Verifica se o subdomínio já existe no ficheiro
            if grep -q "^$NOME IN A" "$ZONE_FILE"; then
                # Substitui o IP do registo existente
                sed -i "s/^$NOME IN A .*/$NOME IN A $VALOR/" "$ZONE_FILE"
                echo "Registo A existente atualizado: $NOME -> $VALOR"
            else
                # Adiciona um novo registo A
                echo -e "$NOME IN A $VALOR" >> "$ZONE_FILE"
                echo "Registo A adicionado: $NOME -> $VALOR"
            fi

        elif [[ "$TIPO" == "MX" ]]; then
            read -p "Qual o hostname do servidor de mail: " VALOR
            read -p "Prioridade do registo MX: " PRIORIDADE
            echo -e "\tIN MX $PRIORIDADE $VALOR" >> "$ZONE_FILE"
            echo "Registo MX adicionado: @ MX $PRIORIDADE -> $VALOR"
        fi

        read -p "Pretende adicionar outro registo? (s/n): " CONTINUAR
        [[ "$CONTINUAR" =~ ^[Nn]$ ]] && break
    done

    echo "A reiniciar o serviço named!"
    systemctl restart named
    echo "Serviço named reiniciado!"
}

# Cria as zonas reverse para um domínio
criar_zona_reverse() {
    read -p "Qual o domínio para criar a zona reverse: " DOMINIO
    ZONE_FILE="$ZONES_DIR/${DOMINIO}.hosts"

    # Verifica se a zona master existe
    if [ ! -f "$ZONE_FILE" ]; then
        echo "A zona master para $DOMINIO não existe. Crie-a primeiro."
        return
    fi

    # Extrai todos os IPs dos registos A
    IPS=$(grep "IN A" "$ZONE_FILE" | awk '{print $NF}')

    # Cria ficheiros e registos PTR para cada IP
    for IP in $(grep "IN A" "$ZONE_FILE" | awk '{print $NF}' | sort -u); do
        IFS='.' read -r o1 o2 o3 o4 <<< "$IP"
        REVERSE_FILE="$ZONES_DIR/$o3.$o2.$o1.in-addr.arpa.hosts"
    
        # Cria o ficheiro da zona reverse se não existir
        if [ ! -f "$REVERSE_FILE" ]; then
            echo -e "zone \"$o3.$o2.$o1.in-addr.arpa\" IN {\n\t type master;\n\t file \"$REVERSE_FILE\";\n};" >> "$NAMED_CONF"
            echo -e "\$TTL 38400\n@ IN SOA projeto.as.pt. mail.$DOMINIO. (\n\t$(date +%Y%m%d%H) ; serial\n\t10800 ; refresh\n\t3600 ; retry\n\t604800 ; expire\n\t38400 ; minimum\n\t)\n\tIN NS projeto.as.pt." > "$REVERSE_FILE"
        fi
    
        NAME=$(grep "$IP" "$ZONE_FILE" | grep -v '^\s*IN' | awk '{print $1}')
        echo "$o4 IN PTR $NAME.$DOMINIO." >> "$REVERSE_FILE"
    done

    systemctl restart named
    echo "Zonas reverse criadas."
}

# Elimina uma zona escolhida
eliminar_zona() {
    read -p "Qual o domínio que pretende eliminar: " DOMINIO
    ZONE_FORWARD_FILE="$ZONES_DIR/${DOMINIO}.hosts"

    # Elimina as entradas PTR e as zonas reverse
    for FILE in "$ZONES_DIR"/*.in-addr.arpa.hosts; do
        if grep -q "PTR.*$DOMINIO\." "$FILE"; then

            # Remove as entradas PTR do domínio
            sed -i "/PTR.*$DOMINIO\./d" "$FILE"
            echo "Entradas PTR de $DOMINIO removidas de $(basename "$FILE")"

            # Se o ficheiro não tiver mais PTR remove o ficheiro e o bloco da zona reverse
            if ! grep -q "PTR" "$FILE"; then
                ZONA_REVERSE=$(basename "$FILE" .hosts)
                rm -f "$FILE"
                sed -i "/zone \"$ZONA_REVERSE\" IN {/,/};/d" "$NAMED_CONF"
                echo "Zona reverse $ZONA_REVERSE e ficheiro $FILE eliminados (sem mais PTRs)."
            fi
        fi
    done

    # Elimina a zona forward
    if [ -f "$ZONE_FORWARD_FILE" ]; then
        rm -f "$ZONE_FORWARD_FILE"
        sed -i "/zone \"$DOMINIO\" IN {/,/};/d" "$NAMED_CONF"
        echo "Zona forward $DOMINIO e ficheiro $ZONE_FORWARD_FILE eliminados."
    fi

    #Elimina o bloco do VirtualHost
    if grep -q "DocumentRoot \"/dominios/$DOMINIO\"" "$HTTPD_CONF"; then
        LINHA_INICIO=$(grep -n "DocumentRoot \"/dominios/$DOMINIO\"" "$HTTPD_CONF" | cut -d: -f1)
        LINHA_FIM=$((LINHA_INICIO + 10))
        echo "Linha Inicial: $LINHA_INICIO | Linha Final: $LINHA_FIM"
        LINHA_CERTA=$((LINHA_INICIO - 1))
        sed -i "${LINHA_CERTA},${LINHA_FIM}d" "$HTTPD_CONF" 
        echo "Bloco VirtualHost do domínio $DOMINIO removido de $HTTPD_CONF."
    fi

    # Eliminar a diretoria do domínio
    rm -rf "$DOMINIOS_DIR/$DOMINIO"
    echo "Diretoria $DOMINIOS_DIR/$DOMINIO eliminada."

    systemctl restart named
    systemctl restart httpd

    echo "Todas as zonas e configurações associadas a $DOMINIO foram eliminadas com sucesso."
}

# Lista todas as zonas criadas
listar_zonas() {
    echo "Zonas definidas:"
    grep "zone \"" "$NAMED_CONF" | awk '{print $2}' | tr -d '"'
}

# Mostra o menu principal com as opções
menu() {
    echo "MENU PRINCIPAL"
    echo "1. Criar zona master e VirtualHost"
    echo "2. Criar zona reverse (requer zona master criada)"
    echo "3. Adicionar registos A ou MX"
    echo "4. Eliminar zona completa"
    echo "5. Listar zonas existentes"
    echo "6. Sair"
    read -p "Escolha a opção: " OPCAO

    case $OPCAO in
        1) criar_zona_master;;
        2) criar_zona_reverse;;
        3) read -p "Introduz o domínio: " DOM; adicionar_registos "$DOM";;
        4) eliminar_zona;;
        5) listar_zonas;;
        6) exit 0;;
        *) echo "Opção inválida";;
    esac
}

while true; do
    menu
done
