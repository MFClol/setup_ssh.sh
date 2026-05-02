#!/bin/bash
# ============================================
# Скрипт установки ELK Stack (Elasticsearch, Logstash, Kibana)
# Версия: 8.17.1
# Используется Яндекс зеркало (доступно из РФ)
# Сервер: 192.168.50.186
# ============================================

set -e  # Остановить скрипт при любой ошибке

# Цвета для красиво оформленного вывода (ANSI коды)
RED='\033[0;31m'      # Красный - для ошибок
GREEN='\033[0;32m'    # Зелёный - для успеха
YELLOW='\033[1;33m'   # Жёлтый - для предупреждений/информации
NC='\033[0m'          # No Color - сброс цвета

# Функция для вывода заголовков
print_header() {
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}============================================${NC}"
}

# Функция для вывода информационных сообщений
print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Функция для вывода сообщений об успехе
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Функция для вывода ошибок
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================
# 1. Обновление системы и установка JDK
# ============================================
print_header "=== 1. Обновление системы и установка JDK ==="

# Отключаем интерактивные запросы (чтобы не спрашивал подтверждение)
export DEBIAN_FRONTEND=noninteractive

# Обновляем список пакетов
print_info "Обновление списка пакетов..."
apt update -qq

# Устанавливаем Java Development Kit (необходим для Elasticsearch)
print_info "Установка JDK (Java Development Kit)..."
apt install -y -qq default-jdk wget curl

print_success "JDK успешно установлен"

# Проверяем версию Java (для отладки)
java -version

# ============================================
# 2. Скачивание пакетов ELK с Яндекс зеркала
# ============================================
print_header "=== 2. Скачивание пакетов ELK с Яндекс зеркала ==="

# Переходим во временную директорию
cd /tmp

# Скачиваем Elasticsearch (движок поиска и хранения данных)
print_info "Скачивание Elasticsearch 8.17.1..."
if wget -q --show-progress https://mirror.yandex.ru/mirrors/elastic/8.17.1/elasticsearch-8.17.1-amd64.deb; then
    print_success "Elasticsearch скачан"
else
    print_error "Не удалось скачать Elasticsearch"
    exit 1
fi

# Скачиваем Logstash (обработчик логов)
print_info "Скачивание Logstash 8.17.1..."
if wget -q --show-progress https://mirror.yandex.ru/mirrors/elastic/8.17.1/logstash-8.17.1-amd64.deb; then
    print_success "Logstash скачан"
else
    print_error "Не удалось скачать Logstash"
    exit 1
fi

# Скачиваем Kibana (веб-интерфейс для визуализации)
print_info "Скачивание Kibana 8.17.1..."
if wget -q --show-progress https://mirror.yandex.ru/mirrors/elastic/8.17.1/kibana-8.17.1-amd64.deb; then
    print_success "Kibana скачана"
else
    print_error "Не удалось скачать Kibana"
    exit 1
fi

# ============================================
# 3. Установка пакетов ELK
# ============================================
print_header "=== 3. Установка пакетов ELK ==="

print_info "Установка Elasticsearch..."
dpkg -i elasticsearch-8.17.1-amd64.deb
print_success "Elasticsearch установлен"

print_info "Установка Logstash..."
dpkg -i logstash-8.17.1-amd64.deb
print_success "Logstash установлен"

print_info "Установка Kibana..."
dpkg -i kibana-8.17.1-amd64.deb
print_success "Kibana установлена"

# ============================================
# 4. Настройка Elasticsearch
# ============================================
print_header "=== 4. Настройка Elasticsearch ==="

# Создаём конфигурационный файл Elasticsearch
# Подробнее: https://www.elastic.co/guide/en/elasticsearch/reference/8.17/settings.html
cat > /etc/elasticsearch/elasticsearch.yml << 'EOF'
# ======================== Elasticsearch Configuration ========================
# Имя кластера (для идентификации)
cluster.name: elk-cluster

# Имя текущего узла
node.name: elk-node

# Пути для хранения данных и логов
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

# Настройки сети: слушаем все интерфейсы, порт 9200
network.host: 0.0.0.0
http.port: 9200

# ========== ОТКЛЮЧЕНИЕ БЕЗОПАСНОСТИ (согласно заданию) ==========
# Используем обычный HTTP, без TLS/SSL, без аутентификации
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

# Настройка начального мастер-узла (для одноузлового кластера)
cluster.initial_master_nodes: ["elk-node"]

