#!/bin/bash

# Заголовок письма
report_header="Report for $(date +'%Y-%m-%d %H:%M:%S')"

# Создание разделителей для отчета
report_separator="----------------------------------------"

# Создание тела отчета

# новый файл блокировки, будет создан
lockfile="//home/pt/vagrant/send_mail/bush.lock" 

# Оформляем блокировку одновременного запуска 
if [ -e ${lockfile} ] && kill -0 `cat ${lockfile}`; then
    echo "Script is already running"
    exit 1
fi
trap "rm -f ${lockfile}; exit" INT TERM EXIT                      # устанавливает обработчики сигналов для скрипта
echo $$ > ${lockfile}                                             # выводит идентификатор текущего процесса (PID)

# Переменные
log_file="/home/pt/vagrant/send_mail/auth.log"                    # Файл с логами
log_file_actual="/home/pt/vagrant/send_mail/auth_actual_time.log" # Время логов, которые актуальны с последнего запуска 
delimiter=" - - "                                                 # Разделитель для парсинга IP
error_nomber=0                                                    # Переменная для подсчета ошибок 
report_separator="----------------------------------------"       # Разделитель для письма  

# Артефакты отладки, пускай будут
##echo "Актуальные данные на $(date)" > /home/pt/vagrant/send_mail/anser_code_pool.txt # записываем в файл текущую дату, причем, перезаписываем файл. так мы удалим прошлые результаты
##echo "Актуальные данные на $(date)" > /home/pt/vagrant/send_mail/ip_puul.txt
##echo "Актуальные данные на $(date)" > /home/pt/vagrant/send_mail/domain_pool.txt
##echo "Актуальные данные на $(date)" > /home/pt/vagrant/send_mail/error_log.txt

# Опустошаем файлы перед запуском скрипта
> /home/pt/vagrant/send_mail/anser_code_pool.txt 
> /home/pt/vagrant/send_mail/ip_puul.txt
> /home/pt/vagrant/send_mail/domain_pool.txt
> /home/pt/vagrant/send_mail/error_log.txt
> /home/pt/vagrant/send_mail/auth_actual_time.log # удалить все из файла

# Начинаем цикл построчного чтения файла с логами
while read -r line; do

  # Получаем дату, парся строку и по регулярке находя нужное
  date_time=$(echo "${line}" | grep -oE '[0-9]{2}/[a-zA-Z]{3}/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}')
  
  # Переделываем под более удобный формат для нас (иначе потом не считаются секунды)
  date_time_new=$(echo "${date_time}" | sed 's/\// /g' | sed 's/:/ /' | awk '{print $1, $2, $3, $4, $5, $6}')


# Я не помню, зачем так сделал...
log_time="${date_time_new}"
last_time="${log_time}"

# Переводим дату в секунды для будущего сравнения
log_time_seconds=$(date -d "$log_time" +%s)

# подтягиваем время последнего запуска скрипта из глобал переменной 
source /etc/profile 
##echo $current_time

# Сравниваем время из логов и временем последнего запуска (оно записывается в глобал переменную)
if [ "$current_time" -gt "$log_time_seconds" ]; then
    # Не делаем ничего
    #echo "Log time is earlier than current time"
    echo "$report_header" > /dev/null
