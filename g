lang: python 3.12
deps: python-telegram-bot playwright aiosqlite
env: NONE
run: pip install -r requirements.txt && playwright install chromium && python bot.py
file: bot.py
import asyncio
import logging
import sqlite3
from pathlib import Path
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
from playwright.async_api import async_playwright
logging.basicConfig(level=logging.INFO)
PROFILES_DIR = Path("browser_profiles")
PROFILES_DIR.mkdir(exist_ok=True)
def init_db():
conn = sqlite3.connect("youtube_bot.db")
cursor = conn.cursor()
cursor.execute("""
CREATE TABLE IF NOT EXISTS accounts (
id INTEGER PRIMARY KEY AUTOINCREMENT,
email TEXT UNIQUE,
proxy TEXT,
status TEXT DEFAULT 'added'
)
""")
conn.commit()
conn.close()
init_db()
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
keyboard = [
[InlineKeyboardButton("1. Аккаунты и прокси", callback_data="tab_accounts")],
[InlineKeyboardButton("2. Редактирование профиля", callback_data="tab_profile")],
[InlineKeyboardButton("3. Автовыгрузка видео", callback_data="tab_upload")]
]
await update.message.reply_text("Главное меню управления YouTube:", reply_markup=InlineKeyboardMarkup(keyboard))
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
query = update.callback_query
await query.answer()
if query.data == "tab_accounts":
keyboard = [
[InlineKeyboardButton("➕ Добавить аккаунт + прокси", callback_data="add_acc_proxy")],
[InlineKeyboardButton("📋 Список аккаунтов", callback_data="list_acc")],
[InlineKeyboardButton("🔙 Главное меню", callback_data="main_menu")]
]
await query.message.edit_text("Управление аккаунтами и прокси:", reply_markup=InlineKeyboardMarkup(keyboard))
elif query.data == "tab_profile":
await query.message.edit_text("Редактирование профилей: выберите аккаунты для массового или одиночного изменения (аватар, имя, описание).")
elif query.data == "tab_upload":
await query.message.edit_text("Автовыгрузка: укажите видеофайл, описание, теги и задержку между публикациями.")
elif query.data == "add_acc_proxy":
await query.message.reply_text("Отправь данные в формате:\n⁠email | ip:port:login:pass⁠", parse_mode="Markdown")
context.user_data["state"] = "awaiting_acc_proxy"
elif query.data == "main_menu":
keyboard = [
[InlineKeyboardButton("1. Аккаунты и прокси", callback_data="tab_accounts")],
[InlineKeyboardButton("2. Редактирование профиля", callback_data="tab_profile")],
[InlineKeyboardButton("3. Автовыгрузка видео", callback_data="tab_upload")]
]
await query.message.edit_text("Главное меню управления YouTube:", reply_markup=InlineKeyboardMarkup(keyboard))
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
state = context.user_data.get("state")
text = update.message.text.strip()
if state == "awaiting_acc_proxy":
if "|" in text:
parts = text.split("|")
email = parts[0].strip()
proxy_str = parts[1].strip()
conn = sqlite3.connect("youtube_bot.db")
cursor = conn.cursor()
try:
cursor.execute("INSERT INTO accounts (email, proxy) VALUES (?, ?)", (email, proxy_str))
conn.commit()
await update.message.reply_text(f"Аккаунт {email} добавлен. Запускаю браузер для авторизации...")
asyncio.create_task(run_browser_auth(email, proxy_str, update))
except Exception as e:
await update.message.reply_text(f"Ошибка: {e}")
finally:
conn.close()
else:
await update.message.reply_text("Неверный формат. Используй ⁠email | ip:port:login:pass⁠", parse_mode="Markdown")
context.user_data["state"] = None
async def run_browser_auth(email: str, proxy_str: str, update: Update):
p_parts = proxy_str.split(":")
server = f"http://{p_parts[0]}:{p_parts[1]}"
proxy_config = {"server": server}
if len(p_parts) >= 4:
proxy_config["username"] = p_parts[2]
proxy_config["password"] = p_parts[3]
user_data_dir = PROFILES_DIR / email.replace("@", "at")
async with async_playwright() as p:
browser = await p.chromium.launch_persistent_context(
user_data_dir=user_data_dir,
headless=False,
proxy=proxy_config
)
page = await browser.new_page()
try:
await page.goto("https://accounts.google.com")
await page.fill('input[type="email"]', email)
await page.click('#identifierNext')
await update.message.reply_text(f"Браузер открыт для {email}. Завершите вход вручную, введите код подтверждения, если потребуется.")
except Exception as e:
logging.error(f"Auth error: {e}")
def main():
token = "8911070749:AAHuVflIROa2f8bICeI7N9nZMCX_5buNCjM"
app = Application.builder().token(token).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button_handler))
app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
app.run_polling()
if name == "main":
main()
file: requirements.txt
python-telegram-bot>=20.0
playwright>=1.40.0
aiosqlite>=0.19.0
