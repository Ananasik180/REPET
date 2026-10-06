import csv
import logging
import os
import statistics
import sys
from datetime import datetime
from pathlib import Path
import urllib.request
import urllib.parse

# --- Настройка логирования ---
LOG_FILE = Path(__file__).parent / "analyze.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)

# --- Опционально: Telegram ---
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

def send_telegram(text: str):
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        logging.warning("Telegram не настроен — пропускаю отправку.")
        return
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    data = urllib.parse.urlencode({"chat_id": TELEGRAM_CHAT_ID, "text": text}).encode()
    try:
        with urllib.request.urlopen(url, data=data, timeout=10) as resp:
            logging.info("Уведомление отправлено в Telegram.")
    except Exception as e:
        logging.error(f"Ошибка отправки в Telegram: {e}")

def read_students(filename: str):
    students = []
    if not Path(filename).exists():
        logging.error(f"Файл {filename} не найден.")
        return students
    with open(filename, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = (row.get("name") or row.get("Имя") or "").strip()
            score_raw = (row.get("score") or row.get("Балл") or "").strip()
            if not name or not score_raw:
                continue
            try:
                students.append((name, float(score_raw)))
            except ValueError:
                logging.warning(f"Пропущена строка с некорректным баллом: {row}")
    logging.info(f"Загружено учеников: {len(students)}")
    return students

def analyze(students):
    if not students:
        return "Нет данных для анализа."
    scores = [s for _, s in students]
    avg = statistics.mean(scores)
    median = statistics.median(scores)
    below_avg = [name for name, s in students if s < avg]

    lines = [
        f"Отчёт от {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"Всего учеников: {len(students)}",
        f"Средний балл: {avg:.2f}",
        f"Медиана: {median:.2f}",
        f"Минимум: {min(scores)}, Максимум: {max(scores)}",
        f"Ниже среднего ({len(below_avg)}): {', '.join(below_avg) if below_avg else 'нет'}",
    ]
    return "\n".join(lines)

def main():
    logging.info("=== Запуск анализа ===")
    filename = sys.argv[1] if len(sys.argv) > 1 else "results.csv"
    students = read_students(filename)
    report = analyze(students)
    logging.info("Результат:\n" + report)
    send_telegram(report)
    logging.info("=== Завершено ===")

if __name__ == "__main__":
    main()
