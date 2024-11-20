import os
import re

# Путь к файлам конфигурации
hyprpaper_conf_path = os.path.expanduser('~/.config/hypr/hyprpaper.conf')  # Убедитесь, что путь правильный
hyprlock_conf_path = os.path.expanduser('~/.config/hypr/hyprlock.conf')    # Убедитесь, что путь правильный

def get_preload_path():
    with open(hyprpaper_conf_path, 'r') as file:
        for line in file:
            # Ищем строку с preload
            if line.startswith('preload'):
                # Извлекаем путь к изображению
                return line.split('=')[1].strip()
    return None

def update_hyprlock_conf(preload_path):
    updated = False
    with open(hyprlock_conf_path, 'r') as file:
        content = file.readlines()

    # Обновляем строку с path
    for i, line in enumerate(content):
        if re.match(r'^\s*path\s*=', line):  # Используем регулярное выражение для поиска строки path с учетом пробелов
            print(f"Обнаружена строка path: {line.strip()}")  # Отладочная информация
            content[i] = f'    path = {preload_path}\n'  # Обновляем путь
            updated = True

    if updated:
        # Записываем изменения обратно в файл
        with open(hyprlock_conf_path, 'w') as file:
            file.writelines(content)
        print(f"Обновлен path в hyprlock.conf на: {preload_path}")
    else:
        print("Строка path не найдена для обновления.")

if __name__ == "__main__":
    preload_path = get_preload_path()
    if preload_path:
        update_hyprlock_conf(preload_path)
    else:
        print("Не удалось найти preload в hyprpaper.conf.")
