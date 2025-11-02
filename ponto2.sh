    #!/bin/bash

    # Função para criar partilha
    criar_partilha() {
        while true; do
            read -p "Insira o nome da partilha: " PART_NAME

            # Verifica se o nome tem apenas letras e números
            if [[ "$PART_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
                echo "Nome válido: $PART_NAME"
                break
            else
                echo "Nome inválido!"
            fi
        done
        read -p "Insira o caminho para a partilha (ex: /script): " SHARE_PATH
        read -p "Insira o nome do utilizador que terá acesso: " USERNAME

        # Verifica se os parâmetros foram fornecidos
        if [ -z "$PART_NAME" ] || [ -z "$SHARE_PATH" ] || [ -z "$USERNAME" ]; then
            echo "Nome da partilha, caminho e utilizador são obrigatórios."
            return
        fi

        # Verifica se o utilizador já existe e cria se nao existir
        if ! id "$USERNAME" &>/dev/null; then
            useradd -m -s /bin/bash "$USERNAME"
            echo "$USERNAME:$USERNAME" | chpasswd
        fi

        # Cria diretoria da partilha se não existir
        mkdir -p "$SHARE_PATH"
        chown "$USERNAME":"$USERNAME" "$SHARE_PATH"
        chmod 770 "$SHARE_PATH"


        # Adiciona o utilizador ao Samba com password igual ao username
        (echo "$USERNAME"; echo "$USERNAME") | smbpasswd -a "$USERNAME"
        smbpasswd -e "$USERNAME"

        if ! sudo pdbedit -L | grep -q "^root:"; then
            (echo "admin"; echo "admin") | smbpasswd -a root
            smbpasswd -e root
        fi

        # Adiciona a partilha ao smb.conf
        echo -e "\n[$PART_NAME]\n\tpath = $SHARE_PATH\n\tavailable = yes\n\tvalid users = $USERNAME root\n\tread only = no" | tee -a /etc/samba/smb.conf > /dev/null

        echo "$PART_NAME:$USERNAME" | tee -a /etc/samba/.usersamba > /dev/null

        # Reinicia o serviço Samba
        systemctl restart smb
        echo "Partilha '$PART_NAME' criada com sucesso para o utilizador '$USERNAME'."
    }

    # Função para eliminar partilha
    eliminar_partilha() {

        # Valida o nome da partilha até que seja válido
        while true; do
        read -p "Insira o nome da partilha que pretende eliminar: " PART_NAME

        # Verifica se o nome tem apenas letras e números
            if [[ "$PART_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
                # Verifica se a partilha existe no ficheiro smb.conf
                if grep -q "\[$PART_NAME\]" /etc/samba/smb.conf; then
                    echo "Nome válido: $PART_NAME"
                    break
                else
                    echo "A partilha '$PART_NAME' não existe. Insira um nome válido."
                fi
            else
                echo "Nome inválido! Só pode conter letras e números."
            fi
        done

        # Remove a partilha do smb.conf
        sed -i "/\[$PART_NAME\]/,+4d" /etc/samba/smb.conf

        # Atualiza o ficheiro .usersamba
        sed -i "s|^$PART_NAME:|:|g" /etc/samba/.usersamba

        # Reinicia o serviço Samba
        systemctl restart smb
        systemctl restart nmb
        echo "Partilha '$PART_NAME' eliminada com sucesso."
    }

    # Função para alterar partilha
    alterar_partilha() {

        # Valida o nome da partilha até que seja válido
        while true; do
            while true; do
                read -p "Insira o nome da partilha: " PART_NAME
            
                # Verifica se o nome contém apenas letras e números
                if [[ "$PART_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
                    echo "Nome válido: $PART_NAME"
                    break
                else
                    echo "Nome inválido! Só pode conter letras e números (sem espaços ou símbolos). Tente novamente."
                fi
            done

            # Verifica se a partilha existe no arquivo smb.conf
            if ! grep -q "\[$PART_NAME\]" /etc/samba/smb.conf; then
                echo "A partilha '$PART_NAME' não existe. Insira um nome válido."
            else
                break
            fi
        done

        read -p "Insira o novo nome para a partilha: " NEW_PART_NAME
        read -p "Insira o novo caminho para a partilha (se pretender mudar): " NEW_PATH

        # Verifica se os valores foram fornecidos
        if [ -z "$PART_NAME" ] || [ -z "$NEW_PART_NAME" ]; then
            echo "O nome da partilha e novo nome são obrigatórios."
            return
        fi

        # Se o novo caminho for fornecido e não começar com '/', adicionar '/'
        if [ ! -z "$NEW_PATH" ]; then
            if [[ "$NEW_PATH" != /* ]]; then
                NEW_PATH="/$NEW_PATH"
            fi
        fi

        # Altera a configuração da partilha no arquivo smb.conf
        sed -i "/\[$PART_NAME\]/,/^$/s|\[$PART_NAME\]|[$NEW_PART_NAME]|" /etc/samba/smb.conf

        if [ ! -z "$NEW_PATH" ]; then
            sed -i "/\[$NEW_PART_NAME\]/,/^$/s|^\tpath = .*|\tpath = $NEW_PATH|" /etc/samba/smb.conf
        fi

        # Atualiza o ficheiro .usersamba
        sed -i "s|^$PART_NAME:|$NEW_PART_NAME:|g" /etc/samba/.usersamba

        # Reinicia o serviço Samba
        systemctl restart smb
        systemctl restart nmb
        echo "Partilha '$PART_NAME' alterada para '$NEW_PART_NAME' com sucesso."
    }

    # Função para desativar partilha
    desativar_partilha() {

        # Valida o nome da partilha até que seja válido
        while true; do
            read -p "Insira o nome da partilha que pretende desativar: " PART_NAME

            # Verifica se o nome tem apenas letras e números
            if [[ "$PART_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
                echo "Nome válido: $PART_NAME"
                break
            else
            
                # Verifica se a partilha existe
                if ! grep -q "\[$PART_NAME\]" /etc/samba/smb.conf; then
                    echo "A partilha '$PART_NAME' não existe no arquivo smb.conf. Insira um nome válido."
                else
                    break
                fi
            fi
        done

        # Desativa a partilha no smb.conf
        sed -i "/\[$PART_NAME\]/,+4s/available = yes/available = no/" /etc/samba/smb.conf

        # Reinicia o serviço SAMBA para aplicar mudanças
        systemctl restart smb
        systemctl restart nmb
        echo "Partilha '$PART_NAME' desativada com sucesso."
    }

    # Função para montar partilha do Windows
    montar_partilha() {
        read -p "Insira o nome da partilha do Windows (ex: 192.168.1.96/PartilhaTest): " WINDOWS_SHARE
        read -p "Insira o ponto de montagem no Linux (ex: /mnt/testeWindows): " MOUNT_POINT
        read -p "Insira o nome de utilizador para autenticação do Windows: " USER

        if [ -z "$WINDOWS_SHARE" ] || [ -z "$MOUNT_POINT" ] || [ -z "$USER" ]; then
            echo "A partilha e ponto de montagem são obrigatórios."
            return
        fi

        # Cria a diretoria de montagem se não existir
        mkdir -p "$MOUNT_POINT"

        read -s -p "Insira a palavra-passe para autenticação do Windows: " PASS
        echo ""
        mount -t cifs "//$WINDOWS_SHARE" "$MOUNT_POINT" -o username="$USER",password="$PASS"
        

        # Verifica se a montagem foi bem-sucedida
        if mount | grep -q "$MOUNT_POINT"; then
            echo "Partilha montada com sucesso em '$MOUNT_POINT'."
        else
            echo "Erro ao montar a partilha."
        fi
    }


    # Função para mostrar as partilhas ativas
    listar_partilhas() {
        echo "Partilhas ativas no servidor Samba:"

        # Itera por todas as partilhas no arquivo smb.conf
        while read -r linha; do
            # Verifica se encontrou um nome de partilha
            if [[ "$linha" =~ ^\[(.*)\]$ ]]; then
                nome_partilha="${BASH_REMATCH[1]}"
            fi

            # Verifica se a linha corresponde a 'available = no'
            if [[ "$linha" =~ ^[[:space:]]*available[[:space:]]*=[[:space:]]*no ]]; then
                # Marca como desativada
                ativo=false
            fi

            # Se encontrar 'available = yes', marca como ativa
            if [[ "$linha" =~ ^[[:space:]]*available[[:space:]]*=[[:space:]]*yes ]]; then
                ativo=true
            fi

            # Quando chegar ao fim da configuração de uma partilha, verificar se está ativa
            if [[ "$linha" =~ ^[[:space:]]*read[[:space:]]*only ]]; then
                if [ "$ativo" = true ]; then
                    echo "$nome_partilha"
                fi
            fi
        done < /etc/samba/smb.conf
    }

    # Função de menu
    menu() {
        echo "Menu de Configuração do Samba"
        echo "1) Criar Partilha"
        echo "2) Eliminar Partilha"
        echo "3) Alterar Partilha"
        echo "4) Desativar Partilha"
        echo "5) Montar Partilha do Windows"
        echo "6) Listar Partilhas Ativas"
        echo "7) Sair"
        read -p "Escolha a opção: " OPCAO


        case $OPCAO in
            1) criar_partilha ;;
            2) eliminar_partilha ;;
            3) alterar_partilha ;;
            4) desativar_partilha ;;
            5) montar_partilha ;;
            6) listar_partilhas ;;
            7) exit 0 ;;
            *) echo "Opção inválida";;
        esac
    }

    while true; do
        menu
    done
