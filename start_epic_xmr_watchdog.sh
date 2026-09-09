#!/usr/bin/env bash

# ============================================================
# EPIC + XMR watchdog for SRBMiner-MULTI 3.6.2
# Запускает майнер в screen и автоматически перезапускает его
# после падения/выхода.
# ============================================================

MINER_DIR="$HOME/SRBMiner-Multi-3-6-2"
MINER="$MINER_DIR/SRBMiner-MULTI"
SESSION="epic-xmr"
LOG_FILE="$HOME/epic_xmr_watchdog.log"

# ===== МЕНЯЕШЬ КОЛИЧЕСТВО ПОТОКОВ ЗДЕСЬ =====
CPU_THREADS=120

# Через сколько секунд перезапустить майнер после падения
RESTART_DELAY=10

# EPIC
EPIC_POOL="de.epicmine.io:3333"
EPIC_WALLET="0x692d6d3b0c073.$(hostname -s)"

# XMR / Kryptex
XMR_POOL="xmr-ru.kryptex.network:7029"
XMR_WALLET="83nNrS9oJxHGFJecEoaX7agA4nkDVCyF79EZgnoSkSDGYYTR3SgAXeQLhWMzdrmGau5KL9KvYWgZr2Ph9jmKWd7q1EaCRax/$(hostname -s)"

# ---------- Внутренний режим watchdog ----------
if [[ "${1:-}" == "--watch" ]]; then
    cd "$MINER_DIR" || exit 1

    echo "============================================================" >> "$LOG_FILE"
    echo "Watchdog started: $(date) | host=$(hostname -s) | threads=$CPU_THREADS" >> "$LOG_FILE"

    while true; do
        echo "Miner start: $(date) | threads=$CPU_THREADS" >> "$LOG_FILE"

        sudo -n "$MINER" \
            --disable-gpu \
            --cpu-threads "$CPU_THREADS;$CPU_THREADS" \
            --algorithm 'randomepic;randomx' \
            --pool "$EPIC_POOL;$XMR_POOL" \
            --tls 'false;false' \
            --wallet "$EPIC_WALLET;$XMR_WALLET" \
            --password 'm=pool;x' \
            --keepalive 'true;true' \
            --retry-time 5

        EXIT_CODE=$?
        echo "Miner stopped: $(date) | exit_code=$EXIT_CODE | restart in ${RESTART_DELAY}s" >> "$LOG_FILE"
        sleep "$RESTART_DELAY"
    done
fi

# ---------- Обычный запуск пользователем ----------
if ! command -v screen >/dev/null 2>&1; then
    echo "Ошибка: screen не установлен. Установи: sudo apt install -y screen"
    exit 1
fi

if [[ ! -x "$MINER" ]]; then
    echo "Ошибка: не найден исполняемый майнер:"
    echo "$MINER"
    exit 1
fi

# Не плодим несколько одинаковых watchdog
if screen -ls 2>/dev/null | grep -q "[.]${SESSION}[[:space:]]"; then
    echo "Watchdog уже запущен в screen: $SESSION"
    echo "Посмотреть: screen -r $SESSION"
    exit 0
fi

SCRIPT_PATH="$(readlink -f "$0")"
screen -dmS "$SESSION" bash "$SCRIPT_PATH" --watch
sleep 1

if screen -ls 2>/dev/null | grep -q "[.]${SESSION}[[:space:]]"; then
    echo "Готово. EPIC + XMR watchdog запущен."
    echo "Host:    $(hostname -s)"
    echo "Threads: $CPU_THREADS"
    echo "Screen:  $SESSION"
    echo "Войти:   screen -r $SESSION"
    echo "Лог:     tail -f $LOG_FILE"
else
    echo "Не удалось запустить screen-сессию. Проверь лог: $LOG_FILE"
    exit 1
fi