# Режим одного узла (для простоты)
discovery.type: single-node
EOF

print_success "Конфигурация Elasticsearch создана"

# Запускаем Elasticsearch
print_info "Запуск Elasticsearch..."
systemctl daemon-reload
systemctl start elasticsearch
systemctl enable elasticsearch

# Ожидаем запуска Elasticsearch (максимум 30 секунд)
print_info "Ожидание запуска Elasticsearch (до 30 секунд)..."
for i in {1..15}; do
    if curl -s http://localhost:9200 > /dev/null 2>&1; then
        print_success "Elasticsearch запущен и отвечает на порту 9200"
        break
    fi
    sleep 2
done

# Проверяем, что Elasticsearch действительно работает
if curl -s http://localhost:9200 > /dev/null 2>&1; then
    print_success "Elasticsearch готов к работе"
else
    print_error "Elasticsearch не запустился! Проверьте: journalctl -u elasticsearch"
    exit 1
fi

# ============================================
# 5. Настройка Kibana
# ============================================
print_header "=== 5. Настройка Kibana ==="

# Создаём конфигурационный файл Kibana
cat > /etc/kibana/kibana.yml << 'EOF'
# ======================== Kibana Configuration ========================
# Порт для веб-интерфейса
server.port: 5601

# Слушаем все интерфейсы (чтобы можно было подключиться из браузера)
server.host: "0.0.0.0"

# Адрес Elasticsearch (локальный, через HTTP)
elasticsearch.hosts: ["http://localhost:9200"]
EOF

print_success "Конфигурация Kibana создана"

# Запускаем Kibana
print_info "Запуск Kibana..."
systemctl start kibana
systemctl enable kibana
print_success "Kibana запущена"

# ============================================
# 6. Настройка Logstash
# ============================================
print_header "=== 6. Настройка Logstash ==="

# Создаём основной конфиг Logstash
cat > /etc/logstash/logstash.yml << 'EOF'
# ======================== Logstash Configuration ========================
# Имя узла
node.name: elk-logstash

# Путь к данным
path.data: /var/lib/logstash

# Директория с конфигурациями пайплайнов
path.config: /etc/logstash/conf.d

# Настройки производительности
pipeline.workers: 2
pipeline.batch.size: 125
pipeline.batch.delay: 50

# Уровень логирования
log.level: info

# Путь к логам Logstash
path.logs: /var/log/logstash

# Отключаем проверку конфига при запуске
config.test_and_exit: false

# Отключаем автоматическую перезагрузку конфигов
config.reload.automatic: false
EOF

# Создаём директорию для конфигов пайплайнов
mkdir -p /etc/logstash/conf.d

# Создаём конфиг для обработки логов nginx
cat > /etc/logstash/conf.d/logstash-nginx-es.conf << 'EOF'
# ======================== Logstash Pipeline: Nginx Logs ========================
# 
# Этот пайплайн:
# 1. Принимает данные от Filebeat на порту 5400
# 2. Парсит логи nginx с помощью GROK
# 3. Конвертирует типы данных
# 4. Отправляет в Elasticsearch
#

# Входные данные: слушаем порт 5400 для соединений от Filebeat
input {
    beats {
        port => 5400
    }
}

# Фильтрация и обработка данных
filter {
    # Разбор строки лога nginx с использованием шаблона COMBINEDAPACHELOG
    # Этот шаблон распознает стандартный формат логов nginx:
    # IP - - [дата] "METHOD /path HTTP/1.1" код ответа байты "referer" "user-agent"
    grok {
        match => [ "message" , "%{COMBINEDAPACHELOG}+%{GREEDYDATA:extra_fields}" ]
        overwrite => [ "message" ]
    }
    
    # Конвертация полей в нужные типы данных
    mutate {
        convert => ["response", "integer"]      # Код ответа HTTP (200, 404, ...)
        convert => ["bytes", "integer"]         # Размер ответа в байтах
        convert => ["responsetime", "float"]    # Время ответа (если есть)
    }
    
    # Обработка временной метки
    date {
        match => [ "timestamp" , "dd/MMM/YYYY:HH:mm:ss Z" ]
        remove_field => [ "timestamp" ]         # Удаляем оригинальное поле
    }
    
    # Парсинг User-Agent (браузер, ОС, устройство)
    useragent {
        source => "agent"
    }
}

