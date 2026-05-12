#!/bin/bash
@@ -0,0 +1,125 @@
#!/bin/bash

# Скрипт для установки и настройки SSH-сервера на Ubuntu Server
# Также выводит диагностическую информацию для подключения через PuTTY

set -e  # Прерывать выполнение при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Установка и настройка SSH-сервера ===${NC}"

# 1. Обновление списка пакетов
echo -e "${YELLOW}[1/8] Обновление списка пакетов...${NC}"
apt update -qq

# 2. Установка OpenSSH Server
echo -e "${YELLOW}[2/8] Установка openssh-server...${NC}"
apt install -y openssh-server

# 3. Включение и запуск службы SSH
echo -e "${YELLOW}[3/8] Включение и запуск SSH...${NC}"
systemctl enable ssh --now

# 4. Настройка UFW (если активен)
echo -e "${YELLOW}[4/8] Настройка брандмауэра UFW...${NC}"
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "active"; then
        echo "UFW активен. Разрешаем SSH..."
        ufw allow 22/tcp comment 'OpenSSH'
        ufw reload
    else
        echo "UFW не активен. Пропускаем..."
    fi
else
    echo "UFW не установлен. Пропускаем..."
fi

# 5. Оптимизация конфигурации (ускорение подключения)
echo -e "${YELLOW}[5/8] Настройка параметров SSH...${NC}"
SSHD_CONFIG="/etc/ssh/sshd_config"
if grep -q "^UseDNS" $SSHD_CONFIG; then
    sed -i 's/^UseDNS.*/UseDNS no/' $SSHD_CONFIG
else
    echo "UseDNS no" >> $SSHD_CONFIG
fi

# Запрещаем вход для root (рекомендация безопасности)
if grep -q "^PermitRootLogin" $SSHD_CONFIG; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' $SSHD_CONFIG
else
    echo "PermitRootLogin prohibit-password" >> $SSHD_CONFIG
fi

# 6. Перезапуск SSH для применения изменений
echo -e "${YELLOW}[6/8] Перезапуск SSH...${NC}"
systemctl restart ssh

# 7. Проверка статуса
echo -e "${YELLOW}[7/8] Проверка статуса службы...${NC}"
if systemctl is-active --quiet ssh; then
    echo -e "${GREEN}✓ SSH-сервер успешно запущен${NC}"
else
    echo -e "${RED}✗ Ошибка: SSH-сервер не запущен${NC}"
    exit 1
fi

# 8. Диагностика и вывод информации для подключения
echo -e "${GREEN}=== Диагностическая информация ===${NC}"

# IP-адреса сервера
echo -e "${YELLOW}IP-адреса сервера:${NC}"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | while read ip; do
    if [ "$ip" != "127.0.0.1" ]; then
        echo "  • $ip"
    fi
done

# Порт, который слушает SSH
echo -e "\n${YELLOW}Проверка порта 22:${NC}"
if ss -tlnp | grep -q ":22.*sshd"; then
    echo -e "  ${GREEN}✓ Порт 22 слушается (SSH готов к подключению)${NC}"
else
    echo -e "  ${RED}✗ Порт 22 не слушается${NC}"
fi

# Проверка локального подключения
echo -e "\n${YELLOW}Проверка локального подключения:${NC}"
if ssh -o ConnectTimeout=3 localhost exit 2>/dev/null; then
    echo -e "  ${GREEN}✓ Локальное подключение работает${NC}"
else
    echo -e "  ${RED}✗ Локальное подключение не удалось${NC}"
fi

# Статус брандмауэра (если UFW активен)
if command -v ufw &> /dev/null; then
    echo -e "\n${YELLOW}Статус UFW:${NC}"
    ufw status | grep -q "active" && echo "  UFW активен. Разрешённые порты:" && ufw status | grep -E "22.*ALLOW" || echo "  UFW не активен"
fi

echo -e "\n${GREEN}=== Инструкция для подключения через PuTTY ===${NC}"
echo "1. Введите IP-адрес вашего сервера (один из указанных выше)"
echo "2. Порт: 22"
echo "3. Имя пользователя: ваше текущее имя ($SUDO_USER или $(whoami))"
echo "4. Пароль: пароль этого пользователя"

# Проверка сетевой связности (опционально)
echo -e "\n${YELLOW}=== Советы по устранению неполадок ===${NC}"
echo "• Если соединение не устанавливается (Connection refused):"
echo "    - Убедитесь, что IP-адрес сервера правильный"
echo "    - Проверьте, что SSH-сервер запущен: systemctl status ssh"
echo ""
echo "• Если не проходит ping:"
echo "    - Компьютеры должны быть в одной подсети (первые три цифры IP)"
echo "    - Проверьте брандмауэр: sudo ufw allow 22/tcp"
echo "    - Отключите изоляцию клиентов в настройках роутера"
echo ""
echo "• Если не принимает пароль:"
echo "    - Проверьте раскладку клавиатуры и Caps Lock"
echo "    - Для входа под root нужно сначала разрешить в /etc/ssh/sshd_config"

echo -e "\n${GREEN}Готово! Теперь можно подключаться через PuTTY.${NC}"
echo ""
