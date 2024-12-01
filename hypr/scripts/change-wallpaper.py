import os
import subprocess
import tkinter as tk
from tkinter import messagebox, scrolledtext
import json
from subprocess import Popen, PIPE

def get_monitors():
    try:
        # Получаем информацию о мониторах в формате JSON
        result = subprocess.run(['hyprctl', '-j', 'monitors'], capture_output=True, text=True)
        monitors_info = json.loads(result.stdout.strip())
        # Извлекаем имена мониторов
        monitor_names = [monitor['name'] for monitor in monitors_info]
        return monitor_names
    except Exception as e:
        messagebox.showerror("Ошибка", f"Не удалось получить информацию о мониторах: {e}")
        return None

def select_file():
    try:
        # Запускаем Thunar с возможностью выбора файла
        process = Popen(['zenity', '--file-selection', '--title=Выберите изображение', '--file-filter=*.jpg *.jpeg *.png *.gif *.bmp'], stdout=PIPE, stderr=PIPE)
        output, error = process.communicate()
        
        # Если файл выбран (пользователь не нажал отмену)
        if process.returncode == 0:
            filename = output.decode().strip()
            # Очищаем текстовое поле и вставляем новый путь
            wallpaper_text.delete('1.0', tk.END)
            wallpaper_text.insert('1.0', filename)
    except Exception as e:
        messagebox.showerror("Ошибка", f"Не удалось открыть файловый менеджер: {e}")

def set_wallpaper():
    new_wallpaper = wallpaper_text.get("1.0", tk.END).strip()
    if not os.path.isfile(new_wallpaper):
        messagebox.showerror("Ошибка", "Указанный файл не существует.")
        return

    monitor_names = get_monitors()
    if monitor_names is None:
        return

    # Записываем конфигурацию в файл
    hyprpaper_conf_file = os.path.expanduser('~/.config/hypr/hyprpaper.conf')
    try:
        with open(hyprpaper_conf_file, 'w') as file:
            file.write(f"preload={new_wallpaper}\n")
            for monitor_name in monitor_names:
                file.write(f"wallpaper={monitor_name}, {new_wallpaper}\n")

        # Убиваем процесс hyprpaper, если он запущен
        subprocess.run(['killall', 'hyprpaper'])
        # Запускаем hyprpaper с новой конфигурацией
        subprocess.run(["hyprctl", "dispatch", "exec", "hyprpaper"])

        # Автоматический запуск скрипта update-hyprlock.py
        update_hyprlock_script = os.path.expanduser("~/.config/hypr/scripts/update-hyprlock.py")  # Укажите путь к скрипту
        subprocess.run(['python3', update_hyprlock_script], check=True)

        messagebox.showinfo("Успех", "Обои успешно установлены и конфигурация Hyprlock обновлена!")
    except Exception as e:
        messagebox.showerror("Ошибка", f"Не удалось записать конфигурацию: {e}")


def select_all(event):
    wallpaper_text.tag_add("sel", "1.0", "end")
    wallpaper_text.mark_set("insert", "end")
    return "break"

# Создаем главное окно
root = tk.Tk()
root.title("Hyprpaper Wallpaper Setter")

# Создаем фрейм для организации элементов
frame = tk.Frame(root)
frame.pack(padx=10, pady=10)

# Создаем метку
label = tk.Label(frame, text="Путь к изображению обоев:")
label.pack(pady=5)

# Создаем горизонтальный фрейм для текстового поля и кнопки выбора файла
input_frame = tk.Frame(frame)
input_frame.pack(fill=tk.X, pady=5)

# Создаем текстовое поле
wallpaper_text = scrolledtext.ScrolledText(input_frame, width=50, height=1, font=("Arial", 18))
wallpaper_text.pack(side=tk.LEFT, expand=True, fill=tk.X)

# Создаем кнопку выбора файла
select_button = tk.Button(frame, text="Выбрать файл", command=select_file)
select_button.pack(pady=10)

# Привязываем сочетание клавиш Ctrl+A к функции выделения текста
wallpaper_text.bind('<Control-a>', select_all)

# Создаем кнопку для установки обоев
set_button = tk.Button(frame, text="Установить обои", command=set_wallpaper)
set_button.pack(pady=10)

# Запускаем главный цикл приложения
root.mainloop()