# Выходные данные: отправляем в Elasticsearch и выводим в консоль
output {
    # Отправка в Elasticsearch (локальный, HTTP, без TLS)
    elasticsearch {
        hosts => ["http://localhost:9200"]
        # Индекс с динамическим именем (по дате)
        index => "weblogs-%{+YYYY.MM.dd}"
    }
    # Вывод в консоль для отладки (можно закомментировать после проверки)
    stdout { codec => rubydebug }
}
EOF

print_success "Конфигурация Logstash создана"

# Запускаем Logstash
print_info "Запуск Logstash..."
systemctl start logstash
systemctl enable logstash
print_success "Logstash запущен"

# ============================================
# 7. Настройка UFW (межсетевой экран)
# ============================================
print_header "=== 7. Настройка UFW (межсетевой экран) ==="

# Устанавливаем UFW (Uncomplicated Firewall) если не установлен
apt install -y ufw

# Разрешаем SSH (ОБЯЗАТЕЛЬНО! иначе потеряем доступ к серверу)
print_info "Разрешение SSH (порт 22)..."
ufw allow 22/tcp comment 'SSH'

# Разрешаем Kibana (веб-интерфейс)
print_info "Разрешение Kibana (порт 5601)..."
ufw allow 5601/tcp comment 'Kibana Web UI'

# Разрешаем Logstash (приём логов от Filebeat)
print_info "Разрешение Logstash (порт 5400)..."
ufw allow 5400/tcp comment 'Logstash Beats input'

# Включаем UFW (автоматически отвечаем "y" на запрос подтверждения)
print_info "Включение UFW..."
echo "y" | ufw enable

# Показываем статус правил
ufw status verbose
print_success "UFW настроен и включён"

# ============================================
# 8. Проверка работоспособности
# ============================================
print_header "=== 8. Проверка работоспособности ==="

# Небольшая пауза для полного запуска всех сервисов
sleep 5

# Проверяем статус Elasticsearch
echo -e "\n${GREEN}--- Статус Elasticsearch ---${NC}"
if systemctl is-active --quiet elasticsearch; then
    print_success "Elasticsearch: АКТИВЕН"
    curl -s http://localhost:9200 | head -3
else
    print_error "Elasticsearch: НЕ АКТИВЕН"
fi

# Проверяем статус Kibana
echo -e "\n${GREEN}--- Статус Kibana ---${NC}"
if systemctl is-active --quiet kibana; then
    print_success "Kibana: АКТИВНА"
else
    print_error "Kibana: НЕ АКТИВНА"
fi

# Проверяем статус Logstash
echo -e "\n${GREEN}--- Статус Logstash ---${NC}"
if systemctl is-active --quiet logstash; then
    print_success "Logstash: АКТИВЕН"
else
    print_error "Logstash: НЕ АКТИВЕН"
fi

# Проверяем открытые порты
echo -e "\n${GREEN}--- Проверка открытых портов ---${NC}"
ss -tlnp | grep -E ':(9200|5400|5601)' || print_info "Порты не найдены (возможно, сервисы ещё запускаются)"

# ============================================
# 9. Итоговая информация
# ============================================
print_header "=== УСТАНОВКА ELK УСПЕШНО ЗАВЕРШЕНА ==="

# Получаем IP-адрес сервера
SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}ELK Stack установлен и настроен!${NC}"
echo ""
echo -e "${YELLOW}Доступ к сервисам:${NC}"
echo "  • Kibana (веб-интерфейс):  http://${SERVER_IP}:5601"
echo "  • Elasticsearch (API):      http://${SERVER_IP}:9200"
echo "  • Logstash (приём логов):   ${SERVER_IP}:5400"
echo ""
echo -e "${YELLOW}Полезные команды для отладки:${NC}"
echo "  # Просмотр логов сервисов"
echo "  journalctl -u elasticsearch -f"
echo "  journalctl -u logstash -f"
echo "  journalctl -u kibana -f"
echo ""
echo "  # Проверка индексов в Elasticsearch"
echo "  curl http://localhost:9200/_cat/indices"
echo ""
echo "  # Проверка правил UFW"
echo "  ufw status verbose"
echo ""
echo -e "${YELLOW}Дальнейшие шаги:${NC}"
echo "  1. Откройте в браузере Kibana: http://${SERVER_IP}:5601"
echo "  2. Настройте Index Pattern: Management → Index Patterns → Create"
echo "  3. Введите 'weblogs-*' и выберите '@timestamp'"
echo "  4. На сервере с nginx установите Filebeat (отдельный скрипт)"