else
    # это работает, но по всему тексту, а мне надо тольно по одной строке, раз уж я в цикле 
    # awk -F"${delimiter}" '{print $1}' "${log_file}" #>> /home/pt/vagrant/send_mail/ip_puul.txt 
    
    ip=$(echo "${line}" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')                    # получаем IP из строки
    echo "${ip}" >> /home/pt/vagrant/send_mail/ip_puul.txt                                              # записываем его в файл
    get3=$(echo "${line}" | grep -oE '(GET|POST) /([^"]*)' | grep -oE '.*HTTP\/[0-9]\.[0-9]')           # получаем строку с запросом 
    get2=$(echo "${get3}" | awk -F'HTTP/1.1' '{print $1}')                                              # убираем HTTP/1.1
    get1=$(echo "${get2}" | sed 's/^GET \//\//' | sed 's/^POST \//\//')                                 # убираем метод get или post

    echo "${get1}" >> /home/pt/vagrant/send_mail/domain_pool.txt                                        # Полученный домен записываем в файл
    echo "${log_time}" >> /home/pt/vagrant/send_mail/auth_actual_time.log                               # Полученное время записываем в файл
    echo "${line}" | awk '{print $9}' >> /home/pt/vagrant/send_mail/anser_code_pool.txt                 # Полученный код ответа записываем в файл
    
    anser_code=$(echo "${line}" | awk '{print $9}')                                                     # Сохраняем код в переменную
fi

# Снова проверяем время логов
if [ "$current_time" -gt "$log_time_seconds" ]; then 
    echo "$report_header" > /dev/null
elif [ "$anser_code" -eq 404 ]; then                                                                    # Смотрим, равен ли код ответа известному коду ошибки
    error_nomber=$((error_nomber + 1))                                                                  # Считаем количество
    echo "${line}" >> /home/pt/vagrant/send_mail/error_log.txt                                          # Дозаписываем в файл лог с ошибкой
fi
 
#awk -F"${delimiter}" '{print $1}' "${log_file}" >> /home/pt/vagrant/send_mail/ip_puul.txt              # Артефакты отладки, пускай будут
  
done < "${log_file}" # вот тут мы ссылаемся на файл, чтобы цикл отработал 

# берем первую строку из нового файла с теми датами, которые старше времени запуска скрипта
first_line2=$(head -n 1 ${log_file_actual}) 

# корректируем время 
date_time_log_first2=$(echo $(date -d "${first_line2} + 1 hours" "+%d/%b/%Y:%H:%M:%S")) 

# берем ПРЕД ПОСЛЕДНЮЮ строку из нового файла с теми датами, которые старше времени запуска скрипта
last_line=$(tail -n 2 ${log_file_actual}) 

# корректируем время 
date_time_log_last=$(echo $(date -d "${last_line} + 1 hours" "+%d/%b/%Y:%H:%M:%S")) 

##echo "Обработанный временной диапазон логов: ${date_time_log_first2} - ${date_time_log_last}"

#echo "$(grep -v '^[[:space:]]*$' /home/pt/vagrant/send_mail/anser_code_pool.txt | sort | uniq -c)" | head -n 3 # эта штука тоже работает

# Это отладка, пускай останется
# Полученный домен записываем в файл
#echo "$(sort -nk1,1 /home/pt/vagrant/send_mail/anser_code_pool.txt | uniq -c | sort -nrk1,1)" | head -n 3 >> /home/pt/vagrant/send_mail/1.txt
# Полученное время записываем в файл
#echo "$(sort -nk1,1 /home/pt/vagrant/send_mail/ip_puul.txt | uniq -c | sort -nrk1,1)" | head -n 4 >> /home/pt/vagrant/send_mail/1.txt
# Полученный код ответа записываем в файл
#echo "$(sort -nk1,1 /home/pt/vagrant/send_mail/domain_pool.txt | uniq -c | sort -nrk1,1)" | head -n 4 >> /home/pt/vagrant/send_mail/1.txt


echo "current_time=$(date +"%s")" > /home/pt/vagrant/send_mail/my_global_variable.txt # Записываем текущее время в секундах в глобал переменную ЗАКОМЕНТИТЬ ДЛЯ ДЕБАГА

# удаляет файл блокировки
rm -f ${lockfile} 

# адрес электронной почты для отправки отчета
email="some_mail@mail.ru"

# Отправка отчета по электронной почте
{
  echo "$report_header"
  echo "$report_separator"
  echo "Администратор, привет!"
  echo "Это письмо ты получил, так как я написал скрипт, "
  echo "который анализирует логи и делает по ним легкую статистику."
  echo "$report_separator"
  echo "Сам файл логов лежит тут: ${log_file}"
  echo "В этой же директории лежат файлы для работы скрипта"
  echo "Отрабатывает раз в час"
  echo "Если хочешь изменить периодичность, вызови crontab -e"
  echo "Например, вот раз в минуту */1 * * * * /home/pt/vagrant/send_mail/cron.sh"
  echo "$report_separator"
  echo "Учитывает только логи, которые пришли после последнего запуска скрипта"
  echo "за это отвечает строка echo current_time=\$(date +%s)"
  echo "$report_separator"
  echo "Блокируется для одновременного запуска нескольких копий"
  echo "за это отвечает файл ${lockfile}"
  echo "$report_separator"
  echo "Теперь по делу:"
  echo " "
  echo "Обработанный временной диапазон логов: ${date_time_log_first2} - ${date_time_log_last}"
  echo "Я надеюсь, логи у тебя пишутся последовательно, а не вперемешку"
  echo " "
  echo "Самые частые IP-адреса:"
  echo "--Колич Адрес---------"
  echo "$(sort -nk1,1 /home/pt/vagrant/send_mail/ip_puul.txt | uniq -c | sort -nrk1,1)" | head -n 4 
  echo " "
  echo "Самые популярные домены:"
  echo "--Колич Домен---------"
  echo "$(sort -nk1,1 /home/pt/vagrant/send_mail/domain_pool.txt | uniq -c | sort -nrk1,1)" | head -n 4
  echo " "
  echo "Самые популярные коды ответов:"
  echo "--Колич Код-----------"
  echo "$(sort -nk1,1 /home/pt/vagrant/send_mail/anser_code_pool.txt | uniq -c | sort -nrk1,1)" | head -n 3
  echo " "
  echo "Количество шибок веб-сервера/приложения c момента последнего запуска: ${error_nomber}"
  echo "Все логи с ошибками смотри в error_log.txt"
} | mail -s "Report" "$email" # Отправляем письмо
